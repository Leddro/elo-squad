import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/network/api_config.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Necessário antes de usar plugins (Firebase) antes do runApp.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (ApiConfig.useFirestoreEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator(ApiConfig.host, 8080);
  }

  // ProviderScope: onde o Riverpod guarda o estado de todos os providers.
  runApp(const ProviderScope(child: EloSquadApp()));
}
