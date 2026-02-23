#!/bin/bash

# quick-setup.sh
# Exterview Assessment - Quick Setup Script for Git Bash/Linux

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}Exterview Assessment - Quick Setup${NC}"
echo -e "${GREEN}===================================${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required tools
echo -e "\n${YELLOW}Checking required tools...${NC}"

if ! command_exists az; then
    echo -e "${RED}Azure CLI not found. Please install it first:${NC}"
    echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

if ! command_exists jq; then
    echo -e "${YELLOW}jq not found. Installing...${NC}"
    if command_exists apt-get; then
        sudo apt-get install -y jq
    elif command_exists yum; then
        sudo yum install -y jq
    elif command_exists brew; then
        brew install jq
    else
        echo -e "${RED}Please install jq manually:${NC}"
        echo "https://stedolan.github.io/jq/download/"
        exit 1
    fi
fi

# Check if logged in
echo -e "\n${YELLOW}Checking Azure login status...${NC}"
ACCOUNT=$(az account show 2>/dev/null || true)
if [ -z "$ACCOUNT" ]; then
    echo -e "${YELLOW}Please login to Azure first...${NC}"
    az login
else
    echo -e "${GREEN}Already logged in to Azure${NC}"
fi

# Get subscription info
echo -e "\n${YELLOW}Getting subscription information...${NC}"
SUB_ID=$(az account show --query id -o tsv)
SUB_NAME=$(az account show --query name -o tsv)
echo -e "${GREEN}Using Subscription: ${CYAN}$SUB_NAME ($SUB_ID)${NC}"

# List existing management groups
echo -e "\n${YELLOW}Checking Management Groups...${NC}"
MG_GROUPS=$(az account management-group list --query "[].name" -o tsv 2>/dev/null || echo "No management groups found")
echo -e "${GREEN}Found Management Groups: ${CYAN}$MG_GROUPS${NC}"

# Create Azure AD groups if needed
echo -e "\n${YELLOW}Setting up Azure AD Groups...${NC}"

# Function to create or get group
create_or_get_group() {
    local group_name=$1
    local group_mail=$2
    
    echo -e "${YELLOW}Checking $group_name group...${NC}"
    
    # Try to get existing group
    GROUP_JSON=$(az ad group show --group "$group_name" 2>/dev/null || echo "")
    
    if [ -z "$GROUP_JSON" ]; then
        echo -e "${YELLOW}Creating $group_name group...${NC}"
        GROUP_JSON=$(az ad group create \
            --display-name "$group_name" \
            --mail-nickname "$group_mail" \
            --output json)
        echo -e "${GREEN}Created $group_name group${NC}"
    else
        echo -e "${GREEN}$group_name already exists${NC}"
    fi
    
    echo "$GROUP_JSON"
}

# Create Interview-Team group
TEAM_GROUP=$(create_or_get_group "Interview-Team" "interview-team")
TEAM_GROUP_ID=$(echo "$TEAM_GROUP" | jq -r '.id')
echo -e "${GREEN}Team Group ID: ${CYAN}$TEAM_GROUP_ID${NC}"

# Create Interview-Audit group
AUDIT_GROUP=$(create_or_get_group "Interview-Audit" "interview-audit")
AUDIT_GROUP_ID=$(echo "$AUDIT_GROUP" | jq -r '.id')
echo -e "${GREEN}Audit Group ID: ${CYAN}$AUDIT_GROUP_ID${NC"

# Add current user to groups (optional)
echo -e "\n${YELLOW}Adding current user to groups...${NC}"
USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")

if [ -n "$USER_ID" ]; then
    # Add to Team group
    az ad group member add --group "$TEAM_GROUP_ID" --member-id "$USER_ID" 2>/dev/null && \
        echo -e "${GREEN}Added user to Interview-Team group${NC}" || \
        echo -e "${YELLOW}User might already be in group or insufficient permissions${NC}"
    
    # Add to Audit group
    az ad group member add --group "$AUDIT_GROUP_ID" --member-id "$USER_ID" 2>/dev/null && \
        echo -e "${GREEN}Added user to Interview-Audit group${NC}" || \
        echo -e "${YELLOW}User might already be in group or insufficient permissions${NC}"
else
    echo -e "${YELLOW}Could not get current user ID, skipping group membership${NC}"
fi

# Generate terraform.tfvars
echo -e "\n${YELLOW}Generating terraform.tfvars...${NC}"

# Create terraform directory if it doesn't exist
mkdir -p ../terraform

# Get current timestamp for unique suffix
TIMESTAMP=$(date +%m%d)
UNIQUE_SUFFIX="${TIMESTAMP}"

# Get user email for alerts
USER_EMAIL=$(az ad signed-in-user show --query "userPrincipalName" -o tsv 2>/dev/null || echo "admin@interviewcorp.com")

# Create tfvars file
cat > ../terraform/terraform.tfvars << EOF
# Environment
environment = "dev"
location    = "centralindia"

# Resource naming
resource_prefix = "ext"
unique_suffix   = "$UNIQUE_SUFFIX"

# APIM
publisher_name     = "InterviewCorp"
publisher_email    = "$USER_EMAIL"
apim_sku           = "Developer_1"

# SignalR
signalr_sku          = "Free_F1"
signalr_capacity     = 1
signalr_service_mode = "Serverless"

# Rate Limiting
rate_limit_calls  = 1000
rate_limit_period = 60

# Governance - Using actual Azure AD Group IDs
team_object_id   = "$TEAM_GROUP_ID"
audit_object_id  = "$AUDIT_GROUP_ID"

# Management Group Parent
# Using your existing InterviewCorp management group
management_group_parent_id = "/providers/Microsoft.Management/managementGroups/InterviewCorp"

# Observability
log_retention_days  = 30
alert_email_addresses = [
  "$USER_EMAIL",
  "oncall@interviewcorp.com"
]

# Cosmos DB
cosmosdb_consistency_level = "Session"

# AI Readiness
openai_quota_tokens_per_month = 500000000
EOF

echo -e "${GREEN}terraform.tfvars generated successfully!${NC}"
echo -e "${BLUE}File location: ../terraform/terraform.tfvars${NC}"

# Setup Terraform Backend
echo -e "\n${YELLOW}Setting up Terraform Backend...${NC}"

RG_NAME="terraform-state-rg"
SA_NAME="tfstateextcentral$UNIQUE_SUFFIX"
CONTAINER_NAME="tfstate"

# Create resource group
echo -e "${YELLOW}Creating resource group...${NC}"
az group create \
    --name $RG_NAME \
    --location "centralindia" \
    --tags "Environment=terraform" "Project=Exterview" \
    --output none

echo -e "${GREEN}Resource group created: $RG_NAME${NC}"

# Create storage account
echo -e "${YELLOW}Creating storage account...${NC}"
az storage account create \
    --name $SA_NAME \
    --resource-group $RG_NAME \
    --location "centralindia" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --output none

echo -e "${GREEN}Storage account created: $SA_NAME${NC}"

# Get storage account key
ACCOUNT_KEY=$(az storage account keys list \
    --resource-group $RG_NAME \
    --account-name $SA_NAME \
    --query '[0].value' -o tsv)

# Create container
echo -e "${YELLOW}Creating container...${NC}"
az storage container create \
    --name $CONTAINER_NAME \
    --account-name $SA_NAME \
    --account-key "$ACCOUNT_KEY" \
    --output none

echo -e "${GREEN}Container created: $CONTAINER_NAME${NC}"

# Create backend.tf
echo -e "\n${YELLOW}Creating backend.tf...${NC}"

cat > ../terraform/backend.tf << EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "$RG_NAME"
    storage_account_name = "$SA_NAME"
    container_name       = "$CONTAINER_NAME"
    key                  = "exterview-assessment.tfstate"
  }
}
EOF

echo -e "${GREEN}backend.tf created successfully!${NC}"

# Create service principal if needed (optional)
echo -e "\n${YELLOW}Do you want to create a service principal for Terraform? (y/n)${NC}"
read -r CREATE_SP

if [[ "$CREATE_SP" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Creating service principal 'terraform-sp'...${NC}"
    
    SP_NAME="terraform-sp-$(date +%s)"
    SP_JSON=$(az ad sp create-for-rbac \
        --name "$SP_NAME" \
        --role Contributor \
        --scopes "/subscriptions/$SUB_ID" \
        --output json)
    
    CLIENT_ID=$(echo "$SP_JSON" | jq -r '.appId')
    CLIENT_SECRET=$(echo "$SP_JSON" | jq -r '.password')
    TENANT_ID=$(echo "$SP_JSON" | jq -r '.tenant')
    
    echo -e "${GREEN}Service Principal created successfully!${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "${CYAN}ARM_CLIENT_ID: $CLIENT_ID${NC}"
    echo -e "${CYAN}ARM_CLIENT_SECRET: $CLIENT_SECRET${NC}"
    echo -e "${CYAN}ARM_TENANT_ID: $TENANT_ID${NC}"
    echo -e "${CYAN}ARM_SUBSCRIPTION_ID: $SUB_ID${NC}"
    echo -e "${BLUE}================================${NC}"
    
    # Save credentials to file
    cat > ../terraform/sp-credentials.json << EOF
{
  "clientId": "$CLIENT_ID",
  "clientSecret": "$CLIENT_SECRET",
  "tenantId": "$TENANT_ID",
  "subscriptionId": "$SUB_ID"
}
EOF
    echo -e "${GREEN}Credentials saved to ../terraform/sp-credentials.json${NC}"
    
    # Create environment variables file
    cat > ../terraform/setenv.sh << EOF
#!/bin/bash
export ARM_CLIENT_ID="$CLIENT_ID"
export ARM_CLIENT_SECRET="$CLIENT_SECRET"
export ARM_TENANT_ID="$TENANT_ID"
export ARM_SUBSCRIPTION_ID="$SUB_ID"
echo "Environment variables set for Terraform"
EOF
    
    chmod +x ../terraform/setenv.sh
    echo -e "${GREEN}Environment setup script created: ../terraform/setenv.sh${NC}"
    echo -e "${YELLOW}Run 'source ../terraform/setenv.sh' to set environment variables${NC}"
fi

# Create deployment script
echo -e "\n${YELLOW}Creating deployment script...${NC}"

cat > ../terraform/deploy.sh << 'EOF'
#!/bin/bash

set -e

echo "Exterview Assessment - Terraform Deployment"
echo "==========================================="

# Check if environment variables are set
if [ -z "$ARM_CLIENT_ID" ]; then
    echo "Warning: ARM_CLIENT_ID not set. Make sure you're authenticated."
    echo "Options:"
    echo "1. Run 'az login' (use your personal account)"
    echo "2. Or set service principal environment variables"
    echo ""
    read -p "Continue with az login? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Validate configuration
echo "Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "Creating deployment plan..."
terraform plan -out=tfplan

# Apply deployment
echo "Apply deployment? (y/n)"
read -r APPLY
if [[ "$APPLY" =~ ^[Yy]$ ]]; then
    echo "Applying deployment..."
    terraform apply tfplan
    
    # Show outputs
    echo ""
    echo "Deployment Outputs:"
    echo "==================="
    terraform output
else
    echo "Deployment cancelled"
fi
EOF

chmod +x ../terraform/deploy.sh
echo -e "${GREEN}Deployment script created: ../terraform/deploy.sh${NC}"

# Final summary
echo -e "\n${GREEN}✅ Setup Complete!${NC}"
echo -e "${GREEN}=================${NC}"
echo -e "${CYAN}Team Group ID:${NC} $TEAM_GROUP_ID"
echo -e "${CYAN}Audit Group ID:${NC} $AUDIT_GROUP_ID"
echo -e "${CYAN}Subscription ID:${NC} $SUB_ID"
echo -e "${CYAN}Storage Account:${NC} $SA_NAME"
echo -e "${CYAN}Resource Group:${NC} $RG_NAME"

echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "${BLUE}1. cd ../terraform${NC}"
echo -e "${BLUE}2. source setenv.sh (if you created a service principal)${NC}"
echo -e "${BLUE}3. ./deploy.sh${NC}"
echo -e "${BLUE}4. Or run manually:${NC}"
echo -e "   terraform init"
echo -e "   terraform plan"
echo -e "   terraform apply"

echo -e "\n${GREEN}Happy deploying! 🚀${NC}"