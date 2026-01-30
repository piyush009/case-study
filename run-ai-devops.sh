#!/bin/bash
# AI DevOps Analysis Script

set -e
echo "Running AI DevOps Analysis"

# Check if OpenAI API key is set
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Get your key from: https://platform.openai.com/api-keys"
    read -p "Enter OpenAI API key: " api_key
    export OPENAI_API_KEY="$api_key"
fi

# Setup virtual environment if needed
cd ai-devops

if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    deactivate
fi

# Set defaults
export KUBERNETES_NAMESPACE=${KUBERNETES_NAMESPACE:-ideas-api}
export CLOUDWATCH_LOG_GROUP=${CLOUDWATCH_LOG_GROUP:-/aws/eks/ideas-api-dev/cluster}

# Run analysis
echo "Running deployment analysis..."
source venv/bin/activate
python3 analyze_deployment.py
deactivate

cd ..

echo "Analysis complete!"
