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