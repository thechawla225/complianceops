# 0002. Authenticate CI to AWS with GitHub OIDC, never static keys

- **Status:** Accepted
- **Date:** 2026-10-03

## Context
Pipelines need AWS access to run Terraform and push images. Long-lived IAM user keys stored as CI secrets can leak,
don't expire, and are hard to audit or rotate.

## Decision
Register `token.actions.githubusercontent.com` as an IAM OIDC provider. Workflows request a short-lived JWT
(`id-token: write`) and exchange it for temporary credentials via `AssumeRoleWithWebIdentity`.
Trust policies pin the `aud` claim to `sts.amazonaws.com` and the `sub` claim to specific repositories using
GitHub's **immutable subject** format (`repo:<owner>@<owner_id>/<repo>@<repo_id>:...`), which cannot be
reused if a repository or account is renamed or deleted.

## Alternatives considered
- **IAM user access keys in GitHub secrets:** long-lived credentials and a leak risk.
- **Name-based `sub` (`repo:owner/repo:*`):** vulnerable to name squatting after renames. Also didn't match,
  because the repos have the immutable subject enabled; this caused the first CI failure.

## Consequences
- No AWS credentials exist anywhere in GitHub.
- The role ARN is stored as a plain repository *variable* (it isn't a secret).
- The OIDC provider and the hub CI role had to be bootstrapped once with local credentials: CI cannot create the
  role it needs in order to log in, and cannot fix its own trust policy.
