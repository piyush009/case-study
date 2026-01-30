# Terraform Backend Configuration
# Stores state in S3 with DynamoDB for state locking
# This ensures state is shared across team members and prevents concurrent modifications

terraform {
  backend "s3" {
    bucket         = "task-28-01-2026"
    key            = "devops-case-study/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }

  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}
