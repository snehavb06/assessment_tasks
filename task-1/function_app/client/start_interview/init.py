import azure.functions as func
import azure.durable_functions as df
import logging
import json
import uuid

async def main(req: func.HttpRequest, starter: str) -> func.HttpResponse:
    """
    HTTP client function to start a new interview orchestration
    """
    logging.info('Starting new interview workflow')
    
    # Get request body
    try:
        req_body = req.get_json()
    except ValueError:
        req_body = {}
    
    # Generate interview ID if not provided
    interview_id = req_body.get('interview_id', str(uuid.uuid4()))
    
    # Prepare input data
    instance_id = f"interview-{interview_id}-{uuid.uuid4().hex[:8]}"
    
    function_input = {
        "interview_id": interview_id,
        "candidate_name": req_body.get('candidate_name', 'Unknown'),
        "interview_data": req_body.get('interview_data', {}),
        "initiated_by": req.headers.get('X-User-ID', 'system'),
        "initiated_at": req.headers.get('Date', '')
    }
    
    # Create orchestration client
    client = df.DurableOrchestrationClient(starter)
    
    # Start new orchestration
    instance = await client.start_new(
        "orchestrator_function",
        instance_id,
        function_input
    )
    
    logging.info(f"Started orchestration with ID: {instance}")
    
    # Return response with status check URL
    response = {
        "instance_id": instance,
        "interview_id": interview_id,
        "status_query_uri": f"/api/status/{instance}",
        "send_approval_uri": f"/api/send-approval/{instance}",
        "message": "Interview workflow started successfully"
    }
    
    return func.HttpResponse(
        json.dumps(response),
        status_code=202,
        mimetype="application/json",
        headers={
            "Location": f"/api/status/{instance}",
            "Content-Type": "application/json"
        }
    )