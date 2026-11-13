# Opinionated wrapper around terraform-aws-modules/vpc/aws.
#
# Design decisions (see docs/adr and README):
#   * Three AZs, /16 VPC, private /20 subnets for workloads, /24 public subnets for load balancers.
#   * NAT: one gateway per AZ in prod (no cross-AZ single point of failure), one in non-prod (cost).
#   * Default security group is emptied, so resources must declare their own rules.
#   * Flow logs are always on, encrypted with a CMK, and retained for a configurable period.
#   * Interface endpoints (ECR, STS, SSM, CloudWatch Logs) keep traffic on the AWS network.
#     Non-prod places them in one AZ to avoid paying hourly endpoint charges three times.

locals {
  is_prod = var.environment == "prod"

  private_subnet_cidrs = [for i, _ in var.availability_zones : cidrsubnet(var.cidr_block, 4, i)]
  public_subnet_cidrs  = [for i, _ in var.availability_zones : cidrsubnet(var.cidr_block, 8, 240 + i)]

  flow_log_kms_key_arn = coalesce(var.flow_log_kms_key_arn, one(aws_kms_key.flow_logs[*].arn))

  endpoint_subnet_ids = local.is_prod ? module.vpc.private_subnets : slice(module.vpc.private_subnets, 0, 1)
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

module "vpc" {
  #checkov:skip=CKV_TF_1: The Terraform Registry does not expose commit hashes. The module is pinned by an exact minor range (~> 6.7) and updated by Dependabot.
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = var.name
  cidr = var.cidr_block
  azs  = var.availability_zones

  private_subnets = local.private_subnet_cidrs
  public_subnets  = local.public_subnet_cidrs

  # Tags let the EKS cloud controller pick the right subnets for internet-facing and internal load balancers.
  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }

  map_public_ip_on_launch = false

  enable_nat_gateway     = true
  single_nat_gateway     = !local.is_prod
  one_nat_gateway_per_az = local.is_prod

  enable_dns_hostnames = true
  enable_dns_support   = true

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_destination_type                       = "cloud-watch-logs"
  flow_log_traffic_type                           = "ALL"
  flow_log_max_aggregation_interval               = 60
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_log_retention_days
  flow_log_cloudwatch_log_group_kms_key_id        = local.flow_log_kms_key_arn

  tags = var.tags
}
