# Como ligar o app ao banco da Rokuzen

Este guia é para quem for conectar o app Flutter aos dados reais. Hoje o app
roda com **dados de exemplo** (os mesmos do protótipo) e **não lê nem grava
nada no banco**.

## Como o app está organizado

```
App Flutter (lib/)  ──HTTP──▶  Backend Dart (backend/)  ──SQL──▶  MySQL da Rokuzen
```

- O app **nunca** fala direto com o MySQL. Quem acessa o banco é o backend
  (`backend/`), que já tem a conexão em `backend/lib/config/database.dart`.
- As telas não sabem de onde vêm os dados. Elas só usam a classe
  `RokuzenRepository` (`lib/data/repositorio.dart`).
- Hoje a implementação usada é `RepositorioDemonstracao`
  (`lib/data/repositorio_demonstracao.dart`), com tudo em memória.

## Regra combinada: somente leitura

Até o grupo definir com o professor onde os dados serão gravados:

- O backend deve ter **apenas rotas `GET`**, que executam **apenas `SELECT`**.
- Nada de `INSERT`, `UPDATE` ou `DELETE` no banco da Rokuzen.
- As ações do app que "alteram" algo (cadastrar paciente, iniciar/finalizar
  atendimento, adicionar disponibilidade) continuam só na memória do aparelho.

## Passo a passo

1. **Descobrir a estrutura do banco.** Listar as tabelas e colunas (sem ler
   dados de clientes). Pode ser pelo MySQL Workbench/DBeaver ou com
   `SHOW TABLES` e `SHOW COLUMNS FROM <tabela>`.

2. **Criar as rotas de leitura no backend** (`backend/bin/server.dart`), uma
   para cada método de leitura do repositório:

   | Método do repositório | Rota sugerida |
   |---|---|
   | `buscarTerapeuta` | `GET /terapeutas/:id` |
   | `buscarAtendimentos(inicio, fim)` | `GET /atendimentos?terapeuta=:id&inicio=AAAA-MM-DD&fim=AAAA-MM-DD` |
   | `buscarProximoAtendimento` | `GET /atendimentos/proximo?terapeuta=:id&apartir=...` |
   | `buscarPacientes` | `GET /pacientes?terapeuta=:id` (com última sessão e atendimento de hoje) |
   | `buscarPaciente(id)` | `GET /pacientes/:id` |
   | `buscarAtendimentosDoPaciente(id)` | `GET /pacientes/:id/atendimentos` |
   | `buscarDisponibilidades` | `GET /disponibilidades?terapeuta=:id` (se existir no banco) |

   Use sempre consultas com parâmetros (nunca concatene texto do usuário no
   SQL).

3. **Criar `lib/data/repositorio_api.dart`** com uma classe
   `RepositorioApi extends RokuzenRepository` que chama essas rotas (pacote
   `http`) e converte o JSON para os modelos de `lib/data/models/modelos.dart`.
   Os métodos de "ações locais" podem continuar guardando em memória, como no
   repositório de demonstração.

4. **Trocar a origem dos dados** no fim de `lib/data/repositorio.dart`:

   ```dart
   final RokuzenRepository repositorio = RepositorioApi();
   ```

5. **Desligar o modo de demonstração** em `lib/core/app_config.dart`:

   ```dart
   static const bool modoDemonstracao = false;
   ```

   Isso faz o app usar a data e hora reais e voltar a validação normal de
   e-mail no login.

## Cuidados

- **Credenciais:** ficam só no `backend/.env`, que já está no `.gitignore`.
  Nunca coloque senha do banco no código do app nem no GitHub.
- **Dados de pacientes (LGPD):** não suba dados reais para o repositório nem
  para prints da apresentação.
- **Emulador Android:** o backend roda em `localhost:8080` no computador; no
  emulador Android esse endereço é `http://10.0.2.2:8080`. No simulador do iOS,
  `http://localhost:8080` funciona. Em celular físico, use o IP do computador
  na rede e altere o `shelf_io.serve` para `InternetAddress.anyIPv4`.
- **Nomes dos serviços:** o app espera os serviços Quick Massage, Maca,
  Reflexologia Podal (com adicional opcional de Auriculoterapia) e
  Auriculoterapia. A Maca aparece sem modalidade.
