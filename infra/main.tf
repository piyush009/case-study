# Main Terraform Configuration
# Orchestrates all infrastructure modules

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region
}

# Kubernetes Provider Configuration
# This is configured after EKS cluster is created
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name
    ]
  }
}

# VPC Module
# Creates VPC with public and private subnets across multiple AZs
module "vpc" {
  source = "./modules/vpc"
  
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  aws_region  = var.aws_region
  app_name    = var.app_name
}

# ECR Module
# Docker container registry for storing application images
module "ecr" {
  source = "./modules/ecr"
  
  environment  = var.environment
  app_name     = var.app_name
  force_delete = var.environment == "dev" ? true : false
}

# IAM Module
# Creates IAM roles and policies for EKS cluster and node groups
module "iam" {
  source = "./modules/iam"
  
  environment = var.environment
  app_name    = var.app_name
}

# EKS Module
# Creates Kubernetes cluster with managed node groups
module "eks" {
  source = "./modules/eks"
  
  environment           = var.environment
  app_name              = var.app_name
  vpc_id                = module.vpc.vpc_id
  private_subnets       = module.vpc.private_subnet_ids
  public_subnets        = module.vpc.public_subnet_ids
  eks_cluster_role_arn  = module.iam.eks_cluster_role_arn
  eks_node_role_arn     = module.iam.eks_node_role_arn
  
  node_group_instance_types = var.eks_node_instance_types
  node_group_desired_size    = var.eks_node_desired_size
  node_group_min_size       = var.eks_node_min_size
  node_group_max_size       = var.eks_node_max_size
  
  depends_on = [module.iam]
}

# ALB Ingress Controller IAM Policy Attachment
# Grants EKS cluster role permission to manage ALBs
resource "aws_iam_role_policy_attachment" "alb_ingress" {
  role       = module.eks.cluster_iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}
