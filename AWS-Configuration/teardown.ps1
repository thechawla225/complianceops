
Set-Location $PSScriptRoot
terraform destroy -target module.eks -target module.vpc -target aws_ecr_repository.services -target aws_iam_role.ebs_csi -auto-approve