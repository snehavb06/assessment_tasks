# test-2

**Structural Diagr**

Exterview-assessment/
├── terraform/
│   ├── main.tf                 # Core resources
│   ├── variables.tf             # Variables
│   ├── outputs.tf               # Outputs
│   ├── versions.tf              # Provider versions
│   ├── terraform.tfvars.example # Example variables
│   └── modules/
│       ├── durable-function/     # Task 1
│       ├── apim/                 # Task 2  
│       ├── signalr/              # Task 3
│       ├── governance/           # Task 4
│       └── observability/        # Task 5
├── task-1/
│   ├── function_app/
│   │   ├── orchestrator/
│   │   ├── activities/
│   │   └── client/
│   └── requirements.txt
├── task-2/
│   └── policies/                 # APIM policy XML files
├── task-3/
│   └── signalr-negotiate/
├── task-4/
│   └── policies/                 # Azure Policy definitions
├── task-5/
│   └── kql-queries/              # Saved KQL queries
├── task-6/
│   └── design-diagrams/
└── README.md

 **** Architecture Overview Task-1****
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   HTTP      │────▶│  Orchestrator │────▶│     AI      │
│   Client    │     │   Function    │     │  Processing │
└─────────────┘     └──────────────┘     └─────────────┘
                           │                      │
                           ▼                      ▼
                    ┌──────────────┐     ┌─────────────┐
                    │    Human     │     │   Cosmos    │
                    │   Approval   │────▶│     DB      │
                    └──────────────┘     └─────────────┘

**Summary of Task-1**
1. when some clicks start interview in app then function recives InterviewID,Name. Then function will create new workflow uniqueID.
2. From that Ai id, Ai processing workflow automatically calls AI services.  AI analyzes candiodate and return source.
3. Human approval, workflow pause and waits, email sent to HR, plaese revies candidate, manager clicks approve or reject.
4. Everything will be save to CosMosDb.

****** Architecture Overview Task-2******
                   🌐 INTERNET 🌐
                          │
                          ▼
              ┌─────────────────────┐
              │   SECURITY GUARD    │ ←── APIM (Task 2)
              │   (API Management)  │
              └─────────────────────┘
          ┌───────────┼───────────┐
          ▼           ▼           ▼
    ┌─────────┐ ┌─────────┐ ┌─────────┐
    │Function │ │Function │ │Function │
    │   App   │ │   App   │ │   App   │ ←── Your code (Task 1)
    └─────────┘ └─────────┘ └─────────┘


Summary
1.User tries to call your API. then Shows their ID card (JWT Token)
2. APIM checks: Is this ID card real?, Is it expired? VALID → Let them in.
3.Only people with valid login tokens from your company can use the API.
4. Function processes request

* Architecture Overview Task-3*
Interview #123 ───▶ SignalR ───▶ Browser 1 (Hiring Manager)
                    └───▶ Browser 2 (Recruiter)
                    └───▶ Browser 3 (Candidate)

1. User opens interview dashboard, Browser connects to SignalR
        "Hi, I'm watching interview #123"
Server remembers this connection
        ↓
When interview status changes:
        Server: "Hey everyone watching #123 - status updated!"
        ↓
Step 5: All connected browsers update instantly

1.One message reaches many viewers

**Task-4**
1.Azure management groups to organize resources like folders.
2.RBAC to control who can access what.
3.Azure Policies to automatically enforce rules like 'no public storage accounts' and 'every resource must have Environment, CostCenter, and Owner tags'.


Tenant Root Group (e05455be...)
├── InterviewCorp (Your company)
│   └── InterviewLandingZones
│       ├── mg-ext-apps-dev    (Applications)
│       └── mg-ext-sandbox-dev  (Testing)
└── InterviewPlatform
    └── mg-ext-platform-dev     (Infrastructure)

**Task 5: Observability**
Application Insights and Log Analytics to collect logs and metrics, creates KQL queries to track function errors and orchestration status, 
configures alerts to notify when error rates exceed thresholds, 
and builds a dashboard for real-time visualization of the entire interview workflow."

**Task-6**
so the task 4, can be done in various way but we can do this by 
The Azure AI Landing Zone (ALZ) is Microsoft's enterprise-scale reference architecture for deploying secure, resilient AI workloads .
Think of it as a pre-built, battle-tested blueprint that solves all the complex infrastructure challenges of running AI in production.
****1.Using ALZ approach:****
1.Deploy OpenAI in the AI Services Landing Zone subscription.
2.Use separate deployments for GPT-4 (complex) and Embeddings (search).
3.Enable Managed Identity instead of API keys.
4.Apply Azure Policy to enforce private endpoints only

**2. Private Endpoint Setup**
VNet in AI Services Zone
└── Private Endpoint for OpenAI
    ├── Private IP: 10.x.x.x
    └── Private DNS Zone: privatelink.openai.azure.com
└── Network Security Groups restrict all outbound except to hub firewall
Steps:
1. Create a private endpoint for Azure OpenAI in the AI Services VNet, 
2. assign it a private IP, and configure private DNS so your function app connects securely without traversing the public internet.
3.Using Vnet peering

4.Configure Azure's default content filters for hate, sexual, violence, and self-harm categories at Medium severity, add custom blocklists for company-specific terms, and enforce these settings via Azure Policy so developers cannot weaken them.
