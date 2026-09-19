provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "terraform-state" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform-state" {
  bucket                  = aws_s3_bucket.terraform-state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "complianceops-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

// Adding some logic so that I dont have to comment and uncomment eks_managed_node_groups in the module "eks" block 


variable "create_node_group" {
  type    = bool
  default = true
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name = "complianceops-eks"

  // Allow cluster access, but only to the admin
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  // Added logic to prevent repeated uncommenting and commenting
  eks_managed_node_groups = var.create_node_group ? {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
    }
  } : null
}


locals {
  services = ["gateway", "transaction", "screening", "notifier"]
}

resource "aws_ecr_repository" "services" {
  for_each = toset(local.services)

  name                 = "complianceops-${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

// Adding Policies

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "complianceops-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}