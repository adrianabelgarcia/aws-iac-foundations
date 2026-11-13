# Write role used by apply jobs. Trusted only for jobs that run in a GitHub environment.
# Effective permissions are the intersection of the identity policy below and the permission boundary.

data "aws_iam_policy_document" "apply_trust" {
  for_each = var.github_repositories

  statement {
    sid     = "GitHubApplyOidc"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:repository_owner"
      values   = [var.github_owner]
    }

    # Each subject names an environment. GitHub only issues it after the environment's
    # protection rules (required reviewers, branch rules) pass, which is what gates production.
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = local.apply_subjects[each.key]
    }
  }
}

data "aws_iam_policy_document" "apply_permissions" {
  for_each = var.github_repositories

  source_policy_documents = [data.aws_iam_policy_document.iam_scoped.json]

  statement {
    sid       = "PlatformServices"
    effect    = "Allow"
    actions   = local.identity_service_actions
    resources = ["*"]
  }

  # S3 and KMS are granted everywhere except the state resources, which are handled by the next statements.
  statement {
    sid           = "ServiceBucketsAndKeysExceptState"
    effect        = "Allow"
    actions       = ["s3:*", "kms:*"]
    not_resources = concat(local.state_resources, local.state_key_resources)
  }

  statement {
    sid       = "ListOwnStatePrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${each.key}/*"]
    }
  }

  statement {
    sid       = "ReadWriteOwnState"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/${each.key}/*"]
  }

  statement {
    sid       = "UseStateKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = local.state_key_resources
  }
}

resource "aws_iam_role" "apply" {
  for_each = var.github_repositories

  name                 = "${local.ci_name_prefix}${each.key}-apply"
  description          = "Terraform apply role for ${each.key}. Trusted only for jobs in the declared GitHub environments."
  assume_role_policy   = data.aws_iam_policy_document.apply_trust[each.key].json
  permissions_boundary = aws_iam_policy.permission_boundary.arn
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "apply" {
  for_each = var.github_repositories

  name   = "terraform-apply"
  role   = aws_iam_role.apply[each.key].id
  policy = data.aws_iam_policy_document.apply_permissions[each.key].json
}
