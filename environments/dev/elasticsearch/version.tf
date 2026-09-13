# Terraform engine and provider requirements
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider configured with target deployment region
provider "aws" {
  region = var.aws_region
}
