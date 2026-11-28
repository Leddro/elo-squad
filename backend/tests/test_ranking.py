"""Ranking semanal: cálculos puros, o serviço (com Riot e Firestore falsos) e as rotas /jobs."""

import asyncio
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
import pytest
from fastapi.testclient import TestClient

from app.cache import TTLCache
from app.config import Settings
from app.main import app, get_jobs_secret
from app.models import RankedEntry, RiotId, Squad, SquadMember
from app.ranking import absolute_lp, rank_step, week_id, week_start
from app.ranking_service import RankingService, build_entries
from app.riot_client import RiotClient
from conftest import FakeRiot
from fake_store import InMemoryStore

# Quarta-feira da semana 2026-W48 (que começou na segunda, 23/11, 00:00 BRT).
WEDNESDAY = datetime(2026, 11, 25, 15, 0, tzinfo=UTC)
NEXT_MONDAY = datetime(2026, 11, 30, 3, 5, tzinfo=UTC)  # 00:05 BRT


def entry(tier: str, division: str = "I", lp: int = 0, wins: int = 10, losses: int = 10) -> RankedEntry:
    return RankedEntry(tier=tier, division=division, lp=lp, wins=wins, losses=losses)  # type: ignore[arg-type]


def league(tier: str, division: str, lp: int, wins: int = 10, losses: int = 10) -> list[dict[str, Any]]:
    """Resposta do league-v4 com a fila Solo/Duo."""
    return [{"queueType": "RANKED_SOLO_5x5", "tier": tier, "rank": division,
             "leaguePoints": lp, "wins": wins, "losses": losses}]


# ---------- Cálculos puros ----------

def test_semana_vira_na_segunda_00h_de_brasilia() -> None:
    sunday_night = datetime(2026, 11, 30, 2, 59, tzinfo=UTC)  # domingo 23:59 BRT
    monday = datetime(2026, 11, 30, 3, 0, tzinfo=UTC)  # segunda 00:00 BRT

    assert week_id(sunday_night) == "2026-W48"
    assert week_id(monday) == "2026-W49"
    assert week_start(WEDNESDAY) == datetime(2026, 11, 23, 3, 0, tzinfo=UTC)


def test_pdl_absoluto() -> None:
    assert absolute_lp(entry("IRON", "IV", 0)) == 0
    assert absolute_lp(entry("GOLD", "II", 54)) == 3 * 400 + 200 + 54
    assert absolute_lp(entry("DIAMOND", "I", 99)) == 2799
    assert absolute_lp(entry("MASTER", "I", 120)) == 2920
    # Subir de divisão com pouco PDL ainda conta como ganho:
    assert absolute_lp(entry("GOLD", "I", 10)) - absolute_lp(entry("GOLD", "II", 90)) == 20


def test_degrau_detecta_promocao_inclusive_no_mestre_plus() -> None:
    assert rank_step(entry("GOLD", "I", 0)) > rank_step(entry("GOLD", "II", 99))
    assert rank_step(entry("GRANDMASTER", "I", 0)) > rank_step(entry("MASTER", "I", 900))
    assert rank_step(entry("GOLD", "II", 99)) == rank_step(entry("GOLD", "II", 0))


def squad_of(*uids: str) -> Squad:
    return Squad(
        name="Os Brabos", invite_code="ABC234", owner_uid=uids[0], member_uids=list(uids),
        members={uid: SquadMember(uid=uid, display_name=None, riot_id=RiotId(game_name=uid, tag_line="BR1"),
                                  puuid=f"p-{uid}", profile_icon_url=None) for uid in uids},
        created_at=WEDNESDAY,
    )


def test_ordem_do_ranking_maior_ganho_primeiro_e_sem_ranque_no_fim() -> None:
    from app.models import RankSnapshot

    start = {f"p-{u}": RankSnapshot(entry=entry("GOLD", "II", 50, 10, 10), taken_at=WEDNESDAY) for u in "abc"}
    start["p-d"] = RankSnapshot(entry=None, taken_at=WEDNESDAY)
    now = {
        "p-a": entry("GOLD", "II", 40, 10, 11),  # -10
        "p-b": entry("GOLD", "I", 20, 13, 10),  # +70, 3 partidas
        "p-c": entry("GOLD", "II", 50, 10, 10),  # 0
        "p-d": None,  # sem ranque
    }

    entries = build_entries(squad_of("a", "b", "c", "d"), start, now)

    assert [(e.uid, e.lp_delta, e.games) for e in entries] == [
        ("b", 70, 3), ("c", 0, 0), ("a", -10, 1), ("d", None, 0),
    ]


# ---------- Serviço (Riot e Firestore falsos) ----------

class FakeNotifier:
    def __init__(self) -> None:
        self.sent: list[dict[str, Any]] = []

    async def notify(self, uids: list[str], title: str, body: str, data: dict[str, str]) -> None:
        self.sent.append({"uids": uids, "title": title, "body": body, "data": data})


class Moment:
    """Relógio controlável: o serviço e o cache da Riot leem a mesma hora."""

    def __init__(self, now: datetime) -> None:
        self.now = now

    def __call__(self) -> datetime:
        return self.now


@pytest.fixture
def moment() -> Moment:
    return Moment(WEDNESDAY)


@pytest.fixture
def notifier() -> FakeNotifier:
    return FakeNotifier()


@pytest.fixture
def service(riot: FakeRiot, store: InMemoryStore, notifier: FakeNotifier, moment: Moment) -> RankingService:
    settings = Settings(riot_api_key="chave-de-teste", _env_file=None)  # type: ignore[call-arg]
    http = httpx.AsyncClient(transport=httpx.MockTransport(riot))
    riot_client = RiotClient(http, "chave-de-teste", settings.riot_region, settings.riot_platform)
    cache = TTLCache(clock=lambda: moment.now.timestamp())
    return RankingService(store, riot_client, cache, settings, notifier, clock=moment)


@pytest.fixture
def brabos(store: InMemoryStore) -> Squad:
    squad = squad_of("a", "b")
    store.squads["s1"] = squad
    return squad


def run(coro: Any) -> Any:
    return asyncio.run(coro)


def test_primeira_atualizacao_tira_o_retrato_e_comeca_do_zero(
    service: RankingService, store: InMemoryStore, riot: FakeRiot, brabos: Squad,
) -> None:
    riot.league["p-a"] = league("GOLD", "II", 54)
    riot.league["p-b"] = []  # sem ranque

    assert run(service.refresh()) == 1

    ranking = store.rankings[("s1", "2026-W48")]
    assert not ranking.final
    assert [(e.uid, e.lp_delta) for e in ranking.entries] == [("a", 0), ("b", None)]
    assert store.snapshots["2026-W48"]["p-a"].entry.tier == "GOLD"  # type: ignore[union-attr]


def test_ao_longo_da_semana_soma_o_pdl_e_avisa_a_promocao(
    service: RankingService, store: InMemoryStore, riot: FakeRiot, notifier: FakeNotifier,
    moment: Moment, brabos: Squad,
) -> None:
    riot.league["p-a"] = league("GOLD", "II", 54, wins=40, losses=35)
    riot.league["p-b"] = league("SILVER", "I", 80)
    run(service.refresh())

    moment.now += timedelta(hours=2)  # o cache da Riot (5 min) expira
    riot.league["p-a"] = league("GOLD", "I", 10, wins=43, losses=35)
    run(service.refresh())

    ranking = store.rankings[("s1", "2026-W48")]
    top = ranking.entries[0]
    assert (top.uid, top.lp_delta, top.games) == ("a", 56, 3)
    [promotion] = notifier.sent
    assert promotion["uids"] == ["b"]  # avisa os OUTROS
    assert promotion["body"] == "a#BR1 agora é Ouro I (Os Brabos)."
    assert promotion["data"]["squadId"] == "s1"  # tocar abre o squad


def test_riot_falhou_para_um_jogador_mantem_o_elo_anterior(
    service: RankingService, store: InMemoryStore, riot: FakeRiot, moment: Moment, brabos: Squad,
) -> None:
    riot.league["p-a"] = league("GOLD", "II", 54)
    riot.league["p-b"] = league("SILVER", "I", 80)
    run(service.refresh())

    moment.now += timedelta(hours=2)
    riot.league["p-b"] = httpx.Response(503)
    run(service.refresh())

    entries = {e.uid: e for e in store.rankings[("s1", "2026-W48")].entries}
    assert entries["b"].current is not None and entries["b"].current.tier == "SILVER"


def test_fechar_a_semana_avisa_o_destaque_e_abre_a_semana_nova(
    service: RankingService, store: InMemoryStore, riot: FakeRiot, notifier: FakeNotifier,
    moment: Moment, brabos: Squad,
) -> None:
    riot.league["p-a"] = league("GOLD", "II", 54)
    riot.league["p-b"] = league("SILVER", "I", 80)
    run(service.refresh())

    moment.now = NEXT_MONDAY
    riot.league["p-b"] = league("GOLD", "IV", 30)  # +50 desde o começo da semana
    assert run(service.close_week()) == 1

    final = store.rankings[("s1", "2026-W48")]
    assert final.final
    assert [(e.uid, e.lp_delta) for e in final.entries] == [("b", 50), ("a", 0)]
    winner = notifier.sent[-1]
    assert winner["uids"] == ["a", "b"]
    assert winner["body"] == "b#BR1 venceu com 50 pontos."
    # A semana nova começa do elo de agora.
    assert store.snapshots["2026-W49"]["p-b"].entry.tier == "GOLD"  # type: ignore[union-attr]


def test_fechar_a_semana_de_novo_nao_repete_nada(
    service: RankingService, store: InMemoryStore, riot: FakeRiot, notifier: FakeNotifier,
    moment: Moment, brabos: Squad,
) -> None:
    riot.league["p-a"] = league("GOLD", "II", 54)
    riot.league["p-b"] = league("SILVER", "I", 80)
    run(service.refresh())
    moment.now = NEXT_MONDAY
    riot.league["p-b"] = league("GOLD", "IV", 30)
    run(service.close_week())
    sent, final = len(notifier.sent), store.rankings[("s1", "2026-W48")]

    # Repetição alguns minutos depois (ex.: a tarefa tentou de novo).
    moment.now += timedelta(minutes=10)
    riot.league["p-b"] = league("GOLD", "IV", 50)  # jogou nesse meio-tempo
    run(service.close_week())

    assert len(notifier.sent) == sent  # sem aviso repetido
    assert store.rankings[("s1", "2026-W48")] == final
    # O ponto de partida da semana nova continua o de 00h, e não o de agora.
    assert store.snapshots["2026-W49"]["p-b"].entry.lp == 30  # type: ignore[union-attr]


def test_semana_sem_ganho_nao_tem_destaque(
    service: RankingService, notifier: FakeNotifier, riot: FakeRiot, moment: Moment, brabos: Squad,
) -> None:
    riot.league["p-a"] = league("GOLD", "II", 54)
    riot.league["p-b"] = league("GOLD", "II", 54)
    run(service.refresh())

    moment.now = NEXT_MONDAY
    run(service.close_week())

    assert notifier.sent == []


# ---------- Rotas /jobs (segredo do Cloud Scheduler) ----------

@pytest.mark.parametrize("header", [{}, {"X-Jobs-Secret": "errado"}])
def test_jobs_sem_o_segredo_certo_401(client: TestClient, header: dict[str, str]) -> None:
    app.dependency_overrides[get_jobs_secret] = lambda: "segredo"
    assert client.post("/jobs/refresh-rankings", headers=header).status_code == 401


def test_jobs_desligados_sem_segredo_configurado(client: TestClient) -> None:
    app.dependency_overrides[get_jobs_secret] = lambda: None
    r = client.post("/jobs/refresh-rankings", headers={"X-Jobs-Secret": ""})
    assert r.status_code == 401


def test_jobs_com_o_segredo_rodam(client: TestClient, store: InMemoryStore) -> None:
    app.dependency_overrides[get_jobs_secret] = lambda: "segredo"
    store.squads["s1"] = squad_of("a")

    r = client.post("/jobs/refresh-rankings", headers={"X-Jobs-Secret": "segredo"})

    assert r.status_code == 200
    assert r.json() == {"squads": 1}
