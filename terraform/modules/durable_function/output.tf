output "function_app_id" {
  description = "ID of the function app"
  value       = azurerm_linux_function_app.durable.id
}

output "function_app_name" {
  description = "Name of the function app"
  value       = azurerm_linux_function_app.durable.name
}

output "function_app_url" {
  description = "URL of the function app"
  value       = "https://${azurerm_linux_function_app.durable.default_hostname}"
}

output "function_app_principal_id" {
  description = "Principal ID of the function app's managed identity"
  value       = azurerm_linux_function_app.durable.identity[0].principal_id
}

output "function_app_default_key" {
  description = "Default key for the function app"
  value       = data.azurerm_function_app_host_keys.durable.default_function_key
  sensitive   = true
}

output "service_plan_id" {
  description = "ID of the app service plan"
  value       = azurerm_service_plan.functions.id
}

output "staging_slot_url" {
  description = "URL of the staging slot"
  value       = "https://${azurerm_linux_function_app.durable.name}-staging.azurewebsites.net"
}