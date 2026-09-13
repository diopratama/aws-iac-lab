variable "environment" {
  type        = string
  default     = "dev"
  description = "Target deployment environment (e.g. dev, staging, prod)"
}

variable "node_count" {
  type        = number
  default     = 3
  description = "Number of Elasticsearch EC2 nodes to deploy in the cluster"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for Elasticsearch host (e.g. t3.micro for dev, t3.small/m6g.large for prod)"
}

variable "volume_size" {
  type        = number
  default     = 10
  description = "Size of EBS root volume in GB per node"
}

variable "volume_type" {
  type        = string
  default     = "gp3"
  description = "EBS volume type (e.g. gp3, gp2)"
}

variable "volume_encrypted" {
  type        = bool
  default     = true
  description = "Enable KMS encryption for EBS root volume"
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "Custom KMS Key ARN for EBS volume encryption (uses default AWS KMS key if null)"
}

variable "es_heap_size" {
  type        = string
  default     = "512m"
  description = "Elasticsearch JVM Heap size (e.g. 512m for 1GB RAM dev instance, 1g/4g for prod)"
}

variable "es_version" {
  type        = string
  default     = "8.13.0"
  description = "Elasticsearch Docker image version tag"
}

variable "es_password" {
  type        = string
  sensitive   = true
  description = "Master password for elastic superuser account"
}

variable "enable_ilb" {
  type        = bool
  default     = true
  description = "Enable creation of Internal Load Balancer (ILB) in front of cluster nodes"
}

variable "vpc_id" {
  type        = string
  default     = null
  description = "Target VPC ID (optional, defaults to default VPC if null)"
}

variable "subnet_id" {
  type        = string
  default     = null
  description = "Target Subnet ID for EC2 instance placement (optional)"
}

variable "subnet_ids" {
  type        = list(string)
  default     = null
  description = "List of Subnet IDs for Load Balancer placement across multiple AZs"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to attach to resources"
}
