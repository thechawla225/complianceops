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

// One ApplicationSet: an Application per gitops/<chart> folder (see argocd-apps-values.yaml).
// A Helm release, not kubernetes_manifest, because the ApplicationSet CRD doesn't exist at plan time.
resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.7"
  namespace  = "argocd"
  values     = [file("${path.module}/argocd-apps-values.yaml")]

  // CRDs and the ApplicationSet controller come from the argocd release; destroy removes this first
  depends_on = [helm_release.argocd]
}
