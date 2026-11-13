data "aws_iam_policy_document" "state_key" {
  #checkov:skip=CKV_AWS_109: In a KMS key policy, "*" means this key. The statement delegates administration to the account root, the standard key policy.
  #checkov:skip=CKV_AWS_111: Same as above. Day-to-day use is granted by IAM identity policies in github-oidc, not by this key policy.
  #checkov:skip=CKV_AWS_356: Same as above. The resource "*" in a KMS key policy is restricted to this key by definition.
  statement {
    sid       = "AccountRootAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    # In a KMS key policy, "*" means "this key". Day-to-day access is granted through IAM
    # identity policies (see github-oidc), so the key policy only delegates to the account.
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }
}

resource "aws_kms_key" "state" {
  description             = "Encrypts Terraform state and lock objects for ${var.organization}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.state_key.json

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "state" {
  name          = "alias/${var.organization}-terraform-state"
  target_key_id = aws_kms_key.state.key_id
}
