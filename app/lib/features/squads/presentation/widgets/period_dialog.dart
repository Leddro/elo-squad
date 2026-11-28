import 'package:material_ui/material_ui.dart';

import '../../domain/entities/squad.dart';
import 'ranking_section.dart' show dayMonth;

/// O que o líder escolheu: duração, datas (só nas datas próprias) e repetir.
typedef PeriodChoice = ({
  PeriodLength length,
  DateTime? startsAt,
  DateTime? endsAt,
  bool repeat,
});

/// Diálogo do líder para definir o período de disputa.
Future<PeriodChoice?> pickPeriod(BuildContext context, SquadPeriod? current) =>
    showDialog<PeriodChoice>(
      context: context,
      builder: (_) => _PeriodDialog(current: current),
    );

class _PeriodDialog extends StatefulWidget {
  const _PeriodDialog({required this.current});

  final SquadPeriod? current;

  @override
  State<_PeriodDialog> createState() => _PeriodDialogState();
}

class _PeriodDialogState extends State<_PeriodDialog> {
  late PeriodLength _length = widget.current?.length ?? PeriodLength.week;
  late bool _repeat = widget.current?.repeat ?? true;
  late DateTime _start = _today;
  late DateTime _lastDay = _today.add(const Duration(days: 6));

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _custom => _length == PeriodLength.custom;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Período de disputa'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final length in PeriodLength.values)
                  ChoiceChip(
                    label: Text(length.label),
                    selected: _length == length,
                    onSelected: (_) => setState(() => _length = length),
                  ),
              ],
            ),
            if (_custom) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Começa'),
                trailing: Text(_start == _today ? 'Agora' : dayMonth(_start)),
                onTap: () => _pick(start: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available),
                title: const Text('Último dia'),
                trailing: Text(dayMonth(_lastDay)),
                onTap: () => _pick(start: false),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Começa agora e vai até a meia-noite do último dia.',
                  style: text.bodySmall,
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repetir ao acabar'),
              value: _repeat,
              onChanged: (value) => setState(() => _repeat = value),
            ),
            Text(
              'O período atual termina agora, sem troféus. Os pontos são o '
              'PDL ganho na Solo/Duo mais o bônus das vitórias com Ciências.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Começar')),
      ],
    );
  }

  Future<void> _pick({required bool start}) async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _lastDay,
      firstDate: start ? today : _start,
      lastDate: (start ? today : _start).add(const Duration(days: 91)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (!_lastDay.isAfter(_start)) {
          _lastDay = _start.add(const Duration(days: 6));
        }
      } else {
        _lastDay = picked;
      }
    });
  }

  void _confirm() {
    if (_custom && !_lastDay.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O último dia precisa ser depois do começo.'),
        ),
      );
      return;
    }
    Navigator.pop<PeriodChoice>(context, (
      length: _length,
      // Hoje: começa agora (o servidor usa o horário atual).
      startsAt: _custom ? _start : null,
      // Até a meia-noite do último dia.
      endsAt: _custom ? _lastDay.add(const Duration(days: 1)) : null,
      repeat: _repeat,
    ));
  }
}
