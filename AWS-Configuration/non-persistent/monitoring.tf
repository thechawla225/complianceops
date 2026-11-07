// -----------------------------------------------------Monitoring (ADR 0016)-----------------------------------------------------
// Platform, so Terraform installs it, like Argo CD and Kyverno. What each service exposes and how it's scraped
// (ServiceMonitor / PodMonitor) ships in the service's own chart in gitops/.
// Everything lives in the monitoring namespace: outside sanctions-platform's default-deny, quota and Kyverno policies.
// Storage is emptyDir: the data goes with the cluster on teardown, which also means no EBS volumes left behind.

// Prometheus (+ operator and CRDs), Alertmanager, Grafana, kube-state-metrics, node-exporter
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "92.22.0" # Prometheus Operator v0.94.2
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  timeout          = 600
  values           = [file("${path.module}/monitoring-values.yaml")]

  depends_on = [time_sleep.eks_access_propagation]
}

// Log store, single-binary mode (one pod)
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "7.5.0" # Loki 3.6
  namespace  = "monitoring"
  wait       = true
  timeout    = 600
  values     = [file("${path.module}/loki-values.yaml")]

  depends_on = [helm_release.kube_prometheus_stack] # creates the namespace
}

// Log collector: tails every pod's logs through the Kubernetes API and pushes them to Loki
resource "helm_release" "alloy" {
  name       = "alloy"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = "1.15.0" # Alloy v1.21
  namespace  = "monitoring"
  wait       = true
  timeout    = 600
  values     = [file("${path.module}/alloy-values.yaml")]

  depends_on = [helm_release.loki]
}
