variable "environment" {
  type = string
}

variable "app_name" {
  type = string
}

variable "force_delete" {
  type        = bool
  default     = false
  description = "Allow force delete of ECR repository (only for dev/test)"
}
