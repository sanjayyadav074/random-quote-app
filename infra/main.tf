terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Random suffix so names are globally unique
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  lower   = true
  numeric = true
  special = false
}

# 1) Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "${var.project_name}-rg-${random_string.suffix.result}"
  location = var.location
}

# 2) Linux App Service Plan (Free tier F1 to stay cheap)
resource "azurerm_service_plan" "asp" {
  name                = "${var.project_name}-plan-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  os_type  = "Linux"
  sku_name = "B1" # Free tier; can upgrade later for real HA
}

# 3) Azure SQL Server
resource "azurerm_mssql_server" "sql" {
  name                          = "${var.project_name}-sql-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_login
  administrator_login_password  = var.sql_admin_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = true
}

# 4) Azure SQL Database (cheap Basic tier)
resource "azurerm_mssql_database" "db" {
  name        = "${var.project_name}-db"
  server_id   = azurerm_mssql_server.sql.id
  sku_name    = "Basic"
  max_size_gb = 2
}

# 5) Firewall: allow Azure services
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzure"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# 6) Key Vault to store SQL connection string (treat as PII)
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = "${var.project_name}kv${random_string.suffix.result}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true

  # Allow YOU (signed-in user) to manage secrets
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "Set", "List"]
  }
}

# 7) Store SQL connection string in Key Vault
resource "azurerm_key_vault_secret" "sql_conn" {
  name         = "SqlConnectionString"
  value        = "Server=tcp:${azurerm_mssql_server.sql.name}.database.windows.net,1433;Initial Catalog=${azurerm_mssql_database.db.name};Persist Security Info=False;User ID=${var.sql_admin_login};Password=${var.sql_admin_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.kv.id
}

# 8) Linux Web App with system-assigned managed identity
resource "azurerm_linux_web_app" "app" {
  name                = "${var.project_name}-web-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.asp.id

  https_only = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      node_version = "18-lts"
    }
    ftps_state    = "Disabled"
    http2_enabled = true
  }

  # App reads SQL connection string via Key Vault reference
  app_settings = {
    "NODE_ENV"              = "production"
    "SQL_CONNECTION_STRING" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.sql_conn.versionless_id})"
  }

  depends_on = [
    azurerm_key_vault_secret.sql_conn
  ]
}

# 9) Give the Web App identity permission to read secrets
resource "azurerm_key_vault_access_policy" "app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.app.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}
