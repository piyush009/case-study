"""
AI-Powered Replica Count Suggester

Suggests optimal replica count based on:
- Current metrics
- Traffic patterns
- Resource utilization
"""

import os
import subprocess
import json

try:
    import openai
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False
    print("Warning: OpenAI not installed. Install with: pip install openai")


def get_current_metrics(deployment_name: str = "ideas-api", namespace: str = "ideas-api") -> dict:
    """
    Get current deployment metrics from Kubernetes.
    
    Args:
        deployment_name: Name of the deployment
        namespace: Kubernetes namespace
    
    Returns:
        Dictionary with current metrics
    """
    try:
        # Get deployment info
        result = subprocess.run(
            ["kubectl", "get", "deployment", deployment_name, "-n", namespace, "-o", "json"],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            deployment = json.loads(result.stdout)
            status = deployment.get("status", {})
            
            return {
                "replicas": status.get("replicas", 0),
                "ready_replicas": status.get("readyReplicas", 0),
                "available_replicas": status.get("availableReplicas", 0)
            }
    except Exception as e:
        print(f"Error getting metrics: {str(e)}")
    
    return {"replicas": 0, "ready_replicas": 0, "available_replicas": 0}


def suggest_replica_count(metrics: dict, traffic_pattern: str = "normal", api_key: str = None) -> dict:
    """
    Get AI suggestion for optimal replica count.
    
    Args:
        metrics: Current deployment metrics
        traffic_pattern: Traffic pattern (low, normal, high, spike)
        api_key: OpenAI API key (optional)
    
    Returns:
        Dictionary with suggestion and reasoning
    """
    if not OPENAI_AVAILABLE:
        return {"error": "OpenAI not available"}
    
    if not api_key:
        api_key = os.getenv("OPENAI_API_KEY")
    
    if not api_key:
        return {"error": "OPENAI_API_KEY not set"}
    
    openai.api_key = api_key
    
    try:
        prompt = f"""Based on these Kubernetes deployment metrics, suggest optimal replica count:

Current replicas: {metrics.get('replicas', 0)}
Ready replicas: {metrics.get('ready_replicas', 0)}
Traffic pattern: {traffic_pattern}

Consider:
- High availability (minimum 2 replicas)
- Cost optimization
- Traffic patterns
- Resource utilization

Return JSON with keys: suggested_replicas (number), reason (string), confidence (LOW/MEDIUM/HIGH)"""

        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a Kubernetes expert. Return JSON only."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=200,
            temperature=0.3
        )
        
        import json
        result = json.loads(response.choices[0].message.content)
        return result
    except Exception as e:
        return {"error": f"Suggestion failed: {str(e)}"}


if __name__ == "__main__":
    # Example usage
    metrics = get_current_metrics()
    suggestion = suggest_replica_count(metrics, traffic_pattern="normal")
    print("Current metrics:", metrics)
    print("Suggestion:", suggestion)
