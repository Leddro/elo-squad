import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/push_service.dart';
import '../data/auth_providers.dart';

/// Logout completo: primeiro desliga o push do aparelho (precisa do login
/// para falar com o proxy), depois sai da conta.
final signOutProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    await ref.read(pushServiceProvider).unregister();
    await ref.read(authRepositoryProvider).signOut();
  },
);
