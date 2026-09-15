# infra/teardown.ps1
Set-Location $PSScriptRoot
terraform destroy -target module.vpc -auto-approve