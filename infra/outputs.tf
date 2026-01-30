# Terraform Outputs
# These values are used by deployment scripts and CI/CD pipelines

output "vpc_id" {
  description = "VPC ID for reference"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name for kubectl configuration"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing Docker images"
  value       = module.ecr.repository_url
}

output "kubeconfig_command" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
