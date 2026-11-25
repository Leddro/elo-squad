import 'package:drift/drift.dart';

import '../../../../core/network/json.dart';
import '../models/summoner_profile_dto.dart';

/// Cópia do último perfil buscado de cada Riot ID (cache offline).
///
/// Aqui a modelagem é o oposto da tabela de partidas: o perfil inteiro vai
/// numa coluna JSON (um "blob"). O perfil só é lido INTEIRO, pela chave, e
/// nunca filtrado ou somado pelo SQL; colunas separadas seriam trabalho sem
/// ganho. E o JSON salvo é o mesmo do proxy, já testado na ida e volta
/// (`fromJson(dto.toJson()) == dto`).
@DataClassName('CachedProfileRow')
class CachedProfiles extends Table {
  /// `RiotId.storageKey`: "fulano#br1" (minúsculas).
  TextColumn get riotIdKey => text()();

  TextColumn get profile => text().map(profileDtoConverter)();

  @override
  Set<Column> get primaryKey => {riotIdKey};
}

/// SummonerProfileDto ⇄ texto JSON. `json2` é o conversor de JSON pronto do
/// drift: usa o `fromJson` dado e, na volta, o `toJson()` do próprio DTO.
final profileDtoConverter = TypeConverter.json2<SummonerProfileDto>(
  fromJson: (json) => SummonerProfileDto.fromJson(json! as Json),
);
