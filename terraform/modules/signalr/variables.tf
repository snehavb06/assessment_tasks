variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "unique_suffix" {
  description = "Unique suffix for resource naming"
  type        = string
}

variable "signalr_sku" {
  description = "SignalR Service SKU"
  type        = string
}

variable "signalr_capacity" {
  description = "SignalR capacity units"
  type        = number
}

variable "signalr_service_mode" {
  description = "SignalR service mode"
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name"
  type        = string
}

variable "storage_account_key" {
  description = "Storage account access key"
  type        = string
  sensitive   = true
}

variable "storage_account_connection_string" {
  description = "Storage account connection string"
  type        = string
  sensitive   = true
}

variable "app_insights_connection_string" {
  description = "Application Insights connection string"
  type        = string
  sensitive   = true
}

variable "app_insights_key" {
  description = "Application Insights instrumentation key"
  type        = string
  sensitive   = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  type        = string
}

variable "function_app_plan_id" {
  description = "Function App Plan ID"
  type        = string
  default     = null
}

variable "function_app_name" {
  description = "Function App name for upstream"
  type        = string
  default     = ""
}

variable "function_app_key" {
  description = "Function App key for upstream"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}