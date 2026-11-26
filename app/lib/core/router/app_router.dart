import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/sciences/presentation/pages/sciences_page.dart';
import '../../features/squads/presentation/pages/link_riot_id_page.dart';
import '../../features/squads/presentation/pages/squad_detail_page.dart';
import '../../features/squads/presentation/pages/squads_page.dart';
import '../../features/summoner/domain/entities/riot_id.dart';
import '../../features/summoner/presentation/pages/home_page.dart';
import '../../features/summoner/presentation/pages/profile_page.dart';

/// Nomes das rotas: as telas navegam pelo nome, não pelo caminho.
abstract final class Routes {
  static const splash = 'splash';
  static const login = 'login';
  static const home = 'home';
  static const profile = 'profile';
  static const sciences = 'sciences';
  static const squads = 'squads';
  static const squad = 'squad';
  static const linkRiotId = 'linkRiotId';
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

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
    navigatorKey: _rootKey,
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
      // Telas por cima das abas (sem a barra inferior), abertas de qualquer aba.
      GoRoute(
        path: '/profile/:gameName/:tagLine',
        name: Routes.profile,
        parentNavigatorKey: _rootKey,
        builder: (_, state) => ProfilePage(
          riotId: RiotId(
            state.pathParameters['gameName']!,
            state.pathParameters['tagLine']!,
          ),
        ),
      ),
      GoRoute(
        path: '/link-riot-id',
        name: Routes.linkRiotId,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const LinkRiotIdPage(),
      ),
      // As abas: cada uma guarda a própria pilha de navegação.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _ScaffoldWithNavBar(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: Routes.home,
                builder: (_, _) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sciences',
                name: Routes.sciences,
                builder: (_, _) => const SciencesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/squads',
                name: Routes.squads,
                builder: (_, _) => const SquadsPage(),
                routes: [
                  GoRoute(
                    path: ':squadId',
                    name: Routes.squad,
                    builder: (_, state) => SquadDetailPage(
                      squadId: state.pathParameters['squadId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      // Tocar de novo na aba atual volta ao início dela.
      onDestinationSelected: (index) =>
          shell.goBranch(index, initialLocation: index == shell.currentIndex),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
        NavigationDestination(
          icon: Icon(Icons.science_outlined),
          selectedIcon: Icon(Icons.science),
          label: 'Ciências',
        ),
        NavigationDestination(icon: Icon(Icons.groups), label: 'Squads'),
      ],
    ),
  );
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
