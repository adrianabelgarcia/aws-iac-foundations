aws_region            = "us-east-1"
expected_account_id   = "111111111111"
organization          = "acme"
github_owner          = "adrianabelgarcia"
github_default_branch = "main"
environment           = "shared"
project               = "aws-iac-foundations"
owner                 = "platform-sre"
cost_center           = "PLAT-1000"
repository            = "adrianabelgarcia/aws-iac-foundations"

# One plan role and one apply role per consuming repository.
github_repositories = {
  "aws-eks-platform" = {
    environments = ["staging", "prod"]
  }
  "aws-ecs-fargate-service" = {
    environments = ["staging", "prod"]
  }
  "aws-ec2-asg-golden-ami" = {
    environments = ["staging", "prod"]
  }
}
