Set-Location $PSScriptRoot


Set-Location (Join-Path $PSScriptRoot "persistent")
terraform init -input=false
terraform apply -auto-approve

Set-Location (Join-Path $PSScriptRoot "non-persistent")
terraform init -input=false

# Single apply: addon ordering (before_compute / depends_on) lives in main.tf now
terraform apply -var="create_node_group=true" -auto-approve

Set-Location $PSScriptRoot
