"""Ciências: builds incomuns de monochamps de elite, coletadas da Riot.

Fluxo (roda no GitHub Actions, uma vez por dia; ver collect.py):
  monochamps (apex + maestria) → partidas ranqueadas + linha do tempo →
  extract (build de cada partida) → aggregate (contadores no Firestore) →
  scoring (winrate, raridade, buffs do patch) → documento `sciences/current`,
  o único que o app lê.
"""
