# test-workflow.ps1
param(
    [string]$FunctionUrl = "https://func-ext-durable-dev-2311.azurewebsites.net"
)

Write-Host "Testing Durable Function Interview Workflow" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

# Step 1: Start interview
Write-Host "`n1. Starting interview workflow..." -ForegroundColor Yellow
$interviewId = "test-$(Get-Random -Maximum 9999)"
$body = @{
    interview_id = $interviewId
    candidate_name = "John Doe"
    interview_data = @{
        position = "Senior Developer"
        experience = 5
        skills = @("Azure", "Python", "Terraform")
    }
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$FunctionUrl/api/start-interview" `
        -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
    
    $instanceId = $response.instance_id
    Write-Host "✅ Started with Instance ID: $instanceId" -ForegroundColor Green
    Write-Host "   Interview ID: $($response.interview_id)"
} catch {
    Write-Host "❌ Failed to start workflow: $_" -ForegroundColor Red
    return
}

# Step 2: Check status after AI processing
Write-Host "`n2. Waiting for AI processing (10 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$status = Invoke-RestMethod -Uri "$FunctionUrl/api/status/$instanceId" -Method Get
Write-Host "   Status: $($status.runtimeStatus)" -ForegroundColor Cyan
Write-Host "   Step: $($status.customStatus.step)"

# Step 3: Send approval
Write-Host "`n3. Sending human approval..." -ForegroundColor Yellow
$approvalBody = @{
    approved = $true
    reviewer = "hiring-manager@company.com"
    comments = "Excellent candidate, proceed to next round"
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "$FunctionUrl/api/send-approval/$instanceId" `
        -Method Post -Body $approvalBody -ContentType "application/json" -ErrorAction Stop
    Write-Host "✅ Approval sent successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to send approval: $_" -ForegroundColor Red
}

# Step 4: Monitor until completion
Write-Host "`n4. Monitoring workflow completion..." -ForegroundColor Yellow
$maxAttempts = 12
$attempt = 0
do {
    Start-Sleep -Seconds 5
    $status = Invoke-RestMethod -Uri "$FunctionUrl/api/status/$instanceId" -Method Get
    Write-Host "   Status: $($status.runtimeStatus)" -ForegroundColor Cyan
    $attempt++
} while ($status.runtimeStatus -eq "Running" -and $attempt -lt $maxAttempts)

# Step 5: Show final result
if ($status.runtimeStatus -eq "Completed") {
    Write-Host "`n✅ Workflow completed successfully!" -ForegroundColor Green
    $status.output | ConvertTo-Json
} else {
    Write-Host "`n❌ Workflow did not complete: $($status.runtimeStatus)" -ForegroundColor Red
}

# Step 6: Check Cosmos DB
Write-Host "`n5. Verify data in Cosmos DB:" -ForegroundColor Yellow
Write-Host "   Go to Azure Portal → Cosmos DB account → Data Explorer"
Write-Host "   Check 'interviews' container for document with id: $interviewId"