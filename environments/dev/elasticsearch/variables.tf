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

variable "node_count" {
  type        = number
  default     = 3
  description = "Number of Elasticsearch EC2 nodes in the cluster"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for Elasticsearch host"
}

variable "volume_size" {
  type        = number
  default     = 10
  description = "Size of EBS root volume in GB per node"
}

variable "enable_ilb" {
  type        = bool
  default     = true
  description = "Enable creation of Internal Load Balancer"
}

variable "es_password" {
  type        = string
  sensitive   = true
  description = "Master password for elastic superuser account (Loaded from secrets.auto.tfvars)"
}
