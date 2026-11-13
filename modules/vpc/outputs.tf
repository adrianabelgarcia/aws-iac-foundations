output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Primary IPv4 CIDR of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, one per AZ, in the order of availability_zones."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private workload subnets, one per AZ, in the order of availability_zones."
  value       = module.vpc.private_subnets
}

output "private_route_table_ids" {
  description = "Route tables attached to the private subnets."
  value       = module.vpc.private_route_table_ids
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs. Three in prod, one otherwise."
  value       = module.vpc.natgw_ids
}

output "nat_public_ips" {
  description = "Elastic IPs of the NAT gateways. Useful for allow-listing egress at third-party services."
  value       = module.vpc.nat_public_ips
}

output "interface_endpoint_subnet_ids" {
  description = "Subnets that host the interface endpoints. All private subnets in prod, one in other environments."
  value       = local.endpoint_subnet_ids
}

output "interface_endpoint_security_group_id" {
  description = "Security group attached to interface endpoints. Allows HTTPS from the VPC CIDR only."
  value       = module.endpoints.security_group_id
}

output "vpc_endpoint_ids" {
  description = "Map of endpoint key (for example s3, ecr-api, ssm) to VPC endpoint ID."
  value       = { for k, v in module.endpoints.endpoints : k => v.id }
}

output "flow_log_kms_key_arn" {
  description = "KMS key ARN that encrypts the flow log group (created or supplied)."
  value       = local.flow_log_kms_key_arn
}

output "flow_log_id" {
  description = "ID of the VPC flow log."
  value       = module.vpc.vpc_flow_log_id
}
