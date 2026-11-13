output "state_bucket_name" {
  description = "Name of the Terraform state bucket. Consumers reference it in backend.hcl."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state bucket. Used by github-oidc to scope state access."
  value       = aws_s3_bucket.state.arn
}

output "state_kms_key_arn" {
  description = "ARN of the CMK that encrypts state objects and lock files."
  value       = aws_kms_key.state.arn
}

output "state_kms_alias" {
  description = "Alias of the state CMK. Set as kms_key_id in backend.hcl."
  value       = aws_kms_alias.state.name
}

output "access_logs_bucket_name" {
  description = "Bucket that receives S3 server access logs for the state bucket."
  value       = aws_s3_bucket.access_logs.id
}

output "locking_strategy" {
  description = "State locking mechanism. S3 native lock files, no DynamoDB table (requires Terraform >= 1.10)."
  value       = "s3-native (use_lockfile = true)"
}
