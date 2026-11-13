output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider used by every CI role in this account."
  value       = local.oidc_provider_arn
}

output "permission_boundary_arn" {
  description = "ARN of the permission boundary attached to apply roles. Roles created by CI must use it."
  value       = aws_iam_policy.permission_boundary.arn
}

output "plan_role_arns" {
  description = "Map of repository to read-only plan role ARN. Set as aws-role-arn in the caller workflow."
  value       = { for repo, role in aws_iam_role.plan : repo => role.arn }
}

output "apply_role_arns" {
  description = "Map of repository to apply role ARN. Set as aws-apply-role-arn in the caller workflow."
  value       = { for repo, role in aws_iam_role.apply : repo => role.arn }
}
