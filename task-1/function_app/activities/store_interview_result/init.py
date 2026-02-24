import azure.functions as func
import logging
import json
import uuid
import os
from azure.cosmos import CosmosClient
from datetime import datetime

def main(result_data: dict) -> dict:
    """
    Store interview result in Cosmos DB
    Idempotent operation - uses interview_id as document ID
    """
    logging.info(f"Storing interview result")
    
    # Get Cosmos DB connection
    cosmos_connection = os.environ["CosmosDBConnection"]
    database_name = os.environ["CosmosDBDatabaseName"]
    container_name = os.environ["CosmosDBContainerName"]
    
    # Connect to Cosmos DB
    client = CosmosClient.from_connection_string(cosmos_connection)
    database = client.get_database_client(database_name)
    container = database.get_container_client(container_name)
    
    # Prepare document
    interview_id = result_data.get('interview_id', str(uuid.uuid4()))
    
    document = {
        "id": interview_id,
        "interview_id": interview_id,
        "timestamp": datetime.utcnow().isoformat(),
        "workflow_instance": result_data.get('workflow_instance'),
        "status": result_data.get('status', 'completed'),
        "result": result_data.get('result', {}),
        "error": result_data.get('error'),
        "custom_status": result_data.get('custom_status', {})
    }
    
    # Remove None values
    document = {k: v for k, v in document.items() if v is not None}
    
    # Upsert document (idempotent operation)
    try:
        # Try to read existing document
        existing = container.read_item(item=interview_id, partition_key=interview_id)
        # Update existing
        existing.update(document)
        result = container.upsert_item(existing)
        logging.info(f"Updated existing document: {interview_id}")
    except:
        # Create new
        result = container.create_item(document)
        logging.info(f"Created new document: {interview_id}")
    
    return {
        "id": result['id'],
        "status": "stored"
    }