import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/failure_messages.dart';
import '../../../../core/presentation/formatters.dart';
import '../../domain/entities/match_history.dart';
import '../providers/match_history_providers.dart';
import 'match_tile.dart';

/// A seção "Partidas recentes", feita para ficar DENTRO de uma rolagem maior
/// (o CustomScrollView da tela de perfil).
///
/// SLIVER: um pedaço de uma área rolável. Uma lista comum (ListView) dentro de
/// outra rolagem teria de construir TODOS os itens de uma vez; um sliver deixa
/// a rolagem de fora construir só os itens perto da tela (lazy).
class MatchHistorySliver extends ConsumerWidget {
  const MatchHistorySliver({super.key, required this.puuid});

  final String puuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(matchHistoryProvider(puuid));
    // Observar o refresh também o DISPARA: ao abrir o perfil, a primeira
    // página é atualizada em segundo plano, com o cache já na tela.
    final refresh = ref.watch(matchRefreshProvider(puuid));
    final loadMore = ref.watch(matchLoadMoreProvider(puuid));

    // SliverMainAxisGroup: junta vários slivers (título + lista) num só.
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: _SectionTitle('Partidas recentes')),
        ...switch (history) {
          AsyncValue(:final value?) => _loaded(ref, value, refresh, loadMore),
          // Erro ao LER o banco local (raro): tenta abrir o Stream de novo.
          AsyncValue(:final error?) => [
            SliverToBoxAdapter(
              child: _ErrorCard(
                message: shortFailureMessage(error),
                onRetry: () => ref.invalidate(matchHistoryProvider(puuid)),
              ),
            ),
          ],
          _ => const [SliverToBoxAdapter(child: MatchListSkeleton())],
        },
      ],
    );
  }

  List<Widget> _loaded(
    WidgetRef ref,
    MatchHistory history,
    AsyncValue<void> refresh,
    AsyncValue<void> loadMore,
  ) {
    final refreshError = refresh.isLoading ? null : refresh.error;

    // Nada salvo ainda: depende só da primeira busca.
    if (history.neverLoaded) {
      return [
        SliverToBoxAdapter(
          child: refreshError == null
              ? const MatchListSkeleton()
              : _ErrorCard(
                  message: shortFailureMessage(refreshError),
                  onRetry: () => ref.invalidate(matchRefreshProvider(puuid)),
                ),
        ),
      ];
    }

    final matches = history.matches;
    return [
      // Tem cache, mas a atualização falhou: mostra o cache e avisa.
      if (refreshError != null)
        SliverToBoxAdapter(
          child: _StaleNotice(
            message: shortFailureMessage(refreshError),
            savedAt: history.refreshedAt!,
          ),
        ),
      if (matches.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Nenhuma partida recente.'),
          ),
        )
      else
        // builder: só constrói os itens perto da tela. O ÚLTIMO item é o
        // rodapé (+1), que dispara a próxima página quando é construído.
        //
        // A cada página nova, o rodapé vai para um índice novo, e o
        // SliverList cria um elemento novo para ele: o sentinela nasce de
        // novo e dispara. (Limite conhecido: se uma página trouxer só
        // partidas repetidas, a contagem não muda e o indicador fica girando
        // até o usuário rolar. Disparar a cada redesenho seria pior: num caso
        // assim, viraria um loop de requisições.)
        SliverList.builder(
          itemCount: matches.length + 1,
          itemBuilder: (context, index) => index < matches.length
              ? MatchTile(match: matches[index])
              : _ListFooter(
                  hasMore: history.hasMore,
                  loadMore: loadMore,
                  onLoadMore: () => ref
                      .read(matchLoadMoreProvider(puuid).notifier)
                      .loadMore(),
                ),
        ),
    ];
  }
}

/// Fim da lista: carregando a próxima página, erro, ou "acabou".
class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.hasMore,
    required this.loadMore,
    required this.onLoadMore,
  });

  final bool hasMore;
  final AsyncValue<void> loadMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Fim do histórico')),
      );
    }
    // Falhou: espera o usuário pedir. Tentar sozinho, num 429, viraria um
    // loop de requisições piorando o próprio rate limit.
    if (loadMore case AsyncValue(:final error?, isLoading: false)) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(shortFailureMessage(error), textAlign: TextAlign.center),
            TextButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }
    return _LoadMoreSentinel(onVisible: onLoadMore);
  }
}

/// SENTINELA da rolagem infinita: um item que, ao ser construído (ou seja,
/// quando o usuário rola até perto do fim), pede a próxima página.
///
/// Funciona também quando a lista é curta e nem dá para rolar: o sentinela já
/// nasce visível e dispara sozinho.
class _LoadMoreSentinel extends StatefulWidget {
  const _LoadMoreSentinel({required this.onVisible});

  final VoidCallback onVisible;

  @override
  State<_LoadMoreSentinel> createState() => _LoadMoreSentinelState();
}

class _LoadMoreSentinelState extends State<_LoadMoreSentinel> {
  @override
  void initState() {
    super.initState();
    // Depois do frame: mudar o estado de um provider DURANTE a construção
    // dos widgets é proibido (o Riverpod lança erro).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// "Mostrando partidas salvas": o cache está na tela, mas está velho.
class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.message, required this.savedAt});

  final String message;
  final DateTime savedAt;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.cloud_off),
      title: Text(message),
      subtitle: Text(
        'Mostrando as partidas salvas '
        '${formatTimeAgo(savedAt, now: DateTime.now())}. '
        'Puxe a tela para tentar de novo.',
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar de novo'),
          ),
        ],
      ),
    ),
  );
}

/// Esqueleto da lista: retângulos no lugar das partidas, enquanto a primeira
/// página não chega. Estático (sem animação) de propósito: é rápido e não
/// atrapalha os testes.
class MatchListSkeleton extends StatelessWidget {
  const MatchListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Carregando partidas',
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: 84,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
        ],
      ),
    );
  }
}
