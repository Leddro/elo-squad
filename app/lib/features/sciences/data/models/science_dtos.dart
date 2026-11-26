import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/network/json.dart';
import '../../../squads/data/models/ranking_dtos.dart' show TimestampConverter;
import '../../domain/entities/science.dart';

part 'science_dtos.freezed.dart';
part 'science_dtos.g.dart';

/// Documento sciences/current, publicado pela coleta diária (backend).
@freezed
abstract class SciencesBoardDto with _$SciencesBoardDto {
  const SciencesBoardDto._();

  const factory SciencesBoardDto({
    required String patch,
    @TimestampConverter() required DateTime updatedAt,
    required List<ScienceBuildDto> builds,
  }) = _SciencesBoardDto;

  factory SciencesBoardDto.fromJson(Json json) =>
      _$SciencesBoardDtoFromJson(json);

  SciencesBoard toEntity() => SciencesBoard(
    patch: patch,
    updatedAt: updatedAt,
    builds: [
      // Rota desconhecida (versão nova do backend): a build é ignorada.
      for (final b in builds) ?b.toEntity(),
    ],
  );
}

@freezed
abstract class ScienceBuildDto with _$ScienceBuildDto {
  const ScienceBuildDto._();

  const factory ScienceBuildDto({
    required String title,
    required String championName,
    required String? championIconUrl,
    required String role,
    required List<ScienceItemDto> items,
    required ScienceItemDto? boots,
    required String skills,
    required String maxOrder,
  }) = _ScienceBuildDto;

  factory ScienceBuildDto.fromJson(Json json) =>
      _$ScienceBuildDtoFromJson(json);

  ScienceBuild? toEntity() {
    final role = ScienceRole.fromRiot(this.role);
    if (role == null) return null;
    return ScienceBuild(
      title: title,
      championName: championName,
      championIconUrl: championIconUrl,
      role: role,
      items: [for (final i in items) i.toEntity()],
      boots: boots?.toEntity(),
      skills: skills,
      maxOrder: maxOrder,
    );
  }
}

@freezed
abstract class ScienceItemDto with _$ScienceItemDto {
  const ScienceItemDto._();

  const factory ScienceItemDto({
    required int id,
    required String name,
    required String? iconUrl,
  }) = _ScienceItemDto;

  factory ScienceItemDto.fromJson(Json json) => _$ScienceItemDtoFromJson(json);

  ScienceItem toEntity() => ScienceItem(id: id, name: name, iconUrl: iconUrl);
}
