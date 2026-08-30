@'
# complianceops

ComplianceOps is a policy-gated Kubernetes delivery platform: Terraform-provisioned
AWS infrastructure, ArgoCD-driven GitOps delivery, and Kyverno/Vault-backed compliance
guardrails for four independently deployed microservices. This repo is the hub —
infrastructure, GitOps manifests, policies, observability config, and architecture
docs live here; application code lives in the four complianceops-* service repos.


Links for the 4 services:

https://github.com/thechawla225/complianceops-gatewayservice

https://github.com/thechawla225/complianceops-transactionservice

https://github.com/thechawla225/complianceops-screeningservice

https://github.com/thechawla225/complianceops-notifierservice


'@ | Set-Content -Path README.md -Encoding utf8