// These two buckets were created back when everything lived in one root state
// (before the persistent/non-persistent split) and never made it into
// persistent's state. Adopt them instead of letting Terraform try to create
// them again (which fails: BucketAlreadyOwnedByYou). Safe to delete this file
// once the import has been applied.

import {
  to = aws_s3_bucket.terraform-state
  id = "complianceops-terraform-state"
}

import {
  provider = aws.replica
  to       = aws_s3_bucket.terraform_state_replica
  id       = "complianceops-terraform-state-replica"
}
