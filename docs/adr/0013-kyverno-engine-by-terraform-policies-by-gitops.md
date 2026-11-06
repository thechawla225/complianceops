# 0013. Install Kyverno with Terraform and deliver its policies with Argo CD

- **Status:** Proposed
- **Date:** 2026-11-06

## Context
CI already scans (Trivy, Checkov) and signs (Cosign) images, but it only protects what goes through CI. A manual
`kubectl apply`, an image pushed straight to ECR or a chart change that drops limits reaches the cluster unchecked,
and nothing verifies the Cosign signature at deploy time. Guardrails have to be enforced at admission, the one point
every deploy path passes.

The cluster is rebuilt every session (ADR 0001), and Argo CD starts deploying apps as soon as Terraform installs it
(ADR 0008). The admission webhook must be running before the first app pod is created, or those pods are never checked.

## Decision
- **Engine:** Kyverno, installed by a pinned `helm_release` in `non-persistent` (chart 3.9.2, Kyverno v1.19.2), in its
  own `kyverno` namespace. Argo CD's `argocd_apps` release depends on it, so the webhook is Ready before any
  Application exists; on destroy the order reverses.
- **Policies:** plain YAML in `policies/` at the repo root, synced by a separate Argo CD Application (`policies`) with
  prune and self-heal. A policy change is a reviewed PR with an audit trail, like any deploy.
- **Policy API:** the CEL-based `policies.kyverno.io/v1` types (`ValidatingPolicy`, later `ImageValidatingPolicy`).
  `kyverno.io/v1` `ClusterPolicy` is deprecated as of Kyverno 1.19.
- **Rollout:** every policy starts in `Audit` (violations recorded in PolicyReports) and moves to `Deny` once the reports
  for the current charts are clean.
- **Scope:** policies match the `sanctions-platform` namespace. The webhooks skip `kube-system`, `kyverno` and `argocd`.
- **Baseline policies (07.2):** `disallow-latest-tag`, `require-resource-limits`, `require-non-root` (non-root,
  no privilege escalation, not privileged) and `restrict-image-registries`. Each also checks Deployments (autogen):
  the namespace LimitRange injects default limits into pods, so only the Deployment shows the chart as written.
- **Third-party images:** service images must come from this account's `complianceops-*` ECR repositories. The two
  official datastore images (postgres, redis) are allow-listed by **exact digest** and pinned to the same digest in
  their charts, because Docker Hub tags are mutable. Mirroring them into ECR (an ECR pull-through cache) would also
  remove the Docker Hub dependency and let our scanning cover them; that's the production answer, but for a dev
  cluster pulling two images per session it isn't worth a mirroring pipeline yet.
- **Tests (07.3):** `policy-test.yaml` runs `kyverno test` on good and bad cases in `tests/policies/` (outside
  `policies/`, so Argo CD never deploys test resources) and `kyverno apply` on every chart rendered with
  `values-dev.yaml`. A policy moves to `Deny` only when both are green.

## Alternatives considered
- **OPA Gatekeeper:** policies in Rego, a separate language to learn and review; no built-in image signature
  verification. Kyverno policies are Kubernetes YAML with CEL expressions, the same CEL as Kubernetes'
  ValidatingAdmissionPolicy.
- **Kubernetes ValidatingAdmissionPolicy only:** built in and no extra pods, but no image signature verification and
  no policy reports.
- **Kyverno installed by Argo CD:** keeps everything in GitOps, but the ordering between the engine and the apps
  can't be expressed across independent Applications without app-of-apps and sync waves, and a leftover webhook
  could block namespace deletion on destroy. Terraform already orders platform components (ADR 0008).
- **Policies in a Helm chart under `gitops/`:** the ApplicationSet would deploy it into `sanctions-platform` like a
  service and count it as one; policies are cluster-scoped platform config, not a service.

## Consequences
- Every rebuilt cluster comes up with the guardrails already active, before the apps.
- About 3 more pods (admission, background, reports controllers); the cleanup controller is disabled. The EKS module's
  node security group already allows the control plane to reach webhooks on 9443.
- If Kyverno is down, admission falls back to the webhook failure policy. In `Audit` nothing is blocked; before moving
  policies to `Deny`, decide fail-open versus fail-closed per policy.
- The post-apply check (`verify apps`) waits for the `policies` Application to be Synced and Healthy with the rest.
- Planned in the same phase: the remaining baseline policies (07.2), `kyverno test` in CI (07.3), Cosign verification
  at admission with `mutateDigest: false` so Argo CD doesn't see tag-to-digest drift (07.4), External Secrets Operator
  with AWS Secrets Manager (07.5).
