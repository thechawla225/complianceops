# Contributing to ComplianceOps

These rules apply to the hub repo (`complianceops`) and all four service repos
(`complianceops-gatewayservice`, `-transactionservice`, `-screeningservice`, `-notifierservice`).

## Workflow

1. Branch from `main`: `feat/<short-name>`, `fix/<short-name>`, `ci/...`, `infra/...`, `docs/...`, `chore/...`
2. Commit in small, focused steps using [Conventional Commits](#commit-messages).
3. Open a pull request and fill in the template (What / Why / How tested / Risk & rollback).
4. Merge only when all required checks are green. `main` is protected: no direct pushes, no force-pushes.
5. Squash or rebase merge only, so `main` keeps a linear history.

## One-time setup per clone

```bash
pip install pre-commit
pre-commit install          # installs the pre-commit and commit-msg hooks
```

The hooks catch whitespace/encoding issues, invalid YAML/JSON, merge-conflict markers,
large files, secrets (gitleaks) and non-conventional commit messages before they reach CI.

## Commit messages

Format: `<type>(<optional scope>): <summary in imperative mood>`

| Type | Use for |
|---|---|
| `feat` | New behaviour in a service |
| `fix` | Bug fix |
| `infra` | Terraform / AWS changes |
| `deploy` | Changing what is deployed (image tags, Helm values) |
| `ci` | Pipelines and workflows |
| `build` | Dockerfiles, dependencies, build tooling |
| `test` | Tests only |
| `docs` | Documentation, ADRs, runbooks |
| `refactor`, `style`, `perf`, `chore` | As named |

Examples: `fix(notifier): log the underlying SQS error in the poll loop`,
`infra(eks): move ebs-csi addon after the node group`.

## Definition of done

A change is done when:

- CI is green (lint, tests, scans, `terraform plan` where relevant)
- The PR description explains *why*, not just *what*
- Any design decision is recorded as an ADR in [`docs/adr/`](docs/adr/)
- Docs and runbooks reflect the new behaviour
- Nothing is described in docs as built before it actually works (planned work is labelled *Planned*)

## Secrets and configuration

- Never commit secrets. `.env` files are git-ignored; use `.env.example` for placeholders.
- AWS access from CI uses OIDC roles, never static access keys.
- Account IDs, ARNs and other environment-specific values should come from Terraform outputs
  or a single CI variable, not be copied into multiple files.

## AI-assisted changes

AI tools (Claude Code) are used as a pair programmer on this project. The rule is simple:
**nothing is merged that the author cannot explain line by line.** Read the diff, not just the summary,
and record the reasoning for non-obvious decisions in the PR or an ADR.
