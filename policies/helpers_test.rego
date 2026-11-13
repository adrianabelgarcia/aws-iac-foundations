package foundations.helpers_test

import rego.v1

import data.foundations.helpers

test_managed_changes_skip_data_sources_and_deletes if {
	changes := helpers.managed_changes with input as {"resource_changes": [
		{"mode": "managed", "type": "aws_vpc", "address": "aws_vpc.a", "change": {"after": {}}},
		{"mode": "data", "type": "aws_caller_identity", "address": "data.x.y", "change": {"after": {}}},
		{"mode": "managed", "type": "aws_vpc", "address": "aws_vpc.b", "change": {"after": null}},
	]}
	count(changes) == 1
}

test_is_unknown_reads_after_unknown if {
	helpers.is_unknown({"change": {"after_unknown": {"bucket": true}}}, "bucket")
}

test_as_list_normalises_null_and_scalars if {
	count(helpers.as_list(null)) == 0
	count(helpers.as_list([1, 2])) == 2
}
