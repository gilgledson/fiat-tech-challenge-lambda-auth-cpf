# oficina-lambda-auth-cpf

Function Serverless (Azure Functions, Node.js) que autentica **clientes** da
Oficina API por CPF, sem exigir e-mail/senha. Um dos 4 repositórios do Tech
Challenge Fase 3 — ver os outros:

- [oficina-app](https://github.com/SEU_USUARIO/oficina-app) — aplicação principal (Quarkus, roda em Kubernetes)
- [oficina-infra-kubernetes](https://github.com/SEU_USUARIO/oficina-infra-kubernetes) — Terraform do cluster AKS + API Gateway
- [oficina-infra-banco-dados](https://github.com/SEU_USUARIO/oficina-infra-banco-dados) — Terraform do Postgres gerenciado

> Atualize os links acima com as URLs reais assim que os repositórios forem
> criados no GitHub.

## Propósito

Implementa o requisito da Fase 3: *"Validar o CPF do cliente; consultar a
existência e o status do cliente na base de dados; gerar e devolver um
token JWT válido"*. Login de equipe interna (`ADMIN`/`ATENDENTE`/`MECANICO`)
continua no repositório `oficina-app`, via `POST /api/usuarios/login` — essa
Function é um **segundo modo de login**, só para clientes.

## Como funciona

```
POST /api/auth/cpf   { "cpf": "529.982.247-25" }
        │
        ├── 400 se o CPF for inválido (formato/dígito verificador)
        ├── 404 se não existir cliente com esse CPF
        ├── 403 se o cliente existir mas estiver inativo (soft-deleted)
        └── 200 { "access_token": "...", "token_type": "Bearer", "expires_in": 28800 }
```

O token emitido usa a **mesma chave RSA e o mesmo issuer** que a API Quarkus
(`oficina-app`) já usa para os logins por e-mail/senha — ver
[ADR-004](https://github.com/SEU_USUARIO/oficina-app/blob/main/docs/architecture/adr-004-jwt-compartilhado-entre-servicos.md)
no repositório da aplicação principal para o racional completo dessa
decisão. Isso significa que o `@RolesAllowed({"CLIENTE"})` já existente nos
endpoints da API valida esse token **sem nenhuma alteração de código** do
lado Java.

Esta Function consulta o Postgres **diretamente** (mesmo banco do
repositório `oficina-infra-banco-dados`) — não depende da API principal
estar no ar.

## Tecnologias

- Node.js 18+, [Azure Functions Programming Model v4](https://learn.microsoft.com/azure/azure-functions/functions-reference-node)
- [`jsonwebtoken`](https://www.npmjs.com/package/jsonwebtoken) — assina o JWT em RS256
- [`pg`](https://node-postgres.com/) — consulta direta ao Postgres
- Terraform (`infra/`) — provisiona a Function App (Consumption Plan) e sua Storage Account própria

## Variáveis de ambiente (App Settings da Function)

| Variável | Descrição |
|---|---|
| `DB_HOST` | Host do Postgres Flexible Server |
| `DB_PORT` | Porta (padrão `5432`) |
| `DB_NAME` | Nome do banco (padrão `postgres`) |
| `DB_USER` | Usuário do Postgres |
| `DB_PASSWORD` | Senha do Postgres — nunca commitar |
| `DB_SSL` | `"true"` (padrão) para exigir SSL |
| `JWT_ISSUER` | Issuer do token (padrão `oficina-api-interna`) |
| `JWT_EXPIRES_IN_SECONDS` | Validade do token em segundos (padrão `28800` = 8h) |
| `JWT_PRIVATE_KEY` | Mesmo `privateKey.pem` do repositório `oficina-app` — nunca commitar |

Copie `local.settings.json.example` para `local.settings.json` (gitignorado)
para rodar localmente.

## Como executar localmente

Requer [Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local).

```bash
npm install
cp local.settings.json.example local.settings.json
# preencher DB_PASSWORD e JWT_PRIVATE_KEY em local.settings.json
npm start   # roda `func start`, expõe em http://localhost:7071/api/auth/cpf
```

## Testes

```bash
npm test
```

Cobre a validação de CPF (formato, dígito verificador, sequências
inválidas) de forma isolada, sem depender de banco/Azure. O teste de
integração de ponta a ponta (cria cliente → login por CPF → usa o token na
API principal) vive na collection Postman do repositório `oficina-app`
(`docs/postman_collection.json`, pasta "Fase 3 - Autenticação CPF").

## Deploy

### Infraestrutura (Terraform)

```bash
cd infra
terraform init
export TF_VAR_db_admin_password="a mesma senha do repositório oficina-infra-banco-dados"
export TF_VAR_jwt_private_key_pem="$(cat ../../oficina-app/src/main/resources/privateKey.pem)"
terraform plan
terraform apply
```

> A infraestrutura de Resource Group e do Postgres já precisa existir
> (repositórios `oficina-infra-kubernetes` e `oficina-infra-banco-dados`
> aplicados primeiro) — este Terraform só lê esses recursos via `data
> source`, nunca os cria.

> **Nota sobre região**: os recursos desta Function (Storage Account,
> Service Plan, Function App) são provisionados em `var.function_location`
> (padrão `East US`), **diferente** da região do Resource Group
> (`Brazil South`) — a assinatura Azure usada não tinha cota de Consumption
> Plan (Y1 VMs) liberada em Brazil South
> (`401 — Current Limit (Y1 VMs): 0`), e cota de Consumption Plan é por
> região. Azure permite recursos em região diferente da do seu Resource
> Group. Se East US também não tiver cota disponível na sua assinatura,
> sobrescreva com `TF_VAR_function_location="outra-regiao"`. Ver
> ADR-003 do repositório `oficina-app` para o histórico completo da
> decisão.

### Código da Function

```bash
func azure functionapp publish oficina-auth-cpf
```

### CI/CD

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) roda os testes a
cada push/PR na `main`. O deploy do código
(`func azure functionapp publish`) e o `terraform apply` continuam manuais
nesta fase — mesma convenção adotada nos outros 3 repositórios (a infra via
Terraform nunca é aplicada automaticamente em CI, só validada com
`terraform plan`).

## Swagger / Postman

Esta Function expõe um único endpoint (`POST /api/auth/cpf`), sem Swagger
próprio. Cobertura de teste na collection Postman do repositório
`oficina-app`: `docs/postman_collection.json`, pasta "Fase 3 - Autenticação
CPF (Function Serverless)".
