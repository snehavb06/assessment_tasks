import azure.functions as func
import logging
import json
import time
from datetime import datetime

def main(interview_data: dict) -> dict:
    """
    Finalize interview activity
    Processes approved interviews and generates final output
    """
    logging.info(f"Finalizing interview: {interview_data.get('interview_id')}")
    
    interview_id = interview_data.get('interview_id')
    ai_result = interview_data.get('ai_result', {})
    approval = interview_data.get('approval', {})
    
    # Simulate processing
    time.sleep(1)
    
    # Generate final result
    final_result = {
        "interview_id": interview_id,
        "status": "approved",
        "ai_score": ai_result.get('score'),
        "ai_sentiment": ai_result.get('sentiment'),
        "ai_recommendation": ai_result.get('recommendation'),
        "reviewer": approval.get('reviewer', 'system'),
        "reviewer_comments": approval.get('comments', ''),
        "final_decision": "proceed" if ai_result.get('score', 0) > 70 else "review",
        "processed_timestamp": datetime.utcnow().isoformat(),
        "version": "1.0"
    }
    
    logging.info(f"Interview finalized: {interview_id}")
    
    return final_result