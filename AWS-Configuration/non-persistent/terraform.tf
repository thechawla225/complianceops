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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }

  required_version = ">= 1.11.0"

  backend "s3" {
    bucket = "complianceops-terraform-state"
    key    = "non-persistent/terraform.tfstate"
    region = "us-west-2"
    // Lock the state so a local apply/teardown and a CI run can't write it at the same time
    encrypt      = true
    use_lockfile = true
  }
}
