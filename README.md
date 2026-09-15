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
export TF_VAR_db_admin_password="a mesma senha do repositório oficina-infra-banco-dados"
export TF_VAR_jwt_private_key_pem="$(cat ../../oficina-app/src/main/resources/privateKey.pem)"
terraform plan
terraform apply
```

> A infraestrutura de Resource Group e do Postgres já precisa existir
> (repositórios `oficina-infra-kubernetes` e `oficina-infra-banco-dados`
> aplicados primeiro) — este Terraform só lê esses recursos via `data
> source`, nunca os cria.

> **Nota sobre o plano de hospedagem**: o padrão é `var.function_plan_sku =
> "B1"` (Basic), **não** `Y1` (Consumption) — a assinatura Azure usada tem
> cota zero pra VMs "Dynamic" (Y1) em **toda a assinatura**, confirmado com
> o mesmo erro 401 (`Current Limit (Y1 VMs): 0`) tanto em `Brazil South`
> quanto em `East US` (`var.function_location`, região só dos recursos
> desta Function). B1 é compute normal, sem essa restrição — funciona, mas
> fica sempre ligado (custo fixo baixo, sem escalar a zero). Se sua
> assinatura tiver cota de Consumption liberada, sobrescreva com
> `TF_VAR_function_plan_sku="Y1"`. Ver ADR-003 (seção "Atualização 2") do
> repositório `oficina-app` para o histórico completo da decisão.

### Código da Function

```bash
cp local.settings.json.example local.settings.json
npm install
func azure functionapp publish oficina-lambda-auth-cpf
```

> **Nota de nomenclatura**: o Function App real na Azure se chama
> `oficina-lambda-auth-cpf` (criado manualmente pelo Portal, ver "Nota
> sobre o plano de hospedagem" abaixo) — diferente do nome
> `oficina-auth-cpf` usado no `infra/function.tf`. Isso é uma divergência
> conhecida entre o que o Terraform declara e o que existe de fato na
> nuvem; ver seção seguinte.

### CI/CD

[`.github/workflows/ci.yml`](.github/workflows/ci.yml): a cada push na
`main`, roda os testes e **publica o código automaticamente** no Function
App (`Azure/functions-action@v1`, usando a mesma Service Principal do
`AZURE_CREDENTIALS`) — mesmo padrão de deploy automático do repositório
`oficina-app`. O `terraform apply` continua manual, mesma convenção dos
outros 3 repositórios (infraestrutura nunca é aplicada automaticamente em
CI, só validada com `terraform plan`).

### ⚠️ Pendência: Terraform não gerencia o Function App real ainda

O Function App e o App Service Plan que estão em produção
(`oficina-lambda-auth-cpf`, plano **`FC1`/Flex Consumption**) foram criados
**manualmente pelo Portal Azure**, não pelo `terraform apply` — o
`infra/function.tf` deste repositório ainda declara os recursos com SKU
`B1` (não `FC1`) e nome `oficina-auth-cpf` (não `oficina-lambda-auth-cpf`).
Motivo: tanto `Y1` (Consumption) quanto `B1` (Basic) falharam por cota
zero na assinatura (testado em duas regiões); só o Portal, usando o plano
mais novo `FC1` (Flex Consumption), conseguiu provisionar. Um próximo passo
é atualizar `infra/function.tf` para usar `FC1` (recurso
`azurerm_function_app_flex_consumption`, disponível a partir de versões
mais recentes do provider `azurerm`) e rodar `terraform import` nos
recursos já existentes, para que o Terraform passe a gerenciá-los de
verdade. Ver ADR-003 no repositório `oficina-app` para o histórico
completo.

## Swagger / Postman

Esta Function expõe um único endpoint (`POST /api/auth/cpf`), sem Swagger
próprio. Cobertura de teste na collection Postman do repositório
`oficina-app`: `docs/postman_collection.json`, pasta "Fase 3 - Autenticação
CPF (Function Serverless)".
