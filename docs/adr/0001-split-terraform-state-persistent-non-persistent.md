# 0001. Split Terraform into persistent and non-persistent states

- **Status:** Accepted
- **Date:** 2026-10-03

## Context
EKS, the NAT gateway and nodes are destroyed between work sessions to control cost. With everything in one
state, an untargeted `terraform destroy` also deleted the ECR repositories (`force_delete = true`) and every
pushed image. Avoiding that required fragile `-target` lists.

## Decision
Two root modules with separate states:
- `AWS-Configuration/persistent/`: state bucket, ECR, SQS, GitHub OIDC provider and CI roles. Never destroyed.
- `AWS-Configuration/non-persistent/`: VPC, EKS, node group, IRSA roles, namespace/RBAC. Destroyed freely.

`non-persistent` reads persistent resources by name with data sources (`aws_sqs_queue`, `aws_iam_role`),
not `terraform_remote_state`, so the states stay decoupled.

## Alternatives considered
- **One state with `-target`ed destroys:** relies on remembering an exclusion list. That's how the incident happened.
- **`prevent_destroy` lifecycle on ECR:** makes a full destroy fail rather than skip the repos.
- **`terraform_remote_state`:** couples `non-persistent` to persistent's state format and needs read access to it.

## Consequences
- A plain `terraform destroy` in `non-persistent` cannot touch images, queues or CI access.
- IRSA roles must live in `non-persistent` because they trust the cluster's OIDC provider, which changes on every rebuild.
- Moving resources between states needs explicit `removed`/`import` blocks. Missing this once left the state buckets
  untracked until they were imported (2026-10-14).
