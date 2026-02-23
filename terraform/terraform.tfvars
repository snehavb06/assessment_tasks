# Environment
environment = "dev"
location    = "centralindia"

# Resource naming
resource_prefix = "ext"
unique_suffix   = "2311"

# APIM
publisher_name  = "InterviewCorp"
publisher_email = "admin@interviewcorp.com" # Update this
apim_sku        = "Developer_1"

# SignalR
signalr_sku          = "Free_F1"
signalr_capacity     = 1
signalr_service_mode = "Serverless"

# Rate Limiting
rate_limit_calls  = 1000
rate_limit_period = 60

# Governance - Using your actual IDs from the screenshot
tenant_id       = "e05455be-e3eb-417e-a2d1-1d5872d61586" # This is your tenant ID
team_object_id  = "35da2373-6cc6-4269-9e51-87cfd087527a" # Using tenant ID for team
audit_object_id = "35da2373-6cc6-4269-9e51-87cfd087527a" # Using tenant ID for audit

# Management Group Configuration
management_group_parent_id = "/providers/Microsoft.Management/managementGroups/InterviewCorp"

# Subscriptions
subscription_id_new  = "66a7b046-11b4-488f-8e16-b4fc3a028d62"
subscription_id_demo = "8068472b-b45e-4be3-a6a4-32433ea44b46"

# Observability
log_retention_days = 30
alert_email_addresses = [
  "admin@interviewcorp.com",
  "oncall@interviewcorp.com"
]

# Cosmos DB
cosmosdb_consistency_level = "Session"

# AI Readiness
openai_quota_tokens_per_month = 500000000