# Terraform Variables
# Centralized variable definitions for the infrastructure

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name used for resource naming"
  type        = string
  default     = "ideas-api"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for EKS node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired number of nodes in the EKS cluster"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of nodes (for auto-scaling)"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of nodes (for auto-scaling)"
  type        = number
  default     = 5
}
