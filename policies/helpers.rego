package foundations.helpers

import rego.v1

# Resource changes that will exist after the plan is applied, across every module.
# Data sources and deletions are excluded. Works on the output of `terraform show -json`.
managed_changes := [rc |
	some rc in input.resource_changes
	rc.mode == "managed"
	rc.change.after != null
]

resources_of_type(t) := [rc | some rc in managed_changes; rc.type == t]

# True when an attribute's value is not known until apply. Checks skip unknown values and are
# re-evaluated on the next plan, instead of failing on a value that does not exist yet.
is_unknown(rc, attr) if rc.change.after_unknown[attr] == true

# Normalises a missing or null list into an empty list.
as_list(x) := x if is_array(x)

as_list(x) := [] if not is_array(x)

# A bucket sub-resource (public access block, encryption configuration, policy) targets a bucket
# when both reference the same bucket name. An unknown reference is treated as a match.
targets_bucket(sub, bucket) if sub.change.after.bucket == bucket.change.after.bucket

targets_bucket(sub, _) if is_unknown(sub, "bucket")
