output "webapp_url" {
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
  description = "Public URL of the web app"
}

output "sql_server_name" {
  value       = azurerm_mssql_server.sql.name
  description = "SQL server name (hostname is <name>.database.windows.net)"
}

output "sql_database_name" {
  value       = azurerm_mssql_database.db.name
  description = "SQL database name"
}

output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "Resource group name"
}
