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

variable "location" {
  description = "Azure region"
  type        = string
}

variable "management_group_parent_id" {
  description = "Parent management group ID"
  type        = string
  default     = ""
}

variable "resource_group_id" {
  description = "Resource group ID for policy exemptions"
  type        = string
  default     = ""
}

variable "team_object_id" {
  description = "Azure AD group object ID for team"
  type        = string
}

variable "audit_object_id" {
  description = "Azure AD group object ID for audit"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}