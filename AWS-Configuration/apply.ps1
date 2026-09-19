Set-Location $PSScriptRoot
# Run first befrore prompting creation of the eks_node_group
terraform apply -var="create_node_group=false" -auto-approve

# Run by creation of the eks_node_group
terraform apply -var="create_node_group=true" -auto-approve