"""Buffs e nerfs de um patch para o outro, pelos dados do Data Dragon.

A Riot não tem API de notas de patch. Comparamos os números de duas versões:
atributos base dos campeões, recarga e custo das habilidades, e preço e
atributos dos itens. Cada número que melhora conta +1; que piora, -1.
É aproximado (o Data Dragon não traz todos os valores das habilidades), por
isso o peso disso na nota da ciência é pequeno (ver scoring.py).
"""

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class PatchChanges:
    champions: dict[int, int] = field(default_factory=dict)  # id → saldo (+ buff, - nerf)
    items: dict[int, int] = field(default_factory=dict)


def _sign(x: float) -> int:
    return (x > 0) - (x < 0)


def _numbers(values: Any) -> list[float]:
    return [float(v) for v in values] if isinstance(values, list) else []


def _compare_lists(old: list[float], new: list[float], lower_is_better: bool) -> int:
    if not old or not new or len(old) != len(new) or old == new:
        return 0
    delta = sum(new) - sum(old)
    return -_sign(delta) if lower_is_better else _sign(delta)


def diff_champions(old: dict[str, Any], new: dict[str, Any]) -> dict[int, int]:
    """`old`/`new` = championFull.json["data"] de duas versões."""
    changes: dict[int, int] = {}
    for name, champ in new.items():
        before = old.get(name)
        if before is None:
            continue  # campeão novo: sem comparação
        score = 0
        for stat, value in champ.get("stats", {}).items():
            prev = before.get("stats", {}).get(stat)
            if isinstance(value, (int, float)) and isinstance(prev, (int, float)):
                score += _sign(value - prev)  # atributo base: maior é melhor
        for spell, prev_spell in zip(champ.get("spells", []), before.get("spells", []), strict=False):
            score += _compare_lists(_numbers(prev_spell.get("cooldown")), _numbers(spell.get("cooldown")), True)
            score += _compare_lists(_numbers(prev_spell.get("cost")), _numbers(spell.get("cost")), True)
        if score:
            changes[int(champ["key"])] = score
    return changes


def diff_items(old: dict[str, Any], new: dict[str, Any]) -> dict[int, int]:
    """`old`/`new` = item.json["data"] de duas versões."""
    changes: dict[int, int] = {}
    for item_id, item in new.items():
        before = old.get(item_id)
        if before is None:
            continue
        score = -_sign(item.get("gold", {}).get("total", 0) - before.get("gold", {}).get("total", 0))
        for stat, value in item.get("stats", {}).items():
            score += _sign(value - before.get("stats", {}).get(stat, 0))
        for stat in before.get("stats", {}).keys() - item.get("stats", {}).keys():
            score -= 1  # atributo removido
        if score:
            changes[int(item_id)] = score
    return changes
