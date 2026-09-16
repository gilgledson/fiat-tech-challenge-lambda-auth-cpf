# oficina-lambda-auth-cpf

Function Serverless (Azure Functions, Node.js) que autentica **clientes** da
Oficina API por CPF, sem exigir e-mail/senha. Um dos 4 repositórios do Tech
Challenge Fase 3 — ver os outros:

- [oficina-app](https://github.com/gilgledson/fiat-tech-challenge-app) — aplicação principal (Quarkus, roda em Kubernetes)
- [oficina-infra-kubernetes](https://github.com/gilgledson/fiat-tech-challenge-infra-kubernetes) — Terraform do cluster AKS + API Gateway
- [oficina-infra-banco-dados](https://github.com/gilgledson/fiat-tech-challenge-infra-database) — Terraform do Postgres gerenciado

**Endpoint em produção**:
`https://oficina-lambda-auth-cpf-efedakf9cfh7dtbd.brazilsouth-01.azurewebsites.net/api/auth/cpf`
— validado: CPF inválido → `400`, cliente não encontrado → `404` (conexão
com o Postgres confirmada).

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
[ADR-004](https://github.com/gilgledson/fiat-tech-challenge-app/blob/main/docs/architecture/adr-004-jwt-compartilhado-entre-servicos.md)
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
- Terraform (`infra/`) — provisiona a Function App (plano B1/Basic, ver nota abaixo) e sua Storage Account própria

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
terraform plan
terraform apply
```

> A infraestrutura de Resource Group já precisa existir (repositório
> `oficina-infra-kubernetes` aplicado primeiro) — este Terraform só lê esse
> recurso via `data source`, nunca o cria.

> **Nota sobre o plano de hospedagem**: o Function App real roda no plano
> **`FC1` (Flex Consumption)** — `Y1` (Consumption) e `B1` (Basic) falharam
> por cota zero na assinatura, testado em duas regiões (mesmo erro 401,
> `Current Limit (Y1 VMs): 0` / `(B1 VMs): 0`). Só o Portal Azure, usando o
> plano mais novo FC1 (família de cota própria), conseguiu provisionar. Ver
> ADR-003 (seção "Atualização 3") do repositório `oficina-app` para o
> histórico completo da decisão.

### Código da Function

```bash
cp local.settings.json.example local.settings.json
npm install
func azure functionapp publish oficina-lambda-auth-cpf
```

> O nome usado aqui (`oficina-lambda-auth-cpf`) já bate com o
> `infra/function.tf` — o Terraform gerencia o Function App real, não uma
> declaração divergente (ver seção "CI/CD" abaixo pra detalhes).

### CI/CD

[`.github/workflows/ci.yml`](.github/workflows/ci.yml): a cada push na
`main`, roda os testes e **publica o código automaticamente** no Function
App (`Azure/functions-action@v1`, usando a mesma Service Principal do
`AZURE_CREDENTIALS`) — mesmo padrão de deploy automático do repositório
`oficina-app`. O `terraform apply` continua manual, mesma convenção dos
outros 3 repositórios (infraestrutura nunca é aplicada automaticamente em
CI, só validada com `terraform plan`).

### Terraform e a nuvem estão sincronizados

O Function App (`oficina-lambda-auth-cpf`, plano **`FC1`/Flex Consumption**)
foi criado **manualmente pelo Portal Azure** — `Y1` e `B1` falharam por cota
zero na assinatura (ver ADR-003 no repositório `oficina-app`) — mas hoje é
**gerenciado de verdade pelo Terraform**: o provider `azurerm` foi
atualizado pra `~> 4.0` (necessário pro recurso
`azurerm_function_app_flex_consumption`, que só existe a partir dessa
versão) e o Function App, junto com a Storage Account de deployment, o
Service Plan (SKU `FC1`) e o Application Insights, foram todos importados
de verdade (`terraform import`). `terraform plan` limpo, sem drift.

`app_settings` (variáveis de ambiente com segredos — `DB_PASSWORD`,
`JWT_PRIVATE_KEY` etc.) continuam **fora** do Terraform de propósito
(`lifecycle.ignore_changes`): configurados manualmente via
`az functionapp config appsettings set`, nunca passam pelo state do
Terraform nem por CI.

## Swagger / Postman

Esta Function expõe um único endpoint (`POST /api/auth/cpf`), sem Swagger
próprio. Cobertura de teste na collection Postman do repositório
`oficina-app`: `docs/postman_collection.json`, pasta "Fase 3 - Autenticação
CPF (Function Serverless)".
