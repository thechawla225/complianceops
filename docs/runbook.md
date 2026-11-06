# Runbook

Day-to-day operations for the dev environment. Region `us-west-2`, cluster `complianceops-eks`,
apps in namespace `sanctions-platform`, Argo CD in namespace `argocd`.

## Bring the platform up
1. GitHub → Actions → **Terraform Apply** → Run workflow (leave "apply non-persistent" ticked).
2. Wait for green (about 20–25 min). The run fails unless the cluster works **and** every Argo CD Application is
   Synced and Healthy; the job summary shows the apps and pods.
3. Connect locally: `aws eks update-kubeconfig --name complianceops-eks --region us-west-2`

Billing starts here (EKS control plane, NAT gateway, nodes). Bring it down when you stop working.

## Bring the platform down
1. GitHub → Actions → **Terraform Destroy** → type `destroy`.
2. The last step must print `OK: no ...` for every check (state, cluster, NAT, VPC, Elastic IPs, load balancers,
   unattached volumes). If any check fails, delete the listed resource in the console and re-run destroy.

Only `non-persistent` is destroyed. ECR images, SQS and the state bucket stay (ADR 0001).

## Deploy a service change
Merge a PR in the service repo. CI tests, scans, signs and pushes the image, then commits the new tag to
`gitops/<service>/values-dev.yaml` in this repo. Argo CD picks it up within about 3–5 minutes.
Never `helm upgrade` or `kubectl apply` by hand: Argo CD's self-heal reverts it.

## Roll back a service
Revert the tag-bump commit in this repo, through a PR:
```bash
git revert --no-commit <tag-bump-sha>
git commit -m "deploy(<service>): roll back dev to <old-tag>"
```
(`revert:` is not an allowed commit type, hence `--no-commit`.) Argo CD syncs the old tag; no rebuild is needed
because image tags are immutable and stay in ECR. `kubectl rollout undo` does not work: Git still says the new tag.

## Open the Argo CD UI
```powershell
kubectl -n argocd port-forward svc/argocd-server 8080:443
# second window: admin password
$p = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p))
```
Open https://localhost:8080 and log in as `admin`.

## Rotate the dev Postgres password
1. In `AWS-Configuration/persistent/secrets.tf`, bump `postgres_password_version` (1 -> 2) and merge.
2. Run Terraform Apply (persistent). Secrets Manager generates a new password; it never appears in state or the plan.
3. External Secrets picks it up within `refreshInterval` (1h). To apply it now:
   `kubectl -n sanctions-platform annotate externalsecret postgres-credentials force-sync=$(date +%s) --overwrite`
4. Restart both consumers: `kubectl -n sanctions-platform rollout restart deploy/postgres deploy/transaction`.
   Dev data is an emptyDir, so Postgres re-initialises with the new password.

## Troubleshooting
| Symptom | Check | Fix |
|---|---|---|
| App **OutOfSync** | `kubectl -n argocd get application <app> -o jsonpath='{.status.conditions}'` | Usually a chart that fails to render; fix the chart in Git. Hand edits are reverted by self-heal. |
| App **Degraded** | `kubectl -n sanctions-platform get pods`, then `logs` / `describe pod` | Bad image or config: fix forward, or roll back (above). |
| screening/transaction restarting on first boot | Redis/Postgres not ready yet | Expected (no start-up ordering, ADR 0008); settles within a few minutes. |
| No Applications after apply | `kubectl -n argocd get applicationset services -o jsonpath='{.status.conditions}'` | Wrong repo path or branch in `argocd-apps-values.yaml`. |
| Apply fails with `namespaces is forbidden` | Access entry not propagated yet | Handled by `time_sleep.eks_access_propagation` (30 s); if it recurs, re-run apply and raise the duration. |
| Destroy fails with `Unauthorized` | EKS token expired mid-run (~15 min) | Re-run destroy; it continues where it stopped. |
| Apply fails with `AlreadyExists` | Leftovers from a cancelled run, not in state | Find and delete them (cluster, NAT, EIP, KMS alias, log group, VPC), then re-run. Never cancel an apply mid-run. |
| postgres `CreateContainerConfigError`: secret "postgres-credentials" not found | `kubectl -n sanctions-platform get externalsecret,secretstore` (READY / STATUS) | On first boot it appears within seconds. If the store isn't Ready: the External Secrets IRSA role or the secret name (`complianceops/dev/postgres`, created by persistent). |
