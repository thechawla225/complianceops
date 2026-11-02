# 0008. Install Argo CD with Terraform in the non-persistent state

- **Status:** Accepted
- **Date:** 2026-10-14 (accepted 2026-11-02)

## Context
The cluster is destroyed and rebuilt every work session (ADR 0001). Anything installed by hand disappears with it.
The goal is that a single "Terraform Apply" run produces a cluster with every service running at the tags in Git.

## Decision
Install Argo CD with a pinned `helm_release` in `non-persistent`, together with one ApplicationSet that creates an
Application per `gitops/<service>` folder using `values-dev.yaml`, with automated sync, prune and self-heal.
The post-apply verification waits until every Application is Synced and Healthy.

## Alternatives considered
- **Install Argo CD manually after each apply:** repeated toil; drifts between sessions.
- **App-of-apps managed by Argo CD itself:** still needs Argo CD bootstrapped by something; Terraform already runs on every rebuild.
- **Push-based deploys from CI (`helm upgrade`):** rejected in ADR 0007.

## Consequences
- Rebuilds are fully automatic: cluster, Argo CD and services from one workflow run.
- Destroy cannot hang on Argo CD: the Applications carry no `resources-finalizer`, and the ApplicationSet uses
  `preserveResourcesOnDeletion`, so deleting it removes the Applications without cascading. The cluster is deleted
  anyway, so cascading deletes would only add a way to fail.
- More pods on small nodes: nodes moved to `c7i-flex.large` (29 pods per node; t3.small allowed about 11).
- Start-up order is not encoded. There are no sync waves: screening and transaction may start before redis and
  postgres, crash, and recover through Kubernetes restarts and the Application retry policy (5 retries, 10 s backoff
  doubling to 3 min). Convergence over ordering keeps every service independently deployable; the cost is a few
  restarts on first boot, which the post-apply verification tolerates (10 min wait).
- Deploy latency is bounded by Argo CD's repository poll (3 min plus jitter). A GitHub webhook would remove it once
  the Argo CD server is exposed.

## Results (2026-11-02, on EKS)
- One manual "Terraform Apply" produced a cluster with all 6 Applications Synced and Healthy.
- Merged service PR to new pod Ready: about 7 minutes, zero downtime (about 5 minutes of it was polling).
- Self-heal: scaling the gateway to 0 by hand was reverted in under 9 seconds.
- Rollback: `git revert` of the tag bump was synced in about 3m40s, with no rebuild (immutable tags stay in ECR).
- Destroy with Argo CD running completed and its verification found nothing billable left.
- Screenshots: [overview](../images/argocd-applications-overview.png),
  [resource tree](../images/argocd-transaction-resource-tree.png),
  [history and rollback](../images/argocd-gateway-history-rollback.png).
