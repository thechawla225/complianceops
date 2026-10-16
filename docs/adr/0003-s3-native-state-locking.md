# 0003. Lock Terraform state with S3 native locking (no DynamoDB)

- **Status:** Accepted
- **Date:** 2026-10-13

## Context
Both states are applied from two places: CI and, occasionally, a local machine. Concurrent writes would
corrupt state.

## Decision
Use the S3 backend with `use_lockfile = true` (Terraform ≥ 1.11), which writes a `<key>.tflock` object using
S3 conditional writes, plus `encrypt = true`. In CI, both Terraform workflows share one GitHub `concurrency`
group with `cancel-in-progress: false`, so runs queue instead of racing or being cancelled mid-apply.

## Alternatives considered
- **DynamoDB lock table:** the long-standing approach, now deprecated in the S3 backend; one more resource to manage.
- **CI concurrency only:** doesn't protect against a local run happening at the same time as a CI run.

## Consequences
- Locking works for every client, local and CI.
- Terraform must be ≥ 1.11 everywhere. CI is pinned to the version that last wrote the state (1.16.2), because
  older binaries refuse to read state written by newer ones.
