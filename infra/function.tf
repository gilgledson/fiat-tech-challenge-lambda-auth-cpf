# Function Serverless de autenticação por CPF (Fase 3). Código em ../src.
#
# Plano B1 (Basic), não Y1 (Consumption): a assinatura Azure usada tem cota
# zero pra VMs "Dynamic" (Y1) em toda a assinatura, não só numa região
# específica — confirmado empiricamente (mesmo erro 401 em Brazil South e
# em East US). B1 é compute "normal" (B-series), sem essa restrição de
# cota, mas fica sempre ligado (custo fixo baixo, sem escalar a zero). Ver
# ADR-003 no repositório oficina-app, seção "Atualização 2", para o
# histórico completo da decisão.

resource "random_string" "function_storage_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "function_storage" {
  name                     = "oficinafn${random_string.function_storage_suffix.result}"
  resource_group_name      = data.azurerm_resource_group.oficina_rg.name
  location                 = var.function_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_service_plan" "function_plan" {
  name                = "oficina-auth-cpf-plan"
  resource_group_name = data.azurerm_resource_group.oficina_rg.name
  location            = var.function_location
  os_type             = "Linux"
  sku_name            = var.function_plan_sku
}

resource "azurerm_linux_function_app" "auth_cpf" {
  name                = "oficina-auth-cpf"
  resource_group_name = data.azurerm_resource_group.oficina_rg.name
  location            = var.function_location

  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.function_plan.id

  site_config {
    application_stack {
      node_version = "20"
    }
  }

  app_settings = {
    DB_HOST                = data.azurerm_postgresql_flexible_server.oficina_db.fqdn
    DB_PORT                = "5432"
    DB_NAME                = "postgres"
    DB_USER                = "adminuser"
    DB_PASSWORD            = var.db_admin_password
    DB_SSL                 = "true"
    JWT_ISSUER             = "oficina-api-interna"
    JWT_EXPIRES_IN_SECONDS = "28800"
    JWT_PRIVATE_KEY        = var.jwt_private_key_pem
  }
}

output "function_app_url" {
  description = "URL base da Function de autenticação por CPF."
  value       = "https://${azurerm_linux_function_app.auth_cpf.default_hostname}/api/auth/cpf"
}
