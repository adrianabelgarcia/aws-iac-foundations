terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }

  # Partial backend configuration. See bootstrap/versions.tf and README "Bootstrap sequence".
  backend "s3" {}
}
