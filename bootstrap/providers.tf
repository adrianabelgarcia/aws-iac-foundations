provider "aws" {
  region = var.aws_region

  # Refuse to run against any other account, even if the wrong credentials are loaded.
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = module.tags.tags
  }
}
