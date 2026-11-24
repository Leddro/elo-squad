import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';

void main() {
  // ProviderScope: onde o Riverpod guarda o estado de todos os providers.
  // Precisa envolver o app inteiro, senão nenhum ref.watch funciona.
  runApp(const ProviderScope(child: EloSquadApp()));
}
