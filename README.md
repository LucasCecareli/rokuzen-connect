# Rokuzen Connect

App mobile do terapeuta da Rokuzen (Projeto Integrador Interdisciplinar ·
TTI206 · Instituto Mauá de Tecnologia). Feito em Flutter/Dart, roda em Android
e iOS.

## Como rodar

```bash
flutter pub get
flutter run
```

### Login (modo de demonstração)

Enquanto o app não está ligado ao banco, o login aceita **qualquer e-mail
terminado em `@gmail.com`** e **qualquer senha**. O "agora" do app fica parado
em sexta-feira, 2 de outubro de 2026, 13:35, para bater com os dados de
exemplo. Isso é controlado em `lib/core/app_config.dart`.

## Telas

- **Login**, com "Lembrar de mim" e "Esqueci minha senha".
- **Início**: progresso do dia, próximo atendimento (iniciar/finalizar) e
  linha do dia.
- **Agenda**: visões Dia e Semana, navegação entre semanas e atalho "Hoje".
- **Pacientes**: busca, ordenação, perfil, histórico completo e cadastro/edição.
- **Disponibilidade**: calendário, horários particulares fora do expediente,
  repetição semanal e validação de conflitos.

## Estrutura

```
lib/
  core/        cores, tipografia, tema, configuração e formatadores (pt-BR)
  data/        modelos e repositório (origem dos dados)
  widgets/     componentes compartilhados (botões, campos, linha do tempo…)
  features/    uma pasta por tela
backend/       API em Dart que lê o banco da Rokuzen
docs/          documentação
```

## Dados

O app ainda **não lê nem grava** no banco da Rokuzen. Os dados vêm de
`lib/data/repositorio_demonstracao.dart`. Para ligar ao banco, siga
[`docs/INTEGRACAO_BANCO.md`](docs/INTEGRACAO_BANCO.md).
