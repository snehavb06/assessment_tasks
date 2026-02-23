# Core Variables
variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "centralindia"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Project    = "Exterview-Assessment"
    ManagedBy  = "Terraform"
    CostCenter = "Engineering"
    Owner      = "CloudTeam"
  }
}

# Naming Variables
variable "resource_prefix" {
  description = "Prefix for resource naming"
  type        = string
  default     = "ext"
}

variable "unique_suffix" {
  description = "Unique suffix for globally unique names"
  type        = string
  default     = ""
}

# APIM Variables
variable "publisher_name" {
  description = "API Management publisher name"
  type        = string
  default     = "Exterview Assessment"
}

variable "publisher_email" {
  description = "API Management publisher email"
  type        = string
  sensitive   = true
}

variable "apim_sku" {
  description = "API Management SKU"
  type        = string
  default     = "Developer_1"
}

# SignalR Variables
variable "signalr_sku" {
  description = "SignalR Service SKU"
  type        = string
  default     = "Free_F1"
}

variable "signalr_capacity" {
  description = "SignalR capacity units"
  type        = number
  default     = 1
}

variable "signalr_service_mode" {
  description = "SignalR service mode"
  type        = string
  default     = "Serverless"
}

# Rate Limiting
variable "rate_limit_calls" {
  description = "Number of calls allowed per rate limit period"
  type        = number
  default     = 1000
}

variable "rate_limit_period" {
  description = "Rate limit period in seconds"
  type        = number
  default     = 60
}

# Governance Variables
variable "management_group_parent_id" {
  description = "Parent management group ID"
  type        = string
  default     = ""
}

variable "team_object_id" {
  description = "Azure AD group object ID for team"
  type        = string
  sensitive   = true
}

variable "audit_object_id" {
  description = "Azure AD group object ID for audit"
  type        = string
  sensitive   = true
}

# Observability
variable "log_retention_days" {
  description = "Log Analytics workspace retention days"
  type        = number
  default     = 30
}

variable "alert_email_addresses" {
  description = "Email addresses for alerts"
  type        = list(string)
  default     = []
}

# Cosmos DB
variable "cosmosdb_consistency_level" {
  description = "Cosmos DB consistency level"
  type        = string
  default     = "Session"
}

# AI Readiness
variable "openai_quota_tokens_per_month" {
  description = "Monthly token quota for OpenAI"
  type        = number
  default     = 500000000
}

# Tenant ID
variable "tenant_id" {
  description = "Azure AD Tenant ID"
  type        = string
  default     = "e05455be-e3eb-417e-a2d1-1d5872d61586"
}

# Subscription IDs
variable "subscription_id_new" {
  description = "New subscription ID"
  type        = string
  default     = "66a7b046-11b4-488f-8e16-b4fc3a028d62"
}

variable "subscription_id_demo" {
  description = "Demo subscription ID"
  type        = string
  default     = "8068472b-b45e-4be3-a6a4-32433ea44b46"
}