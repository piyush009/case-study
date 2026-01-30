# EKS Module
# Creates Kubernetes cluster with managed node groups
# Uses EKS version 1.29 (1.28 had AMI availability issues)

# CloudWatch Log Group for EKS cluster logs
# Created first as EKS cluster depends on it
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.app_name}-${var.environment}/cluster"
  retention_in_days = 7

  tags = {
    Environment = var.environment
    Application = var.app_name
  }
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "${var.app_name}-${var.environment}"
  role_arn = var.eks_cluster_role_arn
  version  = "1.29"  # Using 1.29 as 1.28 had AMI availability issues

  vpc_config {
    subnet_ids              = concat(var.private_subnets, var.public_subnets)
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # Enable cluster logging for observability
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # Ensure log group exists before cluster creation
  depends_on = [
    aws_cloudwatch_log_group.eks_cluster
  ]

  tags = {
    Environment = var.environment
    Application = var.app_name
  }
}

# EKS Node Group
# Managed node group with auto-scaling capabilities
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.app_name}-${var.environment}-nodes"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.private_subnets  # Nodes in private subnets for security
  instance_types  = var.node_group_instance_types

  # Auto-scaling configuration
  scaling_config {
    desired_size = var.node_group_desired_size
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
  }

  # Update configuration for rolling updates
  update_config {
    max_unavailable = 1  # Allow one node to be unavailable during updates
  }

  depends_on = [
    aws_eks_cluster.main
  ]

  tags = {
    Environment = var.environment
    Application = var.app_name
  }
}

# VPC CNI Add-on
# Required for pod networking in EKS
# Note: coredns and kube-proxy are pre-installed by EKS, so we only add VPC-CNI
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  
  # Wait for node group to be ready before installing add-on
  depends_on = [
    aws_eks_node_group.main
  ]

  tags = {
    Environment = var.environment
  }
}
