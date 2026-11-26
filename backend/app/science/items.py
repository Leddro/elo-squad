"""Catálogo de itens do Data Dragon: o que conta como item COMPLETO e o tipo da build."""

from collections import Counter
from dataclasses import dataclass
from typing import Any

SUMMONERS_RIFT = "11"
# Itens completos custam a partir disso (os componentes ficam abaixo).
MIN_COMPLETED_GOLD = 2000


@dataclass(frozen=True, slots=True)
class Item:
    id: int
    name: str
    gold: int
    tags: frozenset[str]
    completed: bool          # item lendário (fim de árvore)
    boots_tier2: int | None  # botas: a versão de 2º nível (as de 3º viram a de 2º)


class ItemCatalog:
    def __init__(self, items: dict[int, Item]) -> None:
        self._items = items

    @classmethod
    def from_ddragon(cls, data: dict[str, Any]) -> "ItemCatalog":
        """`data` = item.json["data"] do Data Dragon (chave = id em texto)."""
        raw = {int(k): v for k, v in data.items()}
        items: dict[int, Item] = {}
        for item_id, it in raw.items():
            if not it.get("maps", {}).get(SUMMONERS_RIFT) or not it.get("gold", {}).get("purchasable"):
                continue
            tags = frozenset(it.get("tags", []))
            gold = int(it["gold"]["total"])
            boots: int | None = None
            if "Boots" in tags and it.get("depth", 1) >= 2:
                boots = item_id if it.get("depth") == 2 else _tier2_from(raw, it)
            completed = (
                boots is None
                and not it.get("into")
                and gold >= MIN_COMPLETED_GOLD
                and not tags & {"Consumable", "Trinket"}
            )
            items[item_id] = Item(item_id, it["name"], gold, tags, completed, boots)
        return cls(items)

    def get(self, item_id: int) -> Item | None:
        return self._items.get(item_id)

    def is_completed(self, item_id: int) -> bool:
        item = self._items.get(item_id)
        return item is not None and item.completed

    def boots_tier2(self, item_id: int) -> int | None:
        item = self._items.get(item_id)
        return item.boots_tier2 if item else None

    def archetype(self, item_ids: list[int]) -> str | None:
        """O tipo da build pelos atributos dos itens. None = sem tipo claro."""
        if not item_ids:
            return None
        tags: Counter[str] = Counter(t for i in item_ids if (it := self.get(i)) for t in it.tags)
        share = {t: c / len(item_ids) for t, c in tags.items()}
        health = share.get("Health", 0)
        if share.get("CriticalStrike", 0) >= 0.5:
            return "Crítico"
        if share.get("SpellDamage", 0) >= 0.5:
            return "AP"
        damage = share.get("Damage", 0) + share.get("SpellDamage", 0)
        defense = max(share.get("Armor", 0), share.get("SpellBlock", 0))
        if defense >= 0.5 and damage < 0.5:
            return "Tanque"
        if health >= 0.5 and share.get("Damage", 0) >= 0.5:
            return "Bruiser"  # vida + dano (antes de letalidade: o Cutelo Negro tem as duas)
        if share.get("ArmorPenetration", 0) >= 0.5:
            return "Letalidade"
        if share.get("OnHit", 0) >= 0.5:
            return "On-hit"
        if share.get("Damage", 0) >= 0.5:
            return "AD"
        return None


def _tier2_from(raw: dict[int, dict[str, Any]], it: dict[str, Any]) -> int | None:
    """Botas de 3º nível (melhoria) → as botas de 2º nível de que vieram."""
    for parent in it.get("from", []):
        p = raw.get(int(parent))
        if p and "Boots" in p.get("tags", []) and p.get("depth") == 2:
            return int(parent)
    return None
