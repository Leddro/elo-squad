"""Store em MEMÓRIA, com o mesmo contrato do FirestoreStore (app/store.py)."""

from app.models import RankSnapshot, RiotId, Squad, SquadMember, UserRecord, WeeklyRanking


class InMemoryStore:
    def __init__(self) -> None:
        self.users: dict[str, UserRecord] = {}
        self.squads: dict[str, Squad] = {}
        self.codes: dict[str, str] = {}
        self.snapshots: dict[str, dict[str, RankSnapshot]] = {}  # weekId → puuid → retrato
        self.rankings: dict[tuple[str, str], WeeklyRanking] = {}  # (squadId, weekId)
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
        for other_uid, other in self.users.items():
            if other_uid != uid and token in other.fcm_tokens:
                other.fcm_tokens.remove(token)
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

    async def set_icon(self, squad_id: str, icon: str) -> None:
        self.squads[squad_id].icon = icon

    async def set_info(self, squad_id: str, name: str, description: str | None) -> None:
        self.squads[squad_id].name = name
        self.squads[squad_id].description = description

    async def delete_squad(self, squad_id: str, invite_code: str) -> None:
        del self.squads[squad_id]
        del self.codes[invite_code]

    async def list_squads(self) -> list[tuple[str, Squad]]:
        return [(sid, squad.model_copy(deep=True)) for sid, squad in self.squads.items()]

    async def get_snapshots(self, week_id: str, puuids: list[str]) -> dict[str, RankSnapshot]:
        week = self.snapshots.get(week_id, {})
        return {p: week[p] for p in puuids if p in week}

    async def save_snapshots(self, week_id: str, snapshots: dict[str, RankSnapshot]) -> None:
        self.snapshots.setdefault(week_id, {}).update(snapshots)

    async def get_ranking(self, squad_id: str, week_id: str) -> WeeklyRanking | None:
        return self.rankings.get((squad_id, week_id))

    async def save_ranking(self, squad_id: str, ranking: WeeklyRanking) -> None:
        self.rankings[(squad_id, ranking.week_id)] = ranking.model_copy(deep=True)

    async def get_fcm_tokens(self, uids: list[str]) -> dict[str, list[str]]:
        return {uid: list(self.users[uid].fcm_tokens) for uid in uids if uid in self.users and self.users[uid].fcm_tokens}

    async def remove_fcm_tokens(self, uid: str, tokens: list[str]) -> None:
        self._user(uid).fcm_tokens = [t for t in self._user(uid).fcm_tokens if t not in tokens]

