# 0015. Keep secrets in AWS Secrets Manager, out of Terraform state, synced by External Secrets Operator

- **Status:** Proposed
- **Date:** 2026-11-06

## Context
The dev Postgres password was a Terraform `random_password` written into a `kubernetes_secret`. No password was in
Git, but the value sat in Terraform state (encrypted S3, yet readable by anyone with state access) and its only home
was a cluster that is destroyed every session. The plan called for Vault + External Secrets Operator (ESO).

## Decision
- **Store:** AWS Secrets Manager, secret `complianceops/dev/postgres` (`{"password": ...}`), created in the
  **persistent** state, so it outlives cluster rebuilds; a deleted secret's name stays reserved for its 7-30 day
  recovery window, which would break the next non-persistent apply.
- **Never in Terraform state:** the value comes from `ephemeral "aws_secretsmanager_random_password"` and is written
  with the write-only `secret_string_wo` (Terraform 1.11+, AWS provider 6.x). Neither is persisted to state or plan
  files. Rotation is a version bump (`postgres_password_version`), documented in the runbook.
- **Encryption:** the AWS-managed `aws/secretsmanager` key. Checkov CKV_AWS_149 (customer-managed key) and CKV2_AWS_57
  (automatic rotation) are skipped inline with reasons.
- **Sync:** ESO chart 2.14.0, installed by Terraform in its own namespace (ordered before Argo CD's apps, like
  Kyverno). Its controller uses IRSA role `complianceops-external-secrets`, trusted only by
  `external-secrets:external-secrets`, allowed `GetSecretValue`/`DescribeSecret` on this one secret. The policy names
  the secret ARN by pattern (`complianceops/dev/postgres-??????`) instead of a data lookup, so plans work before
  persistent has created the secret.
- **In the cluster:** `gitops/postgres` renders a namespaced `SecretStore` and an `ExternalSecret` that build the
  **same** `postgres-credentials` Secret (`POSTGRES_PASSWORD`, `DATABASE_URL`), so the postgres and transaction
  Deployments are unchanged. Fields the API server would default are written out to avoid Argo CD drift.
  Off by default (`externalSecret.enabled`), on in `values-dev.yaml`; CI's kind smoke test keeps its own Secret.

## Alternatives considered
- **Vault (+ ESO):** the original plan. Dev-mode Vault is in-memory and auto-unsealed, so it demonstrates nothing real;
  a production-grade Vault needs storage, unsealing and its own pods on small nodes. Secrets Manager is managed, uses
  IRSA (no Vault auth method to configure) and costs about $0.40 a month.
- **Customer-managed KMS key:** about $1 a month and a key policy to maintain, for no benefit on a dev password. The
  production answer if key access must be audited or separated from Secrets Manager access.
- **Secrets Store CSI driver (mount as files):** avoids a Kubernetes Secret entirely, but the transaction app reads
  `DATABASE_URL` from its environment, and the postgres image expects a file path from a Secret volume today.
- **Keep the Terraform-generated Secret:** the value stays in state and dies with every cluster.

## Consequences
- No credential value in Git, Terraform state, plan output or CI logs. The Kubernetes Secret still exists in the
  cluster (base64, readable with RBAC on Secrets in the namespace): that's the boundary ESO leaves.
- New pods on every cluster: ESO controller, webhook and cert-controller.
- First boot: postgres can start before the Secret exists (`CreateContainerConfigError`), then recovers; the
  ExternalSecret's Argo CD health check makes the post-apply verification wait for it.
- Rotation is manual and needs a restart of postgres and transaction; automatic rotation would need a Lambda.
- The secret must exist before the cluster's apps start, which Terraform Apply guarantees (persistent before
  non-persistent).
