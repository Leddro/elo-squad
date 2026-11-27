import 'package:material_ui/material_ui.dart';

import '../../../../core/error/failure.dart';

/// Ícone "Poro What?!" (id 5257) do Data Dragon oficial da Riot.
const _poroWhatUrl =
    'https://ddragon.leagueoflegends.com/cdn/16.23.1/img/profileicon/5257.png';

/// Tela de erro: escolhe ilustração, texto e ação para CADA tipo de Failure.
class FailureView extends StatelessWidget {
  const FailureView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onSearchAgain,
  });

  /// `Object`, e não `Failure`: o AsyncError do Riverpod guarda qualquer coisa.
  /// O repositório promete lançar só Failure, mas um bug poderia lançar outra.
  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onSearchAgain;

  @override
  Widget build(BuildContext context) {
    final failure = switch (error) {
      final Failure f => f,
      final other => UnexpectedFailure(other),
    };

    // Switch exaustivo SEM curinga: uma Failure nova não compila até ganhar
    // a sua própria tela aqui. O resultado é um "record" (tupla com nomes).
    final content = switch (failure) {
      NotFoundFailure() => (
        illustration: const _PoroIllustration(),
        title: 'Não encontramos esse jogador',
        message: 'Confira o nome e a tag. Exemplo: Fulano#BR1',
        canRetry: false, // tentar de novo não muda o resultado
      ),
      NoConnectionFailure() => (
        illustration: const _IconIllustration(Icons.wifi_off),
        title: 'Sem conexão',
        message: 'Verifique sua internet e tente de novo.',
        canRetry: true,
      ),
      ServerUnreachableFailure() => (
        illustration: const _IconIllustration(Icons.dns_outlined),
        title: 'O servidor não respondeu',
        message: 'Ele pode estar acordando. Tente de novo em instantes.',
        canRetry: true,
      ),
      RateLimitedFailure(:final retryAfter) => (
        illustration: const _IconIllustration(Icons.hourglass_top),
        title: 'Muitas buscas seguidas',
        message: 'Aguarde ${retryAfter.inSeconds}s e tente de novo.',
        canRetry: true,
      ),
      UpstreamUnavailableFailure() => (
        illustration: const _IconIllustration(Icons.cloud_off),
        title: 'Riot indisponível',
        message: 'Os servidores da Riot não responderam. Tente em instantes.',
        canRetry: true,
      ),
      UnauthenticatedFailure() => (
        illustration: const _IconIllustration(Icons.lock_clock),
        title: 'Sessão expirada',
        message: 'Saia e entre de novo com a sua conta Google.',
        canRetry: true,
      ),
      // Não acontece na busca de perfil, mas o switch exige tratar.
      SquadFailure() || AuthFailure() || UnexpectedFailure() => (
        illustration: const _IconIllustration(Icons.error_outline),
        title: 'Algo deu errado',
        message: 'Tente de novo. Se continuar, avise no grupo.',
        canRetry: true,
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            content.illustration,
            const SizedBox(height: 16),
            Text(
              content.title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(content.message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (content.canRetry)
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar de novo'),
              )
            else
              FilledButton.icon(
                onPressed: onSearchAgain,
                icon: const Icon(Icons.search),
                label: const Text('Buscar outro jogador'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PoroIllustration extends StatelessWidget {
  const _PoroIllustration();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Image.network(
      _poroWhatUrl,
      width: 120,
      height: 120,
      errorBuilder: (_, _, _) => const _IconIllustration(Icons.search_off),
    ),
  );
}

class _IconIllustration extends StatelessWidget {
  const _IconIllustration(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary);
}
