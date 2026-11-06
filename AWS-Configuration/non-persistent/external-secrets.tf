// -----------------------------------------------------External Secrets Operator (ADR 0015)-----------------------------------------------------
// Copies the dev Postgres password from Secrets Manager (persistent/secrets.tf) into the postgres-credentials Secret.
// Platform, so Terraform installs it before Argo CD's apps (like Kyverno); the SecretStore and ExternalSecret are
// delivered by Argo CD in gitops/postgres.

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "2.14.0"
  namespace        = "external-secrets" # own namespace: outside sanctions-platform's default-deny and quota
  create_namespace = true
  wait             = true # apply fails if the controller and webhook don't become Ready
  timeout          = 600
  values           = [file("${path.module}/external-secrets-values.yaml")]

  // IRSA: the controller reads the one secret below (no static AWS keys in the cluster)
  set = [{
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_secrets.arn
  }]

  depends_on = [time_sleep.eks_access_propagation]
}

data "aws_iam_policy_document" "external_secrets_assume_role" {
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
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "complianceops-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role.json
}

// Read-only, this one secret. Encrypted with the AWS-managed aws/secretsmanager key, so no kms:Decrypt grant is
// needed: Secrets Manager decrypts on the caller's behalf.
data "aws_iam_policy_document" "external_secrets" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    // By name, not a data lookup: plans must work before persistent has created the secret. "-??????" matches the
    // 6-character suffix AWS appends to secret ARNs, and nothing else.
    resources = ["arn:aws:secretsmanager:us-west-2:697961193772:secret:complianceops/dev/postgres-??????"]
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  name   = "complianceops-external-secrets-read"
  role   = aws_iam_role.external_secrets.id
  policy = data.aws_iam_policy_document.external_secrets.json
}
