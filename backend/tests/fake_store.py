"""Store em MEMÓRIA, com o mesmo contrato do FirestoreStore (app/store.py)."""

from app.models import RiotId, Squad, SquadMember, UserRecord


class InMemoryStore:
    def __init__(self) -> None:
        self.users: dict[str, UserRecord] = {}
        self.squads: dict[str, Squad] = {}
        self.codes: dict[str, str] = {}
        self._next_id = 0

    def _user(self, uid: str) -> UserRecord:
        return self.users.setdefault(uid, UserRecord())

    async def get_user(self, uid: str) -> UserRecord | None:
        user = self.users.get(uid)
        return user.model_copy(deep=True) if user else None

    async def set_user_riot_id(
        self, uid: str, display_name: str | None, riot_id: RiotId, puuid: str, profile_icon_url: str | None,
    ) -> None:
        user = self._user(uid)
        user.display_name, user.riot_id, user.puuid = display_name, riot_id, puuid
        user.profile_icon_url = profile_icon_url

    async def add_fcm_token(self, uid: str, token: str) -> None:
        tokens = self._user(uid).fcm_tokens
        if token not in tokens:
            tokens.append(token)

    async def invite_code_exists(self, code: str) -> bool:
        return code in self.codes

    async def create_squad(self, squad: Squad) -> str:
        self._next_id += 1
        squad_id = f"squad-{self._next_id}"
        self.squads[squad_id] = squad.model_copy(deep=True)
        self.codes[squad.invite_code] = squad_id
        self._user(squad.owner_uid).squad_ids.append(squad_id)
        return squad_id

    async def squad_id_for_code(self, code: str) -> str | None:
        return self.codes.get(code)

    async def get_squad(self, squad_id: str) -> Squad | None:
        squad = self.squads.get(squad_id)
        return squad.model_copy(deep=True) if squad else None

    async def add_member(self, squad_id: str, member: SquadMember) -> None:
        squad = self.squads[squad_id]
        if member.uid not in squad.member_uids:
            squad.member_uids.append(member.uid)
        squad.members[member.uid] = member
        ids = self._user(member.uid).squad_ids
        if squad_id not in ids:
            ids.append(squad_id)

    async def update_member(self, squad_id: str, member: SquadMember) -> None:
        self.squads[squad_id].members[member.uid] = member

    async def remove_member(self, squad_id: str, uid: str) -> None:
        squad = self.squads[squad_id]
        squad.member_uids.remove(uid)
        squad.members.pop(uid, None)
        self._user(uid).squad_ids.remove(squad_id)

    async def set_owner(self, squad_id: str, uid: str) -> None:
        self.squads[squad_id].owner_uid = uid

    async def delete_squad(self, squad_id: str, invite_code: str) -> None:
        del self.squads[squad_id]
        del self.codes[invite_code]
