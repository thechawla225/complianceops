terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }

  required_version = ">= 1.11.0"

  backend "s3" {
    bucket = "complianceops-terraform-state"
    key    = "non-persistent/terraform.tfstate"
    region = "us-west-2"
  }
}