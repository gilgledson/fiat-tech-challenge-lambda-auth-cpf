terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# O Resource Group e o Postgres são provisionados pelo repositório
# oficina-infra-kubernetes / oficina-infra-banco-dados — aqui só lemos os
# dados de recursos já existentes (nunca criamos nem duplicamos).
data "azurerm_resource_group" "oficina_rg" {
  name = var.resource_group_name
}

data "azurerm_postgresql_flexible_server" "oficina_db" {
  name                = var.postgres_server_name
  resource_group_name = data.azurerm_resource_group.oficina_rg.name
}
