terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# O Resource Group é provisionado pelo repositório oficina-infra-kubernetes
# — aqui só lemos o recurso já existente, nunca o criamos nem duplicamos.
data "azurerm_resource_group" "oficina_rg" {
  name = var.resource_group_name
}
