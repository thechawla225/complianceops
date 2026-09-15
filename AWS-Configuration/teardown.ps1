# infra/teardown.ps1
Set-Location $PSScriptRoot
terraform destroy -target=module.vpc -target=module.eks -auto-approve