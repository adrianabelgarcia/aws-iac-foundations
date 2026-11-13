# VPC endpoints keep AWS API traffic off the NAT gateways.
# S3 is a gateway endpoint (free). The rest are interface endpoints with private DNS.

locals {
  interface_services = ["ecr.api", "ecr.dkr", "logs", "ssm", "ssmmessages", "ec2messages", "sts"]

  interface_endpoints = {
    for svc in local.interface_services : replace(svc, ".", "-") => {
      service_endpoint    = "com.amazonaws.${var.region}.${svc}"
      service_type        = "Interface"
      private_dns_enabled = true
    }
  }

  gateway_endpoints = {
    s3 = {
      service_endpoint = "com.amazonaws.${var.region}.s3"
      service_type     = "Gateway"
      route_table_ids  = module.vpc.private_route_table_ids
    }
  }
}

module "endpoints" {
  #checkov:skip=CKV_TF_1: The Terraform Registry does not expose commit hashes. The submodule is pinned by the same version range as the root module (~> 6.7).
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 6.7"

  region     = var.region
  vpc_id     = module.vpc.vpc_id
  subnet_ids = local.endpoint_subnet_ids

  create_security_group      = true
  security_group_name_prefix = "${var.name}-vpce-"
  security_group_description = "Interface VPC endpoints: HTTPS from inside the VPC only"

  security_group_rules = {
    https_from_vpc = {
      type        = "ingress"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [var.cidr_block]
      description = "HTTPS from the VPC CIDR"
    }
  }

  endpoints = merge(local.gateway_endpoints, local.interface_endpoints)

  tags = var.tags
}
