package foundations.tags

import rego.v1

import data.foundations.helpers

# Every taggable resource must carry the organization's standard tags. tags_all includes the
# tags injected by provider default_tags, so this check covers both sources.
required_tags := {"Project", "Environment", "Owner", "CostCenter", "DataClassification", "ManagedBy"}

valid_tag_value(v) if {
	is_string(v)
	v != ""
}

deny contains msg if {
	some rc in helpers.managed_changes
	tags := rc.change.after.tags_all
	is_object(tags)
	some key in required_tags
	not valid_tag_value(object.get(tags, key, null))
	msg := sprintf("%s: required tag %q is missing or empty", [rc.address, key])
}
