# Git clone 
git clone https://github.com/snehavb06/assessment_tasks.git

Step 2: Configure Authentication
bash
# Login to Azure
az login

# Set subscription
az account set --subscription "your-subscription-id"

# Create service principal (if needed)
az ad sp create-for-rbac --name "terraform-sp" --role Contributor --scopes /subscriptions/$(az account show --query id -o tsv)

# Set environment variables
export ARM_CLIENT_ID="<service-principal-client-id>"
export ARM_CLIENT_SECRET="<service-principal-secret>"
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export ARM_TENANT_ID="$(az account show --query tenantId -o tsv)"
Step 3: Initialize and Deploy
bash
cd terraform

# Initialize with backend
terraform init \
    -backend-config="resource_group_name=terraform-state-rg" \
    -backend-config="storage_account_name=tfstateextcentral2311" \
    -backend-config="container_name=tfstate" \
    -backend-config="key=exterview-assessment.tfstate"

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan

# Apply deployment
terraform apply tfplan
Step 4: Get Output Values
bash
# Get all outputs
terraform output

# Get specific outputs
terraform output durable_function_app_url
terraform output apim_gateway_url
terraform output signalr_service_endpoint
