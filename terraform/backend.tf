terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstateextcentral2311"
    container_name       = "tfstate"
    key                  = "exterview-assessment.tfstate"
  }
}