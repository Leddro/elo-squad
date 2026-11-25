import 'package:material_ui/material_ui.dart';

import 'failure_messages.dart';

/// Roda uma ação de um botão (criar, entrar, sair...) mostrando um indicador
/// de progresso por cima da tela, e um SnackBar se der erro.
///
/// Devolve o resultado, ou null se falhou.
Future<T?> runAction<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
  try {
    return await action();
  } on Object catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(shortFailureMessage(error))));
    return null;
  } finally {
    navigator.pop(); // fecha o indicador
  }
}
