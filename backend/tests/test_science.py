"""Ciências: extração da build, agregação, pontuação, patch e a coleta inteira."""

import asyncio
from collections import Counter
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx

from app.science.aggregate import Aggregator, BuildStats, ChampionStats
from app.science.collect import StaticData, is_monochamp, run
from app.science.extract import champion_games, extract_build
from app.science.items import ItemCatalog
from app.science.patch_diff import PatchChanges, diff_champions, diff_items
from app.science.riot import RateLimiter, ScienceRiot
from app.science.scoring import max_order, pick_sciences, wilson_lower_bound
from app.science.store import Monochamp
from fake_science_store import InMemoryScienceStore

NOW = datetime(2026, 11, 26, 12, tzinfo=UTC)
MALPHITE, JINX = 54, 222


def item(name: str, gold: int, tags: list[str], depth: int = 3, **extra: Any) -> dict[str, Any]:
    return {"name": name, "gold": {"total": gold, "purchasable": True}, "tags": tags,
            "maps": {"11": True}, "depth": depth, "stats": {}, **extra}


ITEMS: dict[str, Any] = {
    "1001": item("Botas", 300, ["Boots"], depth=1, into=["3020"]),
    "3020": item("Sapatos do Feiticeiro", 1100, ["Boots", "MagicPenetration"], depth=2, **{"from": ["1001"]}),
    "3175": item("Sapatos Enfeitiçados", 1100, ["Boots"], depth=3, **{"from": ["3020"]}),
    "1052": item("Tomo Amplificador", 400, ["SpellDamage"], depth=1, into=["3089"]),
    "3089": item("Capuz da Morte", 3600, ["SpellDamage"]),
    "3157": item("Ampulheta de Zhonya", 3250, ["SpellDamage", "Armor"]),
    "6653": item("Tormento de Liandry", 3000, ["SpellDamage", "Health"]),
    "3031": item("Gume do Infinito", 3450, ["CriticalStrike", "Damage"]),
    "3068": item("Égide de Fogo Solar", 2700, ["Health", "Armor"]),
    "3075": item("Armadura de Espinhos", 2450, ["Armor", "Health"]),
    "2003": item("Poção de Vida", 50, ["Consumable"], depth=1),
}
CATALOG = ItemCatalog.from_ddragon(ITEMS)


def player(puuid: str, champion: int, role: str, win: bool, final: list[int], pid: int = 1) -> dict[str, Any]:
    finals = (final + [0] * 7)[:7]
    return {"puuid": puuid, "participantId": pid, "championId": champion, "teamPosition": role, "win": win,
            "gameEndedInEarlySurrender": False,
            "perks": {"styles": [{"selections": [{"perk": 8229}]}]},
            **{f"item{i}": finals[i] for i in range(7)}}


def make_match(match_id: str, players: list[dict[str, Any]], duration: int = 1800) -> dict[str, Any]:
    return {"metadata": {"matchId": match_id},
            "info": {"queueId": 420, "gameDuration": duration, "gameVersion": "16.23.840.1",
                     "participants": players}}


def make_timeline(puuid: str, purchases: list[int], skills: str, undo: int | None = None) -> dict[str, Any]:
    events: list[dict[str, Any]] = []
    t = 1000
    for item_id in purchases:
        events.append({"type": "ITEM_PURCHASED", "participantId": 1, "itemId": item_id, "timestamp": t})
        t += 1000
    if undo is not None:
        events.append({"type": "ITEM_UNDO", "participantId": 1, "beforeId": undo, "afterId": 0, "timestamp": t})
    for key in skills:
        t += 1000
        events.append({"type": "SKILL_LEVEL_UP", "participantId": 1, "skillSlot": "QWER".index(key) + 1,
                       "levelUpType": "NORMAL", "timestamp": t})
    # Evento de outro jogador: tem de ser ignorado.
    events.append({"type": "ITEM_PURCHASED", "participantId": 2, "itemId": 3031, "timestamp": 1500})
    return {"info": {"participants": [{"participantId": 1, "puuid": puuid}],
                     "frames": [{"events": events[: len(events) // 2]}, {"events": events[len(events) // 2:]}]}}


SKILLS = "QEWQQRQEQEREEWWRWW"
AP_PURCHASES = [2003, 1001, 1052, 3089, 3020, 3157, 3175, 6653]


# ---------- Itens ----------

def test_catalogo_separa_itens_completos_e_botas() -> None:
    assert CATALOG.is_completed(3089) and CATALOG.is_completed(3068)
    assert not CATALOG.is_completed(1052)   # componente
    assert not CATALOG.is_completed(2003)   # consumível
    assert not CATALOG.is_completed(3020)   # botas ficam à parte
    assert CATALOG.boots_tier2(3175) == 3020  # 3º nível vira o 2º


def test_tipo_da_build_pelos_atributos() -> None:
    assert CATALOG.archetype([3089, 3157]) == "AP"
    assert CATALOG.archetype([3068, 3075]) == "Tanque"
    assert CATALOG.archetype([3031, 3089]) == "Crítico"


# ---------- Extração ----------

def test_build_em_ordem_com_botas_habilidades_e_desfazer() -> None:
    match = make_match("BR1_1", [player("eu", MALPHITE, "MIDDLE", True, [3089, 3157, 6653])])
    timeline = make_timeline("eu", [*AP_PURCHASES, 3068], SKILLS, undo=3068)

    build = extract_build(match, timeline, "eu", CATALOG)

    assert build is not None
    assert build.items == (3089, 3157, 6653)  # a Égide foi desfeita
    assert build.boots == 3020
    assert build.skills == SKILLS
    assert (build.patch, build.role, build.win, build.keystone) == ("16.23", "MIDDLE", True, 8229)


def test_partida_curta_ou_com_um_item_nao_serve() -> None:
    curta = make_match("BR1_1", [player("eu", MALPHITE, "MIDDLE", True, [])], duration=600)
    assert extract_build(curta, make_timeline("eu", AP_PURCHASES, SKILLS), "eu", CATALOG) is None

    um_item = make_match("BR1_2", [player("eu", MALPHITE, "MIDDLE", True, [])])
    assert extract_build(um_item, make_timeline("eu", [3089], SKILLS), "eu", CATALOG) is None


def test_base_de_comparacao_conta_todos_os_jogadores() -> None:
    match = make_match("BR1_1", [
        player("a", MALPHITE, "TOP", True, [3068, 3075, 1052]),
        player("b", JINX, "BOTTOM", False, [3031], pid=2),
    ])
    games = champion_games(match, CATALOG)
    assert [(g.champion_id, g.role, g.final_items) for g in games] == [
        (MALPHITE, "TOP", frozenset({3068, 3075})), (JINX, "BOTTOM", frozenset({3031})),
    ]


# ---------- Pontuação ----------

def test_wilson_desconta_amostra_pequena() -> None:
    assert wilson_lower_bound(7, 8) < wilson_lower_bound(70, 80)
    assert wilson_lower_bound(0, 0) == 0


def test_ordem_de_maximizar_habilidades() -> None:
    assert max_order(SKILLS) == "Q > E > W"


def baseline(games: int = 100, top: int = 90, mid: int = 10) -> ChampionStats:
    return ChampionStats("16.23", MALPHITE, games, games // 2, Counter({"TOP": top, "MIDDLE": mid}),
                         Counter({3068: 80, 3075: 70, 3089: 12, 3157: 8}))


def ap_mid(games: int, wins: int, core: tuple[int, int] = (3089, 3157)) -> BuildStats:
    return BuildStats("16.23", MALPHITE, "MIDDLE", core, games, wins,
                      Counter({6653: games}), Counter({3020: games}), Counter({SKILLS: games}))


def test_ciencia_e_a_build_incomum_que_ganha() -> None:
    comum = BuildStats("16.23", MALPHITE, "TOP", (3068, 3075), 40, 30)
    sciences = pick_sciences([ap_mid(12, 9), comum], [baseline()], PatchChanges(), CATALOG,
                             {MALPHITE: "Malphite"})

    assert [s.title for s in sciences] == ["Malphite AP no Mid"]  # a build comum fica de fora
    [s] = sciences
    assert s.items == [3089, 3157, 6653] and s.boots == 3020 and s.max_order == "Q > E > W"


def test_poucas_partidas_ou_perdendo_nao_entra() -> None:
    names = {MALPHITE: "Malphite"}
    assert pick_sciences([ap_mid(5, 5)], [baseline()], PatchChanges(), CATALOG, names) == []
    assert pick_sciences([ap_mid(20, 8)], [baseline()], PatchChanges(), CATALOG, names) == []


def test_previa_completa_a_lista_depois_das_ciencias() -> None:
    names = {MALPHITE: "Malphite"}
    comum = BuildStats("16.23", MALPHITE, "TOP", (3068, 3075), 40, 30)
    poucas = ap_mid(5, 5, core=(6653, 3157))
    builds = [ap_mid(12, 9), comum, poucas, ap_mid(20, 8, core=(3089, 6653))]

    sciences = pick_sciences(builds, [baseline()], PatchChanges(), CATALOG, names, fill_to=3)

    assert sciences[0].items[:2] == [3089, 3157]  # a Ciência de verdade vem primeiro
    assert len(sciences) == 3                     # a comum e a de poucas partidas completam
    assert all(s.games != 20 for s in sciences)   # perdendo continua de fora
    assert len(pick_sciences(builds, [baseline()], PatchChanges(), CATALOG, names, fill_to=1)) == 1


def test_buff_no_patch_sobe_a_ciencia() -> None:
    builds = [ap_mid(12, 9), ap_mid(12, 9, core=(6653, 3157))]
    names = {MALPHITE: "Malphite"}
    plain = pick_sciences(builds, [baseline()], PatchChanges(), CATALOG, names)
    buffed = pick_sciences(builds, [baseline()], PatchChanges(items={6653: 3}), CATALOG, names)

    assert buffed[0].items[0] == 6653
    assert buffed[0].score > plain[0].score


# ---------- Patch ----------

def test_diferenca_de_patch_detecta_buff_e_nerf() -> None:
    old = {"Malphite": {"key": "54", "stats": {"hp": 600}, "spells": [{"cooldown": [10, 9], "cost": [50, 50]}]}}
    new = {"Malphite": {"key": "54", "stats": {"hp": 620}, "spells": [{"cooldown": [9, 8], "cost": [50, 50]}]}}
    assert diff_champions(old, new) == {54: 2}  # mais vida + menos recarga

    old_items = {"3089": {"gold": {"total": 3600}, "stats": {"FlatMagicDamageMod": 140}}}
    new_items = {"3089": {"gold": {"total": 3800}, "stats": {"FlatMagicDamageMod": 140}}}
    assert diff_items(old_items, new_items) == {3089: -1}  # mais caro


# ---------- Limite da Riot ----------

def test_rate_limiter_espera_a_janela() -> None:
    now = [0.0]
    waits: list[float] = []

    async def sleep(s: float) -> None:
        waits.append(s)
        now[0] += s

    async def scenario() -> None:
        limiter = RateLimiter(((2, 1.0),), clock=lambda: now[0], sleep=sleep)
        for _ in range(3):
            await limiter.acquire()

    asyncio.run(scenario())
    assert len(waits) == 1 and 1.0 <= waits[0] < 1.1


def test_monochamp_pela_maestria() -> None:
    recent = int(NOW.timestamp() * 1000)
    assert is_monochamp([{"championId": 54, "championPoints": 500_000, "lastPlayTime": recent},
                         {"championId": 1, "championPoints": 100_000}], NOW)
    assert not is_monochamp([{"championId": 54, "championPoints": 500_000, "lastPlayTime": recent},
                             {"championId": 1, "championPoints": 300_000}], NOW)  # não é "mono"
    old = int((NOW - timedelta(days=60)).timestamp() * 1000)
    assert not is_monochamp([{"championId": 54, "championPoints": 500_000, "lastPlayTime": old}], NOW)


# ---------- A coleta inteira ----------

class FakeStatic(StaticData):
    def __init__(self) -> None:
        pass

    async def versions(self) -> list[str]:
        return ["16.23.1", "16.22.1"]

    async def items(self, version: str) -> dict[str, Any]:
        return ITEMS

    async def champions_full(self, version: str) -> dict[str, Any]:
        hp = 620 if version == "16.23.1" else 600
        return {"Malphite": {"key": "54", "id": "Malphite", "name": "Malphite", "stats": {"hp": hp}, "spells": []}}


def riot_transport(key_ok: bool = True) -> httpx.MockTransport:
    recent = int(NOW.timestamp() * 1000)

    def handler(request: httpx.Request) -> httpx.Response:
        path = request.url.path
        if not key_ok and "champion-mastery" in path:
            return httpx.Response(401)
        if "challengerleagues" in path:
            return httpx.Response(200, json={"entries": [{"puuid": "mono", "leaguePoints": 1000},
                                                         {"puuid": "varios", "leaguePoints": 900}]})
        if "grandmasterleagues" in path:
            return httpx.Response(200, json={"entries": []})
        if "champion-mastery" in path:
            if "/mono/" in path:
                return httpx.Response(200, json=[{"championId": MALPHITE, "championPoints": 600_000,
                                                  "lastPlayTime": recent},
                                                 {"championId": JINX, "championPoints": 20_000}])
            return httpx.Response(200, json=[{"championId": JINX, "championPoints": 300_000, "lastPlayTime": recent},
                                             {"championId": MALPHITE, "championPoints": 290_000}])
        if path.endswith("/ids"):
            assert request.url.params["queue"] == "420"
            return httpx.Response(200, json=[f"BR1_{i}" for i in range(5)])
        if path.endswith("/timeline"):
            return httpx.Response(200, json=make_timeline("mono", AP_PURCHASES, SKILLS))
        if "/lol/match/v5/matches/" in path:
            match_id = path.rsplit("/", 1)[1]
            return httpx.Response(200, json=make_match(match_id, [
                player("mono", MALPHITE, "MIDDLE", True, [3089, 3157, 6653]),
                player("outro", JINX, "BOTTOM", False, [3031], pid=2),
            ]))
        return httpx.Response(404)

    return httpx.MockTransport(handler)


async def no_sleep(_: float) -> None:
    return None


def collect(store: InMemoryScienceStore, key_ok: bool = True) -> Any:
    async def scenario() -> Any:
        async with httpx.AsyncClient(transport=riot_transport(key_ok)) as http:
            riot = ScienceRiot(http, "RGAPI-teste", sleep=no_sleep)
            return await run(riot, store, FakeStatic(), NOW, 60, platforms={"br1": "americas"})

    return asyncio.run(scenario())


def test_coleta_encontra_o_monochamp_grava_e_publica() -> None:
    store = InMemoryScienceStore()
    # Dados de dias anteriores: a base do Malphite (top, tanque) e 4 partidas da build.
    store.champions["16.23_54"] = baseline()
    store.builds["seed"] = ap_mid(4, 3)

    report = collect(store)

    assert report.monochamps == 1 and store.monochamps["br1"][1] == [Monochamp("mono", MALPHITE)]
    assert (report.matches, report.samples) == (5, 5)
    assert store.cursor == NOW
    assert store.patches["16.23"].champions == {MALPHITE: 1}  # +20 de vida
    published = store.published
    assert published is not None and published["patch"] == "16.23"
    [build] = published["builds"]
    assert build["title"] == "Malphite AP no Mid"
    assert build["roleName"] == "Mid"
    assert [i["name"] for i in build["items"]] == ["Capuz da Morte", "Ampulheta de Zhonya", "Tormento de Liandry"]
    assert build["boots"]["name"] == "Sapatos do Feiticeiro"
    assert build["skills"] == SKILLS and build["maxOrder"] == "Q > E > W"
    assert build["championIconUrl"].endswith("/img/champion/Malphite.png")


def test_chave_recusada_para_mas_publica_o_que_tem() -> None:
    store = InMemoryScienceStore()
    store.champions["16.23_54"] = baseline()
    store.builds["seed"] = ap_mid(12, 9)

    report = collect(store, key_ok=False)

    assert report.key_rejected
    assert store.published is not None and len(store.published["builds"]) == 1


def test_agregador_soma_por_build() -> None:
    agg = Aggregator()
    match = make_match("BR1_1", [player("eu", MALPHITE, "MIDDLE", True, [])])
    sample = extract_build(match, make_timeline("eu", AP_PURCHASES, SKILLS), "eu", CATALOG)
    assert sample is not None
    agg.add_sample(sample)
    agg.add_sample(sample)

    [stats] = agg.builds.values()
    assert (stats.games, stats.wins, stats.thirds[6653], stats.boots[3020]) == (2, 2, 2, 2)
