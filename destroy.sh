#!/bin/bash
# Complete Infrastructure Destruction Script
# This script destroys all infrastructure created by deploy.sh

set -e

# Configuration
ENVIRONMENT=${1:-dev}

echo "Destroying Infrastructure for Environment: ${ENVIRONMENT}"
echo "=================================================="

# Confirmation
echo ""
echo "WARNING: This will destroy ALL infrastructure!"
echo "This includes:"
echo "  - EKS cluster and node groups"
echo "  - VPC, subnets, NAT gateways"
echo "  - ECR repository (all images will be deleted)"
echo "  - IAM roles and policies"
echo "  - CloudWatch log groups"
echo "  - ALB (via Ingress deletion)"
echo ""
read -p "Type 'yes' to confirm destruction: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Destruction cancelled"
    exit 0
fi

# Step 1: Delete Kubernetes resources
echo ""
echo "Deleting Kubernetes resources..."
if kubectl get namespace ideas-api 2>/dev/null; then
    # Delete ingress first to remove ALB (this takes time)
    echo "Deleting Ingress (this will delete the ALB, may take 2-5 minutes)..."
    kubectl delete ingress ideas-api-ingress -n ideas-api --ignore-not-found=true
    
    # Wait for ALB to be deleted (check every 10 seconds, max 5 minutes)
    echo "Waiting for ALB to be deleted..."
    for i in {1..30}; do
        if ! kubectl get ingress ideas-api-ingress -n ideas-api 2>/dev/null; then
            # Check if ALB still exists in AWS
            ALB_EXISTS=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-ideasapi`)].LoadBalancerName' --output text 2>/dev/null || echo "")
            if [ -z "$ALB_EXISTS" ]; then
                echo "ALB deleted"
                break
            fi
        fi
        sleep 10
        echo "  Waiting... ($i/30)"
    done
    
    # Delete other resources
    kubectl delete hpa ideas-api-hpa -n ideas-api --ignore-not-found=true
    kubectl delete deployment ideas-api -n ideas-api --ignore-not-found=true
    kubectl delete service ideas-api-service -n ideas-api --ignore-not-found=true
    kubectl delete configmap ideas-api-config -n ideas-api --ignore-not-found=true
    kubectl delete namespace ideas-api --ignore-not-found=true
    echo "Kubernetes resources deleted"
else
    echo "No Kubernetes resources found"
fi

# Step 2: Uninstall ALB Controller
echo ""
echo "Uninstalling ALB Controller..."
if kubectl get deployment aws-load-balancer-controller -n kube-system 2>/dev/null; then
    helm uninstall aws-load-balancer-controller -n kube-system --ignore-not-found=true || true
    echo "ALB Controller uninstalled"
else
    echo "ALB Controller not found"
fi

# Step 3: Delete ECR images before destroying repository
echo ""
echo "Cleaning up ECR repository..."
ECR_REPO="ideas-api-${ENVIRONMENT}"
REGION=${AWS_REGION:-us-east-1}

# Check if ECR repository exists and has images
if aws ecr describe-repositories --repository-names ${ECR_REPO} --region ${REGION} 2>/dev/null; then
    echo "Deleting all images from ECR repository..."
    # Get all image tags
    IMAGE_TAGS=$(aws ecr list-images --repository-name ${ECR_REPO} --region ${REGION} --query 'imageIds[*]' --output json 2>/dev/null || echo "[]")
    
    if [ "$IMAGE_TAGS" != "[]" ] && [ -n "$IMAGE_TAGS" ]; then
        # Delete all images
        aws ecr batch-delete-image \
            --repository-name ${ECR_REPO} \
            --region ${REGION} \
            --image-ids "$IMAGE_TAGS" \
            --output text 2>/dev/null || true
        echo "ECR images deleted"
    else
        echo "No images found in ECR repository"
    fi
else
    echo "ECR repository not found"
fi

# Step 4: Destroy Terraform infrastructure
echo ""
echo "Destroying Terraform infrastructure..."
cd infra

# Initialize if needed
terraform init -backend-config="bucket=task-28-01-2026" -backend-config="key=devops-case-study/terraform.tfstate" -backend-config="region=us-east-1" -backend-config="dynamodb_table=terraform-state-lock" || true

# Destroy infrastructure
# Note: This may take 10-15 minutes as it waits for dependencies to be released
echo "Destroying infrastructure (this may take 10-15 minutes)..."
terraform destroy -auto-approve -var-file=envs/${ENVIRONMENT}/terraform.tfvars

# If destroy fails due to dependencies, provide manual cleanup instructions
if [ $? -ne 0 ]; then
    echo ""
    echo "Some resources may still have dependencies"
    echo "If you see errors about:"
    echo "  - ECR repository not empty: Images were deleted, but repository may need force delete"
    echo "  - Subnet dependencies: Wait a few minutes and run destroy again"
    echo "  - Internet Gateway dependencies: NAT gateways need to be fully deleted first"
    echo ""
    echo "You can try running destroy again in a few minutes:"
    echo "  ./destroy.sh ${ENVIRONMENT}"
fi

echo "Infrastructure destruction completed"

# Step 4: Optional cleanup of backend resources
echo ""
echo "Note: S3 bucket and DynamoDB table are preserved for future use"
echo "To delete them manually:"
echo "  aws s3 rb s3://task-28-01-2026 --force"
echo "  aws dynamodb delete-table --table-name terraform-state-lock --region us-east-1"

echo ""
echo "Destruction complete!"
