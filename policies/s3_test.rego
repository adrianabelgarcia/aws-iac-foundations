package foundations.s3_test

import rego.v1

import data.foundations.s3

bucket(name) := {
	"mode": "managed",
	"type": "aws_s3_bucket",
	"address": sprintf("aws_s3_bucket.%s", [name]),
	"change": {"actions": ["create"], "after": {"bucket": name}, "after_unknown": {}},
}

pab(name, attrs) := {
	"mode": "managed",
	"type": "aws_s3_bucket_public_access_block",
	"address": sprintf("aws_s3_bucket_public_access_block.%s", [name]),
	"change": {"actions": ["create"], "after": object.union({"bucket": name}, attrs), "after_unknown": {}},
}

all_blocked := {
	"block_public_acls": true,
	"block_public_policy": true,
	"ignore_public_acls": true,
	"restrict_public_buckets": true,
}

test_fully_blocked_bucket_passes if {
	count(s3.deny) == 0 with input as {"resource_changes": [bucket("data"), pab("data", all_blocked)]}
}

test_partially_blocked_bucket_is_denied if {
	result := s3.deny with input as {"resource_changes": [
		bucket("data"),
		pab("data", object.union(all_blocked, {"ignore_public_acls": false})),
	]}
	count(result) == 1
}

test_bucket_without_public_access_block_is_denied if {
	result := s3.deny with input as {"resource_changes": [bucket("data")]}
	count(result) == 1
}

test_public_read_acl_is_denied if {
	result := s3.deny with input as {"resource_changes": [{
		"mode": "managed",
		"type": "aws_s3_bucket_acl",
		"address": "aws_s3_bucket_acl.site",
		"change": {"actions": ["create"], "after": {"acl": "public-read"}, "after_unknown": {}},
	}]}
	count(result) == 1
}

test_policy_allowing_everyone_without_condition_is_denied if {
	policy := json.marshal({"Statement": [{"Sid": "Open", "Effect": "Allow", "Principal": "*", "Action": "s3:GetObject"}]})
	result := s3.deny with input as {"resource_changes": [{
		"mode": "managed",
		"type": "aws_s3_bucket_policy",
		"address": "aws_s3_bucket_policy.open",
		"change": {"actions": ["create"], "after": {"policy": policy}, "after_unknown": {}},
	}]}
	count(result) == 1
}

test_policy_allowing_everyone_with_condition_passes if {
	policy := json.marshal({"Statement": [{
		"Effect": "Allow",
		"Principal": {"AWS": "*"},
		"Action": "s3:GetObject",
		"Condition": {"StringEquals": {"aws:PrincipalOrgID": "o-example"}},
	}]})
	count(s3.deny) == 0 with input as {"resource_changes": [{
		"mode": "managed",
		"type": "aws_s3_bucket_policy",
		"address": "aws_s3_bucket_policy.org",
		"change": {"actions": ["create"], "after": {"policy": policy}, "after_unknown": {}},
	}]}
}
