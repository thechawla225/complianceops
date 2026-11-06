# 0014. Verify Cosign signatures at admission against the signing workflow's identity

- **Status:** Proposed
- **Date:** 2026-11-06

## Context
CI signs every image with Cosign keyless (ADR 0012), but nothing checked the signature before a pod ran, so an
image pushed to ECR by any other route would still deploy. Signing only pays off when something verifies it.

The signatures are cosign v3 sigstore bundles, stored in ECR as OCI referrers attached to each image digest.
The certificate in each (read from the public Rekor entry for `complianceops-gateway:a7dc2ab`) names the reusable
workflow that signed, not the calling service repo:
`https://github.com/thechawla225/complianceops/.github/workflows/service-image.yaml@refs/heads/main`,
issuer `https://token.actions.githubusercontent.com`.

## Decision
- A Kyverno `ImageValidatingPolicy` (`policies/verify-image-signatures.yaml`) matches
  `697961193772.dkr.ecr.us-west-2.amazonaws.com/complianceops-*` images in `sanctions-platform` (pods, and
  Deployments via autogen) and requires a keyless signature with **exactly** that subject and issuer, checked
  against the public Rekor log. Starts in Audit; Deny after the EKS proof (07.6).
- `mutateDigest: false`: Kyverno would otherwise rewrite tags to digests, and Argo CD would see the live Deployment
  differ from Git and stay OutOfSync.
- `verifyDigest: false`: the charts reference commit-SHA tags (ADR 0006). Safe because the ECR repos are IMMUTABLE,
  so a tag can never be re-pointed at a different image.
- Kyverno's admission controller reads ECR through IRSA: role `complianceops-kyverno-ecr-read`, trusted only by
  `system:serviceaccount:kyverno:kyverno-admission-controller`, read-only on `complianceops-*` repos.
  Background scans are off for this policy, so the reports controller needs no AWS access.
- CI (`policy-test.yaml`, job `signatures`) runs `cosign verify` with the same identity on every image tag in
  `gitops/*/values-dev.yaml`, so Git can't point at an unsigned image even before a cluster exists.

## Alternatives considered
- **Trust any GitHub Actions signature from my account (subject regex `thechawla225/.*`):** any workflow in any of my
  repos, including a PR branch, could then produce a trusted signature. Pinning the one workflow on `main` means only
  the path that also runs the Trivy gate can sign.
- **Key-based Cosign (a private key in CI secrets):** a long-lived secret to protect and rotate; keyless ties the
  signature to the workflow identity with no key to steal (the Codecov lesson).
- **Verify only in CI:** doesn't stop an image pushed or deployed outside CI; admission is the point every path passes.
- **Leave digest mutation on and make Argo CD ignore image fields:** hides real drift in the field that matters most.

## Consequences
- Only images built by `service-image.yaml` on `main`, after the Trivy gate, can run, once the policy is in Deny.
- Each admission of an app pod makes registry and Rekor calls; Kyverno caches results. A Sigstore or ECR outage
  would block new pods in Deny with `failurePolicy: Fail` (fail closed) or skip checks with `Ignore` (fail open).
  Decide in 07.6: fail closed is the compliance answer.
- Moving or renaming `service-image.yaml`, or calling it from a ref other than `main`, changes the certificate
  subject: update this policy, the CI job and this ADR together.
- A compromised signing workflow on `main` would still produce trusted signatures; branch protection and required
  reviews on the hub repo are what protect that identity.
