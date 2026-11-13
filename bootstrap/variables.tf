variable "aws_region" {
  description = "AWS region that hosts the state bucket, its KMS key and the access log bucket."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region name, for example us-east-1."
  }
}

variable "expected_account_id" {
  description = "12-digit AWS account ID this root must target. Enforced by the provider's allowed_account_ids."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be a 12-digit AWS account ID."
  }
}

variable "organization" {
  description = "Short organization identifier. Prefixes the state bucket name (<organization>-tfstate-<account>) and the KMS alias."
  type        = string
  default     = "acme"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,15}$", var.organization))
    error_message = "organization must be 2-16 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days before noncurrent state object versions expire. The lifecycle rule always keeps the 10 most recent noncurrent versions."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 30 && var.noncurrent_version_expiration_days <= 365
    error_message = "noncurrent_version_expiration_days must be between 30 and 365."
  }
}

variable "access_logs_retention_days" {
  description = "Retention in days for S3 server access logs written for the state bucket."
  type        = number
  default     = 365

  validation {
    condition     = var.access_logs_retention_days >= 90 && var.access_logs_retention_days <= 3650
    error_message = "access_logs_retention_days must be between 90 and 3650."
  }
}

variable "project" {
  description = "Project name for the Project tag. Validated by modules/tags."
  type        = string
}

variable "environment" {
  description = "Environment label for the Environment tag. Validated by modules/tags."
  type        = string
}

variable "owner" {
  description = "Owning team slug for the Owner tag. Validated by modules/tags."
  type        = string
}

variable "cost_center" {
  description = "Cost center code for the CostCenter tag. Validated by modules/tags."
  type        = string
}

variable "repository" {
  description = "Source repository (owner/name) for the Repository tag. Validated by modules/tags."
  type        = string
  default     = ""
}
