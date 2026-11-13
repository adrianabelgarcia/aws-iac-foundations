data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# State bucket and key are created by bootstrap/. Looked up here so this root never needs their IDs as inputs.
data "aws_kms_alias" "state" {
  name = "alias/${var.organization}-terraform-state"
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

locals {
  account_id        = data.aws_caller_identity.current.account_id
  partition         = data.aws_partition.current.partition
  role_arn_prefix   = "arn:${local.partition}:iam::${local.account_id}"
  ci_name_prefix    = "${var.organization}-gha-"
  boundary_name     = "${local.ci_name_prefix}permission-boundary"
  boundary_arn      = "${local.role_arn_prefix}:policy/${local.boundary_name}"
  state_bucket_name = "${var.organization}-tfstate-${local.account_id}"
  state_bucket_arn  = "arn:${local.partition}:s3:::${local.state_bucket_name}"
  state_kms_key_arn = data.aws_kms_alias.state.target_key_arn

  github_oidc_host = "token.actions.githubusercontent.com"

  # Subject claims. Plan runs come from pull_request events and default-branch pushes (read-only role).
  # Apply runs come only from jobs that declare a GitHub environment; that environment's protection rules gate the token.
  plan_subjects = {
    for repo in keys(var.github_repositories) : repo => [
      "repo:${var.github_owner}/${repo}:pull_request",
      "repo:${var.github_owner}/${repo}:ref:refs/heads/${var.github_default_branch}",
    ]
  }

  apply_subjects = {
    for repo, cfg in var.github_repositories : repo => [
      for env in cfg.environments : "repo:${var.github_owner}/${repo}:environment:${env}"
    ]
  }
}
