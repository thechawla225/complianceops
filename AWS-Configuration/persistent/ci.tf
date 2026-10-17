# -----------------------------------------------------GitHub Actions OIDC (CI/CD auth)-----------------------------------------------------


data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}

locals {
  // This repo has GitHub's immutable OIDC subject enabled, so the token's sub is
  // "repo:<owner>@<owner_id>/<repo>@<repo_id>:..." not "repo:<owner>/<repo>:...".
  // IDs can't be reused if the repo/user is renamed or deleted (name-squatting safe).
  // Check with: gh api repos/thechawla225/complianceops/actions/oidc/customization/sub
  github_repo = "thechawla225@45570514/complianceops@1351611018"
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions_ci" {
  name               = "complianceops-github-actions-ci"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}


resource "aws_iam_role_policy_attachment" "github_actions_ci_admin" {
  #checkov:skip=CKV_AWS_274:CI creates VPC/EKS/IAM/KMS so needs broad access; trust policy limits it to this one repo via OIDC sub claim. TODO scope down.
  role       = aws_iam_role.github_actions_ci.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_ci_role_arn" {
  value = aws_iam_role.github_actions_ci.arn
}

# -----------------------------------------------------Service repos CI (build + push images to ECR)-----------------------------------------------------
// Separate, least-privilege role: service pipelines can only push to the 4 ECR repos,
// and only from a push to main (PR runs get a different OIDC sub and can't assume it).

locals {
  // <repo>@<repo_id> for GitHub's immutable OIDC subject (same format as github_repo above)
  service_repos = [
    "complianceops-gatewayservice@1351624195",
    "complianceops-transactionservice@1351628573",
    "complianceops-screeningservice@1351625343",
    "complianceops-notifierservice@1351621388",
  ]
}

data "aws_iam_policy_document" "service_ci_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for r in local.service_repos : "repo:thechawla225@45570514/${r}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "service_ci" {
  name               = "complianceops-service-image-ci"
  assume_role_policy = data.aws_iam_policy_document.service_ci_assume_role.json
}

data "aws_iam_policy_document" "service_ci_ecr_push" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] // doesn't support resource-level permissions
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [for r in aws_ecr_repository.services : r.arn]
  }
}

resource "aws_iam_role_policy" "service_ci_ecr_push" {
  name   = "complianceops-service-image-ecr-push"
  role   = aws_iam_role.service_ci.id
  policy = data.aws_iam_policy_document.service_ci_ecr_push.json
}

output "service_ci_role_arn" {
  value = aws_iam_role.service_ci.arn
}
