# 0012. Gate images with Trivy before push and sign them with Cosign keyless

- **Status:** Accepted
- **Date:** 2026-10-17

## Context
Images were built and pushed from a laptop. Nothing scanned them for known vulnerabilities, and nothing could
prove an image in ECR came from reviewed code on `main`. The platform's promise is "signed, scanned images
only", which Kyverno will enforce at admission in Phase 07.

## Decision
In the shared `service-image.yaml` workflow:
- **Trivy scans the locally built image before `docker push`**, using
  `--severity CRITICAL --ignore-unfixed --exit-code 1`. A failure stops the job, so the image never exists in ECR.
  The Trivy version is pinned (`aquasec/trivy:0.76.0`).
- PRs run the same scan (`pr-scan` job, no AWS access) so problems show up before merge.
- **Cosign signs the pushed image by digest, keyless:** the job's GitHub OIDC token gets a short-lived Fulcio
  certificate for the workflow identity, and the signing event is recorded in Rekor. The signature is stored in
  ECR as an OCI referrer (`application/vnd.dev.sigstore.bundle.v0.3+json`).

## Alternatives considered
- **Scan after push (ECR scan-on-push, or a scheduled scan):** the vulnerable image is already in the registry and
  pullable. ECR's basic scan stays on as a second, informational signal.
- **Fail on HIGH as well, or on unfixed CVEs:** blocks on things nobody can fix yet, which trains people to bypass
  the gate. Revisit once base images are consistently clean.
- **Cosign with a stored key pair or KMS key:** a key to protect and rotate. Keyless ties the signature to the
  workflow identity, which is what admission policy will check.
- **Sign the tag:** a tag is a pointer. A digest binds the signature to exact bytes.

## Consequences
- No image reaches ECR without passing the gate, and every image in ECR is signed by the hub workflow on `main`.
  Verify with `cosign verify <image>@<digest> --certificate-identity-regexp
  '^https://github.com/thechawla225/complianceops/.github/workflows/service-image.yaml@'
  --certificate-oidc-issuer https://token.actions.githubusercontent.com`.
- Proven on the first rollout: notifier was blocked twice (Node 20 EOL base, then Debian 12 `perl-base`) and only
  pushed once it was clean.
- A newly published CRITICAL CVE can block an unrelated change. The fix is to update the base image or
  dependency, not to weaken the gate.
- Signing entries are public in Rekor (image digest and workflow identity, no source code). That's acceptable for
  a public portfolio repo, and a private Sigstore instance would be needed for internal images.
