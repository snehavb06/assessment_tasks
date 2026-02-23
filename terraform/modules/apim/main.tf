# API Management Instance
resource "azurerm_api_management" "main" {
  name                = "apim-${var.resource_prefix}-${var.environment}-${var.unique_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.apim_sku

  identity {
    type = "SystemAssigned"
  }

  # ✅ REMOVED the hostname_configuration block completely
  # API will use Azure's default domain: https://apim-{name}.azure-api.net

  tags = {
    CostCenter  = "Engineering"
    DeployDate  = "2026-02-23"
    DeployedBy  = "Terraform"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Owner       = "CloudTeam"
    Project     = "Exterview-Assessment"
    type        = "Microsoft.ApiManagement/service"
  }
}

# Product for Interview API
resource "azurerm_api_management_product" "interview" {
  product_id            = "interview-processor"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = var.resource_group_name
  display_name          = "Interview Processor API"
  subscription_required = true
  approval_required     = false
  published             = true

  description = "Product for Interview Processing API with rate limiting"
}

# API Version Set
resource "azurerm_api_management_api_version_set" "interview" {
  name                = "interview-api-versions"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  display_name        = "Interview Processor API"
  versioning_scheme   = "Segment"
  description         = "Version set for Interview Processor API"
}

# API v1
resource "azurerm_api_management_api" "v1" {
  name                = "interview-processor-api-v1"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "Interview Processor API V1"
  path                = "interview/v1"
  protocols           = ["https"]

  version        = "v1"
  version_set_id = azurerm_api_management_api_version_set.interview.id

  subscription_required = true

  import {
    content_format = "openapi"
    content_value  = <<JSON
{
  "openapi": "3.0.1",
  "info": {
    "title": "Interview Processor API V1",
    "version": "1.0.0"
  },
  "paths": {
    "/start-interview": {
      "post": {
        "summary": "Start interview workflow",
        "responses": {
          "200": {
            "description": "Success"
          }
        }
      }
    }
  }
}
JSON
  }
}

# API v2
resource "azurerm_api_management_api" "v2" {
  name                = "interview-processor-api-v2"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "Interview Processor API V2"
  path                = "interview/v2"
  protocols           = ["https"]

  version        = "v2"
  version_set_id = azurerm_api_management_api_version_set.interview.id

  subscription_required = true
}

# Backend configuration
resource "azurerm_api_management_backend" "function" {
  name                = "durable-function-backend"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "${var.function_app_url}/api"
  description         = "Backend for Durable Function"

  credentials {
    header = {
      "x-functions-key" = var.function_app_key
    }
  }

  tls {
    validate_certificate_chain = true
    validate_certificate_name  = true
  }
}

# Policy for API v1
resource "azurerm_api_management_api_policy" "v1_policy" {
  api_name            = azurerm_api_management_api.v1.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
    <inbound>
        <base />
        <cors allow-credentials="true">
            <allowed-origins>
                <origin>https://*.azurewebsites.net</origin>
                <origin>https://portal.azure.com</origin>
            </allowed-origins>
            <allowed-methods>
                <method>GET</method>
                <method>POST</method>
            </allowed-methods>
        </cors>
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
            <openid-config url="https://login.microsoftonline.com/${var.tenant_id}/v2.0/.well-known/openid-configuration" />
            <audiences>
                <audience>api://${var.function_app_id}</audience>
            </audiences>
        </validate-jwt>
        <rate-limit calls="${var.rate_limit_calls}" renewal-period="${var.rate_limit_period}" />
        <set-backend-service backend-id="durable-function-backend" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
</policies>
XML
}

# Subscription for testing
resource "azurerm_api_management_subscription" "test" {
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  display_name        = "Test Subscription"
  product_id          = azurerm_api_management_product.interview.id
  state               = "active"
}

# Diagnostic settings for APIM
resource "azurerm_monitor_diagnostic_setting" "apim" {
  name                       = "diagnostics-apim"
  target_resource_id         = azurerm_api_management.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "GatewayLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}