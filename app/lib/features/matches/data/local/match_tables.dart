import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/network/json.dart';
import '../../domain/entities/match_summary.dart';
import '../models/match_page_dto.dart';

// Tabelas do cache offline do histórico. O drift lê estas classes e GERA o
// SQL (CREATE TABLE...), a classe de cada linha e as consultas tipadas.
//
// Modelagem HÍBRIDA:
// - Colunas de verdade para o que o SQL precisa enxergar: filtrar por
//   jogador, ordenar por data e, na fase 3, contar vitórias e somar KDA da
//   semana para o ranking (`WHERE result = 'win' AND played_at > ...`).
// - JSON numa coluna de texto para o que só é lido inteiro: os itens. Ninguém
//   vai filtrar "partidas com o item 3078 no 2º espaço".

/// Uma linha = uma partida do ponto de vista de UM jogador.
///
/// CHAVE PRIMÁRIA COMPOSTA (puuid + matchId): se dois amigos jogaram juntos, a
/// mesma partida aparece no histórico dos dois, cada um com o seu campeão e o
/// seu KDA. Só o matchId não seria único.
///
/// ÍNDICE (puuid, played_at): a consulta da tela é "partidas DESTE jogador,
/// da mais nova para a mais antiga". O índice deixa o SQLite achar e ordenar
/// essas linhas sem varrer a tabela inteira.
@DataClassName('MatchRow') // nome da classe gerada para cada linha
@TableIndex(name: 'cached_matches_by_player', columns: {#puuid, #playedAt})
class CachedMatches extends Table {
  TextColumn get puuid => text()();
  TextColumn get matchId => text()();

  // textEnum: guarda o NOME do valor ("rankedSolo"), e não a posição (0, 1...).
  // Assim, reordenar o enum não corrompe os dados salvos. Renomear um valor
  // ainda corromperia: isso exigiria uma migração.
  TextColumn get queue => textEnum<QueueType>()();
  TextColumn get result => textEnum<MatchResult>()();

  IntColumn get placement => integer().nullable()();
  IntColumn get championId => integer()();
  TextColumn get championName => text().nullable()();
  TextColumn get championIconUrl => text().nullable()();
  IntColumn get kills => integer()();
  IntColumn get deaths => integer()();
  IntColumn get assists => integer()();
  IntColumn get cs => integer()();

  // map(conversor): no banco é TEXT (JSON); no Dart, a linha já entrega o
  // tipo pronto (List<Item?>), sem jsonDecode espalhado pelo código.
  TextColumn get items => text().map(const ItemsConverter())();
  TextColumn get trinket => text().map(const ItemConverter()).nullable()();

  IntColumn get durationSeconds => integer()();
  DateTimeColumn get playedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {puuid, matchId};
}

/// Uma linha por jogador: o "estado" do histórico salvo dele.
@DataClassName('MatchHistoryRow')
class MatchHistories extends Table {
  TextColumn get puuid => text()();

  /// true quando a última página já chegou (não há partidas mais antigas).
  BoolColumn get reachedEnd => boolean()();

  /// Quando a primeira página foi atualizada pela última vez.
  DateTimeColumn get refreshedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {puuid};
}

// ---------- Conversores de tipo (TypeConverter) ----------
//
// Traduzem um tipo do Dart para um tipo que o SQLite entende, e de volta.
// Reaproveitam o ItemDto: o formato do JSON salvo é o mesmo do proxy.

/// Um [Item] ⇄ texto JSON. Na coluna anulável (`trinket`), o drift trata o
/// null sozinho e só chama este conversor para valores não nulos.
class ItemConverter extends TypeConverter<Item, String> {
  const ItemConverter();

  @override
  String toSql(Item value) => jsonEncode(ItemDto.fromEntity(value).toJson());

  @override
  Item fromSql(String fromDb) =>
      ItemDto.fromJson(jsonDecode(fromDb) as Json).toEntity();
}

/// Os 6 espaços do inventário ⇄ texto JSON (`[{...}, null, {...}, ...]`).
class ItemsConverter extends TypeConverter<List<Item?>, String> {
  const ItemsConverter();

  @override
  String toSql(List<Item?> value) => jsonEncode([
    for (final item in value)
      item == null ? null : ItemDto.fromEntity(item).toJson(),
  ]);

  @override
  List<Item?> fromSql(String fromDb) => [
    for (final json in jsonDecode(fromDb) as List<dynamic>)
      json == null ? null : ItemDto.fromJson(json as Json).toEntity(),
  ];
}
