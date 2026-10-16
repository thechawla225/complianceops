# 0006. Tag images with the commit SHA

- **Status:** Accepted
- **Date:** 2026-10-14

## Context
Images were pushed as a floating `dev-latest` tag. ECR repos are `IMMUTABLE`, so every push needed a
delete-then-push workaround. Nodes cached the old image under the same tag (`IfNotPresent`), and nothing recorded
which source code was running.

## Decision
Tag every image with the 7-character commit SHA of the service repo that produced it. Never overwrite a tag. If
the tag already exists in ECR, the build is skipped. Builds from a working tree with uncommitted changes are refused.

## Alternatives considered
- **Floating tags (`latest`, `dev-latest`):** not reproducible; fights immutability; stale node caches.
- **Semantic versions:** useful for releases, but needs a release process; can be added on top of SHA tags later.
- **Image digests only:** exact, but unreadable in values files and logs.

## Consequences
- Every running pod maps to an exact commit; rollback means pointing at the previous SHA.
- ECR immutability now works *for* us instead of against us.
- `pullPolicy: IfNotPresent` is safe, because a new tag can never be a stale cached copy.
