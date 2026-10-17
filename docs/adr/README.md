# Architecture Decision Records

Each record captures one significant decision: the context, what was decided, the alternatives, and the
consequences. Records are never edited to change a past decision. A new ADR supersedes the old one.
Start new records from [the template](0000-template.md).

| # | Decision | Status |
|---|---|---|
| [0001](0001-split-terraform-state-persistent-non-persistent.md) | Split Terraform into persistent and non-persistent states | Accepted |
| [0002](0002-github-actions-oidc-no-static-keys.md) | Authenticate CI to AWS with GitHub OIDC, never static keys | Accepted |
| [0003](0003-s3-native-state-locking.md) | Lock Terraform state with S3 native locking (no DynamoDB) | Accepted |
| [0004](0004-eks-access-entries.md) | Grant EKS cluster access with access entries, not creator-admin | Accepted |
| [0005](0005-github-actions-for-service-ci.md) | Use GitHub Actions (not GitLab CI) for service pipelines | Accepted |
| [0006](0006-commit-sha-image-tags.md) | Tag images with the commit SHA | Accepted |
| [0007](0007-ci-bumps-gitops-image-tag.md) | CI bumps the image tag in Git instead of Argo CD Image Updater | Accepted |
| [0008](0008-argocd-installed-by-terraform.md) | Install Argo CD with Terraform in the non-persistent state | Proposed |
| [0009](0009-admin-access-for-infra-ci-role.md) | Accept AdministratorAccess for the infra CI role (for now) | Accepted risk |
| [0010](0010-plan-on-push-manual-apply.md) | Plan on push, apply and destroy only by manual dispatch | Accepted |
| [0011](0011-eks-addon-ordering-in-dependency-graph.md) | Express EKS add-on ordering in the dependency graph | Accepted |
| [0012](0012-trivy-gate-and-cosign-keyless-signing.md) | Gate images with Trivy before push and sign them with Cosign keyless | Accepted |
