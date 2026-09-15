# Function Serverless de autenticação por CPF (Fase 3). Código em ../src.
#
# O Function App em si (plano FC1/Flex Consumption) foi criado manualmente
# pelo Portal Azure, não pelo terraform apply — Y1 (Consumption) e B1
# (Basic) falharam por cota zero na assinatura (testado em duas regiões);
# só o Portal, usando o plano FC1, conseguiu provisionar. Ver ADR-003 no
# repositório oficina-app pra o histórico completo.
#
# O recurso azurerm_function_app_flex_consumption (o único jeito de
# representar um Function App FC1 no Terraform) só existe a partir da
# versão 4.x do provider azurerm — este repositório ainda está em "~> 3.0"
# (mesma versão dos outros 3 repositórios do projeto). Migrar pra v4 é uma
# mudança maior, com breaking changes em vários recursos, não só neste
# arquivo — por isso o Function App continua fora do Terraform por
# enquanto (próximo passo, não feito nesta fase).
#
# O que JÁ dá pra representar corretamente na v3 — e que foi importado de
# verdade (terraform import) a partir dos recursos reais criados pelo
# Portal — é a Storage Account de deployment, o Service Plan (SKU FC1) e o
# Application Insights. Isso evita, no mínimo, que um terraform apply
# tente criar duplicatas desses três recursos.

resource "azurerm_storage_account" "function_storage" {
  name                     = "oficinaresourcesaf22"
  resource_group_name      = data.azurerm_resource_group.oficina_rg.name
  location                 = data.azurerm_resource_group.oficina_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # Valores travados nos mesmos do recurso real (criado pelo Portal) —
  # sem isso, o provider aplicaria os próprios defaults no primeiro apply
  # pós-import, deixando a conta MAIS permissiva do que está hoje (itens
  # aninhados públicos, replicação cross-tenant, autenticação padrão
  # caindo de OAuth pra Shared Key).
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  default_to_oauth_authentication  = true
}

resource "azurerm_service_plan" "function_plan" {
  name                = "ASP-oficinaresources-9d87"
  resource_group_name = data.azurerm_resource_group.oficina_rg.name
  location            = data.azurerm_resource_group.oficina_rg.location
  os_type             = "Linux"
  sku_name            = "FC1"
}

resource "azurerm_application_insights" "auth_cpf" {
  name                = "oficina-lambda-auth-cpf"
  resource_group_name = data.azurerm_resource_group.oficina_rg.name
  location            = data.azurerm_resource_group.oficina_rg.location
  application_type    = "web"

  # Criado pelo Portal como "workspace-based" (vinculado a um Log Analytics
  # workspace) — sem declarar isso aqui, o provider tentaria desvincular no
  # apply, convertendo pro modelo clássico (operação não suportada/perda de
  # dado histórico). sampling_percentage = 0 também é o valor real (sampling
  # adaptativo, não um % fixo).
  workspace_id        = "/subscriptions/946bede0-717a-43e2-8062-5d8cbf16d8f2/resourceGroups/DefaultResourceGroup-CQ/providers/Microsoft.OperationalInsights/workspaces/DefaultWorkspace-946bede0-717a-43e2-8062-5d8cbf16d8f2-CQ"
  sampling_percentage = 0
}

# Function App real, gerenciado manualmente (ver nota no topo do arquivo).
# URL fixa aqui só pra referência — se o Function App for recriado, esse
# hostname muda e precisa ser atualizado à mão.
output "function_app_url" {
  description = "URL base da Function de autenticação por CPF (gerenciada manualmente, ver nota em function.tf)."
  value       = "https://oficina-lambda-auth-cpf-efedakf9cfh7dtbd.brazilsouth-01.azurewebsites.net/api/auth/cpf"
}
