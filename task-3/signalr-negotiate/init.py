import azure.functions as func
import logging
import json
import os
import uuid
from azure.signalr import SignalRService
import hmac
import hashlib
import base64
import time

def generate_jwt(connection_string, user_id, interview_id):
    """
    Generate JWT token for SignalR connection
    """
    # Parse connection string
    parts = dict(item.split('=', 1) for item in connection_string.split(';') if '=' in item)
    endpoint = parts.get('Endpoint', '').replace('https://', '').replace('/', '')
    access_key = parts.get('AccessKey', '')
    
    # Create JWT token
    audience = f"https://{endpoint}/client/?hub=interview"
    
    # Token claims
    claims = {
        'aud': audience,
        'exp': int(time.time()) + 3600,  # 1 hour
        'userId': user_id,
        'interviewId': interview_id
    }
    
    # Create JWT (simplified - in production use a proper JWT library)
    header = base64.urlsafe_b6464encode(json.dumps({'alg': 'HS256', 'typ': 'JWT'}).encode()).decode().rstrip('=')
    payload = base64.urlsafe_b6464encode(json.dumps(claims).encode()).decode().rstrip('=')
    
    signature = hmac.new(
        access_key.encode(),
        f"{header}.{payload}".encode(),
        hashlib.sha256
    ).digest()
    signature = base64.urlsafe_b6464encode(signature).decode().rstrip('=')
    
    return f"{header}.{payload}.{signature}"

def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    SignalR negotiation endpoint
    Returns connection information for clients
    """
    logging.info('Processing SignalR negotiation request')
    
    # Get connection string from environment
    connection_string = os.environ.get('AzureSignalRConnectionString')
    if not connection_string:
        logging.error('SignalR connection string not found')
        return func.HttpResponse(
            json.dumps({'error': 'SignalR not configured'}),
            status_code=500,
            mimetype='application/json'
        )
    
    # Extract user info from headers or query params
    user_id = req.headers.get('X-User-ID', 
               req.params.get('user_id', 
               f"user-{uuid.uuid4().hex[:8]}"))
    
    interview_id = req.params.get('interviewId', 'general')
    
    # Generate connection URL with access token
    # For simplicity, we're returning the full connection info
    # In production, use proper token generation
    
    # Parse connection string to get endpoint
    parts = dict(item.split('=', 1) for item in connection_string.split(';') if '=' in item)
    endpoint = parts.get('Endpoint', '').replace('https://', '').replace('/', '')
    
    # Generate access token (simplified - use proper method)
    access_token = generate_jwt(connection_string, user_id, interview_id)
    
    # Construct connection info
    connection_info = {
        'url': f"https://{endpoint}/client/?hub=interview",
        'accessToken': access_token,
        'userId': user_id
    }
    
    logging.info(f'Negotiation successful for user: {user_id}')
    
    return func.HttpResponse(
        json.dumps(connection_info),
        status_code=200,
        mimetype='application/json',
        headers={
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, X-User-ID'
        }
    )