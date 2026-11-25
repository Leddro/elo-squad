import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/match_data_providers.dart';
import '../../domain/entities/match_history.dart';

// Três providers, um para cada pergunta que a tela faz:
//   1. O que está salvo?               → matchHistoryProvider   (leitura)
//   2. A atualização deu certo?        → matchRefreshProvider   (escrita)
//   3. A próxima página deu certo?     → matchLoadMoreProvider  (escrita)
//
// Repare que (2) e (3) NÃO devolvem partidas: elas chegam pelo (1), que
// observa o banco (fonte única da verdade).

/// O histórico salvo no aparelho, atualizado sozinho a cada escrita no banco.
///
/// StreamProvider: igual ao FutureProvider, mas para um Stream. O AsyncValue
/// muda a cada evento do Stream, e a tela se redesenha.
final matchHistoryProvider = StreamProvider.autoDispose
    .family<MatchHistory, String>(
      (ref, puuid) => ref.watch(matchRepositoryProvider).watchHistory(puuid),
      retry: (_, _) => null,
    );

/// A atualização da primeira página. Roda quando a tela começa a observar
/// (abrir o perfil) e de novo a cada `ref.invalidate` (puxar para atualizar).
///
/// STALE-WHILE-REVALIDATE: enquanto isto carrega, a tela já mostra o que
/// estava salvo (o "velho"), e troca pelo novo quando o banco mudar.
final matchRefreshProvider = FutureProvider.autoDispose.family<void, String>(
  (ref, puuid) => ref.watch(matchRepositoryProvider).refresh(puuid),
  retry: (_, _) => null, // 429 não melhora tentando de novo sozinho
);

/// O carregamento da próxima página (rolagem infinita).
///
/// NOTIFIER: um provider com MÉTODOS. O FutureProvider só sabe "rodar de
/// novo"; aqui a tela chama `loadMore()` quando quiser, quantas vezes quiser.
final matchLoadMoreProvider = AsyncNotifierProvider.autoDispose
    .family<MatchLoadMore, void, String>(
      // No Riverpod 3, o argumento do family chega pelo CONSTRUTOR.
      MatchLoadMore.new,
      retry: (_, _) => null,
    );

class MatchLoadMore extends AsyncNotifier<void> {
  MatchLoadMore(this.puuid);

  final String puuid;

  /// Estado inicial: ocioso (AsyncData). Nada a buscar ao criar.
  @override
  FutureOr<void> build() {}

  Future<void> loadMore() async {
    // TRAVA: a rolagem pode pedir a mesma página duas vezes seguidas.
    if (state.isLoading) return;

    state = const AsyncLoading();
    // guard: roda a função e devolve AsyncData (deu certo) ou AsyncError
    // (lançou), sem precisar de try/catch aqui.
    final result = await AsyncValue.guard(
      () => ref.read(matchRepositoryProvider).loadMore(puuid),
    );
    // ref.mounted (novo no Riverpod 3): o usuário pode ter saído da tela
    // durante o await. Provider descartado não recebe mais estado.
    if (ref.mounted) state = result;
  }
}
