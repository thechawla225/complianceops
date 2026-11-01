// -----------------------------------------------------Argo CD (ADR 0008)-----------------------------------------------------
// Installed by Terraform so every rebuilt cluster comes up with GitOps already running.

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.10.5" # Argo CD v3.5.5
  namespace        = "argocd"  # own namespace: outside sanctions-platform's default-deny and quota
  create_namespace = true
  wait             = true # apply fails if Argo CD doesn't become Ready
  timeout          = 600
  values           = [file("${path.module}/argocd-values.yaml")]

  // Needs the cluster and nodes; on destroy it's removed before them
  depends_on = [module.eks]
}
