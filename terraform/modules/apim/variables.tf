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

variable "publisher_name" {
  description = "API Management publisher name"
  type        = string
}

variable "publisher_email" {
  description = "API Management publisher email"
  type        = string
}

variable "apim_sku" {
  description = "API Management SKU"
  type        = string
}

variable "function_app_url" {
  description = "Function app URL"
  type        = string
}

variable "function_app_id" {
  description = "Function app principal ID"
  type        = string
}

variable "function_app_key" {
  description = "Function app default key"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "rate_limit_calls" {
  description = "Number of calls allowed per period"
  type        = number
}

variable "rate_limit_period" {
  description = "Rate limit period in seconds"
  type        = number
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}