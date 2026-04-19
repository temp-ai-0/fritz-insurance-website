variable "project_name" {
  description = "Project name used for resource naming (lowercase, hyphens ok)"
  type        = string
  default     = "fritz-insurance"
}

variable "environment" {
  description = "Deployment environment (prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for the S3 bucket (CloudFront is always global)"
  type        = string
  default     = "us-east-1"
}
