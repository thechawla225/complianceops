# 0004. Grant EKS cluster access with access entries, not creator-admin

- **Status:** Accepted
- **Date:** 2026-10-13

## Context
`enable_cluster_creator_admin_permissions = true` grants cluster-admin only to the identity that created the
cluster. Two identities apply this config: the local IAM user and the CI role. Whichever did not create the
cluster gets `Unauthorized` on every `kubernetes_*` resource, and which one created it changes with each rebuild.

## Decision
Disable creator-admin and declare `access_entries` for both principals with `AmazonEKSClusterAdminPolicy`
(cluster scope). The CI role ARN is looked up by name (`data "aws_iam_role"`) to keep the states decoupled.

## Alternatives considered
- **`aws-auth` ConfigMap:** lives inside the cluster (chicken-and-egg to edit), a typo can lock everyone out, and it's
  invisible to IAM/EKS APIs.
- **Always apply from one identity:** fragile, and breaks local debugging.

## Consequences
- Access doesn't depend on who ran the apply; verified by running `kubectl` locally against a CI-created cluster.
- Access is managed and audited through the EKS API/CloudTrail and can be recovered through IAM.
- Both principals are full cluster admins. Scoped access policies are a later least-privilege improvement.
