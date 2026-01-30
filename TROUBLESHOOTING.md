# Troubleshooting Guide

This document contains all issues encountered during development and their solutions. This is valuable for understanding common pitfalls and how to resolve them.

## Table of Contents

1. [Terraform Issues](#terraform-issues)
2. [EKS Cluster Issues](#eks-cluster-issues)
3. [ALB Controller Issues](#alb-controller-issues)
4. [Docker Issues](#docker-issues)
5. [Kubernetes Issues](#kubernetes-issues)
6. [IAM Permission Issues](#iam-permission-issues)
7. [AI DevOps Issues](#ai-devops-issues)

---

## Terraform Issues

### Issue 1: S3 Bucket Does Not Exist

**Error:**
```
Error: Failed to get existing workspaces: S3 bucket does not exist.
Error: NoSuchBucket: The specified bucket does not exist
```

**Root Cause:**
Terraform backend requires S3 bucket to exist before initialization. The bucket must be created manually or via script.

**Solution:**
```bash
# Create S3 bucket manually
aws s3 mb s3://task-28-01-2026 --region us-east-1
aws s3api put-bucket-versioning --bucket task-28-01-2026 --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

**Prevention:**
The `deploy.sh` script now automatically checks and creates these resources if they don't exist.

---

### Issue 2: CloudWatch Log Group Already Exists

**Error:**
```
Error: creating CloudWatch Logs Log Group (...): ResourceAlreadyExistsException: 
The specified log group already exists
```

**Root Cause:**
CloudWatch log group was created manually or in a previous deployment, but Terraform doesn't know about it.

**Solution:**
```bash
# Import existing log group into Terraform state
cd infra
terraform import module.eks.aws_cloudwatch_log_group.eks_cluster "/aws/eks/ideas-api-dev/cluster"
```

**Prevention:**
The log group is now created before the EKS cluster in the Terraform configuration using `depends_on`.

---

### Issue 3: Terraform Apply Cancelled

**Error:**
```
Apply cancelled.
```

**Root Cause:**
Terraform prompts for confirmation, but no input was provided in automated scripts.

**Solution:**
```bash
# Use auto-approve flag
terraform apply -auto-approve -var-file=envs/dev/terraform.tfvars
```

**Prevention:**
All scripts now use `-auto-approve` flag for automated deployments.

---

### Issue 4: Module Not Installed

**Error:**
```
Error: Module not installed
Error: Backend initialization required, please run "terraform init"
```

**Root Cause:**
Terraform modules need to be downloaded and backend needs initialization before apply.

**Solution:**
```bash
cd infra
terraform init
terraform plan -var-file=envs/dev/terraform.tfvars
terraform apply -var-file=envs/dev/terraform.tfvars
```

**Prevention:**
Always run `terraform init` before any other Terraform commands.

---

## EKS Cluster Issues

### Issue 5: EKS Version 1.28 AMI Not Available

**Error:**
```
Error: InvalidParameterException: Requested AMI for this version 1.28 is not supported
Error: creating EKS Node Group: operation error EKS: CreateNodegroup
```

**Root Cause:**
EKS version 1.28 had AMI availability issues in certain regions. Some AMIs were deprecated or not available.

**Solution:**
```bash
# Update EKS version to 1.29 in infra/modules/eks/main.tf
version = "1.29"  # Changed from 1.28
```

**Prevention:**
Always use the latest stable EKS version. Check AWS documentation for supported versions.

---

### Issue 6: EKS Add-On Timeout

**Error:**
```
Error: waiting for EKS Add-On (ideas-api-dev:coredns) create: 
timeout while waiting for state to become 'ACTIVE' (last state: 'DEGRADED')
```

**Root Cause:**
Some EKS add-ons (coredns, kube-proxy) are pre-installed by AWS. Trying to install them again causes conflicts.

**Solution:**
```bash
# Remove pre-installed add-ons from Terraform configuration
# Only install vpc-cni add-on, which is not pre-installed

# If already in state, remove them:
terraform state rm module.eks.aws_eks_addon.coredns
terraform state rm module.eks.aws_eks_addon.kube_proxy
```

**Prevention:**
Only install add-ons that are not pre-installed. Check AWS documentation for which add-ons come with EKS by default.

---

### Issue 7: Node Group Creation Failed

**Error:**
```
Error: creating EKS Node Group: InvalidParameterException: 
Requested AMI for this version 1.28 is not supported
```

**Root Cause:**
Same as Issue 5 - AMI availability for EKS version 1.28.

**Solution:**
Update EKS cluster version to 1.29 and ensure node group uses compatible AMI.

**Prevention:**
Use latest stable EKS version and let AWS manage AMI selection.

---

## ALB Controller Issues

### Issue 8: ALB Controller Not Installed

**Error:**
```
No resources found in kube-system namespace.
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

**Root Cause:**
AWS Load Balancer Controller was not installed. It's required for ALB Ingress to work.

**Solution:**
```bash
# Install ALB Controller via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get cluster OIDC ID
OIDC_ID=$(aws eks describe-cluster --name ideas-api-dev --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create OIDC provider
aws iam create-open-id-connect-provider \
    --url https://oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID} \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 9e99a48a9960b14926bb07f369076415ea2fe59 || true

# Download official IAM policy
curl -s -o /tmp/alb-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json

# Create IAM policy
POLICY_ARN=$(aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy-dev \
    --policy-document file:///tmp/alb-policy.json \
    --query 'Policy.Arn' --output text)

# Install ALB Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=ideas-api-dev \
    --set serviceAccount.create=true \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::${ACCOUNT_ID}:role/ideas-api-dev-alb-controller-role \
    --wait
```

**Prevention:**
The `deploy.sh` script now automatically installs ALB Controller if not present.

---

### Issue 9: ALB Controller IAM Permission Errors

**Error:**
```
api error AccessDenied: User: arn:aws:sts::...:assumed-role/ideas-api-dev-alb-controller-role/... 
is not authorized to perform: elasticloadbalancing:DescribeLoadBalancers
is not authorized to perform: elasticloadbalancing:AddTags
is not authorized to perform: elasticloadbalancing:DescribeListenerAttributes
```

**Root Cause:**
The IAM policy attached to ALB Controller service account role was missing required permissions. The official AWS policy includes all necessary permissions.

**Solution:**
```bash
# Download official AWS Load Balancer Controller IAM policy
curl -s -o /tmp/alb-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json

# Create managed policy
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN=$(aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy-dev \
    --policy-document file:///tmp/alb-policy.json \
    --query 'Policy.Arn' --output text 2>/dev/null || \
    aws iam get-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy-dev" \
    --query 'Policy.Arn' --output text)

# Attach policy to role
aws iam attach-role-policy \
    --role-name ideas-api-dev-alb-controller-role \
    --policy-arn $POLICY_ARN

# Restart controller
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
```

**Prevention:**
Always use the official AWS Load Balancer Controller IAM policy from the GitHub repository. Don't create custom policies unless absolutely necessary.

---

### Issue 10: ALB Not Appearing in Ingress

**Error:**
```
kubectl get ingress -n ideas-api
NAME                CLASS    HOSTS   ADDRESS   PORTS   AGE
ideas-api-ingress   <none>   *                 80      10m
```

**Root Cause:**
ALB provisioning takes 2-5 minutes after controller starts. Also, IAM permissions might be missing.

**Solution:**
1. Wait 2-5 minutes for ALB to be provisioned
2. Check controller logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`
3. Verify IAM permissions (see Issue 9)
4. Check ingress events: `kubectl describe ingress ideas-api-ingress -n ideas-api`

**Prevention:**
Ensure ALB Controller has correct IAM permissions before creating Ingress resources.

---

## Docker Issues

### Issue 11: Docker Permission Denied

**Error:**
```
permission denied while trying to connect to the Docker daemon socket
```

**Root Cause:**
User is not in the `docker` group, so Docker commands require `sudo`.

**Solution:**
```bash
# Option 1: Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Option 2: Use sudo (temporary)
sudo docker build -t ...
sudo docker push ...
```

**Prevention:**
The `deploy.sh` script now automatically uses `sudo docker` if user is not in docker group.

---

## Kubernetes Issues

### Issue 12: Namespace Not Found

**Error:**
```
Error from server (NotFound): error when creating "k8s/configmap.yaml": 
namespaces "ideas-api" not found
```

**Root Cause:**
Kubernetes resources were applied before namespace was created, or namespace creation failed.

**Solution:**
```bash
# Create namespace first
kubectl apply -f k8s/namespace.yaml

# Wait for namespace to be ready
sleep 2

# Then apply other resources
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
# ... etc
```

**Prevention:**
Always create namespace first and wait a few seconds before creating other resources. The `deploy.sh` script includes this wait.

---

### Issue 13: Image Pull Errors

**Error:**
```
Error: ImagePullBackOff
Failed to pull image: 542035121679.dkr.ecr.us-east-1.amazonaws.com/ideas-api-dev:latest
```

**Root Cause:**
ECR image doesn't exist or EKS nodes don't have permission to pull from ECR.

**Solution:**
```bash
# Verify image exists
aws ecr describe-images --repository-name ideas-api-dev

# Verify node group has ECR read permission
# Check IAM role has AmazonEC2ContainerRegistryReadOnly policy attached
# This should be in infra/modules/iam/main.tf

# Rebuild and push image
docker build -t $ECR_URL:latest .
docker push $ECR_URL:latest
```

**Prevention:**
Ensure EKS node group IAM role has `AmazonEC2ContainerRegistryReadOnly` policy attached.

---

## IAM Permission Issues

### Issue 14: EKS Cluster Role Missing Permissions

**Error:**
```
Error: creating EKS Cluster: AccessDeniedException: 
User is not authorized to perform: eks:CreateCluster
```

**Root Cause:**
AWS credentials don't have sufficient permissions to create EKS cluster.

**Solution:**
Ensure AWS credentials have:
- `eks:CreateCluster`
- `eks:DescribeCluster`
- `iam:CreateRole`
- `iam:AttachRolePolicy`
- `ec2:CreateVpc`
- And other EKS-related permissions

**Prevention:**
Use IAM user/role with `AdministratorAccess` for development, or create custom policy with minimum required permissions.

---

## AI DevOps Issues

### Issue 15: Python Externally Managed Environment

**Error:**
```
error: externally-managed-environment
× This environment is externally managed
```

**Root Cause:**
Ubuntu 24.04+ uses PEP 668, which prevents installing packages system-wide.

**Solution:**
```bash
# Create virtual environment
cd ai-devops
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Use virtual environment
source venv/bin/activate
python3 analyze_deployment.py
deactivate
```

**Prevention:**
Always use virtual environments for Python projects. The `run-ai-devops.sh` script automatically creates and uses a virtual environment.

---

### Issue 16: OpenAI API Key Not Set

**Error:**
```
Error: OPENAI_API_KEY not set
```

**Root Cause:**
OpenAI API key environment variable is not set.

**Solution:**
```bash
# Set API key
export OPENAI_API_KEY="your-openai-api-key"

# Or add to ~/.bashrc for persistence
echo 'export OPENAI_API_KEY="your-key"' >> ~/.bashrc
source ~/.bashrc
```

**Prevention:**
The `run-ai-devops.sh` script prompts for API key if not set.

---

## Destruction Issues

### Issue 17: ECR Repository Not Empty

**Error:**
```
Error: ECR Repository (ideas-api-dev) not empty, consider using force_delete: 
RepositoryNotEmptyException: The repository with name 'ideas-api-dev' cannot be deleted 
because it still contains images
```

**Root Cause:**
Terraform cannot delete ECR repository if it contains images. Images must be deleted first.

**Solution:**
```bash
# Option 1: Delete images manually before destroy
ECR_REPO="ideas-api-dev"
aws ecr list-images --repository-name ${ECR_REPO} --query 'imageIds[*]' --output json > /tmp/images.json
aws ecr batch-delete-image --repository-name ${ECR_REPO} --image-ids file:///tmp/images.json

# Option 2: Use force_delete in Terraform (not recommended for production)
# Add to infra/modules/ecr/main.tf:
# resource "aws_ecr_repository" "app" {
#   ...
#   force_delete = true  # Only for dev/test environments
# }
```

**Prevention:**
The `destroy.sh` script now automatically deletes all ECR images before destroying infrastructure.

---

### Issue 18: Subnet Dependencies Cannot Be Deleted

**Error:**
```
Error: deleting EC2 Subnet: DependencyViolation: 
The subnet 'subnet-xxx' has dependencies and cannot be deleted.
```

**Root Cause:**
Subnets have active resources attached:
- ALB (Application Load Balancer) still exists
- NAT Gateway still attached
- Network interfaces from EKS nodes
- Other AWS resources

**Solution:**
```bash
# Step 1: Ensure ALB is deleted (from Ingress deletion)
# Wait for ALB to be fully deleted (can take 2-5 minutes)
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-ideasapi`)].LoadBalancerName' --output text

# Step 2: Wait for NAT Gateways to be deleted
# Terraform should handle this, but wait if needed
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=vpc-xxx" --query 'NatGateways[?State==`deleting`].NatGatewayId' --output text

# Step 3: Retry destroy after waiting
cd infra
terraform destroy -auto-approve -var-file=envs/dev/terraform.tfvars
```

**Prevention:**
The `destroy.sh` script now waits for ALB deletion before proceeding with Terraform destroy.

---

### Issue 19: Internet Gateway Dependencies

**Error:**
```
Error: deleting EC2 Internet Gateway: DependencyViolation: 
Network vpc-xxx has some mapped public address(es). 
Please unmap those public address(es) before detaching the gateway.
```

**Root Cause:**
Internet Gateway cannot be detached while:
- NAT Gateways still have Elastic IPs mapped
- Public subnets still have resources
- Elastic IPs are still associated

**Solution:**
```bash
# Step 1: Ensure all NAT Gateways are deleted
# Terraform should delete NAT Gateways first, but verify:
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=vpc-xxx"

# Step 2: Check for Elastic IPs still associated
aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --query 'Addresses[?AssociationId==null].AllocationId' --output text

# Step 3: Wait a few minutes for AWS to release dependencies
sleep 60

# Step 4: Retry destroy
cd infra
terraform destroy -auto-approve -var-file=envs/dev/terraform.tfvars
```

**Prevention:**
Terraform handles dependency ordering automatically. The issue occurs when resources are still being deleted. Wait and retry.

---

### Issue 20: Destroy Takes Too Long

**Error:**
```
terraform destroy hangs on certain resources
```

**Root Cause:**
Some AWS resources take time to delete:
- EKS cluster deletion: 5-10 minutes
- NAT Gateway deletion: 2-3 minutes
- ALB deletion: 2-5 minutes
- VPC deletion: Waits for all dependencies

**Solution:**
```bash
# Be patient - AWS resource deletion takes time
# EKS cluster deletion alone can take 10 minutes

# Check progress
cd infra
terraform destroy -auto-approve -var-file=envs/dev/terraform.tfvars

# If it seems stuck, check AWS Console or use AWS CLI:
aws eks describe-cluster --name ideas-api-dev --query 'cluster.status'
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=vpc-xxx"
```

**Prevention:**
The `destroy.sh` script provides progress updates. Total destruction time is typically 10-15 minutes.

---

## General Best Practices

### Always Check Prerequisites

Before running any deployment:
1. Verify AWS credentials: `aws sts get-caller-identity`
2. Check Terraform version: `terraform version`
3. Verify kubectl access: `kubectl version --client`
4. Test Docker: `docker ps`

### Use Idempotent Operations

All scripts should be idempotent - running them multiple times should be safe:
- Check if resources exist before creating
- Use `--ignore-not-found` flags where appropriate
- Handle errors gracefully

### Monitor Logs

Always check logs when issues occur:
- Terraform: `terraform plan` before `apply`
- Kubernetes: `kubectl logs -n <namespace> <pod-name>`
- ALB Controller: `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`
- CloudWatch: AWS Console or CLI

### State Management

- Never commit `.tfstate` files to git
- Use remote state (S3 backend)
- Use state locking (DynamoDB)
- Backup state before major changes

---

## Getting Help

If you encounter issues not covered here:

1. Check AWS CloudWatch logs
2. Review Kubernetes events: `kubectl get events -n ideas-api`
3. Check Terraform state: `terraform state list`
4. Review AWS CloudTrail for API errors
5. Check GitHub Issues (if applicable)

---

## Destruction Best Practices

### Order of Operations

When destroying infrastructure, follow this order:

1. **Delete Kubernetes Resources** - Removes ALB and pods
2. **Wait for ALB Deletion** - ALB takes 2-5 minutes to fully delete
3. **Delete ECR Images** - Remove all container images
4. **Destroy Terraform** - Let Terraform handle dependency ordering
5. **Wait and Retry** - If errors occur, wait 5 minutes and retry

### Common Destruction Errors

| Error | Cause | Solution |
|-------|-------|----------|
| ECR Repository not empty | Images still exist | Delete images first |
| Subnet dependencies | ALB or NAT Gateway still exists | Wait for ALB/NAT deletion |
| Internet Gateway dependencies | NAT Gateways still attached | Wait for NAT Gateway deletion |
| EKS cluster deletion timeout | Normal - takes 10 minutes | Be patient |

### Manual Cleanup (If Needed)

If Terraform destroy fails completely:

```bash
# 1. Delete ALB manually
ALB_ARN=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-ideasapi`)].LoadBalancerArn' --output text)
aws elbv2 delete-load-balancer --load-balancer-arn ${ALB_ARN}

# 2. Delete ECR images
aws ecr batch-delete-image --repository-name ideas-api-dev --image-ids imageTag=latest

# 3. Delete EKS cluster manually
aws eks delete-cluster --name ideas-api-dev

# 4. Wait for cluster deletion (10 minutes)
aws eks wait cluster-deleted --name ideas-api-dev

# 5. Retry Terraform destroy
cd infra
terraform destroy -auto-approve -var-file=envs/dev/terraform.tfvars
```

---

**Last Updated:** January 2026
**Project Version:** 1.0.0
