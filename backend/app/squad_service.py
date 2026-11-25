"""Regras dos squads: vincular Riot ID, criar, entrar pelo código, sair."""

import secrets
from collections.abc import Callable
from datetime import UTC, datetime

from app.auth import AuthUser
from app.errors import RiotIdRequiredError, SquadFullError, SquadLimitError, SquadNotFoundError
from app.models import LinkRiotIdResponse, Squad, SquadMember, SquadRef, UserRecord
from app.service import SummonerService
from app.store import Store

MAX_MEMBERS = 20
MAX_SQUADS_PER_USER = 10

# Sem caracteres ambíguos (0/O, 1/I/L): o código é digitado ou ditado.
CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
CODE_LENGTH = 6


def normalize_code(code: str) -> str:
    return code.strip().upper()


class SquadService:
    def __init__(
        self,
        store: Store,
        summoner: SummonerService,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._store = store
        self._summoner = summoner
        self._clock = clock

    async def link_riot_id(self, user: AuthUser, game_name: str, tag_line: str) -> LinkRiotIdResponse:
        # Valida na Riot (404 se não existir) e pega a grafia oficial + PUUID.
        profile = await self._summoner.get_profile(game_name, tag_line)
        await self._store.set_user_riot_id(
            user.uid, user.name, profile.riot_id, profile.puuid, profile.profile_icon_url,
        )

        # Atualiza a cópia do membro em cada squad em que ele já está.
        record = await self._store.get_user(user.uid)
        member = SquadMember(
            uid=user.uid, display_name=user.name, riot_id=profile.riot_id,
            puuid=profile.puuid, profile_icon_url=profile.profile_icon_url,
        )
        for squad_id in record.squad_ids if record else []:
            await self._store.update_member(squad_id, member)
        return LinkRiotIdResponse(riot_id=profile.riot_id, puuid=profile.puuid)

    async def add_fcm_token(self, user: AuthUser, token: str) -> None:
        await self._store.add_fcm_token(user.uid, token)

    async def create(self, user: AuthUser, name: str) -> SquadRef:
        member, record = await self._member(user)
        if len(record.squad_ids) >= MAX_SQUADS_PER_USER:
            raise SquadLimitError()

        code = await self._new_code()
        squad = Squad(
            name=name.strip(), invite_code=code, owner_uid=user.uid,
            member_uids=[user.uid], members={user.uid: member}, created_at=self._clock(),
        )
        squad_id = await self._store.create_squad(squad)
        return SquadRef(id=squad_id, invite_code=code)

    async def join(self, user: AuthUser, invite_code: str) -> SquadRef:
        member, record = await self._member(user)
        squad_id = await self._store.squad_id_for_code(normalize_code(invite_code))
        squad = await self._store.get_squad(squad_id) if squad_id else None
        if squad_id is None or squad is None:
            raise SquadNotFoundError()

        if user.uid not in squad.member_uids:  # já é membro: nada a fazer (idempotente)
            if len(squad.member_uids) >= MAX_MEMBERS:
                raise SquadFullError()
            if len(record.squad_ids) >= MAX_SQUADS_PER_USER:
                raise SquadLimitError()
            await self._store.add_member(squad_id, member)
        return SquadRef(id=squad_id, invite_code=squad.invite_code)

    async def leave(self, user: AuthUser, squad_id: str) -> None:
        squad = await self._store.get_squad(squad_id)
        # Quem não é membro recebe "não encontrado": não revela que o squad existe.
        if squad is None or user.uid not in squad.member_uids:
            raise SquadNotFoundError()

        remaining = [uid for uid in squad.member_uids if uid != user.uid]
        if not remaining:
            await self._store.remove_member(squad_id, user.uid)
            await self._store.delete_squad(squad_id, squad.invite_code)
            return
        await self._store.remove_member(squad_id, user.uid)
        if squad.owner_uid == user.uid:
            await self._store.set_owner(squad_id, remaining[0])  # o mais antigo assume

    async def _member(self, user: AuthUser) -> tuple[SquadMember, UserRecord]:
        record = await self._store.get_user(user.uid)
        if record is None or record.riot_id is None or record.puuid is None:
            raise RiotIdRequiredError()
        member = SquadMember(
            uid=user.uid, display_name=record.display_name or user.name,
            riot_id=record.riot_id, puuid=record.puuid, profile_icon_url=record.profile_icon_url,
        )
        return member, record

    async def _new_code(self) -> str:
        while True:  # colisão é raríssima (31^6 ≈ 887 milhões de códigos)
            code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(CODE_LENGTH))
            if not await self._store.invite_code_exists(code):
                return code

