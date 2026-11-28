import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_providers.dart';
import '../../data/squad_data_providers.dart';
import '../../domain/entities/squad.dart';
import '../../domain/entities/squad_ranking.dart';

/// uid de quem está logado (o roteador garante que estas telas só abrem logado).
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);

/// A conta do usuário: Riot ID vinculado ou não.
final accountProvider = StreamProvider.autoDispose<AccountLink>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(AccountLink.empty);
  return ref.watch(squadRepositoryProvider).watchAccount(uid);
}, retry: (_, _) => null);

/// Os squads do usuário, em tempo real.
final mySquadsProvider = StreamProvider.autoDispose<List<Squad>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(squadRepositoryProvider).watchMySquads(uid);
}, retry: (_, _) => null);

/// Um squad, em tempo real. null = não existe mais, ou o usuário saiu.
final squadProvider = StreamProvider.autoDispose.family<Squad?, String>(
  (ref, squadId) => ref.watch(squadRepositoryProvider).watchSquad(squadId),
  retry: (_, _) => null,
);

/// O ranking mais recente de um squad, em tempo real.
final latestRankingProvider = StreamProvider.autoDispose
    .family<SquadRanking?, String>(
      (ref, squadId) =>
          ref.watch(squadRepositoryProvider).watchLatestRanking(squadId),
      retry: (_, _) => null,
    );
