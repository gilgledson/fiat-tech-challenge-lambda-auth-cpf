# Function Serverless de autenticação por CPF (Fase 3). Código em ../src.
# Plano Consumption (Y1): paga só pelas execuções, sem custo de
# infraestrutura ociosa — adequado para uma function de baixo volume como
# essa. Ver ../../docs (ADR-003) no repositório oficina-app para o registro
# da decisão e a pendência de cota conhecida.

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
  sku_name            = "Y1" # Consumption plan
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
