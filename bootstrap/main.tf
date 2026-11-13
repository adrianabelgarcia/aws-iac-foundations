# Bootstrap root: the Terraform state backend for one AWS account.
#
# Creates: a customer managed KMS key, the state bucket (versioned, SSE-KMS, TLS-only,
# lifecycle-managed) and a dedicated access log bucket. Locking uses S3 native lock files
# (use_lockfile = true), so no DynamoDB table is needed. See docs/adr/0001.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id        = data.aws_caller_identity.current.account_id
  partition         = data.aws_partition.current.partition
  state_bucket_name = "${var.organization}-tfstate-${local.account_id}"
  access_logs_name  = "${local.state_bucket_name}-access-logs"
  state_bucket_arn  = "arn:${local.partition}:s3:::${local.state_bucket_name}"
}

module "tags" {
  source = "../modules/tags"

  project             = var.project
  environment         = var.environment
  owner               = var.owner
  cost_center         = var.cost_center
  data_classification = "confidential"
  repository          = var.repository
}
