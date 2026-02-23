# SignalR Service - Correct syntax for AzureRM provider v3.x
resource "azurerm_signalr_service" "main" {
  name                = "sigr-${var.resource_prefix}-${var.environment}-${var.unique_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = var.signalr_sku
    capacity = var.signalr_capacity
  }

  # Service mode and logging configuration
  service_mode = var.signalr_service_mode

  # Fix deprecated live_trace_enabled - use live_trace block instead
  live_trace {
    enabled                   = true
    messaging_logs_enabled    = true
    connectivity_logs_enabled = true
    http_request_logs_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  cors {
    allowed_origins = [
      "https://*.azurewebsites.net",
      "https://portal.azure.com",
      "http://localhost:*"
    ]
  }

  # Only configure upstream if function app name and key are provided
  dynamic "upstream_endpoint" {
    for_each = var.function_app_name != "" && var.function_app_key != "" ? [1] : []
    content {
      category_pattern = ["connections", "messages"]
      event_pattern    = ["*"]
      hub_pattern      = ["*"]
      url_template     = "https://${var.function_app_name}.azurewebsites.net/runtime/webhooks/signalr?code=${var.function_app_key}"
    }
  }

  tags = var.tags
}

# App Service Plan for SignalR Function
resource "azurerm_service_plan" "signalr_functions" {
  name                = "asp-${var.resource_prefix}-signalr-${var.environment}-${var.unique_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan

  tags = var.tags
}

# Function App for SignalR negotiation
resource "azurerm_linux_function_app" "signalr" {
  name                = "func-${var.resource_prefix}-signalr-${var.environment}-${var.unique_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.signalr_functions.id

  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_key

  functions_extension_version = "~4"

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"              = "python"
    "AzureWebJobsStorage"                   = var.storage_account_connection_string
    "AzureSignalRConnectionString"          = azurerm_signalr_service.main.primary_connection_string
    "WEBSITE_RUN_FROM_PACKAGE"              = "1"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = var.app_insights_connection_string
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = var.app_insights_key
    "SignalRServiceMode"                    = var.signalr_service_mode
  }

  site_config {
    application_stack {
      python_version = "3.9"
    }

    application_insights_connection_string = var.app_insights_connection_string
    application_insights_key               = var.app_insights_key

    cors {
      allowed_origins = [
        "https://*.azurewebsites.net",
        "http://localhost:*"
      ]
      support_credentials = true
    }

    ftps_state          = "FtpsOnly"
    minimum_tls_version = "1.2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [
    azurerm_signalr_service.main
  ]
}

# Diagnostic settings for SignalR
# In modules/signalr/main.tf, update the diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "signalr" {
  name                       = "diagnostics-signalr"
  target_resource_id         = azurerm_signalr_service.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Use correct category names
  enabled_log {
    category = "AllLogs"  # Changed from "SignalRServiceDiagnosticLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Role assignment for SignalR to access Function App
resource "azurerm_role_assignment" "signalr_to_function" {
  scope                = azurerm_linux_function_app.signalr.id
  role_definition_name = "SignalR App Server"
  principal_id         = azurerm_signalr_service.main.identity[0].principal_id
}

# Get the default host key for the signalr function
data "azurerm_function_app_host_keys" "signalr" {
  name                = azurerm_linux_function_app.signalr.name
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_linux_function_app.signalr]
}