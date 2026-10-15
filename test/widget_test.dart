import 'package:flutter_test/flutter_test.dart';

import 'package:rokuzen_connect/core/formatadores.dart';
import 'package:rokuzen_connect/data/models/modelos.dart';
import 'package:rokuzen_connect/data/repositorio_demonstracao.dart';

void main() {
  group('Formatadores', () {
    test('máscara de telefone', () {
      expect(mascaraTelefone('11999991234'), '(11) 99999-1234');
      expect(mascaraTelefone('119'), '(11) 9');
      expect(mascaraTelefone(''), '');
    });

    test('durações e contagem regressiva', () {
      expect(duracaoTexto(45), '45 min');
      expect(duracaoTexto(90), '1h30');
      expect(duracaoTexto(120), '2h');
      expect(contagemRegressiva(25), 'em 25 min');
      expect(contagemRegressiva(0), 'Agora');
    });

    test('datas em português', () {
      final d = DateTime(2026, 10, 2);
      expect(dataPorExtenso(d), 'Sexta-feira, 2 de outubro');
      expect(intervaloDatas(DateTime(2026, 9, 28), DateTime(2026, 10, 4)),
          '28 set – 4 out');
      expect(inicioDaSemana(d), DateTime(2026, 9, 28));
    });

    test('busca ignora acentos', () {
      expect(normalizar('Vinícius'), 'vinicius');
    });
  });

  group('Regras da Rokuzen', () {
    const mariana = Terapeuta(
      id: 1,
      nome: 'Mariana',
      unidade: Unidades.moocaPlaza,
      inicioTurno: 600,
      fimTurno: 960,
    );

    test('domingo é sempre das 14h às 20h', () {
      expect(mariana.turnoTexto(DateTime(2026, 10, 4)), '14:00 – 20:00');
      expect(mariana.turnoTexto(DateTime(2026, 10, 2)), '10:00 – 16:00');
    });

    test('adicional de Auriculoterapia entra na duração', () {
      final a = Atendimento(
        id: 1,
        pacienteId: 2,
        pacienteNome: 'Ricardo Mendes',
        inicio: DateTime(2026, 10, 2, 15),
        servico: Servico.reflexologiaPodal,
        duracao: 30,
        adicionalAuriculo: 10,
        unidade: Unidades.moocaPlaza,
        sala: 'Sala 2',
        status: StatusAtendimento.confirmado,
      );
      expect(a.horarioTexto, '15:00 – 15:40 · 40 min');
      expect(a.servicoCompleto,
          'Reflexologia Podal · 30 min + Auriculoterapia 10 min');
    });
  });

  group('Dados de demonstração', () {
    test('sexta, 2 de outubro, tem 5 atendimentos (1 cancelado)', () async {
      final repo = RepositorioDemonstracao();
      final dia = DateTime(2026, 10, 2);
      final lista =
          await repo.buscarAtendimentos(dia, DateTime(2026, 10, 3));
      expect(lista.length, 5);
      expect(lista.where((a) => !a.status.inativo).length, 4);
      // Nenhum serviço de Maca exibe modalidade.
      expect(lista.every((a) => !a.servicoTexto.contains('Shiatsu')), isTrue);
    });

    test('Ana Paula tem 8 sessões concluídas', () async {
      final repo = RepositorioDemonstracao();
      final lista = await repo.buscarAtendimentosDoPaciente(1);
      expect(
        lista.where((a) => a.status == StatusAtendimento.concluido).length,
        8,
      );
    });
  });
}
