variable "aws_region" {
  description = "AWS region of the provider. The permission boundary denies every regional action outside this region."
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
  description = "Short organization identifier. Prefixes every CI role and policy (<organization>-gha-*) and locates the state bucket and KMS alias."
  type        = string
  default     = "acme"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,15}$", var.organization))
    error_message = "organization must be 2-16 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repositories allowed to assume the CI roles."
  type        = string
  default     = "adrianabelgarcia"

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{1,39}$", var.github_owner))
    error_message = "github_owner must be a valid GitHub owner name."
  }
}

variable "github_default_branch" {
  description = "Default branch. Push runs on this branch may assume the read-only plan role so that apply has a plan to consume."
  type        = string
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]{1,100}$", var.github_default_branch))
    error_message = "github_default_branch must be a valid git branch name."
  }
}

variable "github_repositories" {
  description = "Map of repository name to the GitHub environments whose jobs may assume its apply role. Each repository gets exactly one plan role and one apply role."
  type = map(object({
    environments = list(string)
  }))

  validation {
    condition     = alltrue([for repo in keys(var.github_repositories) : can(regex("^[A-Za-z0-9._-]{1,40}$", repo))])
    error_message = "Repository names must be 1-40 characters: letters, digits, dots, underscores or hyphens (keeps role names under the 64-character IAM limit)."
  }

  validation {
    condition = alltrue([
      for cfg in values(var.github_repositories) :
      length(cfg.environments) > 0 && alltrue([for e in cfg.environments : can(regex("^[a-z][a-z0-9-]{0,30}$", e))])
    ])
    error_message = "Every repository needs at least one environment, and environment names must be lowercase kebab-case."
  }
}

variable "create_oidc_provider" {
  description = "Create the account's GitHub OIDC provider. Set to false when another stack already owns it; the provider is then looked up."
  type        = bool
  default     = true
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
