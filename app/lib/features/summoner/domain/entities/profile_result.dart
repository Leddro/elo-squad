import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failure.dart';
import 'summoner_profile.dart';

part 'profile_result.freezed.dart';

/// O resultado de uma busca de perfil: o perfil e DE ONDE ele veio.
///
/// Sem internet (ou com a Riot fora), o repositório devolve o perfil salvo no
/// aparelho, com [staleBecause] dizendo por que não deu para atualizar. A
/// tela usa isso para avisar "mostrando o perfil salvo".
@freezed
abstract class ProfileResult with _$ProfileResult {
  const ProfileResult._();

  const factory ProfileResult({
    required SummonerProfile profile,

    /// null = veio do proxy agora (atualizado).
    Failure? staleBecause,
  }) = _ProfileResult;

  /// true = veio do cache local, porque a busca falhou.
  bool get isStale => staleBecause != null;
}
