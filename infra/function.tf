# Function Serverless de autenticação por CPF (Fase 3). Código em ../src.
#
# O Function App real (plano FC1/Flex Consumption) foi criado manualmente
# pelo Portal Azure — Y1 (Consumption) e B1 (Basic) falharam por cota zero
# na assinatura (testado em duas regiões); só o Portal, usando o plano
# FC1, conseguiu provisionar. Ver ADR-003 no repositório oficina-app pra o
# histórico completo. Storage Account de deployment, Service Plan (SKU
# FC1), Application Insights e o próprio Function App foram todos
# importados de verdade (terraform import) a partir dos recursos reais.

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

resource "azurerm_function_app_flex_consumption" "auth_cpf" {
  name                = "oficina-lambda-auth-cpf"
  resource_group_name = data.azurerm_resource_group.oficina_rg.name
  location            = data.azurerm_resource_group.oficina_rg.location
  service_plan_id     = azurerm_service_plan.function_plan.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "https://oficinaresourcesaf22.blob.core.windows.net/app-package-oficina-lambda-auth-cpf-15860f6"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.function_storage.primary_access_key

  runtime_name    = "node"
  runtime_version = "22"

  maximum_instance_count = 100
  instance_memory_in_mb  = 2048

  # Travados nos valores reais (criados pelo Portal) — sem isso, o provider
  # aplicaria os próprios defaults no primeiro apply pós-import, o que
  # desativaria HTTPS-only, tornaria o certificado de cliente opcional e
  # ligaria autenticação básica pro web deploy: 3 downgrades de segurança
  # reais, não mudanças cosméticas.
  https_only                                     = true
  client_certificate_mode                        = "Required"
  webdeploy_publish_basic_authentication_enabled = false

  tags = {
    "hidden-link: /app-insights-resource-id" = "/subscriptions/946bede0-717a-43e2-8062-5d8cbf16d8f2/resourceGroups/oficina-resources/providers/microsoft.insights/components/oficina-lambda-auth-cpf"
  }

  site_config {
    ip_restriction_default_action     = "Allow"
    scm_ip_restriction_default_action = "Allow"

    # CORS que o Portal Azure configura sozinho pro painel de teste
    # ("Test/Run" na página da Function) funcionar.
    cors {
      allowed_origins     = ["https://portal.azure.com"]
      support_credentials = false
    }
  }

  # app_settings (DB_PASSWORD, JWT_PRIVATE_KEY, APPLICATIONINSIGHTS_CONNECTION_STRING
  # etc.) e a config do Application Insights no site_config continuam
  # configurados manualmente (az functionapp config appsettings set) — o
  # Terraform nunca deve tentar sobrescrevê-los, tanto por segurança
  # (valores não passam por aqui) quanto porque um apply sem esses valores
  # apagaria a configuração real da Function em produção.
  lifecycle {
    ignore_changes = [
      app_settings,
      site_config[0].application_insights_connection_string,
      site_config[0].application_insights_key,
    ]
  }
}

output "function_app_url" {
  description = "URL base da Function de autenticação por CPF."
  value       = "https://${azurerm_function_app_flex_consumption.auth_cpf.default_hostname}/api/auth/cpf"
}
