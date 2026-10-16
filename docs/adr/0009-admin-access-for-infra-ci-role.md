# 0009. Accept AdministratorAccess for the infra CI role (for now)

- **Status:** Accepted (accepted risk, revisit)
- **Date:** 2026-10-03

## Context
The hub repo's pipeline creates VPCs, EKS clusters, IAM roles and policies, KMS keys, S3 and ECR. Hand-writing a
least-privilege policy covering all of that is large, brittle work for a single-account personal project.
Checkov flags it (CKV_AWS_274).

## Decision
Attach `AdministratorAccess` to `complianceops-github-actions-ci`, with a documented `checkov:skip`, and limit
who can use it through the trust policy instead: OIDC only, from one repository, identified by immutable IDs.
Service pipelines get a separate role that can only push to the four ECR repositories, from `main` only.

## Alternatives considered
- **Custom least-privilege policy now:** high effort; IAM creation permissions are effectively privilege
  escalation anyway, which limits the real gain.
- **Permissions boundary on roles created by CI:** the right next step; deferred.

## Consequences
- If the hub workflow were compromised, the blast radius is the whole account. Mitigated by OIDC-only trust,
  no static keys, protected `main`, and manual-dispatch-only applies.
- Revisit by scoping the policy to the services Terraform actually uses, plus a permissions boundary.
