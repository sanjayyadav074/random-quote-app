variable "project_name" {
  type    = string
  default = "quotesapp"
}

variable "location" {
  type    = string
  default = "centralus"
}

variable "sql_admin_login" {
  type    = string
  default = "sqladminuser"
}

variable "sql_admin_password" {
  type      = string
  sensitive = true
}
