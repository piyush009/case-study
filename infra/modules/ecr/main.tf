# ECR Module
# Creates Docker container registry with image scanning and lifecycle policies

resource "aws_ecr_repository" "app" {
  name                 = "${var.app_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"
  
  # Allow force delete for dev/test environments
  # Set to false for production to prevent accidental deletion
  force_delete = var.environment == "dev" ? true : false

  # Enable image scanning on push for security
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encryption at rest
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment = var.environment
    Application = var.app_name
  }
}

# Lifecycle policy to manage image retention
# Keeps last 10 images to prevent storage bloat
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
