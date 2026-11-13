# These tests run fully offline. mock_provider replaces the AWS API, so nothing is created
# and no credentials are needed. They verify the wrapper's decisions, not AWS behaviour.

mock_provider "aws" {
  # Policy documents are rendered by the provider; the mock needs a syntactically valid default.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  # Downstream resources validate ARN syntax, so mocked ARNs must be well-formed.
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111111111111:role/mock-role"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::111111111111:policy/mock-policy"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:111111111111:log-group:/mock/flow-logs"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-east-1:111111111111:key/11111111-2222-3333-4444-555555555555"
    }
  }
}

variables {
  name               = "platform-test"
  environment        = "staging"
  region             = "us-east-1"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  cidr_block         = "10.20.0.0/16"
  tags = {
    Project = "aws-iac-foundations"
  }
}

run "non_prod_uses_single_nat_and_one_endpoint_subnet" {
  command = apply

  assert {
    condition     = length(output.nat_gateway_ids) == 1
    error_message = "Non-prod must run a single NAT gateway to control cost."
  }

  assert {
    condition     = length(output.interface_endpoint_subnet_ids) == 1
    error_message = "Non-prod must place interface endpoints in a single subnet."
  }

  assert {
    condition     = length(output.private_subnet_ids) == 3 && length(output.public_subnet_ids) == 3
    error_message = "Three AZs must yield three private and three public subnets."
  }

  assert {
    condition     = output.flow_log_kms_key_arn != null
    error_message = "A flow log KMS key must be created when none is supplied."
  }
}

run "prod_uses_nat_and_endpoints_per_az" {
  command = apply

  variables {
    environment = "prod"
  }

  assert {
    condition     = length(output.nat_gateway_ids) == 3
    error_message = "Prod must run one NAT gateway per AZ."
  }

  assert {
    condition     = length(output.interface_endpoint_subnet_ids) == 3
    error_message = "Prod must place interface endpoints in every private subnet."
  }
}

run "endpoints_cover_s3_ecr_sts_ssm_and_logs" {
  command = apply

  assert {
    condition = alltrue([
      for k in ["s3", "ecr-api", "ecr-dkr", "sts", "ssm", "ssmmessages", "ec2messages", "logs"] :
      contains(keys(output.vpc_endpoint_ids), k)
    ])
    error_message = "The wrapper must create S3, ECR (api and dkr), STS, SSM (three endpoints) and CloudWatch Logs endpoints."
  }

  assert {
    condition     = length(output.vpc_endpoint_ids) == 8
    error_message = "Exactly eight endpoints are expected: one gateway and seven interface endpoints."
  }
}

run "supplied_kms_key_is_used_without_creating_one" {
  command = apply

  variables {
    flow_log_kms_key_arn = "arn:aws:kms:us-east-1:111111111111:key/11111111-2222-3333-4444-555555555555"
  }

  assert {
    condition     = output.flow_log_kms_key_arn == "arn:aws:kms:us-east-1:111111111111:key/11111111-2222-3333-4444-555555555555"
    error_message = "A supplied KMS key must be used for flow logs."
  }
}

run "rejects_cidr_that_is_not_a_slash_16" {
  command = plan

  variables {
    cidr_block = "10.20.0.0/20"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_public_cidr_range" {
  command = plan

  variables {
    cidr_block = "8.8.0.0/16"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_two_availability_zones" {
  command = plan

  variables {
    availability_zones = ["us-east-1a", "us-east-1b"]
  }

  expect_failures = [var.availability_zones]
}

run "rejects_duplicate_availability_zones" {
  command = plan

  variables {
    availability_zones = ["us-east-1a", "us-east-1a", "us-east-1b"]
  }

  expect_failures = [var.availability_zones]
}

run "rejects_unsupported_flow_log_retention" {
  command = plan

  variables {
    flow_log_retention_days = 42
  }

  expect_failures = [var.flow_log_retention_days]
}
