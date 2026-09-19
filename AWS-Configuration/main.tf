provider "aws" {
  region = "us-west-2"
}


//-----------------------------------------------------S3 Configuration-----------------------------------------------------
resource "aws_s3_bucket" "terraform-state" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id
  versioning_configuration {
    status = "Enabled"
  }
}

// Replacing the default S3 bucket encryption with KMS key as per checkov suggestion for policy compliance and security best practices
resource "aws_kms_key" "terraform_state" {
  description         = "KMS key for encrypting the Terraform state bucket"
  enable_key_rotation = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform-state" {
  bucket                  = aws_s3_bucket.terraform-state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

// Enablding logs for S3 bucket as per checkov suggestion for policy compliance and security best practices


resource "aws_s3_bucket" "terraform_state_logs" {
  bucket = "${var.bucket_name}-logs"
}

resource "aws_s3_bucket_logging" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  target_bucket = aws_s3_bucket.terraform_state_logs.id
  target_prefix = "log/"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "S3ServerAccessLogsPolicy"
      Effect    = "Allow"
      Principal = { Service = "logging.s3.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.terraform_state_logs.arn}/log/*"
      Condition = {
        ArnLike      = { "aws:SourceArn" = aws_s3_bucket.terraform-state.arn }
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

// Enabling event notifications for S3 bucket as per checkov suggestion for policy compliance and security best practices

resource "aws_s3_bucket_notification" "terraform-state" {
  bucket      = aws_s3_bucket.terraform-state.id
  eventbridge = true
}

// Added lifecycle configuration for S3 bucket as per checkov suggestion for cost saving best practise
resource "aws_s3_bucket_lifecycle_configuration" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

// Cross Region replication for S3 bucket as per checkov suggestion for policy compliance and security best practices

provider "aws" {
  alias  = "replica"
  region = "us-east-1"
}

resource "aws_kms_key" "terraform_state_replica" {
  provider            = aws.replica
  description         = "KMS key for encrypting the replicated Terraform state bucket"
  enable_key_rotation = true
}

resource "aws_s3_bucket" "terraform_state_replica" {
  provider = aws.replica
  bucket   = "${var.bucket_name}-replica"
}

resource "aws_s3_bucket_versioning" "terraform_state_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.terraform_state_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.terraform_state_replica.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state_replica.arn
    }
    bucket_key_enabled = true
  }
}

data "aws_iam_policy_document" "replication_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

// IAM roles added for checkov issue resolution 
resource "aws_iam_role" "replication" {
  name               = "complianceops-s3-replication-role"
  assume_role_policy = data.aws_iam_policy_document.replication_assume_role.json
}

data "aws_iam_policy_document" "replication" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.terraform-state.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
    resources = ["${aws_s3_bucket.terraform-state.arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
    resources = ["${aws_s3_bucket.terraform_state_replica.arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.terraform_state.arn]

    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["s3.us-west-2.amazonaws.com"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Encrypt"]
    resources = [aws_kms_key.terraform_state_replica.arn]

    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["s3.us-east-1.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "replication" {
  name   = "complianceops-s3-replication-policy"
  role   = aws_iam_role.replication.id
  policy = data.aws_iam_policy_document.replication.json
}

resource "aws_s3_bucket_replication_configuration" "terraform-state" {
  depends_on = [
    aws_s3_bucket_versioning.terraform-state,
    aws_s3_bucket_versioning.terraform_state_replica,
  ]

  bucket = aws_s3_bucket.terraform-state.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "replicate-state"
    status = "Enabled"

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket        = aws_s3_bucket.terraform_state_replica.arn
      storage_class = "STANDARD"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.terraform_state_replica.arn
      }
    }
  }
}


// -----------------------------------------------------VPC Configuration-----------------------------------------------------

module "vpc" {
  // Added Source with commit hash as per checkov suggestion to prevent supply chain attack
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=b3abd6df2ecf052451a361ed55b8f06f8742a795"

  name = "complianceops-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}


// -----------------------------------------------------EKS Configuration-----------------------------------------------------
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


// -----------------------------------------------------ECR Configuration-----------------------------------------------------

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