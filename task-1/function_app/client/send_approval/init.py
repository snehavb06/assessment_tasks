import azure.functions as func
import azure.durable_functions as df
import logging
import json

async def main(req: func.HttpRequest, starter: str) -> func.HttpResponse:
    """
    HTTP client function to send approval decision to an orchestration
    """
    # Get instance ID from route
    instance_id = req.route_params.get('instanceId')
    
    if not instance_id:
        return func.HttpResponse(
            json.dumps({"error": "Instance ID is required"}),
            status_code=400,
            mimetype="application/json"
        )
    
    # Get request body
    try:
        req_body = req.get_json()
    except ValueError:
        return func.HttpResponse(
            json.dumps({"error": "Invalid request body"}),
            status_code=400,
            mimetype="application/json"
        )
    
    # Validate approval data
    if 'approved' not in req_body:
        return func.HttpResponse(
            json.dumps({"error": "Approval decision (approved) is required"}),
            status_code=400,
            mimetype="application/json"
        )
    
    # Prepare approval event
    approval_data = {
        "approved": req_body.get('approved', False),
        "reviewer": req_body.get('reviewer', req.headers.get('X-User-ID', 'unknown')),
        "comments": req_body.get('comments', ''),
        "timestamp": req.headers.get('Date', '')
    }
    
    # Create orchestration client
    client = df.DurableOrchestrationClient(starter)
    
    try:
        # Raise approval event to orchestration
        await client.raise_event(
            instance_id,
            "ApprovalDecision",
            approval_data
        )
        
        logging.info(f"Approval sent to instance: {instance_id}")
        
        return func.HttpResponse(
            json.dumps({
                "status": "success",
                "message": "Approval decision sent",
                "instance_id": instance_id
            }),
            status_code=200,
            mimetype="application/json"
        )
        
    except Exception as e:
        logging.error(f"Failed to send approval: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            mimetype="application/json"
        )