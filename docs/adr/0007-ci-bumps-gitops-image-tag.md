# 0007. CI bumps the image tag in Git instead of Argo CD Image Updater

- **Status:** Accepted (implementation in progress)
- **Date:** 2026-10-14

## Context
After CI pushes a signed image, the deployed version must change without anyone running `helm upgrade` or
`kubectl`. In GitOps the desired version must live in Git.

## Decision
The final step of the service pipeline commits the new SHA into `gitops/<service>/values-dev.yaml` in the hub
repo (`deploy(<service>): dev -> <sha>`), using an SSH deploy key scoped to the hub repo only. Argo CD
(ADR 0008) syncs the cluster from Git.

## Alternatives considered
- **Argo CD Image Updater:** polls ECR and writes back to Git itself; adds an in-cluster component and ECR
  credentials, and the cluster is rebuilt every session.
- **Pipeline runs `helm upgrade` against the cluster:** push-based; CI needs cluster credentials; Git stops
  being the source of truth.
- **Personal access token for the cross-repo write:** broader scope than a single-repo deploy key, and it expires.

## Consequences
- Every deploy is a Git commit: reviewable, auditable, and revertible.
- Concurrent pipelines can race on the hub repo. Handled with `pull --rebase` retries and a per-service
  concurrency group.
- Branch protection on the hub repo must allow the deploy key to bypass the PR requirement.
