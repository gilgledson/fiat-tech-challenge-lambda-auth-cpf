variable "resource_group_name" {
  description = "Nome do Resource Group já criado pelo repositório oficina-infra-kubernetes."
  type        = string
  default     = "oficina-resources"
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
