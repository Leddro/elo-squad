"""Períodos do líder, bônus das Ciências e troféus do pódio."""

from datetime import UTC, datetime, timedelta

import pytest

from app.auth import AuthUser
from app.errors import NotSquadOwnerError
from app.models import ScienceWin, SquadPeriod, SquadPeriodRequest
from app.periods import custom_period, default_period, next_period, period_id, preset_period
from app.ranking import BRT
from app.ranking_service import RankingService
from conftest import FakeRiot
from fake_store import InMemoryStore
from test_ranking import WEDNESDAY, Moment, league, run, squad_of
from test_ranking import moment, notifier, service  # noqa: F401  (fixtures)

# ---------- Cálculos puros ----------


def test_semana_padrao_mantem_o_id_antigo() -> None:
    period = default_period(WEDNESDAY)
    assert period_id(period) == "2026-W48"
    assert period_id(next_period(period)) == "2026-W49"
    assert next_period(period).ends_at - next_period(period).starts_at == timedelta(days=7)


def test_preset_comeca_agora_e_acaba_a_meia_noite() -> None:
    period = preset_period("two_weeks", WEDNESDAY, repeat=True)  # quarta 12:00 BRT
    end = period.ends_at.astimezone(BRT)
    assert period.starts_at == WEDNESDAY
    assert (end.day, end.month, end.hour) == (10, 12, 0)  # quinta, 14 dias depois, 00:00
    assert period_id(period) == "20261125-1200_20261210"


def test_mes_e_proximo_periodo_emendado() -> None:
    period = preset_period("month", WEDNESDAY, repeat=True)
    end = period.ends_at.astimezone(BRT)
    assert (end.day, end.month) == (26, 12)
    after = next_period(period)
    assert after.starts_at == period.ends_at
    assert after.ends_at.astimezone(BRT).month == 1


def test_personalizado_valida_a_duracao_e_nao_comeca_no_passado() -> None:
    period = custom_period(WEDNESDAY - timedelta(days=3), WEDNESDAY + timedelta(days=5), WEDNESDAY, repeat=False)
    assert period.starts_at == WEDNESDAY
    assert next_period(period).ends_at - next_period(period).starts_at == timedelta(days=5)
    with pytest.raises(ValueError):
        custom_period(WEDNESDAY, WEDNESDAY + timedelta(hours=5), WEDNESDAY, repeat=False)
    with pytest.raises(ValueError):
        custom_period(WEDNESDAY, WEDNESDAY + timedelta(days=100), WEDNESDAY, repeat=False)


# ---------- Serviço ----------


def win(match: str, at: datetime, bonus: int, tier: str = "D") -> ScienceWin:
    return ScienceWin(match_id=match, played_at=at, champion_name="Malphite", title="Malphite AP no Mid",
                      tier=tier, bonus=bonus)


def test_bonus_das_ciencias_soma_aos_pontos_so_dentro_do_periodo(
    service: RankingService, store: InMemoryStore, riot: FakeRiot, moment: Moment,
) -> None:
    store.squads["s1"] = squad_of("a", "b")
    riot.league["p-a"] = league("GOLD", "II", 54)
    riot.league["p-b"] = league("GOLD", "II", 60)
    run(service.refresh())

    store.science_wins["p-a"] = [
        win("BR1_1", WEDNESDAY + timedelta(hours=1), 20),
        win("BR1_0", WEDNESDAY - timedelta(hours=1), 20),  # antes do retrato: não conta
    ]
    moment.now += timedelta(hours=2)
    riot.league["p-b"] = league("GOLD", "II", 70)  # +10 PDL
    run(service.refresh())

    entries = store.rankings[("s1", "2026-W48")].entries
    assert [(e.uid, e.lp_delta, e.bonus, e.points) for e in entries] == [("a", 0, 20, 20), ("b", 10, 0, 10)]
    assert [w.match_id for w in entries[0].science_wins] == ["BR1_1"]


def test_fim_do_periodo_da_trofeus_ao_podio_e_comeca_o_proximo(
    service: RankingService, store: InMemoryStore, riot: FakeRiot, moment: Moment,
) -> None:
    store.squads["s1"] = squad_of("a", "b", "c", "d")
    for u in "abcd":
        riot.league[f"p-{u}"] = league("GOLD", "II", 10)
    run(service.refresh())

    moment.now = datetime(2026, 11, 30, 3, 5, tzinfo=UTC)
    riot.league["p-a"] = league("GOLD", "II", 40)
    riot.league["p-b"] = league("GOLD", "II", 30)
    riot.league["p-c"] = league("GOLD", "II", 20)
    riot.league["p-d"] = league("GOLD", "II", 0)  # perdeu PDL: fora do pódio
    run(service.refresh())

    squad = store.squads["s1"]
    assert squad.podiums[0].places == ["a", "b", "c"] and squad.podiums[0].points == [30, 20, 10]
    assert [(t.place, t.points) for t in store.users["a"].trophies] == [(1, 30)]
    assert store.users["c"].trophies[0].place == 3
    assert "d" not in store.users or not store.users["d"].trophies
    assert squad.period is not None and period_id(squad.period) == "2026-W49"
    assert ("s1", "2026-W49") in store.rankings

    run(service.refresh())  # de novo: não dá troféu repetido
    assert len(store.users["a"].trophies) == 1 and len(store.squads["s1"].podiums) == 1


def test_periodo_sem_repetir_para_no_fim(
    service: RankingService, store: InMemoryStore, riot: FakeRiot, moment: Moment,
) -> None:
    store.squads["s1"] = squad_of("a")
    store.squads["s1"].period = SquadPeriod(
        length="custom", starts_at=WEDNESDAY, ends_at=WEDNESDAY + timedelta(days=2), repeat=False,
    )
    riot.league["p-a"] = league("GOLD", "II", 10)
    run(service.refresh())

    moment.now += timedelta(days=3)
    run(service.refresh())

    assert [k for k in store.rankings] == [("s1", "20261125-1200_20261127")]
    assert store.rankings[("s1", "20261125-1200_20261127")].final


def test_lider_troca_o_periodo_e_o_atual_acaba_sem_trofeus(
    service: RankingService, store: InMemoryStore, riot: FakeRiot,
) -> None:
    store.squads["s1"] = squad_of("a", "b")
    riot.league["p-a"] = league("GOLD", "II", 10)
    riot.league["p-b"] = league("GOLD", "II", 10)
    run(service.refresh())
    assert ("s1", "2026-W48") in store.rankings

    with pytest.raises(NotSquadOwnerError):
        run(service.set_period(AuthUser(uid="b", name=None), "s1", SquadPeriodRequest(length="month")))

    period = run(service.set_period(AuthUser(uid="a", name=None), "s1", SquadPeriodRequest(length="month")))

    assert ("s1", "2026-W48") not in store.rankings
    assert ("s1", period_id(period)) in store.rankings
    assert store.squads["s1"].podiums == []
