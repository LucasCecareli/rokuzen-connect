/// Configurações gerais do app.
abstract final class AppConfig {
  /// Enquanto o grupo não define onde os dados serão gravados, o app roda em
  /// modo de demonstração:
  ///  - o login aceita qualquer e-mail terminado em @gmail.com e qualquer senha;
  ///  - o "agora" do app fica parado em sexta-feira, 2 de outubro de 2026, 13:35,
  ///    para bater com os dados de exemplo do protótipo.
  ///
  /// Quando os dados vierem do banco da Rokuzen, troque para `false`.
  static const bool modoDemonstracao = true;

  /// Data e hora usadas como "agora" no modo de demonstração.
  static final DateTime agoraDemonstracao = DateTime(2026, 10, 2, 13, 35);

  /// Tempo simulado de carregamento (mostra os skeletons das telas).
  static const Duration atrasoSimulado = Duration(milliseconds: 600);
}

/// Data e hora atuais do app (respeita o modo de demonstração).
DateTime agora() =>
    AppConfig.modoDemonstracao ? AppConfig.agoraDemonstracao : DateTime.now();
