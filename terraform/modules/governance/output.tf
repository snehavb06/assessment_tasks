output "management_group_ids" {
  description = "Map of management group IDs"
  value = {
    root        = azurerm_management_group.root.id
    platform    = azurerm_management_group.platform.id
    applications = azurerm_management_group.applications.id
    sandbox     = azurerm_management_group.sandbox.id
  }
}

output "policy_definition_ids" {
  description = "Map of policy definition IDs"
  value = {
    deny_public_storage = azurerm_policy_definition.deny_public_storage.id
    mandatory_tags      = azurerm_policy_definition.mandatory_tags.id
  }
}

output "policy_assignment_ids" {
  description = "Map of policy assignment IDs"
  value = {
    deny_public_storage = azurerm_management_group_policy_assignment.deny_public_storage.id
    mandatory_tags      = azurerm_management_group_policy_assignment.mandatory_tags.id
  }
}

output "policy_exemption_ids" {
  description = "Map of policy exemption IDs"
  value = {
    sandbox_tag_exemption = azurerm_management_group_policy_exemption.sandbox_tag_exemption.id
    # specific_exemption is temporarily disabled
    specific_exemption    = null
  }
}