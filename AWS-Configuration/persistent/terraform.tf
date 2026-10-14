terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  // The bucket below is created by this same config, so the very first apply
  // (bootstrap) has to run with local state. Once the bucket exists, state is
  // migrated here with `terraform init -migrate-state` so CI can share it.
  backend "s3" {
    bucket       = "complianceops-terraform-state"
    key          = "persistent/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}