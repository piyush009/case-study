"""
CloudWatch Log Analyzer with AI

Analyzes application logs from CloudWatch using AI to detect:
- Errors and exceptions
- Performance issues
- Warning patterns
- Security concerns
"""

import os
import boto3
from datetime import datetime, timedelta

try:
    import openai
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False
    print("Warning: OpenAI not installed. Install with: pip install openai boto3")


def fetch_cloudwatch_logs(log_group: str, hours_back: int = 1) -> str:
    """
    Fetch logs from CloudWatch Log Group.
    
    Args:
        log_group: CloudWatch log group name
        hours_back: How many hours back to fetch logs
    
    Returns:
        Combined log entries as string
    """
    try:
        logs_client = boto3.client('logs')
        
        # Calculate time range
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=hours_back)
        
        # Fetch log streams
        response = logs_client.filter_log_events(
            logGroupName=log_group,
            startTime=int(start_time.timestamp() * 1000),
            endTime=int(end_time.timestamp() * 1000),
            limit=1000  # Limit to prevent huge responses
        )
        
        # Combine log events
        log_entries = []
        for event in response.get('events', []):
            log_entries.append(event['message'])
        
        return '\n'.join(log_entries)
    except Exception as e:
        print(f"Error fetching logs: {str(e)}")
        return ""


def analyze_logs_with_ai(logs: str, api_key: str = None) -> dict:
    """
    Analyze logs using AI to detect issues and provide recommendations.
    
    Args:
        logs: Log entries as string
        api_key: OpenAI API key (optional)
    
    Returns:
        Dictionary with analysis results
    """
    if not OPENAI_AVAILABLE:
        return {"error": "OpenAI not available"}
    
    if not api_key:
        api_key = os.getenv("OPENAI_API_KEY")
    
    if not api_key:
        return {"error": "OPENAI_API_KEY not set"}
    
    if not logs:
        return {"error": "No logs to analyze"}
    
    openai.api_key = api_key
    
    try:
        prompt = f"""Analyze these application logs and provide:
1. List of errors (if any)
2. List of warnings (if any)
3. Severity level (LOW, MEDIUM, HIGH, CRITICAL)
4. Recommendations for fixing issues

Logs:
{logs[:5000]}  # Limit to prevent token overflow

Format response as JSON with keys: errors, warnings, severity, recommendations"""

        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a DevOps engineer analyzing application logs. Return JSON only."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=500,
            temperature=0.3
        )
        
        import json
        result = json.loads(response.choices[0].message.content)
        return result
    except Exception as e:
        return {"error": f"Analysis failed: {str(e)}"}


def should_rollback(analysis: dict) -> bool:
    """
    Determine if rollback is recommended based on log analysis.
    
    Args:
        analysis: Analysis result from analyze_logs_with_ai
    
    Returns:
        True if rollback is recommended
    """
    if "error" in analysis:
        return False
    
    severity = analysis.get("severity", "").upper()
    errors = analysis.get("errors", [])
    
    # Rollback if critical severity or multiple errors
    if severity == "CRITICAL":
        return True
    
    if severity == "HIGH" and len(errors) > 3:
        return True
    
    return False


if __name__ == "__main__":
    # Example usage
    log_group = "/aws/eks/ideas-api-dev/cluster"
    logs = fetch_cloudwatch_logs(log_group, hours_back=1)
    
    if logs:
        analysis = analyze_logs_with_ai(logs)
        print("Analysis:", analysis)
        print("Rollback recommended:", should_rollback(analysis))
    else:
        print("No logs found")
