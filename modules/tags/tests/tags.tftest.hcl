variables {
  project     = "aws-eks-platform"
  environment = "prod"
  owner       = "platform-sre"
  cost_center = "PLAT-1024"
  repository  = "adrianabelgarcia/aws-eks-platform"
}

run "emits_standard_tags" {
  command = plan

  assert {
    condition     = output.tags.Project == "aws-eks-platform"
    error_message = "Project tag must mirror var.project."
  }

  assert {
    condition     = output.tags.Environment == "prod" && output.tags.Owner == "platform-sre"
    error_message = "Environment and Owner tags must mirror their inputs."
  }

  assert {
    condition     = output.tags.CostCenter == "PLAT-1024"
    error_message = "CostCenter tag must mirror var.cost_center."
  }

  assert {
    condition     = output.tags.ManagedBy == "terraform"
    error_message = "ManagedBy must always be terraform."
  }

  assert {
    condition     = output.tags.DataClassification == "internal"
    error_message = "DataClassification must default to internal."
  }

  assert {
    condition     = output.tags.Repository == "adrianabelgarcia/aws-eks-platform"
    error_message = "Repository tag must be emitted when repository is set."
  }

  assert {
    condition     = length(output.tags) == 7
    error_message = "Exactly seven standard tags are expected when repository is set."
  }
}

run "omits_repository_when_empty" {
  command = plan

  variables {
    repository = ""
  }

  assert {
    condition     = !contains(keys(output.tags), "Repository")
    error_message = "Repository must not be emitted when empty."
  }
}

run "extra_tags_are_merged" {
  command = plan

  variables {
    extra_tags = {
      Team = "sre"
    }
  }

  assert {
    condition     = output.tags.Team == "sre"
    error_message = "Non-reserved extra tags must be merged into the output."
  }
}

run "cost_allocation_keys_are_exposed" {
  command = plan

  assert {
    condition     = contains(output.cost_allocation_tag_keys, "CostCenter") && length(output.cost_allocation_tag_keys) == 4
    error_message = "Cost allocation keys must include the four FinOps dimensions."
  }
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "production"
  }

  expect_failures = [var.environment]
}

run "rejects_personal_email_as_owner" {
  command = plan

  variables {
    owner = "someone@example.com"
  }

  expect_failures = [var.owner]
}

run "rejects_malformed_cost_center" {
  command = plan

  variables {
    cost_center = "1024"
  }

  expect_failures = [var.cost_center]
}

run "rejects_reserved_extra_tag" {
  command = plan

  variables {
    extra_tags = {
      Owner = "someone-else"
    }
  }

  expect_failures = [var.extra_tags]
}

run "rejects_malformed_repository" {
  command = plan

  variables {
    repository = "not-a-repo-path"
  }

  expect_failures = [var.repository]
}

run "rejects_invalid_data_classification" {
  command = plan

  variables {
    data_classification = "secret"
  }

  expect_failures = [var.data_classification]
}
