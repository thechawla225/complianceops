# 0005. Use GitHub Actions (not GitLab CI) for service pipelines

- **Status:** Accepted
- **Date:** 2026-10-14

## Context
The original plan specified `.gitlab-ci.yml` in each service repo plus a parallel Jenkinsfile, to show existing
GitLab/Jenkins strength. All repositories live on GitHub, and the infra pipeline already runs on GitHub Actions
with OIDC to AWS. GitLab and Jenkins are already covered by daily work experience.

## Decision
Build all service CI on GitHub Actions: per-repo lint + test jobs, and a reusable workflow in the hub repo for
build → Trivy scan → push to ECR → Cosign sign → GitOps tag bump. The parallel Jenkinsfile is dropped.

## Alternatives considered
- **GitLab CI for GitHub-hosted repos:** needs repository mirroring or a paid "CI/CD for external repos" feature,
  plus a second OIDC trust setup. More moving parts and no new skill demonstrated.
- **Jenkins:** needs a self-hosted controller; duplicates existing day-job experience.

## Consequences
- One CI platform and one OIDC provider for infra and services.
- The portfolio shows GitHub Actions depth (reusable workflows, OIDC, keyless signing) alongside GitLab/Jenkins
  experience from work.
- The original plan document must be updated so the portfolio matches what was built.
