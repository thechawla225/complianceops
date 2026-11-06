// -----------------------------------------------------Kyverno ECR read (IRSA, ADR 0014)-----------------------------------------------------
// Kyverno's admission controller reads image signatures (cosign v3 bundles, stored as OCI referrers next to each
// image) from the private ECR repos. Read-only, complianceops-* repos only, and only for that one service account.
// Lives here, not in persistent: the trust policy references this cluster's OIDC provider.

data "aws_iam_policy_document" "kyverno_ecr_assume_role" {
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
      values   = ["system:serviceaccount:kyverno:kyverno-admission-controller"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "kyverno_ecr" {
  name               = "complianceops-kyverno-ecr-read"
  assume_role_policy = data.aws_iam_policy_document.kyverno_ecr_assume_role.json
}

data "aws_iam_policy_document" "kyverno_ecr" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] // doesn't support resource-level permissions
  }
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages",
      "ecr:ListImages", // the OCI referrers API, where cosign v3 bundles are found
    ]
    resources = ["arn:aws:ecr:us-west-2:697961193772:repository/complianceops-*"]
  }
}

resource "aws_iam_role_policy" "kyverno_ecr" {
  name   = "complianceops-kyverno-ecr-read"
  role   = aws_iam_role.kyverno_ecr.id
  policy = data.aws_iam_policy_document.kyverno_ecr.json
}
