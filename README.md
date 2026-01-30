# DevOps Case Study: Production-Grade AWS Platform

A complete DevOps solution demonstrating enterprise-level AWS infrastructure, Kubernetes deployment, CI/CD pipelines, and AI-powered DevOps automation.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Deployment](#deployment)
- [CI/CD Pipeline](#cicd-pipeline)
- [AI DevOps](#ai-devops)
- [Troubleshooting](#troubleshooting)
- [Interview Talking Points](#interview-talking-points)

## 🎯 Overview

This project demonstrates a production-ready DevOps platform built on AWS, featuring:

- **Minimal Python FastAPI Application** - Simple but well-structured backend API
- **Infrastructure as Code** - Modular Terraform configuration
- **Kubernetes Deployment** - EKS cluster with auto-scaling
- **CI/CD Pipeline** - Complete GitHub Actions workflow
- **AI-Powered DevOps** - Intelligent automation and analysis

## 🏗️ Architecture

### AWS Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │   Application        │
            │   Load Balancer      │
            │   (ALB)              │
            └──────────┬───────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │      EKS Cluster             │
        │  ┌────────────────────────┐ │
        │  │  Kubernetes Pods       │ │
        │  │  (ideas-api)           │ │
        │  └────────────────────────┘ │
        │  ┌────────────────────────┐ │
        │  │  HPA (Auto-scaling)     │ │
        │  └────────────────────────┘ │
        └──────────┬───────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
┌──────────────┐      ┌──────────────┐
│ Public       │      │ Private      │
│ Subnets      │      │ Subnets       │
│ (ALB)        │      │ (EKS Nodes)  │
└──────────────┘      └──────────────┘
        │                     │
        └──────────┬──────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │   VPC                │
        │   (10.0.0.0/16)      │
        └──────────────────────┘

┌─────────────────────────────────────────┐
│  Supporting Services:                   │
│  • ECR (Docker Registry)                │
│  • CloudWatch (Logging)                 │
│  • S3 (Terraform State)                │
│  • IAM (Roles & Policies)              │
└─────────────────────────────────────────┘
```

### DevOps Workflow

```
┌─────────────┐
│   Developer │
│   Pushes    │
│   Code      │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│  GitHub Actions │
│  CI/CD Pipeline │
└──────┬──────────┘
       │
       ├──► Lint & Test
       ├──► Build Docker Image
       ├──► Scan with Trivy
       ├──► Push to ECR
       ├──► Terraform Plan/Apply
       ├──► Deploy to EKS
       └──► AI DevOps Analysis
       │
       ▼
┌─────────────────┐
│  EKS Cluster    │
│  (Production)   │
└─────────────────┘
```

## ✨ Features

### Application
- **FastAPI** - Modern Python web framework
- **Health Checks** - Kubernetes liveness and readiness probes
- **In-Memory Storage** - Simple, no database required
- **RESTful API** - Clean endpoint design

### Infrastructure
- **VPC** - Multi-AZ, public/private subnets
- **EKS** - Managed Kubernetes cluster (v1.29)
- **ECR** - Docker container registry with scanning
- **ALB** - Application Load Balancer via Ingress
- **CloudWatch** - Centralized logging
- **IAM** - Least privilege access

### Kubernetes
- **Deployment** - Rolling updates, zero downtime
- **Service** - ClusterIP for internal communication
- **Ingress** - ALB integration
- **HPA** - Horizontal Pod Autoscaler
- **ConfigMap** - Configuration management

### CI/CD
- **GitHub Actions** - Automated pipeline
- **Linting** - Code quality checks
- **Testing** - Unit tests with pytest
- **Security Scanning** - Trivy vulnerability scanning
- **Terraform** - Infrastructure automation
- **Kubernetes Deployment** - Automated rollouts

### AI DevOps
- **kubectl Command Generator** - Natural language to commands
- **Log Analyzer** - AI-powered log analysis
- **Replica Suggester** - Intelligent scaling recommendations
- **Rollback Detection** - Automated failure detection

## 🚀 Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured (`aws configure`)
- Terraform >= 1.5.0
- kubectl installed
- Docker installed
- Python 3.11+

### One-Command Deployment

**Using Shell Scripts:**
```bash
# Clone repository
git clone <repository-url>
cd case-study

# Make scripts executable
chmod +x deploy.sh destroy.sh run-ai-devops.sh

# Deploy everything
./deploy.sh dev
```

**Using Python Scripts:**
```bash
# Clone repository
git clone <repository-url>
cd case-study

# Deploy everything
python3 deploy.py dev
```

The script will:
1. Check prerequisites
2. Setup Terraform backend (S3 + DynamoDB)
3. Deploy infrastructure
4. Configure kubectl
5. Install ALB Controller
6. Build and push Docker image
7. Deploy to Kubernetes

### Manual Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for step-by-step instructions.

## 📁 Project Structure

```
case-study/
├── app.py                      # FastAPI application
├── requirements.txt            # Python dependencies
├── test_app.py                # Unit tests
├── Dockerfile                 # Container definition
├── docker-compose.yml         # Local development
├── deploy.sh                  # Complete deployment script
├── destroy.sh                 # Infrastructure destruction
├── run-ai-devops.sh          # AI DevOps analysis
│
├── infra/                     # Terraform infrastructure
│   ├── backend.tf            # S3 backend config
│   ├── main.tf               # Main configuration
│   ├── variables.tf           # Variable definitions
│   ├── outputs.tf             # Output values
│   ├── modules/               # Terraform modules
│   │   ├── vpc/              # VPC module
│   │   ├── eks/              # EKS module
│   │   ├── ecr/              # ECR module
│   │   └── iam/              # IAM module
│   └── envs/                 # Environment configs
│       ├── dev/
│       └── prod/
│
├── k8s/                       # Kubernetes manifests
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── hpa.yaml
│
├── ai-devops/                 # AI DevOps scripts
│   ├── kubectl_ai.py         # Command generator
│   ├── log_analyzer.py       # Log analysis
│   ├── replica_suggester.py  # Scaling suggestions
│   ├── analyze_deployment.py # Complete analysis
│   └── requirements.txt      # AI dependencies
│
└── .github/
    └── workflows/
        └── ci-cd.yml         # CI/CD pipeline
```

## 🔄 Deployment

### Deployment Scripts

Both shell and Python versions are available:

| Script | Shell | Python |
|--------|-------|--------|
| Deploy | `./deploy.sh dev` | `python3 deploy.py dev` |
| Destroy | `./destroy.sh dev` | `python3 destroy.py dev` |
| AI DevOps | `./run-ai-devops.sh` | `python3 run_ai_devops.py` |

### Deploy Infrastructure

```bash
cd infra
terraform init
terraform plan -var-file=envs/dev/terraform.tfvars
terraform apply -var-file=envs/dev/terraform.tfvars
```

### Deploy Application

```bash
# Get ECR URL
ECR_URL=$(cd infra && terraform output -raw ecr_repository_url)

# Build and push image
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL
docker build -t $ECR_URL:latest .
docker push $ECR_URL:latest

# Configure kubectl
CLUSTER_NAME=$(cd infra && terraform output -raw eks_cluster_name)
aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1

# Deploy to Kubernetes
sed "s|ECR_REPOSITORY_URL|$ECR_URL|g" k8s/deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -n ideas-api

# Check services
kubectl get svc -n ideas-api

# Check ingress (ALB URL)
kubectl get ingress -n ideas-api

# Test endpoints
ALB_URL=$(kubectl get ingress ideas-api-ingress -n ideas-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$ALB_URL/health
curl http://$ALB_URL/ideas
```

## 🔧 CI/CD Pipeline

**Note**: The CI/CD pipeline runs automatically on GitHub when you push code. It requires GitHub Secrets to be configured. 

**Important**: If GitHub redirects you to `/actions/new`, this is normal - it happens when there are no workflow runs yet. Push code to trigger the workflow, then check the Actions tab again. See [ACTIONS_TROUBLESHOOTING.md](ACTIONS_TROUBLESHOOTING.md) for details.

The GitHub Actions pipeline includes:

1. **Lint & Test** - Code quality and unit tests
2. **Build & Scan** - Docker image build with Trivy scanning
3. **Push to ECR** - Container registry upload
4. **Terraform Plan** - Infrastructure validation
5. **Terraform Apply** - Infrastructure deployment (main branch only)
6. **Deploy to EKS** - Kubernetes rollout
7. **AI DevOps Analysis** - Post-deployment analysis

### GitHub Secrets Required

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `OPENAI_API_KEY` (for AI DevOps)

## 🤖 AI DevOps

### Setup

```bash
cd ai-devops
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
export OPENAI_API_KEY="your-key"
```

### Run Analysis

```bash
# Complete analysis
./run-ai-devops.sh

# Or manually
cd ai-devops
source venv/bin/activate
python3 analyze_deployment.py
```

### Features

- **kubectl Command Generator**: Convert natural language to kubectl commands
- **Log Analyzer**: AI-powered CloudWatch log analysis
- **Replica Suggester**: Intelligent scaling recommendations
- **Rollback Detection**: Automated failure detection

## 🐛 Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

Common issues:
- EKS cluster creation failures
- ALB not appearing
- IAM permission errors
- Terraform state issues

## 💼 Interview Talking Points

### Architecture Decisions

1. **Modular Terraform** - Reusable modules for different environments
2. **EKS v1.29** - Latest stable version with AMI availability
3. **Multi-AZ Deployment** - High availability across availability zones
4. **Private Subnets for Nodes** - Security best practice
5. **ALB via Ingress** - Native Kubernetes integration

### DevOps Best Practices

1. **Infrastructure as Code** - Version controlled infrastructure
2. **Automated CI/CD** - Zero-touch deployments
3. **Security Scanning** - Trivy integration for vulnerabilities
4. **Health Checks** - Liveness and readiness probes
5. **Auto-Scaling** - HPA for dynamic resource management

### AI Integration

1. **Proactive Monitoring** - AI analyzes logs before issues escalate
2. **Intelligent Scaling** - AI suggests optimal replica counts
3. **Natural Language Interface** - kubectl commands from plain English
4. **Automated Rollback** - AI determines when rollback is needed

### Cost Optimization

1. **Right-Sized Instances** - t3.medium for dev, scalable for prod
2. **ECR Lifecycle Policies** - Automatic image cleanup
3. **HPA Configuration** - Scale down during low traffic
4. **CloudWatch Retention** - 7-day log retention

## 📚 Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

## 📝 License

This project is for educational and interview purposes.

## 👤 Author

DevOps Engineer - Case Study Project

---

**Note**: This is a demonstration project showcasing DevOps best practices. For production use, additional considerations like monitoring, alerting, backup strategies, and disaster recovery should be implemented.
