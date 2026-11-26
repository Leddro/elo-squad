import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/network/dio_provider.dart';
import 'core/presentation/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/auth/data/auth_providers.dart';
import 'features/notifications/push_service.dart';

class EloSquadApp extends ConsumerStatefulWidget {
  const EloSquadApp({super.key});

  @override
  ConsumerState<EloSquadApp> createState() => _EloSquadAppState();
}

class _EloSquadAppState extends ConsumerState<EloSquadApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _subscriptions = <StreamSubscription<Object>>[];

  @override
  void initState() {
    super.initState();
    ref.read(proxyWarmUpProvider)();
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
      // Sempre escuro: o visual hextech do LoL não tem versão clara.
      theme: AppTheme.hextech,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
