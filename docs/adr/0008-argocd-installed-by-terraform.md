# 0008. Install Argo CD with Terraform in the non-persistent state

- **Status:** Proposed
- **Date:** 2026-10-14

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
- Argo CD Applications have finalizers; destroy ordering must remove them before the cluster, or the destroy can hang.
- More pods on small nodes. Node sizing must be revisited (t3.small allows about 11 pods per node with the VPC CNI).
