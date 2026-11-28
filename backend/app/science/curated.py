"""Ciências curadas à mão (vídeos de criadores), publicadas junto com as da coleta.

A lista fica em curated.json. A cada publicação, a taxa de vitória é refeita
com os dados da coleta, nesta ordem de preferência:
  1. a build (mesmo campeão, rota e 2 primeiros itens), com MIN_BUILD_GAMES;
  2. o campeão na base de comparação, com MIN_CHAMPION_GAMES;
  3. a taxa que o vídeo informa;
  4. sem dado: 0 partidas (o tier fica baixo até aparecerem dados).
O tier sai da mesma régua das outras Ciências (assign_tiers).
"""

import json
from pathlib import Path
from typing import Any

from app.science.aggregate import BuildStats, ChampionStats
from app.science.scoring import Science

CURATED_FILE = Path(__file__).with_name("curated.json")
MIN_BUILD_GAMES = 5
MIN_CHAMPION_GAMES = 30
VIDEO_SAMPLE = 20  # amostra "de mentira" para a taxa do vídeo entrar no Wilson sem valer demais


def load_curated(path: Path = CURATED_FILE) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def curated_sciences(
    data: dict[str, Any],
    builds: list[BuildStats],
    champions: dict[int, ChampionStats],
    base_matches: float,
    ban_matches: int,
) -> list[Science]:
    by_core: dict[tuple[int, str, tuple[int, ...]], tuple[int, int]] = {}
    for b in builds:
        key = (b.champion_id, b.role, tuple(b.core))
        games, wins = by_core.get(key, (0, 0))
        by_core[key] = (games + b.games, wins + b.wins)

    result = []
    for entry in data["builds"]:
        cid, role, items = entry["championId"], entry["role"], list(entry["items"])
        champ = champions.get(cid)
        games, wins = by_core.get((cid, role, tuple(items[:2])), (0, 0))
        basis = "build"
        if games < MIN_BUILD_GAMES:
            if champ is not None and champ.games >= MIN_CHAMPION_GAMES:
                games, wins, basis = champ.games, champ.wins, "champion"
            elif entry.get("videoWinRate") is not None:
                games, wins, basis = VIDEO_SAMPLE, round(entry["videoWinRate"] * VIDEO_SAMPLE), "video"
            else:
                games, wins, basis = 0, 0, "none"
        result.append(Science(
            champion_id=cid, role=role, title=entry["title"], items=items, boots=entry.get("boots"),
            skills="", max_order="", games=games, wins=wins, score=0.0,
            pick_rate=champ.roles[role] / base_matches if champ else 0.0,
            ban_rate=champ.bans / ban_matches if champ and ban_matches else 0.0,
            source=data.get("source"), video_url=f"https://www.youtube.com/watch?v={entry['video']}",
            win_rate_basis=basis,
        ))
    return result
