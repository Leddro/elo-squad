import 'package:material_ui/material_ui.dart';

import 'features/summoner/presentation/pages/home_page.dart';

class EloSquadApp extends StatelessWidget {
  const EloSquadApp({super.key});

  // Cor-semente: o Material 3 gera a paleta inteira (claro e escuro) a partir dela.
  static const _seed = Color(0xFF0AC8B9);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elo Squad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      themeMode: ThemeMode.system, // segue o tema do celular
      home: const HomePage(),
    );
  }
}
