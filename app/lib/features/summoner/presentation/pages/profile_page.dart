import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../matches/presentation/providers/match_history_providers.dart';
import '../../../matches/presentation/widgets/match_history_sliver.dart';
import '../../domain/entities/riot_id.dart';
import '../providers/summoner_profile_provider.dart';
import '../widgets/failure_view.dart';
import '../widgets/profile_skeleton.dart';
import '../widgets/profile_view.dart';

/// Tela de perfil. Recebe o [riotId] pelo construtor: aqui ele SEMPRE existe
/// (o estado "nenhuma busca ainda" é da HomePage, não daqui).
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key, required this.riotId});

  final RiotId riotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = summonerProfileProvider(riotId);

    // ref.watch: "me dê o estado E me redesenhe quando ele mudar".
    final profile = ref.watch(provider);

    // ref.listen: "me AVISE quando mudar, sem redesenhar". Para efeitos
    // colaterais (SnackBar, navegação), que não devem rodar a cada build.
    // Caso: o usuário puxou para atualizar, já tinha um perfil na tela, e a
    // atualização falhou. Mantemos o perfil antigo e só avisamos.
    ref.listen(provider, (previous, next) {
      if (next.hasError && next.hasValue && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível atualizar agora.')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(riotId.toString())),
      // Padrões por PROPRIEDADE, na ordem certa. Detalhe do Riverpod 3: ao
      // recarregar, o estado mantém o tipo anterior (um AsyncError continua
      // AsyncError, só que com isLoading: true). Por isso não dá para
      // perguntar só "é AsyncError?".
      body: switch (profile) {
        // 1. Tem perfil (inclusive durante o puxar-para-atualizar): mostra.
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async {
            final matches = matchRefreshProvider(value.puuid);
            // invalidate: descarta o estado atual e manda buscar de novo.
            ref.invalidate(provider);
            ref.invalidate(matches);
            // Espera as DUAS buscas (em paralelo), para o indicador de
            // "atualizando" sumir na hora certa. As falhas já são avisadas
            // na tela: SnackBar do perfil (ref.listen) e aviso nas partidas.
            await Future.wait([
              ref.read(provider.future).then((_) {}, onError: (_) {}),
              ref.read(matches.future).then((_) {}, onError: (_) {}),
            ]);
          },
          // Uma rolagem só para a tela inteira, feita de SLIVERS: o perfil
          // no topo e o histórico embaixo, com rolagem infinita.
          // AlwaysScrollable: o "puxar para atualizar" precisa de algo
          // rolável, mesmo quando o conteúdo cabe inteiro na tela.
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverToBoxAdapter(child: ProfileView(profile: value)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: MatchHistorySliver(puuid: value.puuid),
              ),
            ],
          ),
        ),
        // 2. Tem erro e NÃO está tentando de novo: tela de erro.
        AsyncValue(:final error?, isLoading: false) => FailureView(
          error: error,
          onRetry: () => ref.invalidate(provider),
          onSearchAgain: () => Navigator.of(context).pop(),
        ),
        // 3. O que sobra é carregando: primeira busca ou nova tentativa.
        _ => const ProfileSkeleton(),
      },
    );
  }
}
