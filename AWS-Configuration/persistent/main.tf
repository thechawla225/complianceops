
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
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms_key_policy" {
  #checkov:skip=CKV_AWS_356:KMS key policies always target "this key" via Resource="*" — the AWS-documented convention, not a wildcard across resources
  #checkov:skip=CKV_AWS_111:standard AWS-generated default key policy pattern (root grant); actual access is still gated by IAM policies attached elsewhere
  #checkov:skip=CKV_AWS_109:same as above
  statement {
    sid       = "EnableRootAccountPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_kms_key" "terraform_state" {
  description         = "KMS key for encrypting the Terraform state bucket"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms_key_policy.json
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
  #checkov:skip=CKV_AWS_18:log bucket — logging a log bucket to itself is circular
  #checkov:skip=CKV_AWS_144:log bucket does not need cross-region replication
  bucket = "${var.bucket_name}-logs"
}

resource "aws_s3_bucket_versioning" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_logs" {
  bucket                  = aws_s3_bucket.terraform_state_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_notification" "terraform_state_logs" {
  bucket      = aws_s3_bucket.terraform_state_logs.id
  eventbridge = true
}

resource "aws_s3_bucket_logging" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  target_bucket = aws_s3_bucket.terraform_state_logs.id
  target_prefix = "log/"
}

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
  policy              = data.aws_iam_policy_document.kms_key_policy.json
}

resource "aws_s3_bucket" "terraform_state_replica" {
  #checkov:skip=CKV_AWS_18:S3 access-logging target must be in the same region as the source bucket — a second regional log bucket isn't warranted just for the replication target
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

resource "aws_s3_bucket_public_access_block" "terraform_state_replica" {
  provider                = aws.replica
  bucket                  = aws_s3_bucket.terraform_state_replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.terraform_state_replica.id

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

resource "aws_s3_bucket_notification" "terraform_state_replica" {
  provider    = aws.replica
  bucket      = aws_s3_bucket.terraform_state_replica.id
  eventbridge = true
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

// -----------------------------------------------------SQS Configuration-----------------------------------------------------

resource "aws_sqs_queue" "flagged_transactions_dlq" {
  name                      = "complianceops-flagged-transactions-dlq"
  message_retention_seconds = 1209600 # 14 days
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "flagged_transactions" {
  name                       = "complianceops-flagged-transactions"
  visibility_timeout_seconds = 30
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.flagged_transactions_dlq.arn
    maxReceiveCount     = 5
  })
}