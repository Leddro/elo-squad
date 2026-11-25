"""Persistência dos usuários e squads (Firestore).

`Store` é o CONTRATO; `FirestoreStore` é a implementação de verdade, e os testes
usam uma versão em memória (tests/fake_store.py). As escritas que mexem em mais
de um documento usam operações atômicas do Firestore (batch, ArrayUnion).
"""

from typing import Any, Protocol

from app.models import RankSnapshot, RiotId, Squad, SquadMember, UserRecord, WeeklyRanking

USERS = "users"
SQUADS = "squads"
INVITE_CODES = "inviteCodes"
WEEKS = "weeks"  # weeks/{weekId}/snapshots/{puuid}: elo no começo da semana
RANKINGS = "rankings"  # squads/{id}/rankings/{weekId}


class Store(Protocol):
    async def get_user(self, uid: str) -> UserRecord | None: ...

    async def set_user_riot_id(
        self, uid: str, display_name: str | None, riot_id: RiotId, puuid: str, profile_icon_url: str | None,
    ) -> None: ...

    async def add_fcm_token(self, uid: str, token: str) -> None: ...

    async def invite_code_exists(self, code: str) -> bool: ...

    async def create_squad(self, squad: Squad) -> str:
        """Cria o squad, o código de convite e põe o squad na lista do dono. Devolve o id."""
        ...

    async def squad_id_for_code(self, code: str) -> str | None: ...

    async def get_squad(self, squad_id: str) -> Squad | None: ...

    async def add_member(self, squad_id: str, member: SquadMember) -> None: ...

    async def update_member(self, squad_id: str, member: SquadMember) -> None: ...

    async def remove_member(self, squad_id: str, uid: str) -> None: ...

    async def set_owner(self, squad_id: str, uid: str) -> None: ...

    async def delete_squad(self, squad_id: str, invite_code: str) -> None: ...

    # ----- Ranking semanal -----

    async def list_squads(self) -> list[tuple[str, Squad]]: ...

    async def get_snapshots(self, week_id: str, puuids: list[str]) -> dict[str, RankSnapshot]: ...

    async def save_snapshots(self, week_id: str, snapshots: dict[str, RankSnapshot]) -> None: ...

    async def get_ranking(self, squad_id: str, week_id: str) -> WeeklyRanking | None: ...

    async def save_ranking(self, squad_id: str, ranking: WeeklyRanking) -> None: ...

    # ----- Notificações -----

    async def get_fcm_tokens(self, uids: list[str]) -> dict[str, list[str]]: ...

    async def remove_fcm_tokens(self, uid: str, tokens: list[str]) -> None: ...


def _dump(model: Any) -> dict[str, Any]:
    # by_alias: camelCase, o mesmo formato que o app lê do Firestore.
    return model.model_dump(by_alias=True)


class FirestoreStore:
    def __init__(self, db: Any) -> None:  # google.cloud.firestore.AsyncClient
        self._db = db

    def _user(self, uid: str) -> Any:
        return self._db.collection(USERS).document(uid)

    def _squad(self, squad_id: str) -> Any:
        return self._db.collection(SQUADS).document(squad_id)

    def _code(self, code: str) -> Any:
        return self._db.collection(INVITE_CODES).document(code)

    async def get_user(self, uid: str) -> UserRecord | None:
        snap = await self._user(uid).get()
        return UserRecord.model_validate(snap.to_dict()) if snap.exists else None

    async def set_user_riot_id(
        self, uid: str, display_name: str | None, riot_id: RiotId, puuid: str, profile_icon_url: str | None,
    ) -> None:
        # merge=True: cria o documento se não existir, sem apagar squads e tokens.
        await self._user(uid).set({
            "displayName": display_name, "riotId": _dump(riot_id),
            "puuid": puuid, "profileIconUrl": profile_icon_url,
        }, merge=True)

    async def add_fcm_token(self, uid: str, token: str) -> None:
        from google.cloud.firestore import ArrayUnion

        await self._user(uid).set({"fcmTokens": ArrayUnion([token])}, merge=True)

    async def invite_code_exists(self, code: str) -> bool:
        return (await self._code(code).get()).exists

    async def create_squad(self, squad: Squad) -> str:
        from google.cloud.firestore import ArrayUnion

        ref = self._db.collection(SQUADS).document()  # id aleatório
        batch = self._db.batch()  # tudo ou nada
        batch.set(ref, _dump(squad))
        batch.set(self._code(squad.invite_code), {"squadId": ref.id})
        batch.set(self._user(squad.owner_uid), {"squadIds": ArrayUnion([ref.id])}, merge=True)
        await batch.commit()
        return ref.id

    async def squad_id_for_code(self, code: str) -> str | None:
        snap = await self._code(code).get()
        return snap.to_dict()["squadId"] if snap.exists else None

    async def get_squad(self, squad_id: str) -> Squad | None:
        snap = await self._squad(squad_id).get()
        return Squad.model_validate(snap.to_dict()) if snap.exists else None

    async def add_member(self, squad_id: str, member: SquadMember) -> None:
        from google.cloud.firestore import ArrayUnion

        batch = self._db.batch()
        batch.update(self._squad(squad_id), {
            "memberUids": ArrayUnion([member.uid]),
            f"members.{member.uid}": _dump(member),
        })
        batch.set(self._user(member.uid), {"squadIds": ArrayUnion([squad_id])}, merge=True)
        await batch.commit()

    async def update_member(self, squad_id: str, member: SquadMember) -> None:
        await self._squad(squad_id).update({f"members.{member.uid}": _dump(member)})

    async def remove_member(self, squad_id: str, uid: str) -> None:
        from google.cloud.firestore import DELETE_FIELD, ArrayRemove

        batch = self._db.batch()
        batch.update(self._squad(squad_id), {
            "memberUids": ArrayRemove([uid]),
            f"members.{uid}": DELETE_FIELD,
        })
        batch.set(self._user(uid), {"squadIds": ArrayRemove([squad_id])}, merge=True)
        await batch.commit()

    async def set_owner(self, squad_id: str, uid: str) -> None:
        await self._squad(squad_id).update({"ownerUid": uid})

    async def delete_squad(self, squad_id: str, invite_code: str) -> None:
        batch = self._db.batch()
        batch.delete(self._squad(squad_id))
        batch.delete(self._code(invite_code))
        await batch.commit()

    # ----- Ranking semanal -----

    async def list_squads(self) -> list[tuple[str, Squad]]:
        return [(doc.id, Squad.model_validate(doc.to_dict())) async for doc in self._db.collection(SQUADS).stream()]

    def _snapshots(self, week_id: str) -> Any:
        return self._db.collection(WEEKS).document(week_id).collection("snapshots")

    async def get_snapshots(self, week_id: str, puuids: list[str]) -> dict[str, RankSnapshot]:
        refs = [self._snapshots(week_id).document(p) for p in puuids]
        found: dict[str, RankSnapshot] = {}
        async for snap in self._db.get_all(refs):  # uma ida ao banco para todos
            if snap.exists:
                found[snap.id] = RankSnapshot.model_validate(snap.to_dict())
        return found

    async def save_snapshots(self, week_id: str, snapshots: dict[str, RankSnapshot]) -> None:
        batch = self._db.batch()
        for puuid, snapshot in snapshots.items():
            batch.set(self._snapshots(week_id).document(puuid), _dump(snapshot))
        await batch.commit()

    async def get_ranking(self, squad_id: str, week_id: str) -> WeeklyRanking | None:
        snap = await self._squad(squad_id).collection(RANKINGS).document(week_id).get()
        return WeeklyRanking.model_validate(snap.to_dict()) if snap.exists else None

    async def save_ranking(self, squad_id: str, ranking: WeeklyRanking) -> None:
        await self._squad(squad_id).collection(RANKINGS).document(ranking.week_id).set(_dump(ranking))

    # ----- Notificações -----

    async def get_fcm_tokens(self, uids: list[str]) -> dict[str, list[str]]:
        refs = [self._user(uid) for uid in uids]
        tokens: dict[str, list[str]] = {}
        async for snap in self._db.get_all(refs):
            if snap.exists and (user_tokens := (snap.to_dict() or {}).get("fcmTokens")):
                tokens[snap.id] = list(user_tokens)
        return tokens

    async def remove_fcm_tokens(self, uid: str, tokens: list[str]) -> None:
        from google.cloud.firestore import ArrayRemove

        await self._user(uid).set({"fcmTokens": ArrayRemove(tokens)}, merge=True)

