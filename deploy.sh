#!/bin/bash
# Complete Deployment Script
# This script handles the entire deployment process from infrastructure to application

set -e  # Exit on error

# Configuration
ENVIRONMENT=${1:-dev}
REGION=${AWS_REGION:-us-east-1}

echo "Starting Deployment for Environment: ${ENVIRONMENT}"
echo "=================================================="

# Step 1: Check prerequisites
echo ""
echo "Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "Error: terraform not found"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl not found"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Error: docker not found"; exit 1; }

# Check AWS credentials
aws sts get-caller-identity >/dev/null 2>&1 || { echo "Error: AWS credentials not configured"; exit 1; }

echo "Prerequisites check passed"

# Step 2: Setup Terraform backend (S3 bucket and DynamoDB table)
echo ""
echo "Setting up Terraform backend..."
cd infra

# Check if S3 bucket exists
BUCKET_NAME="task-28-01-2026"
if ! aws s3 ls "s3://${BUCKET_NAME}" 2>/dev/null; then
    echo "Creating S3 bucket for Terraform state..."
    aws s3 mb "s3://${BUCKET_NAME}" --region ${REGION} || true
    aws s3api put-bucket-versioning --bucket ${BUCKET_NAME} --versioning-configuration Status=Enabled
fi

# Check if DynamoDB table exists
TABLE_NAME="terraform-state-lock"
if ! aws dynamodb describe-table --table-name ${TABLE_NAME} --region ${REGION} 2>/dev/null; then
    echo "Creating DynamoDB table for state locking..."
    aws dynamodb create-table \
        --table-name ${TABLE_NAME} \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region ${REGION} || true
    echo "Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name ${TABLE_NAME} --region ${REGION} || true
fi

# Step 3: Initialize and apply Terraform
echo ""
echo "Deploying infrastructure with Terraform..."
terraform init
terraform plan -var-file=envs/${ENVIRONMENT}/terraform.tfvars
echo ""
read -p "Apply Terraform changes? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled"
    exit 1
fi
terraform apply -auto-approve -var-file=envs/${ENVIRONMENT}/terraform.tfvars

# Get outputs
ECR_URL=$(terraform output -raw ecr_repository_url)
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)

echo "Infrastructure deployed"

# Step 4: Configure kubectl
echo ""
echo "Configuring kubectl..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}
echo "kubectl configured"

# Step 5: Install ALB Controller (if not already installed)
echo ""
echo "Checking ALB Controller..."
if ! kubectl get deployment aws-load-balancer-controller -n kube-system 2>/dev/null; then
    echo "Installing AWS Load Balancer Controller..."
    
    # Add EKS Helm repo
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    # Get cluster OIDC issuer URL
    OIDC_ID=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # Create OIDC provider if it doesn't exist
    aws iam list-open-id-connect-providers | grep -q ${OIDC_ID} || \
    aws iam create-open-id-connect-provider \
        --url https://oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID} \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 9e99a48a9960b14926bb07f369076415ea2fe59 || true
    
    # Create IAM policy for ALB controller
    curl -s -o /tmp/alb-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json
    
    # Create IAM role for ALB controller
    POLICY_ARN=$(aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy-${ENVIRONMENT} \
        --policy-document file:///tmp/alb-policy.json \
        --query 'Policy.Arn' --output text 2>/dev/null || \
        aws iam get-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy-${ENVIRONMENT}" \
        --query 'Policy.Arn' --output text)
    
    # Install ALB controller via Helm
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=${CLUSTER_NAME} \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::${ACCOUNT_ID}:role/${CLUSTER_NAME}-alb-controller-role \
        --wait || true
    
    echo "ALB Controller installed"
else
    echo "ALB Controller already installed"
fi

# Step 6: Build and push Docker image
echo ""
echo "Building and pushing Docker image..."
cd ..

# Login to ECR
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_URL}

# Build image
IMAGE_TAG="${ECR_URL}:latest"
docker build -t ${IMAGE_TAG} .

# Push image
docker push ${IMAGE_TAG}
echo "Docker image pushed"

# Step 7: Deploy to Kubernetes
echo ""
echo "Deploying to Kubernetes..."

# Replace ECR URL in deployment.yaml
sed "s|ECR_REPOSITORY_URL|${ECR_URL}|g" k8s/deployment.yaml > k8s/deployment-temp.yaml
mv k8s/deployment-temp.yaml k8s/deployment.yaml

# Apply Kubernetes manifests
kubectl apply -f k8s/namespace.yaml
sleep 2  # Wait for namespace to be ready
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml

# Wait for deployment
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/ideas-api -n ideas-api --timeout=300s

echo "Deployment complete!"

# Step 8: Display status
echo ""
echo "Deployment Status:"
echo "===================="
kubectl get pods -n ideas-api
kubectl get svc -n ideas-api
kubectl get ingress -n ideas-api

echo ""
echo "ALB is being provisioned. This may take 2-5 minutes."
echo "Check status with: kubectl get ingress -n ideas-api"
echo ""
echo "Deployment script completed successfully!"
