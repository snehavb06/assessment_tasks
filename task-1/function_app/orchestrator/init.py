import azure.functions as func
import azure.durable_functions as df
import logging
import json
from datetime import timedelta
import asyncio

# Orchestrator Function
def orchestrator_function(context: df.DurableOrchestrationContext):
    """
    Interview workflow orchestrator with human approval step
    Demonstrates replay behavior, external events, and error handling
    """
    interview_data = context.get_input()
    instance_id = context.instance_id
    
    logging.info(f"Orchestrator started for interview: {interview_data.get('interview_id')}")
    
    try:
        # Step 1: AI Processing with retry configuration
        retry_options = df.RetryOptions(
            first_retry_interval_in_milliseconds=5000,
            max_number_of_attempts=3,
            backoff_coefficient=2
        )
        
        ai_result = yield context.call_activity_with_retry(
            "process_interview_ai",
            retry_options,
            interview_data
        )
        
        # Store intermediate state in context (demonstrates replay)
        context.set_custom_status({
            "step": "ai_processing_complete",
            "interview_id": interview_data.get('interview_id'),
            "ai_score": ai_result.get('score')
        })
        
        # Step 2: Human Review - Wait for external event
        # Idempotency: Check if already approved in previous replay
        approval_event = context.get_input("approval_result")
        if not approval_event:
            # Wait up to 24 hours for approval
            approval_task = context.wait_for_external_event("ApprovalDecision")
            timeout_task = context.create_timer(context.current_utc_datetime + timedelta(hours=24))
            
            winner = yield context.task_any([approval_task, timeout_task])
            
            if winner == timeout_task:
                # Timeout occurred
                approval_result = {
                    "approved": False,
                    "reason": "timeout",
                    "reviewer": "system"
                }
            else:
                approval_result = yield approval_task
        else:
            approval_result = approval_event
        
        context.set_custom_status({
            "step": "human_review_complete",
            "approved": approval_result.get('approved', False)
        })
        
        # Step 3: Final Processing
        if approval_result.get('approved', False):
            final_result = yield context.call_activity(
                "finalize_interview",
                {
                    "interview_id": interview_data.get('interview_id'),
                    "ai_result": ai_result,
                    "approval": approval_result
                }
            )
        else:
            final_result = {
                "status": "rejected",
                "reason": approval_result.get('reason', 'no_approval'),
                "interview_id": interview_data.get('interview_id')
            }
        
        # Step 4: Store in Cosmos DB (idempotent operation)
        storage_result = yield context.call_activity(
            "store_interview_result",
            {
                "interview_id": interview_data.get('interview_id'),
                "result": final_result,
                "workflow_instance": instance_id,
                "custom_status": context.get_custom_status()
            }
        )
        
        return {
            "instance_id": instance_id,
            "status": "completed",
            "final_result": final_result,
            "storage_id": storage_result.get('id')
        }
        
    except Exception as e:
        logging.error(f"Orchestration failed: {str(e)}")
        context.set_custom_status({
            "step": "failed",
            "error": str(e),
            "interview_id": interview_data.get('interview_id')
        })
        
        # Store failure in Cosmos DB for idempotent tracking
        failure_result = yield context.call_activity(
            "store_interview_result",
            {
                "interview_id": interview_data.get('interview_id'),
                "error": str(e),
                "workflow_instance": instance_id,
                "status": "failed"
            }
        )
        raise

main = df.Orchestrator.create(orchestrator_function)