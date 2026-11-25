import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/summoner/domain/entities/riot_id.dart';
import '../../features/summoner/presentation/pages/home_page.dart';
import '../../features/summoner/presentation/pages/profile_page.dart';

/// Nomes das rotas: as telas navegam pelo nome, não pelo caminho.
abstract final class Routes {
  static const splash = 'splash';
  static const login = 'login';
  static const home = 'home';
  static const profile = 'profile';
}

/// O roteador do app. Sem usuário logado, toda rota leva ao login.
final routerProvider = Provider<GoRouter>((ref) {
  // O GoRouter reavalia o `redirect` quando este Listenable avisa.
  final authState = ValueNotifier<AsyncValue<AppUser?>>(const AsyncLoading());
  ref
    ..listen(
      authStateProvider,
      (_, next) => authState.value = next,
      fireImmediately: true,
    )
    ..onDispose(authState.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: authState,
    redirect: (context, state) {
      final at = state.matchedLocation;
      return switch (authState.value) {
        // Ainda descobrindo se há sessão salva: tela de abertura.
        AsyncValue(hasValue: false, hasError: false) =>
          at == '/splash' ? null : '/splash',
        // Deslogado (ou erro ao ler a sessão): login.
        AsyncValue(value: null) => at == '/login' ? null : '/login',
        // Logado: sai do login/abertura para a home.
        _ => (at == '/login' || at == '/splash') ? '/' : null,
      };
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: Routes.splash,
        builder: (_, _) => const _SplashPage(),
      ),
      GoRoute(
        path: '/login',
        name: Routes.login,
        builder: (_, _) => const LoginPage(),
      ),
      GoRoute(
        path: '/',
        name: Routes.home,
        builder: (_, _) => const HomePage(),
        routes: [
          GoRoute(
            path: 'profile/:gameName/:tagLine',
            name: Routes.profile,
            builder: (_, state) => ProfilePage(
              riotId: RiotId(
                state.pathParameters['gameName']!,
                state.pathParameters['tagLine']!,
              ),
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
