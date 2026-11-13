locals {
  # Standard tags. Every resource in a root that wires these into provider default_tags
  # gets the same keys, which keeps cost allocation and access reviews consistent.
  required_tags = {
    Project            = var.project
    Environment        = var.environment
    Owner              = var.owner
    CostCenter         = var.cost_center
    DataClassification = var.data_classification
    ManagedBy          = "terraform"
  }

  optional_tags = var.repository == "" ? {} : { Repository = var.repository }

  # Standard keys win over extra_tags; validation already rejects collisions.
  tags = merge(var.extra_tags, local.required_tags, local.optional_tags)

  # Keys that FinOps should activate as cost allocation tags in Billing.
  cost_allocation_tag_keys = ["Project", "Environment", "Owner", "CostCenter"]
}
