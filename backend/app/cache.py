"""Cache em memória com TTL (tempo de validade) por chave.

Limitações conscientes (ok para a fase 1):
- Some quando o servidor reinicia. Se um dia rodarem várias instâncias, troca por Redis.
- Falhas NÃO são cacheadas: um erro da Riot não "gruda" por 5 minutos.
"""

import time
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any


@dataclass(frozen=True, slots=True)
class CacheEntry[T]:
    value: T
    stored_at: datetime  # relógio de parede: vira o `fetchedAt` da resposta
    expires_at: float    # relógio monotônico: não é afetado por ajuste de hora do sistema


class TTLCache:
    def __init__(self, clock: Callable[[], float] = time.monotonic) -> None:
        # `clock` é injetável para os testes "avançarem o tempo" sem esperar de verdade.
        self._clock = clock
        self._data: dict[str, CacheEntry[Any]] = {}

    def get(self, key: str) -> CacheEntry[Any] | None:
        entry = self._data.get(key)
        if entry is None:
            return None
        if self._clock() >= entry.expires_at:
            del self._data[key]
            return None
        return entry

    def set[T](self, key: str, value: T, ttl_s: float) -> CacheEntry[T]:
        entry = CacheEntry(value, datetime.now(UTC), self._clock() + ttl_s)
        self._data[key] = entry
        return entry

    async def get_or_set[T](
        self, key: str, ttl_s: float, factory: Callable[[], Awaitable[T]]
    ) -> CacheEntry[T]:
        """Devolve do cache se válido; senão chama `factory`, guarda e devolve."""
        if (entry := self.get(key)) is not None:
            return entry
        value = await factory()  # se lançar exceção, nada é guardado
        return self.set(key, value, ttl_s)
