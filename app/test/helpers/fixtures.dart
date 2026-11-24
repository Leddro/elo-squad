import 'dart:convert';
import 'dart:io';

/// Lê um JSON de `test/fixtures/`. Devolve uma cópia NOVA a cada chamada,
/// então um teste pode alterar o mapa sem afetar os outros.
Map<String, dynamic> loadFixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;
