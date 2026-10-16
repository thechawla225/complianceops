# 0010. Plan on push, apply and destroy only by manual dispatch

- **Status:** Accepted
- **Date:** 2026-10-13

## Context
Applying `non-persistent` starts billing (EKS control plane, NAT gateway, nodes), and a destroy removes the whole
environment. Neither should happen as a side effect of a commit.

## Decision
- Push and pull request runs: `fmt -check`, `validate`, `plan` only.
- Apply: `workflow_dispatch` only, with a checkbox to apply only `persistent`. Followed by an automated
  cluster verification step.
- Destroy: a separate `workflow_dispatch` workflow that requires typing `destroy`, can only target
  `non-persistent`, and passes user input through `env:` to prevent shell injection.

## Alternatives considered
- **Auto-apply on merge to main:** standard for team platforms with approvals; here it would start billing on every infra commit.
- **GitHub Environments with required reviewers:** the right control for a team; adds nothing when solo.

## Consequences
- No surprise infrastructure or cost from a push.
- There is no CI path that can destroy persistent resources (state bucket, images, CI roles).
- Applying is a deliberate human action. Plan output in the run log serves as the review.
