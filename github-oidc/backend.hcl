# Backend configuration for the staging account (111111111111).
bucket       = "acme-tfstate-111111111111"
key          = "github-oidc/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
kms_key_id   = "alias/acme-terraform-state"
use_lockfile = true
