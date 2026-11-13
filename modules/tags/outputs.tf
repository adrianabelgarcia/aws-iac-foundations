output "tags" {
  description = "Map of standard and extra tags. Pass to provider default_tags or to resource tags."
  value       = local.tags
}

output "cost_allocation_tag_keys" {
  description = "Tag keys that should be activated as cost allocation tags. Used by roots that manage aws_ce_cost_allocation_tag."
  value       = local.cost_allocation_tag_keys
}
