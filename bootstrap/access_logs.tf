resource "aws_s3_bucket" "access_logs" {
  #checkov:skip=CKV2_AWS_62: No event consumers. Access logs are read by query tools on a schedule, not by event-driven code.
  #checkov:skip=CKV_AWS_144: Accepted single-region risk. Logs are regenerable and not a recovery source. Replicating them is tracked as a follow-up.
  #checkov:skip=CKV_AWS_145: S3 server access log delivery supports SSE-S3 target buckets only. The default encryption here is AES256.
  bucket        = local.access_logs_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "access_logs" {
  #checkov:skip=CKV2_AWS_65: S3 server access log delivery requires bucket ACLs, so ACLs cannot be disabled on the log target.
  bucket = aws_s3_bucket.access_logs.id

  rule {
    # S3 server access log delivery relies on bucket ACLs, so ownership is BucketOwnerPreferred
    # here instead of BucketOwnerEnforced. Every object is still owned by the bucket owner.
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket     = aws_s3_bucket.access_logs.id
  depends_on = [aws_s3_bucket_versioning.access_logs]

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.access_logs_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "access_logs_bucket" {
  statement {
    sid       = "AllowS3ServerAccessLogDelivery"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.access_logs.arn}/s3-access/*"]

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    # Only logs produced by the state bucket in this account may be delivered here.
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [local.state_bucket_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.access_logs.arn, "${aws_s3_bucket.access_logs.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = data.aws_iam_policy_document.access_logs_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.access_logs]
}
