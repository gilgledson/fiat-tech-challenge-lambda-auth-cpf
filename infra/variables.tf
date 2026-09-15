variable "resource_group_name" {
  description = "Nome do Resource Group já criado pelo repositório oficina-infra-kubernetes."
  type        = string
  default     = "oficina-resources"
}

variable "function_location" {
  description = "Região Azure só dos recursos desta Function (Storage Account, Service Plan, Function App) — separada da região do Resource Group (Brazil South). Motivo: a assinatura usada não tem cota de Consumption Plan (Y1 VMs) liberada em Brazil South (erro 401 'Current Limit (Y1 VMs): 0' no terraform apply). Cota de Consumption Plan é por região; regiões como East US costumam ter cota padrão liberada em assinaturas novas/trial. Ver ADR-003 no repositório oficina-app para o histórico completo."
  type        = string
  default     = "East US"
}

variable "postgres_server_name" {
  description = "Nome do Postgres Flexible Server já criado pelo repositório oficina-infra-banco-dados."
  type        = string
  default     = "oficina-postgres-server"
}

variable "db_admin_password" {
  description = "Senha do administrador do Postgres — a mesma usada no repositório oficina-infra-banco-dados. Nunca definir um valor aqui — fornecer via TF_VAR_db_admin_password ou um arquivo *.tfvars (gitignored)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_admin_password) >= 12
    error_message = "A senha do banco deve ter pelo menos 12 caracteres."
  }
}

variable "jwt_private_key_pem" {
  description = "Conteúdo do mesmo privateKey.pem usado pela API principal (repositório oficina-app, src/main/resources/privateKey.pem), para esta Function assinar tokens compatíveis. Nunca definir um valor aqui — fornecer via TF_VAR_jwt_private_key_pem ou um arquivo *.tfvars (gitignored)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.jwt_private_key_pem) > 0
    error_message = "jwt_private_key_pem não pode ser vazio."
  }
}
