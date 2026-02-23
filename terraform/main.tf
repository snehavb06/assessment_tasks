# Generate random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  unique_suffix   = var.unique_suffix != "" ? var.unique_suffix : random_string.suffix.result
  resource_prefix = var.resource_prefix

  # Common tags for all resources
  common_tags = merge(var.tags, {
    Environment = var.environment
    DeployedBy  = "Terraform"
    DeployDate  = formatdate("YYYY-MM-DD", timestamp())
  })
}

# Core Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.resource_prefix}-assessment-${var.environment}-${local.unique_suffix}"
  location = var.location
  tags     = local.common_tags
}

# Storage Account for Function Apps
resource "azurerm_storage_account" "functions" {
  name                            = "st${local.resource_prefix}func${var.environment}${local.unique_suffix}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }

  tags = local.common_tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.resource_prefix}-${var.environment}-${local.unique_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.common_tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "appi-${local.resource_prefix}-${var.environment}-${local.unique_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.common_tags
}

# Cosmos DB Account
resource "azurerm_cosmosdb_account" "main" {
  name                = "cosmos-${local.resource_prefix}-${var.environment}-${local.unique_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level       = var.cosmosdb_consistency_level
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }

  capabilities {
    name = "EnableServerless"
  }

  tags = local.common_tags
}

# Cosmos DB SQL Database
resource "azurerm_cosmosdb_sql_database" "main" {
  name                = "interviewdb"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
 # throughput          = 400
}

# Cosmos DB Container - CORRECT SYNTAX
# Cosmos DB Container - CORRECT for v4.x provider (partition_key_paths with array)
resource "azurerm_cosmosdb_sql_container" "interviews" {
  name                = "interviews"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name
  partition_key_path  = "/id"  # ← CHANGE THIS - singular, not plural

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/\"_etag\"/?"
    }
  }
}

# Cosmos DB Container for Orchestration History - USE SINGULAR
resource "azurerm_cosmosdb_sql_container" "orchestrations" {
  name                = "orchestrations"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name
  partition_key_path  = "/instanceId"  # ← CHANGE THIS - singular, not plural

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }
  }
}

# Key Vault for Secrets
resource "azurerm_key_vault" "main" {
  name                = "kv-${local.resource_prefix}-${var.environment}-${local.unique_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name           = "standard"

  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = ["47.11.47.122"]  # Add your IP address
  }

  tags = local.common_tags
}

# Get current client configuration
data "azurerm_client_config" "current" {}

# Grant current user access to Key Vault
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Backup",
    "Restore"
  ]
}

# Store Cosmos DB connection string in Key Vault
resource "azurerm_key_vault_secret" "cosmos_connection_string" {
  name         = "cosmos-connection-string"
  value        = azurerm_cosmosdb_account.main.primary_sql_connection_string
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# Store Storage Account connection string in Key Vault
resource "azurerm_key_vault_secret" "storage_connection_string" {
  name         = "storage-connection-string"
  value        = azurerm_storage_account.functions.primary_connection_string
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# Task 1: Durable Functions Module
module "durable_functions" {
  source = "./modules/durable_function"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = var.environment
  resource_prefix     = local.resource_prefix
  unique_suffix       = local.unique_suffix

  storage_account_name              = azurerm_storage_account.functions.name
  storage_account_key               = azurerm_storage_account.functions.primary_access_key
  storage_account_connection_string = azurerm_storage_account.functions.primary_connection_string

  cosmosdb_connection_string = azurerm_cosmosdb_account.main.primary_sql_connection_string

  app_insights_connection_string = azurerm_application_insights.main.connection_string
  app_insights_key               = azurerm_application_insights.main.instrumentation_key

  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = local.common_tags
}

# Task 2: API Management Module
module "apim" {
  source = "./modules/apim"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = var.environment
  resource_prefix     = local.resource_prefix
  unique_suffix       = local.unique_suffix

  publisher_name  = var.publisher_name
  publisher_email = var.publisher_email
  apim_sku        = var.apim_sku

  function_app_url = module.durable_functions.function_app_url
  function_app_id  = module.durable_functions.function_app_principal_id
  function_app_key = module.durable_functions.function_app_default_key

  rate_limit_calls  = var.rate_limit_calls
  rate_limit_period = var.rate_limit_period

  tenant_id = data.azurerm_client_config.current.tenant_id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = local.common_tags

  depends_on = [module.durable_functions]
}

# Task 3: SignalR Module
module "signalr" {
  source = "./modules/signalr"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = var.environment
  resource_prefix     = local.resource_prefix
  unique_suffix       = local.unique_suffix

  signalr_sku          = var.signalr_sku
  signalr_capacity     = var.signalr_capacity
  signalr_service_mode = var.signalr_service_mode

  storage_account_name              = azurerm_storage_account.functions.name
  storage_account_key               = azurerm_storage_account.functions.primary_access_key
  storage_account_connection_string = azurerm_storage_account.functions.primary_connection_string

  app_insights_connection_string = azurerm_application_insights.main.connection_string
  app_insights_key               = azurerm_application_insights.main.instrumentation_key

  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  function_app_plan_id = module.durable_functions.service_plan_id
  function_app_name    = module.durable_functions.function_app_name
  function_app_key     = module.durable_functions.function_app_default_key

  tags = local.common_tags

  depends_on = [module.durable_functions]
}

# Task 4: Governance Module
module "governance" {
  source = "./modules/governance"

  environment     = var.environment
  resource_prefix = local.resource_prefix
  unique_suffix   = local.unique_suffix

  location                   = azurerm_resource_group.main.location
  resource_group_id          = azurerm_resource_group.main.id
  management_group_parent_id = var.management_group_parent_id

  team_object_id  = var.team_object_id
  audit_object_id = var.audit_object_id

  tags = local.common_tags
}

# Task 5: Observability Module
module "observability" {
  source = "./modules/observability"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = var.environment
  resource_prefix     = local.resource_prefix
  unique_suffix       = local.unique_suffix

  log_analytics_workspace_id   = azurerm_log_analytics_workspace.main.id
  log_analytics_workspace_name = azurerm_log_analytics_workspace.main.name

  app_insights_name = azurerm_application_insights.main.name
  app_insights_id   = azurerm_application_insights.main.id

  function_app_ids = {
    durable = module.durable_functions.function_app_id
    signalr = module.signalr.function_app_id
  }

  apim_id = module.apim.apim_id

  alert_email_addresses  = var.alert_email_addresses
  alert_action_group_ids = []

  tags = local.common_tags

  depends_on = [
    module.durable_functions,
    module.signalr,
    module.apim
  ]
}