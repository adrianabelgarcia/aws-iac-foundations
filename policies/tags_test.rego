package foundations.tags_test

import rego.v1

import data.foundations.tags

standard := {
	"Project": "aws-eks-platform",
	"Environment": "prod",
	"Owner": "platform-sre",
	"CostCenter": "PLAT-1024",
	"DataClassification": "internal",
	"ManagedBy": "terraform",
}

resource_with(tags_all) := {"resource_changes": [{
	"mode": "managed",
	"type": "aws_vpc",
	"address": "module.vpc.aws_vpc.this[0]",
	"change": {"actions": ["create"], "after": {"tags_all": tags_all}, "after_unknown": {}},
}]}

test_standard_tags_pass if {
	count(tags.deny) == 0 with input as resource_with(standard)
}

test_missing_cost_center_is_denied if {
	result := tags.deny with input as resource_with(object.remove(standard, ["CostCenter"]))
	count(result) == 1
}

test_empty_owner_is_denied if {
	result := tags.deny with input as resource_with(object.union(standard, {"Owner": ""}))
	count(result) == 1
}

test_null_tag_value_is_denied if {
	result := tags.deny with input as resource_with(object.union(standard, {"ManagedBy": null}))
	count(result) == 1
}

test_resources_without_tags_all_are_ignored if {
	count(tags.deny) == 0 with input as {"resource_changes": [{
		"mode": "managed",
		"type": "aws_s3_bucket_policy",
		"address": "aws_s3_bucket_policy.x",
		"change": {"actions": ["create"], "after": {"policy": "{}"}, "after_unknown": {}},
	}]}
}

test_unknown_tags_are_skipped_until_known if {
	count(tags.deny) == 0 with input as {"resource_changes": [{
		"mode": "managed",
		"type": "aws_vpc",
		"address": "aws_vpc.x",
		"change": {"actions": ["create"], "after": {"tags_all": null}, "after_unknown": {"tags_all": true}},
	}]}
}
