import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/router/app_router.dart';
import 'features/auth/data/auth_providers.dart';
import 'features/notifications/push_service.dart';

class EloSquadApp extends ConsumerStatefulWidget {
  const EloSquadApp({super.key});

  // Cor-semente: o Material 3 gera a paleta inteira (claro e escuro) a partir dela.
  static const _seed = Color(0xFF0AC8B9);

  @override
  ConsumerState<EloSquadApp> createState() => _EloSquadAppState();
}

class _EloSquadAppState extends ConsumerState<EloSquadApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _subscriptions = <StreamSubscription<Object>>[];

  @override
  void initState() {
    super.initState();
    final push = ref.read(pushServiceProvider);

    // Logou (ou abriu já logado): registra o aparelho para receber push.
    ref.listenManual(authStateProvider, (previous, next) {
      final uid = next.value?.uid;
      if (uid != null && uid != previous?.value?.uid) push.register();
    }, fireImmediately: true);

    _subscriptions
      ..add(
        push.foreground.listen((message) {
          _messenger.currentState?.showSnackBar(
            SnackBar(content: Text('${message.title}\n${message.body}')),
          );
        }),
      )
      ..add(
        push.openedSquads.listen(
          (squadId) => ref
              .read(routerProvider)
              .pushNamed(Routes.squad, pathParameters: {'squadId': squadId}),
        ),
      );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Elo Squad',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      theme: ThemeData(
        colorSchemeSeed: EloSquadApp._seed,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: EloSquadApp._seed,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system, // segue o tema do celular
      routerConfig: ref.watch(routerProvider),
    );
  }
}
