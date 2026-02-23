# Get current client configuration
data "azurerm_client_config" "current" {}

# Action Group for Alerts
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${var.resource_prefix}-alerts-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "ext-alerts"

  email_receiver {
    name                    = "send-to-admin"
    email_address           = var.alert_email_addresses[0]
    use_common_alert_schema = true
  }

  dynamic "email_receiver" {
    for_each = length(var.alert_email_addresses) > 1 ? slice(var.alert_email_addresses, 1, length(var.alert_email_addresses)) : []
    content {
      name                    = "send-to-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  tags = var.tags
}

# Diagnostic Settings for Function Apps
resource "azurerm_monitor_diagnostic_setting" "function_apps" {
  for_each = var.function_app_ids

  name                       = "diagnostics-${each.key}"
  target_resource_id         = each.value
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FunctionAppLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Diagnostic Settings for APIM
# TEMPORARILY REMOVED - This resource causes count dependency issues
# resource "azurerm_monitor_diagnostic_setting" "apim" {
#   count = var.apim_id != null ? 1 : 0
#
#   name                       = "diagnostics-apim"
#   target_resource_id         = var.apim_id
#   log_analytics_workspace_id = var.log_analytics_workspace_id
#
#   enabled_log {
#     category = "GatewayLogs"
#   }
#
#   metric {
#     category = "AllMetrics"
#     enabled  = true
#   }
# }

# Saved KQL Queries
resource "azurerm_log_analytics_saved_search" "function_errors" {
  name                       = "Function Errors Last 24h"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  category     = "Exterview Monitoring"
  display_name = "Function Errors - Last 24 Hours"
  query        = <<QUERY
FunctionAppLogs
| where TimeGenerated > ago(24h)
| where Level == "Error"
| project TimeGenerated, FunctionName, Message, InvocationId, HostInstanceId
| order by TimeGenerated desc
| take 100
QUERY

  tags = {
    "Environment" = var.environment
  }
}

resource "azurerm_log_analytics_saved_search" "durable_orchestrations" {
  name                       = "Durable Orchestrations"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  category     = "Exterview Monitoring"
  display_name = "Durable Function Orchestration Status"
  query        = <<QUERY
FunctionAppLogs
| where TimeGenerated > ago(7d)
| where Category == "Host.Triggers.DurableTask"
| parse Message with * "functionName='" OrchestratorName "'" *
| extend Status = case(
    Message contains "Orchestrator started", "Started",
    Message contains "Orchestrator completed", "Completed",
    Message contains "Orchestrator failed", "Failed",
    "Other"
  )
| summarize OrchestrationCount = count() by OrchestratorName, Status, bin(TimeGenerated, 1h)
| order by TimeGenerated desc
QUERY
}

resource "azurerm_log_analytics_saved_search" "distributed_tracing" {
  name                       = "Distributed Tracing"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  category     = "Exterview Monitoring"
  display_name = "End-to-end Transaction Tracing"
  query        = <<QUERY
union AppTraces, AppRequests, AppDependencies
| where OperationId in (
    AppRequests
    | where Name contains "StartInterview"
    | project OperationId
    | take 10
)
| project Timestamp=datetime(TimeGenerated), OperationId, ItemType=Type, Name, 
          DurationMs=DurationMs, Success=Success, Properties
| order by Timestamp asc
QUERY
}

resource "azurerm_log_analytics_saved_search" "performance_metrics" {
  name                       = "Performance Metrics"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  category     = "Exterview Monitoring"
  display_name = "Function Performance Metrics"
  query        = <<QUERY
AppRequests
| where TimeGenerated > ago(24h)
| where Name contains "Interview"
| summarize 
    RequestCount = count(),
    AvgDuration = avg(DurationMs),
    P95Duration = percentile(DurationMs, 95),
    P99Duration = percentile(DurationMs, 99),
    SuccessRate = 100 - (countif(Success == false) * 100.0 / count())
    by bin(TimeGenerated, 1h), Name
| order by TimeGenerated desc
QUERY
}

# Alert Rule for High Error Rate
resource "azurerm_monitor_scheduled_query_rules_alert" "high_error_rate" {
  name                = "High Error Rate Alert"
  location            = var.location
  resource_group_name = var.resource_group_name

  action {
    action_group = [azurerm_monitor_action_group.main.id]
  }

  data_source_id = var.log_analytics_workspace_id
  description    = "Alert when function error rate exceeds threshold"
  enabled        = true

  query = <<QUERY
FunctionAppLogs
| where TimeGenerated > ago(5m)
| where Level == "Error"
| summarize ErrorCount = count()
QUERY

  severity    = 1
  frequency   = 5
  time_window = 5
  trigger {
    operator  = "GreaterThan"
    threshold = 5
  }
}

# Alert Rule for Long Running Functions
resource "azurerm_monitor_scheduled_query_rules_alert" "long_running" {
  name                = "Long Running Functions Alert"
  location            = var.location
  resource_group_name = var.resource_group_name

  action {
    action_group = [azurerm_monitor_action_group.main.id]
  }

  data_source_id = var.log_analytics_workspace_id
  description    = "Alert when functions run longer than expected"
  enabled        = true

  query = <<QUERY
AppRequests
| where TimeGenerated > ago(10m)
| where Name contains "Interview"
| where DurationMs > 30000
| project TimeGenerated, Name, DurationMs, OperationId
QUERY

  severity    = 2
  frequency   = 5
  time_window = 10
  trigger {
    operator  = "GreaterThan"
    threshold = 1
  }
}

# Metric Alert for Function Health
resource "azurerm_monitor_metric_alert" "function_health" {
  for_each = var.function_app_ids

  name                = "Function Health Alert - ${each.key}"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Alert when function app is unhealthy"
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = var.tags
}

# Dashboard for Monitoring
resource "azurerm_portal_dashboard" "main" {
  name                = "exterview-dashboard-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          "0" = {
            position = {
              x = 0
              y = 0
              colSpan = 3
              rowSpan = 2
            }
            metadata = {
              inputs = [{
                name = "queryInputs"
                value = {
                  query = "AppRequests | summarize count() by bin(TimeGenerated, 1h), Name"
                }
              }]
              type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
            }
          }
          "1" = {
            position = {
              x = 3
              y = 0
              colSpan = 3
              rowSpan = 2
            }
            metadata = {
              inputs = [{
                name = "queryInputs"
                value = {
                  query = "FunctionAppLogs | where Level == 'Error' | summarize count() by bin(TimeGenerated, 1h)"
                }
              }]
              type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
            }
          }
          "2" = {
            position = {
              x = 6
              y = 0
              colSpan = 3
              rowSpan = 2
            }
            metadata = {
              inputs = [{
                name = "options"
                value = {
                  chart = {
                    metrics = [{
                      resourceMetadata = {
                        id = length(var.function_app_ids) > 0 ? "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Web/sites/${values(var.function_app_ids)[0]}" : ""
                      }
                      name = "HttpResponseTime"
                      aggregationType = 1
                    }]
                  }
                }
              }]
              type = "Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart"
            }
          }
        }
      }
    }
    metadata = {
      model = {
        timeRange = {
          value = "P1D"
          type = "MsPortalFx.Data.TimeRange.Last"
        }
      }
    }
  })
}