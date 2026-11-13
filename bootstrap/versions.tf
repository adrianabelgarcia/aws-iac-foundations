terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }

  # Partial backend configuration: bucket, key, region, KMS key and locking come from backend.hcl.
  # The first apply runs with a local state file; see README "Bootstrap sequence" for the migration.
  backend "s3" {}
}
