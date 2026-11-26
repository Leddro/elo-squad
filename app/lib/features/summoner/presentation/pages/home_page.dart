import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/failure_messages.dart';
import '../../../../core/presentation/widgets/elo_squad_logo.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/sign_out.dart';
import '../../../squads/domain/entities/squad.dart';
import '../../../squads/presentation/providers/squad_providers.dart';
import '../../domain/entities/riot_id.dart';
import '../providers/summoner_profile_provider.dart';
import '../widgets/profile_skeleton.dart';
import '../widgets/profile_view.dart';

/// Tela inicial: barra de busca e, embaixo, o perfil do dono da conta.
///
/// StatefulWidget (e não Riverpod) de propósito: o texto digitado e a mensagem
/// de erro do campo são ESTADO EFÊMERO, que só esta tela usa e que pode sumir
/// quando ela fecha. Riverpod é para estado compartilhado ou que vem de fora
/// (como o perfil buscado).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    // Validação ANTES de qualquer requisição: Riot ID inválido nem sai do celular.
    final riotId = RiotId.tryParse(_controller.text);
    if (riotId == null) {
      setState(
        () => _errorText = 'Use o formato nome#tag. Exemplo: Fulano#BR1',
      );
      return;
    }

    setState(() => _errorText = null);
    FocusScope.of(context).unfocus(); // fecha o teclado
    // Pelo NOME da rota; o go_router monta e codifica o caminho.
    context.pushNamed(
      Routes.profile,
      pathParameters: {'gameName': riotId.gameName, 'tagLine': riotId.tagLine},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elo Squad'),
        actions: const [_SignOutButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Riot ID',
                hintText: 'Fulano#BR1',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _search,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Expanded(child: _MyProfile()),
          ],
        ),
      ),
    );
  }
}

/// O perfil do dono da conta (o Riot ID vinculado). Sem vínculo, convida a
/// vincular.
class _MyProfile extends ConsumerWidget {
  const _MyProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(accountProvider)) {
      AsyncValue(value: AccountLink(:final riotId?)) => _OwnProfile(
        riotId: riotId,
      ),
      AsyncValue(hasValue: true) ||
      AsyncValue(hasError: true) => const _NoRiotId(),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _OwnProfile extends ConsumerWidget {
  const _OwnProfile({required this.riotId});

  final RiotId riotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = summonerProfileProvider(riotId);
    return switch (ref.watch(provider)) {
      AsyncValue(:final value?) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(provider);
          await ref.read(provider.future).then((_) {}, onError: (_) {});
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            ProfileView(profile: value.profile),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.pushNamed(
                Routes.profile,
                pathParameters: {
                  'gameName': riotId.gameName,
                  'tagLine': riotId.tagLine,
                },
              ),
              icon: const Icon(Icons.history),
              label: const Text('Ver partidas'),
            ),
          ],
        ),
      ),
      AsyncValue(:final error?, isLoading: false) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(shortFailureMessage(error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(provider),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
      _ => const ProfileSkeleton(),
    };
  }
}

class _NoRiotId extends StatelessWidget {
  const _NoRiotId();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const EloSquadEmblem(size: 96),
        const SizedBox(height: 16),
        Text(
          'Busque um invocador pelo Riot ID',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => context.pushNamed(Routes.linkRiotId),
          icon: const Icon(Icons.link),
          label: const Text('Vincular o meu Riot ID'),
        ),
      ],
    ),
  );
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Sair',
    icon: const Icon(Icons.logout),
    onPressed: () async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sair da conta?'),
          content: const Text('Tem certeza que deseja sair?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sair'),
            ),
          ],
        ),
      );
      // Depois do logout, o roteador leva ao login sozinho.
      if (confirmed ?? false) await ref.read(signOutProvider)();
    },
  );
}
