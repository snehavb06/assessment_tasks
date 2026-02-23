# Management Group Structure
resource "azurerm_management_group" "root" {
  name         = "mg-${var.resource_prefix}-root-${var.environment}"
  display_name = "Exterview Root Management Group - ${var.environment}"

  parent_management_group_id = var.management_group_parent_id != "" ? var.management_group_parent_id : null
}

resource "azurerm_management_group" "platform" {
  name         = "mg-${var.resource_prefix}-platform-${var.environment}"
  display_name = "Platform Management Group - ${var.environment}"

  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "applications" {
  name         = "mg-${var.resource_prefix}-apps-${var.environment}"
  display_name = "Applications Management Group - ${var.environment}"

  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "sandbox" {
  name         = "mg-${var.resource_prefix}-sandbox-${var.environment}"
  display_name = "Sandbox Management Group - ${var.environment}"

  parent_management_group_id = azurerm_management_group.root.id
}

# RBAC Assignments //temporaryly commentiing our as i am not root user i dont have authority to assign 
#resource "azurerm_role_assignment" "team_contributor" {
 # scope                = azurerm_management_group.applications.id
  #role_definition_name = "Contributor"
  #principal_id         = var.team_object_id
  #description          = "Team members have contributor access to applications management group"
#}

#resource "azurerm_role_assignment" "audit_reader" {
 # scope                = azurerm_management_group.platform.id
  #role_definition_name = "Reader"
  #principal_id         = var.audit_object_id
  #description          = "Audit team has read access to platform management group"
#}

resource "azurerm_role_assignment" "security_reader" {
  scope                = azurerm_management_group.root.id
  role_definition_name = "Security Reader"
  principal_id         = var.audit_object_id
  description          = "Audit team has security read access"
}

# Custom Policy Definition: Deny public network access for storage accounts
# Custom Policy Definition - Specify management group scope
resource "azurerm_policy_definition" "deny_public_storage" {
  name         = "deny-public-storage-${var.environment}"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny public network access for storage accounts"
  description  = "This policy denies creation of storage accounts with public network access"
  
  management_group_id = "/providers/Microsoft.Management/managementGroups/mg-ext-apps-dev"  # Add this line

  metadata = jsonencode({
    version = "1.0.0"
    category = "Storage"
  })

  policy_rule = jsonencode({
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.Storage/storageAccounts"
        },
        {
          "anyOf": [
            {
              "field": "Microsoft.Storage/storageAccounts/networkAcls.defaultAction",
              "equals": "Allow"
            },
            {
              "field": "Microsoft.Storage/storageAccounts/publicNetworkAccess",
              "equals": "Enabled"
            }
          ]
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  })
}

# Custom Policy Definition: Mandatory tags
resource "azurerm_policy_definition" "mandatory_tags" {
  name         = "mandatory-tags-${var.environment}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require mandatory tags on resources"
  description  = "This policy requires specific tags on all resources"

  metadata = jsonencode({
    version  = "1.0.0"
    category = "Tags"
  })

  parameters = jsonencode({
    "tagNames" : {
      "type" : "Array",
      "metadata" : {
        "displayName" : "Required Tag Names",
        "description" : "List of tag names that must be present on resources"
      },
      "defaultValue" : ["Environment", "CostCenter", "Owner"]
    }
  })

  policy_rule = jsonencode({
    "if" : {
      "anyOf" : [
        {
          "field" : "[concat('tags[', parameters('tagNames')[0], ']')]",
          "exists" : "false"
        },
        {
          "field" : "[concat('tags[', parameters('tagNames')[1], ']')]",
          "exists" : "false"
        },
        {
          "field" : "[concat('tags[', parameters('tagNames')[2], ']')]",
          "exists" : "false"
        }
      ]
    },
    "then" : {
      "effect" : "deny"
    }
  })
}

# Policy Assignment at Applications Management Group - FIXED NAME LENGTH
resource "azurerm_management_group_policy_assignment" "deny_public_storage" {
  name                 = "assign-deny-storage" # Shorter name (within 3-24 characters)
  policy_definition_id = azurerm_policy_definition.deny_public_storage.id
  management_group_id  = azurerm_management_group.applications.id
  display_name         = "Enforce no public storage access"
  description          = "Prevent storage accounts from being publicly accessible"
  location             = var.location

  identity {
    type = "SystemAssigned"
  }
}

# Policy Assignment at Applications Management Group for tags
resource "azurerm_management_group_policy_assignment" "mandatory_tags" {
  name                 = "assign-mandatory-tags" # Shorter name
  policy_definition_id = azurerm_policy_definition.mandatory_tags.id
  management_group_id  = azurerm_management_group.applications.id
  display_name         = "Enforce mandatory tags"
  description          = "Require Environment, CostCenter, and Owner tags on all resources"
  location             = var.location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    "tagNames" : {
      "value" : ["Environment", "CostCenter", "Owner"]
    }
  })
}

# Policy Exemption for Sandbox
resource "azurerm_management_group_policy_exemption" "sandbox_tag_exemption" {
  name                 = "sandbox-tag-exempt"
  management_group_id  = azurerm_management_group.sandbox.id
  policy_assignment_id = azurerm_management_group_policy_assignment.mandatory_tags.id
  exemption_category   = "Waiver"
  display_name         = "Sandbox tag exemption"
  description          = "Sandbox environment is exempt from mandatory tags for testing"
  expires_on           = timeadd(timestamp(), "8760h") # 1 year from now
}

# Policy Exemption for specific resource (conditional)
# Policy Exemption for specific resource - only create if resource_group_id is provided
#resource "azurerm_resource_group_policy_exemption" "specific_exemption" {
# count = var.resource_group_id != "" && var.resource_group_id != null ? 1 : 0
#
# name                 = "specific-resource-exempt"a
#resource_group_id    = var.resource_group_id
#policy_assignment_id = azurerm_management_group_policy_assignment.deny_public_storage.id
#exemption_category   = "Mitigated"
#display_name         = "Specific resource exemption for testing"
#description          = "This resource is exempted for testing purposes"
#expires_on           = timeadd(timestamp(), "168h") # 7 days from now
#}