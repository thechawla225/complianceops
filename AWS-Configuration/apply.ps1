Set-Location $PSScriptRoot


Set-Location (Join-Path $PSScriptRoot "persistent")
terraform init -input=false
terraform apply -auto-approve

Set-Location (Join-Path $PSScriptRoot "non-persistent")
terraform init -input=false

# Run first before prompting creation of the eks_node_group
terraform apply -var="create_node_group=false" -auto-approve

# Run by creation of the eks_node_group
terraform apply -var="create_node_group=true" -auto-approve

Set-Location $PSScriptRoot