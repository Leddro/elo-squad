import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            // invalidate: descarta o estado atual e manda buscar de novo.
            // read(...future): espera essa nova busca terminar, para o
            // indicador de "atualizando" sumir na hora certa.
            ref.invalidate(provider);
            try {
              await ref.read(provider.future);
            } on Object {
              // A falha já é avisada pelo ref.listen acima (SnackBar).
            }
          },
          child: ProfileView(profile: value),
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
