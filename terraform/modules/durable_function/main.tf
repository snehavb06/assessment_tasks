# App Service Plan for Functions
resource "azurerm_service_plan" "functions" {
  name                = "asp-${var.resource_prefix}-durable-${var.environment}-${var.unique_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan for serverless

  tags = var.tags
}

# Linux Function App for Durable Functions
resource "azurerm_linux_function_app" "durable" {
  name                = "func-${var.resource_prefix}-durable-${var.environment}-${var.unique_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.functions.id

  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_key

  functions_extension_version = "~4"

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"                 = "python"
    "FUNCTIONS_EXTENSION_VERSION"              = "~4"
    "AzureWebJobsStorage"                      = var.storage_account_connection_string
    "CosmosDBConnection"                       = var.cosmosdb_connection_string
    "CosmosDBDatabaseName"                     = "interviewdb"
    "CosmosDBContainerName"                    = "interviews"
    "WEBSITE_RUN_FROM_PACKAGE"                 = "1"
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = var.storage_account_connection_string
    "WEBSITE_CONTENTSHARE"                     = "func-content-${var.environment}"
    "APPLICATIONINSIGHTS_CONNECTION_STRING"    = var.app_insights_connection_string
    "APPINSIGHTS_INSTRUMENTATIONKEY"           = var.app_insights_key
  }

  site_config {
    application_stack {
      python_version = "3.9"
    }

    application_insights_connection_string = var.app_insights_connection_string
    application_insights_key               = var.app_insights_key

    cors {
      allowed_origins = [
        "https://portal.azure.com",
        "https://functions.azure.com",
        "https://*.azurewebsites.net"
      ]
      support_credentials = true
    }

    health_check_path = "/api/health"

    use_32_bit_worker = false

    ftps_state = "FtpsOnly"

    # This is the correct way to set min_tls_version
    minimum_tls_version = "1.2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Function App Slot for staging
resource "azurerm_linux_function_app_slot" "staging" {
  name            = "staging"
  function_app_id = azurerm_linux_function_app.durable.id

  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_key

  app_settings = azurerm_linux_function_app.durable.app_settings

  site_config {
    application_stack {
      python_version = "3.9"
    }
    application_insights_connection_string = var.app_insights_connection_string
    application_insights_key               = var.app_insights_key
  }

  tags = var.tags
}

# Diagnostic Settings for Function App
resource "azurerm_monitor_diagnostic_setting" "function_app" {
  name                       = "diagnostics-durable-function"
  target_resource_id         = azurerm_linux_function_app.durable.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FunctionAppLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Get the default host key for the function app
data "azurerm_function_app_host_keys" "durable" {
  name                = azurerm_linux_function_app.durable.name
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_linux_function_app.durable]
}