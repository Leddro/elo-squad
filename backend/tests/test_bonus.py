"""Bônus dos squads: vitória com Ciência (campeão, rota e 3 primeiros itens)."""

import asyncio
from datetime import UTC, datetime, timedelta
from typing import Any

from app.science.bonus import BONUS, Publication, ScienceRef, matching_science, run
from app.science.extract import extract_build
from test_science import AP_PURCHASES, CATALOG, MALPHITE, SKILLS, make_match, make_timeline, player

PLAYED = datetime(2026, 11, 27, 20, tzinfo=UTC)
MALPHITE_AP = ScienceRef(MALPHITE, "Malphite", "MIDDLE", "Malphite AP no Mid", "D", (3089, 3157, 6653))


def publication(at: datetime, *sciences: ScienceRef) -> Publication:
    return Publication(published_at=at, sciences=list(sciences))


def sample(purchases: list[int] = AP_PURCHASES, role: str = "MIDDLE") -> Any:
    match = make_match("BR1_1", [player("eu", MALPHITE, role, True, [3089, 3157, 6653])])
    return extract_build(match, make_timeline("eu", purchases, SKILLS), "eu", CATALOG)


def test_mesma_ciencia_com_os_3_itens_na_ordem() -> None:
    history = [publication(PLAYED - timedelta(hours=3), MALPHITE_AP)]
    assert matching_science(sample(), PLAYED, history) == MALPHITE_AP


def test_itens_fora_de_ordem_ou_outra_rota_nao_valem() -> None:
    history = [publication(PLAYED - timedelta(hours=3), MALPHITE_AP)]
    swapped = [2003, 1001, 1052, 3157, 3020, 3089, 6653]  # Zhonya antes do Capuz
    assert matching_science(sample(swapped), PLAYED, history) is None
    assert matching_science(sample(role="TOP"), PLAYED, history) is None


def test_so_vale_a_ciencia_publicada_ate_24h_antes() -> None:
    depois = [publication(PLAYED + timedelta(hours=1), MALPHITE_AP)]
    velha = [publication(PLAYED - timedelta(hours=30), MALPHITE_AP)]
    assert matching_science(sample(), PLAYED, depois) is None
    assert matching_science(sample(), PLAYED, velha) is None


def test_tier_pior_da_bonus_maior() -> None:
    assert BONUS["D"] > BONUS["C"] > BONUS["B"] > BONUS["A"] > BONUS["S"] > 0
    assert BONUS["D"] == 20  # o dobro de uma vitória típica de 20 PDL


class FakeRiot:
    def __init__(self, matches: dict[str, tuple[dict[str, Any], dict[str, Any]]]) -> None:
        self.matches = matches
        self.timelines = 0

    async def ranked_match_ids(self, region: str, puuid: str, start_time: int, count: int) -> list[str]:
        return list(self.matches)

    async def match(self, region: str, match_id: str) -> dict[str, Any]:
        return self.matches[match_id][0]

    async def timeline(self, region: str, match_id: str) -> dict[str, Any]:
        self.timelines += 1
        return self.matches[match_id][1]


class FakeStore:
    def __init__(self) -> None:
        self.saved: dict[str, dict[str, Any]] = {}

    async def active_targets(self, now: datetime) -> dict[str, datetime]:
        return {"eu": PLAYED - timedelta(days=1)}

    async def history(self, since: datetime) -> list[Publication]:
        return [publication(PLAYED - timedelta(hours=2), MALPHITE_AP)]

    async def known_matches(self, puuid: str) -> set[str]:
        return {"BR1_velha"}

    async def save_matches(self, puuid: str, matches: dict[str, dict[str, Any]], now: datetime) -> None:
        self.saved.update(matches)


def test_rodada_grava_a_vitoria_com_bonus_e_ignora_as_conhecidas() -> None:
    start = int(PLAYED.timestamp() * 1000)
    timeline = make_timeline("eu", AP_PURCHASES, SKILLS)
    riot = FakeRiot({
        "BR1_win": (make_match("BR1_win", [player("eu", MALPHITE, "MIDDLE", True, [])], start_ms=start), timeline),
        "BR1_loss": (make_match("BR1_loss", [player("eu", MALPHITE, "MIDDLE", False, [])], start_ms=start), timeline),
        "BR1_velha": ({}, {}),
    })
    store = FakeStore()

    wins = asyncio.run(run(riot, store, CATALOG, "americas", PLAYED + timedelta(hours=1)))  # type: ignore[arg-type]

    assert wins == 1
    assert store.saved["BR1_win"]["bonus"] == 20 and store.saved["BR1_win"]["tier"] == "D"
    assert store.saved["BR1_loss"]["bonus"] == 0
    assert "BR1_velha" not in store.saved
    assert riot.timelines == 1  # linha do tempo só da vitória
