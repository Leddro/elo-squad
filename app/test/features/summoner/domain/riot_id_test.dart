import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RiotId.tryParse', () {
    // Testes "orientados a tabela": cada linha é um caso.
    // Adicionar um caso novo é só adicionar uma linha.
    const validos = {
      'Fulano#BR1': RiotId('Fulano', 'BR1'),
      'Nome Com Espaço#BR1': RiotId('Nome Com Espaço', 'BR1'),
      '  Fulano#BR1  ': RiotId('Fulano', 'BR1'),
      'Fulano # BR1': RiotId('Fulano', 'BR1'),
      'Abc#123': RiotId('Abc', '123'), // limites mínimos (3 e 3)
      'NomeComDezesseis#12345': RiotId(
        'NomeComDezesseis',
        '12345',
      ), // limites máximos (16 e 5)
    };

    for (final MapEntry(key: entrada, value: esperado) in validos.entries) {
      test('aceita "$entrada"', () {
        final resultado = RiotId.tryParse(entrada);

        expect(resultado, esperado);
        expect(resultado?.gameName, esperado.gameName); // grafia preservada
      });
    }

    const invalidos = {
      'Fulano': 'falta a tag',
      'Fulano#': 'tag vazia',
      '#BR1': 'nome vazio',
      'Fu#BR1': 'nome curto demais (2)',
      'NomeComDezessete1#BR1': 'nome longo demais (17)',
      'Fulano#BR': 'tag curta demais (2)',
      'Fulano#BR12345': 'tag longa demais (7)',
      'a#b#c': 'mais de um #',
      '': 'texto vazio',
      '   ': 'só espaços',
    };

    for (final MapEntry(key: entrada, value: motivo) in invalidos.entries) {
      test('rejeita "$entrada" ($motivo)', () {
        expect(RiotId.tryParse(entrada), isNull);
      });
    }
  });

  group('igualdade', () {
    test('mesmo conteúdo → iguais', () {
      expect(const RiotId('Fulano', 'BR1'), const RiotId('Fulano', 'BR1'));
    });

    test('ignora maiúsculas/minúsculas, como a Riot', () {
      expect(const RiotId('fulano', 'br1'), const RiotId('Fulano', 'BR1'));
    });

    test('iguais têm o mesmo hashCode (contrato do ==)', () {
      expect(
        const RiotId('fulano', 'br1').hashCode,
        const RiotId('Fulano', 'BR1').hashCode,
      );
    });

    test(
      'funciona como chave de Set/Map (é o que o .family do Riverpod faz)',
      () {
        final buscas = {
          const RiotId('Fulano', 'BR1'),
          const RiotId('FULANO', 'br1'),
        };

        expect(buscas, hasLength(1));
      },
    );

    test('contas diferentes → diferentes', () {
      expect(
        const RiotId('Fulano', 'BR1'),
        isNot(const RiotId('Fulano', 'BR2')),
      );
    });
  });

  test('toString usa o formato nome#tag com a grafia original', () {
    expect(const RiotId('Fulano', 'BR1').toString(), 'Fulano#BR1');
  });

  test('storageKey: minúsculas, igual para "Fulano#BR1" e "fulano#br1"', () {
    expect(const RiotId('Fulano', 'BR1').storageKey, 'fulano#br1');
    expect(
      const RiotId('fulano', 'br1').storageKey,
      const RiotId('FULANO', 'Br1').storageKey,
    );
  });
}
