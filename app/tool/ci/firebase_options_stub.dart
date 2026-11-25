// STUB usado só no CI. O firebase_options.dart de verdade é gerado pelo
// `flutterfire configure` e fica fora do git. Os testes nunca inicializam o
// Firebase (usam fakes), então o CI só precisa que o arquivo exista e
// compile, com valores falsos.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'ci-stub',
    appId: '1:0:android:0',
    messagingSenderId: '0',
    projectId: 'ci-stub',
  );
}
