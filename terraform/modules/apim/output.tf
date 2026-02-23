output "apim_id" {
  description = "ID of the API Management instance"
  value       = azurerm_api_management.main.id
}

output "apim_name" {
  description = "Name of the API Management instance"
  value       = azurerm_api_management.main.name
}

output "apim_gateway_url" {
  description = "Gateway URL of the API Management instance"
  value       = azurerm_api_management.main.gateway_url
}

output "api_path" {
  description = "API path"
  value       = azurerm_api_management_api.v1.path
}

output "test_subscription_key" {
  description = "Test subscription key"
  value       = azurerm_api_management_subscription.test.primary_key
  sensitive   = true
}

output "api_v1_url" {
  description = "URL for API v1"
  value       = "${azurerm_api_management.main.gateway_url}/${azurerm_api_management_api.v1.path}"
}

output "api_v2_url" {
  description = "URL for API v2"
  value       = "${azurerm_api_management.main.gateway_url}/${azurerm_api_management_api.v2.path}"
}