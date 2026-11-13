# Backend configuration for the production account (222222222222).
bucket       = "acme-tfstate-222222222222"
key          = "bootstrap/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
kms_key_id   = "alias/acme-terraform-state"
use_lockfile = true
