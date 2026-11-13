# Read-only role used by plan jobs. Trusted for pull_request events and default-branch pushes only.
# It can read its own repository's state prefix, take lock files, and never read secret values.

data "aws_iam_policy_document" "plan_trust" {
  for_each = var.github_repositories

  statement {
    sid     = "GitHubPlanOidc"
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

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = local.plan_subjects[each.key]
    }
  }
}

data "aws_iam_policy_document" "plan_permissions" {
  for_each = var.github_repositories

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
    sid       = "ReadOwnState"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_bucket_arn}/${each.key}/*"]
  }

  # terraform plan takes a lock by writing <key>.tflock with use_lockfile = true.
  statement {
    sid       = "TakeOwnStateLock"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/${each.key}/*.tflock"]
  }

  statement {
    sid       = "DecryptOwnState"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [local.state_kms_key_arn]
  }

  # ReadOnlyAccess is broad, so secret values are explicitly denied. Plans use references, not values.
  statement {
    sid       = "DenySecretValues"
    effect    = "Deny"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "plan" {
  for_each = var.github_repositories

  name                 = "${local.ci_name_prefix}${each.key}-plan"
  description          = "Read-only Terraform plan role for ${each.key}. Trusted for pull_request and default-branch runs."
  assume_role_policy   = data.aws_iam_policy_document.plan_trust[each.key].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_read_only" {
  for_each = var.github_repositories

  role       = aws_iam_role.plan[each.key].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "plan" {
  for_each = var.github_repositories

  name   = "terraform-plan-state"
  role   = aws_iam_role.plan[each.key].id
  policy = data.aws_iam_policy_document.plan_permissions[each.key].json
}
