"""
Complete AI DevOps Deployment Analysis

Runs comprehensive analysis after deployment:
1. Checks deployment health
2. Analyzes CloudWatch logs
3. Determines if rollback is needed
4. Suggests optimal replica count
"""

import os
import sys
import subprocess
import json
from datetime import datetime

try:
    from log_analyzer import fetch_cloudwatch_logs, analyze_logs_with_ai, should_rollback
    from replica_suggester import get_current_metrics, suggest_replica_count
except ImportError:
    print("Warning: AI DevOps modules not found. Install dependencies first.")
    sys.exit(0)


def check_deployment_health(namespace: str = "ideas-api", deployment_name: str = "ideas-api") -> dict:
    """
    Check if deployment is healthy.
    
    Returns:
        Dictionary with health status
    """
    try:
        result = subprocess.run(
            ["kubectl", "get", "deployment", deployment_name, "-n", namespace, "-o", "json"],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            deployment = json.loads(result.stdout)
            status = deployment.get("status", {})
            
            ready = status.get("readyReplicas", 0)
            total = status.get("replicas", 0)
            
            return {
                "healthy": ready == total and ready > 0,
                "ready_replicas": ready,
                "replicas": total
            }
    except Exception as e:
        print(f"Error checking deployment: {str(e)}")
    
    return {"healthy": False, "ready_replicas": 0, "replicas": 0}


def main():
    """Main analysis function"""
    print("=" * 60)
    print("AI DevOps Deployment Analysis")
    print("=" * 60)
    print(f"Timestamp: {datetime.now().isoformat()}\n")
    
    # Get configuration from environment
    namespace = os.getenv("KUBERNETES_NAMESPACE", "ideas-api")
    log_group = os.getenv("CLOUDWATCH_LOG_GROUP", "/aws/eks/ideas-api-dev/cluster")
    api_key = os.getenv("OPENAI_API_KEY")
    
    # 1. Check deployment health
    print("1. Checking deployment health...")
    health = check_deployment_health(namespace)
    if health.get("healthy"):
        print(f"   Status: Healthy")
    else:
        print(f"   Status: Unhealthy")
    print(f"   Replicas: {health.get('ready_replicas', 0)}/{health.get('replicas', 0)} ready\n")
    
    # 2. Analyze logs (if API key available)
    if api_key:
        print("2. Analyzing CloudWatch logs...")
        logs = fetch_cloudwatch_logs(log_group, hours_back=1)
        if logs:
            analysis = analyze_logs_with_ai(logs, api_key)
            if "error" not in analysis:
                severity = analysis.get("severity", "UNKNOWN")
                errors = analysis.get("errors", [])
                warnings = analysis.get("warnings", [])
                
                print(f"   Severity: {severity}")
                print(f"   Errors: {len(errors)}")
                print(f"   Warnings: {len(warnings)}")
                
                rollback = should_rollback(analysis)
                print(f"   Rollback Recommended: {'YES' if rollback else 'NO'}")
                
                if rollback:
                    print("\n   WARNING: Rollback recommended!")
            else:
                print(f"   Error: {analysis.get('error')}")
        else:
            print("   No logs found (this is normal for new deployments)\n")
    else:
        print("2. Skipping log analysis (OPENAI_API_KEY not set)\n")
    
    # 3. Suggest replica count
    if api_key:
        print("3. Analyzing replica count...")
        metrics = get_current_metrics(namespace=namespace)
        suggestion = suggest_replica_count(metrics, api_key=api_key)
        
        if "error" not in suggestion:
            current = metrics.get("replicas", 0)
            suggested = suggestion.get("suggested_replicas", current)
            reason = suggestion.get("reason", "No reason provided")
            confidence = suggestion.get("confidence", "UNKNOWN")
            
            print(f"   Current: {current} replicas")
            print(f"   Suggested: {suggested} replicas")
            print(f"   Confidence: {confidence}")
            print(f"   Reason: {reason}")
        else:
            print(f"   Error: {suggestion.get('error')}")
        print()
    
    print("Analysis complete")
    
    # Exit with error code if unhealthy
    if not health.get("healthy"):
        sys.exit(1)
    
    sys.exit(0)


if __name__ == "__main__":
    main()
