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

  // Needs the cluster, nodes and propagated access entries; on destroy it's removed before them
  depends_on = [time_sleep.eks_access_propagation]
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

  // CRDs and the ApplicationSet controller come from the argocd release; destroy removes this first.
  // Kyverno too: its webhook must be up before Argo CD creates app pods or the policies (ADR 0013).
  // External Secrets too: its CRDs must exist before Argo CD syncs gitops/postgres's ExternalSecret (ADR 0015).
  // kube-prometheus-stack too: the charts' ServiceMonitor/PodMonitor CRDs (ADR 0016).
  depends_on = [
    helm_release.argocd,
    helm_release.kyverno,
    helm_release.external_secrets,
    helm_release.kube_prometheus_stack,
  ]
}
