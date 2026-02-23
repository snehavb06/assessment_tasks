#!/bin/bash

# Variables
RESOURCE_GROUP="terraform-state-rg"
LOCATION="centralindia"
STORAGE_ACCOUNT="tfstateextcentral2311"
CONTAINER_NAME="tfstate"

# Create resource group
echo "Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create storage account
echo "Creating storage account..."
az storage account create \
    --name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS \
    --kind StorageV2

# Get storage account key
ACCOUNT_KEY=$(az storage account keys list \
    --resource-group $RESOURCE_GROUP \
    --account-name $STORAGE_ACCOUNT \
    --query '[0].value' -o tsv)

# Create container
echo "Creating container..."
az storage container create \
    --name $CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT \
    --account-key "$ACCOUNT_KEY"

echo "Backend setup complete!"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container: $CONTAINER_NAME"
echo "Resource Group: $RESOURCE_GROUP"