variable "aws_region" {
  type        = string
  default     = "ap-southeast-3"
  description = "AWS region for deployment"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment name"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for Elasticsearch host"
}

variable "es_password" {
  type        = string
  sensitive   = true
  description = "Master password for elastic superuser account (Loaded from secrets.auto.tfvars)"
}
