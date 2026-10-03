Set-Location $PSScriptRoot
Set-Location (Join-Path $PSScriptRoot "non-persistent")

terraform destroy -auto-approve

Set-Location $PSScriptRoot