output "signalr_id" {
  description = "ID of the SignalR service"
  value       = azurerm_signalr_service.main.id
}

output "signalr_name" {
  description = "Name of the SignalR service"
  value       = azurerm_signalr_service.main.name
}

output "signalr_endpoint" {
  description = "Endpoint of the SignalR service"
  value       = azurerm_signalr_service.main.hostname # Changed from externally_accessible_url
}

output "signalr_primary_connection_string" {
  description = "Primary connection string for SignalR"
  value       = azurerm_signalr_service.main.primary_connection_string
  sensitive   = true
}

output "function_app_id" {
  description = "ID of the SignalR function app"
  value       = azurerm_linux_function_app.signalr.id
}

output "function_app_name" {
  description = "Name of the SignalR function app"
  value       = azurerm_linux_function_app.signalr.name
}

output "negotiation_function_url" {
  description = "URL of the negotiation function"
  value       = "https://${azurerm_linux_function_app.signalr.default_hostname}/api/negotiate"
}

output "negotiation_function_key" {
  description = "Key for the negotiation function"
  value       = data.azurerm_function_app_host_keys.signalr.default_function_key
  sensitive   = true
}