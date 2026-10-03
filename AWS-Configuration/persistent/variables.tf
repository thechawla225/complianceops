variable "bucket_name" {
  description = "S3 bucket for ComplianceOps Terraform remote state"
  type        = string
  default     = "complianceops-terraform-state"
}