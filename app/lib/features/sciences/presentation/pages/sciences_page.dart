import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/failure_messages.dart';
import '../../../../core/presentation/formatters.dart';
import '../../domain/entities/science.dart';
import '../providers/science_providers.dart';
import '../widgets/science_card.dart';

/// Aba Ciências: builds incomuns de monochamps de elite que estão ganhando.
class SciencesPage extends ConsumerWidget {
  const SciencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(sciencesProvider);
    final role = ref.watch(scienceRoleFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ciências'),
        bottom: switch (board) {
          AsyncValue(value: final SciencesBoard value) => PreferredSize(
            preferredSize: const Size.fromHeight(20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Patch ${value.patch} · atualizado '
                '${formatTimeAgo(value.updatedAt, now: DateTime.now())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          _ => null,
        },
      ),
      body: switch (board) {
        AsyncValue(value: final SciencesBoard value)
            when value.builds.isNotEmpty =>
          _BuildList(builds: value.builds, role: role),
        AsyncValue(hasValue: true) => const _Message(
          icon: Icons.science_outlined,
          title: 'Nenhuma ciência ainda',
          body:
              'As builds aparecem depois de alguns dias de coleta de '
              'partidas dos monochamps de elite.',
        ),
        AsyncValue(:final error?) => _Message(
          icon: Icons.cloud_off,
          title: shortFailureMessage(error),
          body: 'Tente de novo em instantes.',
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _BuildList extends ConsumerWidget {
  const _BuildList({required this.builds, required this.role});

  final List<ScienceBuild> builds;
  final ScienceRole? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = [
      for (final b in builds)
        if (role == null || b.role == role) b,
    ];
    final filter = ref.read(scienceRoleFilterProvider.notifier);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: role == null,
                  onSelected: (_) => filter.select(null),
                ),
                for (final r in ScienceRole.values)
                  ChoiceChip(
                    label: Text(r.label),
                    selected: role == r,
                    onSelected: (_) => filter.select(r),
                  ),
              ],
            ),
          ),
        ),
        if (shown.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _Message(
              icon: Icons.filter_alt_off,
              title: 'Nenhuma ciência nesta rota',
              body: 'Tente outra rota ou "Todas".',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            sliver: SliverList.builder(
              itemCount: shown.length,
              itemBuilder: (_, i) => ScienceCard(science: shown[i]),
            ),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
