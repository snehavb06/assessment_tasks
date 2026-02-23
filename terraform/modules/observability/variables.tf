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

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Log Analytics workspace name"
  type        = string
}

variable "app_insights_name" {
  description = "Application Insights name"
  type        = string
}

variable "app_insights_id" {
  description = "Application Insights ID"
  type        = string
}

variable "function_app_ids" {
  description = "Map of function app IDs"
  type        = map(string)
  default     = {}
}

variable "apim_id" {
  description = "API Management ID"
  type        = string
  default     = null
}

variable "alert_email_addresses" {
  description = "Email addresses for alerts"
  type        = list(string)
  default     = []
}

variable "alert_action_group_ids" {
  description = "List of action group IDs for alerts"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}