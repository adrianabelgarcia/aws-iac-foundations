# The permission boundary is the ceiling for every CI apply role and for every role those roles create.
# Effective permissions = identity policy AND boundary, so the boundary is what makes the apply role safe
# even if an identity policy is later widened by mistake.

locals {
  # Services the platform may use. The boundary allows all of them. The apply role's identity policy grants
  # the same list except S3 and KMS, which are granted per repository prefix and per state key.
  platform_service_actions = [
    "acm:*",
    "application-autoscaling:*",
    "autoscaling:*",
    "backup:*",
    "cloudwatch:*",
    "dynamodb:*",
    "ec2:*",
    "ecr:*",
    "ecs:*",
    "eks:*",
    "elasticfilesystem:*",
    "elasticloadbalancing:*",
    "events:*",
    "kms:*",
    "lambda:*",
    "logs:*",
    "rds:*",
    "resource-groups:*",
    "route53:*",
    "s3:*",
    "secretsmanager:*",
    "sns:*",
    "sqs:*",
    "ssm:*",
    "sts:GetCallerIdentity",
    "tag:*",
    "wafv2:*",
  ]

  identity_service_actions = [for a in local.platform_service_actions : a if !contains(["s3:*", "kms:*"], a)]

  # Global services that the allowlist uses. The region guardrail must exempt them. Other global services
  # are not in the allowlist, so the allow statements already deny them and they need no exemption here.
  global_service_actions = [
    "iam:*",
    "route53:*",
    "sts:*",
  ]

  ci_roles_pattern    = "${local.role_arn_prefix}:role/${local.ci_name_prefix}*"
  ci_policies_pattern = "${local.role_arn_prefix}:policy/${local.ci_name_prefix}*"
  apply_roles_pattern = "${local.role_arn_prefix}:role/${local.ci_name_prefix}*-apply"

  state_key_resources = [local.state_kms_key_arn]
  state_resources     = [local.state_bucket_arn, "${local.state_bucket_arn}/*"]
}

# Scoped IAM for the platform. Roles, policies and instance profiles must carry the organization prefix.
data "aws_iam_policy_document" "iam_scoped" {
  #checkov:skip=CKV_AWS_356: IAM Get and List actions do not accept resource ARNs, so the read statement must use "*". All write statements are scoped to the organization prefix.
  #checkov:skip=CKV_AWS_109: Same as above. Write permissions are limited to <org>-* names and to the boundary the role is attached to.
  statement {
    sid    = "ManageOrgRoles"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePermissionsBoundary",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
    ]
    resources = ["${local.role_arn_prefix}:role/${var.organization}-*"]
  }

  statement {
    sid    = "ManageOrgPolicies"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = ["${local.role_arn_prefix}:policy/${var.organization}-*"]
  }

  statement {
    sid    = "ManageOrgInstanceProfiles"
    effect = "Allow"
    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
    ]
    resources = ["${local.role_arn_prefix}:instance-profile/${var.organization}-*"]
  }

  statement {
    sid       = "PassOrgRoles"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["${local.role_arn_prefix}:role/${var.organization}-*"]
  }

  statement {
    sid       = "ServiceLinkedRoles"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["${local.role_arn_prefix}:role/aws-service-role/*"]
  }

  statement {
    sid       = "ReadIamForRefresh"
    effect    = "Allow"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "permission_boundary" {
  #checkov:skip=CKV_AWS_111: This document is a ceiling, not a grant. The allowlist is intentionally broad, and the Deny statements below are the controls.
  #checkov:skip=CKV_AWS_356: Same as above. The allowlist uses service wildcards on purpose. Region, identity, state and governance are enforced by explicit Deny statements.
  source_policy_documents = [data.aws_iam_policy_document.iam_scoped.json]

  statement {
    sid       = "AllowPlatformServices"
    effect    = "Allow"
    actions   = local.platform_service_actions
    resources = ["*"]
  }

  # Deny statements below always win over the allows above.

  statement {
    sid     = "DenyCiRoleAndBoundaryTampering"
    effect  = "Deny"
    actions = ["iam:*"]
    resources = [
      local.ci_roles_pattern,
      local.ci_policies_pattern,
    ]
  }

  # Anything this boundary is attached to, including roles created by CI, may only be created or re-bounded
  # with this exact boundary. Without it, a created role could be granted more than the apply role has.
  statement {
    sid    = "DenyRoleCreationWithoutBoundary"
    effect = "Deny"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_arn]
    }
  }

  statement {
    sid       = "DenyBoundaryRemoval"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary"]
    resources = ["*"]
  }

  statement {
    sid    = "DenyIdentityAndTrustChanges"
    effect = "Deny"
    actions = [
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:AddUserToGroup",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
      "iam:CreateOpenIDConnectProvider",
      "iam:CreateSAMLProvider",
      "iam:CreateUser",
      "iam:DeleteOpenIDConnectProvider",
      "iam:DeleteSAMLProvider",
      "iam:UpdateAccountPasswordPolicy",
      "iam:UpdateLoginProfile",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:UpdateSAMLProvider",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyGovernanceAndBilling"
    effect = "Deny"
    actions = [
      "account:*",
      "aws-portal:*",
      "billing:*",
      "organizations:*",
      "support:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenySecurityControlTampering"
    effect = "Deny"
    actions = [
      "cloudtrail:DeleteTrail",
      "cloudtrail:PutEventSelectors",
      "cloudtrail:StopLogging",
      "config:DeleteConfigurationRecorder",
      "config:DeleteDeliveryChannel",
      "config:StopConfigurationRecorder",
      "ec2:DisableEbsEncryptionByDefault",
      "guardduty:DeleteDetector",
      "guardduty:DisassociateFromAdministratorAccount",
      "s3:DeleteAccountPublicAccessBlock",
      "s3:PutAccountPublicAccessBlock",
      "securityhub:DisableSecurityHub",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyStateBucketDestruction"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:DeleteObjectVersion",
      "s3:DeletePublicAccessBlock",
      "s3:PutBucketAcl",
      "s3:PutBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:PutObjectAcl",
    ]
    resources = local.state_resources
  }

  statement {
    sid    = "DenyStateKeyDestruction"
    effect = "Deny"
    actions = [
      "kms:CreateGrant",
      "kms:DisableKey",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
    ]
    resources = local.state_key_resources
  }

  # State contains secrets. Only the apply roles may touch the state bucket or key at all.
  statement {
    sid       = "DenyStateAccessToNonApplyPrincipals"
    effect    = "Deny"
    actions   = ["s3:*", "kms:*"]
    resources = concat(local.state_resources, local.state_key_resources)

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = [local.apply_roles_pattern]
    }
  }

  statement {
    sid         = "DenyOutsideRegion"
    effect      = "Deny"
    not_actions = local.global_service_actions
    resources   = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }
}

resource "aws_iam_policy" "permission_boundary" {
  name        = local.boundary_name
  description = "Maximum permissions for CI apply roles and for any role they create. Denies IAM escalation, governance changes and state tampering."
  policy      = data.aws_iam_policy_document.permission_boundary.json
}
