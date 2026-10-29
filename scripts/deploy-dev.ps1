# Installs/upgrades every chart into the dev namespace, dependencies first.
# Stopgap until ArgoCD (Phase C) deploys from gitops/. Needs kubeconfig for complianceops-eks.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$charts = @("postgres", "redis", "screening", "transaction", "gateway", "notifier")

foreach ($chart in $charts) {
    Write-Host "`n=== $chart ===" -ForegroundColor Cyan
    # --wait: don't start the next chart until this one's pods are Ready
    helm upgrade --install $chart "gitops/$chart" -f "gitops/$chart/values-dev.yaml" `
        -n sanctions-platform --wait --timeout 5m
    if ($LASTEXITCODE -ne 0) { throw "$chart failed to become ready; see kubectl describe/logs" }
}

kubectl get pods -n sanctions-platform
