import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/formatters.dart';
import '../../../../core/presentation/widgets/network_avatar.dart';
import '../../domain/entities/mastery.dart';
import '../../domain/entities/ranked.dart';
import '../../domain/entities/summoner_profile.dart';
import '../formatters.dart';

/// O perfil carregado. Recebe a ENTIDADE pronta: não sabe nada de Riverpod,
/// Dio ou carregamento. Widgets assim ("burros", só exibem) são fáceis de
/// reaproveitar e de testar.
///
/// Não rola sozinho: é um pedaço da rolagem da ProfilePage, junto com o
/// histórico de partidas.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.profile});

  final SummonerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(profile: profile),
        const SizedBox(height: 24),
        const _SectionTitle('Ranqueado'),
        _RankedSection(ranked: profile.ranked),
        const SizedBox(height: 24),
        const _SectionTitle('Campeões mais jogados'),
        _MasteriesSection(masteries: profile.topMasteries),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final SummonerProfile profile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        NetworkAvatar(url: profile.profileIconUrl, size: 72),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.riotId.toString(), style: text.titleLarge),
              Text('Nível ${profile.level}', style: text.bodyMedium),
              Text(
                'Atualizado ${formatTimeAgo(profile.fetchedAt, now: DateTime.now())}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
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

/// Aviso de seção que falhou (resposta parcial do proxy).
class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.cloud_off),
      title: Text(message),
      subtitle: const Text('Puxe a tela para baixo para tentar de novo.'),
    ),
  );
}

class _RankedSection extends StatelessWidget {
  const _RankedSection({required this.ranked});

  final Ranked? ranked;

  @override
  Widget build(BuildContext context) {
    // Os dois "nulls" diferentes, cada um com a sua tela:
    final ranked = this.ranked;
    if (ranked == null) {
      return const _UnavailableNotice('Ranqueado indisponível no momento');
    }
    return Row(
      children: [
        Expanded(
          child: _RankedCard(queue: 'Solo/Duo', entry: ranked.solo),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RankedCard(queue: 'Flex', entry: ranked.flex),
        ),
      ],
    );
  }
}

class _RankedCard extends StatelessWidget {
  const _RankedCard({required this.queue, required this.entry});

  final String queue;
  final RankedEntry? entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final entry = this.entry;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(queue, style: text.labelLarge),
            const SizedBox(height: 4),
            if (entry == null)
              Text('Sem ranque', style: text.titleMedium)
            else ...[
              Text(rankLabel(entry), style: text.titleMedium),
              Text('${entry.lp} PDL'),
              Text(
                '${entry.wins}V ${entry.losses}D · ${formatWinRate(entry.winRate)}',
                style: text.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MasteriesSection extends StatelessWidget {
  const _MasteriesSection({required this.masteries});

  final List<Mastery>? masteries;

  @override
  Widget build(BuildContext context) {
    final masteries = this.masteries;
    if (masteries == null) {
      return const _UnavailableNotice('Maestrias indisponíveis no momento');
    }
    if (masteries.isEmpty) {
      return const Text('Nenhuma maestria ainda.');
    }
    return Card(
      child: Column(
        children: [
          for (final mastery in masteries)
            ListTile(
              leading: NetworkAvatar(
                url: mastery.championIconUrl,
                size: 40,
                fallbackIcon: Icons.shield,
              ),
              title: Text(
                mastery.championName ?? 'Campeão #${mastery.championId}',
              ),
              subtitle: Text(
                'Nível ${mastery.level} · ${formatThousands(mastery.points)} pontos',
              ),
            ),
        ],
      ),
    );
  }
}
