variable "name" {
  description = "Name of the VPC and prefix for related resources (flow logs, endpoint security group)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,40}$", var.name))
    error_message = "name must be 3-41 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment. Only prod gets one NAT gateway per AZ and interface endpoints in every AZ; other environments trade resilience for cost."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod", "shared"], var.environment)
    error_message = "environment must be one of: dev, staging, prod, shared."
  }
}

variable "region" {
  description = "AWS region of the VPC. Used to build VPC endpoint service names."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", var.region))
    error_message = "region must be a valid AWS region name, for example us-east-1."
  }
}

variable "availability_zones" {
  description = "Exactly three availability zones in var.region. The caller chooses them, which keeps the module free of data lookups."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 3 && length(distinct(var.availability_zones)) == 3
    error_message = "availability_zones must contain exactly three distinct zones."
  }

  validation {
    condition     = alltrue([for az in var.availability_zones : can(regex("^[a-z]{2}(-[a-z]+)+-[0-9][a-z]$", az))])
    error_message = "every entry must be an availability zone name such as us-east-1a."
  }
}

variable "cidr_block" {
  description = "IPv4 CIDR of the VPC. Must be a /16 inside an RFC 1918 range so that the module can carve /20 private and /24 public subnets deterministically."
  type        = string

  validation {
    condition     = can(regex("/16$", var.cidr_block)) && can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 /16 CIDR."
  }

  validation {
    condition     = can(regex("^(10\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|192\\.168\\.)", var.cidr_block))
    error_message = "cidr_block must be inside an RFC 1918 range (10/8, 172.16/12 or 192.168/16)."
  }
}

variable "flow_log_retention_days" {
  description = "Retention for VPC flow logs in CloudWatch Logs. Must be a value CloudWatch accepts."
  type        = number
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_log_retention_days)
    error_message = "flow_log_retention_days must be a retention period CloudWatch Logs supports, such as 90, 365 or 731."
  }
}

variable "flow_log_kms_key_arn" {
  description = "ARN of a customer managed KMS key for the flow log group. When null, the module creates a key with rotation enabled."
  type        = string
  default     = null

  validation {
    condition     = var.flow_log_kms_key_arn == null || can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/", var.flow_log_kms_key_arn))
    error_message = "flow_log_kms_key_arn must be null or a KMS key ARN."
  }
}

variable "tags" {
  description = "Tags applied to every resource in the module, in addition to provider default_tags."
  type        = map(string)
  default     = {}
}
