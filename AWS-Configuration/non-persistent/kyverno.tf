// -----------------------------------------------------Kyverno (ADR 0013)-----------------------------------------------------
// The policy engine is platform, so Terraform installs it, like Argo CD. The policies themselves live in policies/
// and are delivered by Argo CD (argocd-apps-values.yaml), so a policy change is a reviewed PR.

resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  version          = "3.9.2"   # Kyverno v1.19.2
  namespace        = "kyverno" # own namespace: outside sanctions-platform's default-deny and quota
  create_namespace = true
  wait             = true # apply fails if the admission webhook doesn't become Ready
  timeout          = 600
  values           = [file("${path.module}/kyverno-values.yaml")]

  // IRSA: the admission controller reads image signatures from ECR (kyverno-ecr.tf, ADR 0014)
  set = [{
    name  = "admissionController.rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.kyverno_ecr.arn
  }]

  // Same ordering as Argo CD. argocd_apps depends on this too, so the webhook is up before any app pod is created;
  // on destroy the apps go first, then Kyverno (its pre-delete hook removes the webhooks).
  depends_on = [time_sleep.eks_access_propagation]
}
