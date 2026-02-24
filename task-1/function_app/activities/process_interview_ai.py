import azure.functions as func
import logging
import json
import random
import time

def main(interview_data: dict) -> dict:
    """
    AI Processing activity - idempotent by design
    Uses interview_id to ensure same input produces same output
    """
    logging.info(f"Processing AI for interview: {interview_data.get('interview_id')}")
    
    # Simulate AI processing with potential transient failures
    # This demonstrates the need for retry logic
    interview_id = interview_data.get('interview_id')
    
    # Deterministic processing based on interview_id (for idempotency)
    random.seed(interview_id)
    
    # Simulate occasional failure (10% of the time)
    if random.random() < 0.1:
        raise Exception("Transient AI processing failure - retryable")
    
    # Simulate processing time
    time.sleep(2)
    
    # Mock AI response
    return {
        "interview_id": interview_id,
        "score": random.randint(60, 100),
        "sentiment": random.choice(["positive", "neutral", "negative"]),
        "key_points": [
            "Communication skills: strong",
            "Technical knowledge: demonstrated",
            "Cultural fit: aligned"
        ],
        "recommendation": random.choice(["advance", "review", "reject"]),
        "processing_timestamp": time.time()
    }