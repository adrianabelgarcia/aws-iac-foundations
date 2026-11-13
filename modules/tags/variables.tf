variable "project" {
  description = "Project or product name. Emitted as the Project tag and used as the primary cost allocation dimension."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,38}[a-z0-9]$", var.project))
    error_message = "project must be 3-40 characters: lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "environment" {
  description = "Deployment environment. Emitted as the Environment tag."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod", "shared"], var.environment)
    error_message = "environment must be one of: dev, staging, prod, shared."
  }
}

variable "owner" {
  description = "Owning team, not an individual. Emitted as the Owner tag. Email addresses are rejected so that tags never contain personal data."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,62}[a-z0-9]$", var.owner))
    error_message = "owner must be a team slug (lowercase letters, digits, hyphens). Email addresses and person names are not allowed."
  }
}

variable "cost_center" {
  description = "Finance cost center code, for example PLAT-1024. Emitted as the CostCenter tag."
  type        = string

  validation {
    condition     = can(regex("^[A-Z]{2,4}-[0-9]{4,6}$", var.cost_center))
    error_message = "cost_center must match the format ABC-1234 (2-4 uppercase letters, dash, 4-6 digits)."
  }
}

variable "data_classification" {
  description = "Data sensitivity of the workload. Emitted as the DataClassification tag."
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "repository" {
  description = "Source repository in owner/name form. Emitted as the Repository tag when non-empty, so resources can be traced back to code."
  type        = string
  default     = ""

  validation {
    condition     = var.repository == "" || can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.repository))
    error_message = "repository must be empty or in owner/name form."
  }
}

variable "extra_tags" {
  description = "Additional tags. Reserved keys are rejected so the standard set cannot be overridden."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k in keys(var.extra_tags) :
      !contains(["Project", "Environment", "Owner", "CostCenter", "DataClassification", "ManagedBy", "Repository"], k)
    ])
    error_message = "extra_tags must not set a reserved key (Project, Environment, Owner, CostCenter, DataClassification, ManagedBy, Repository)."
  }

  validation {
    condition     = length(var.extra_tags) <= 20
    error_message = "extra_tags may contain at most 20 entries."
  }
}
