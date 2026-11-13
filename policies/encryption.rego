package foundations.encryption

import rego.v1

import data.foundations.helpers

# Data at rest must be encrypted. Every S3 bucket needs default encryption: aws:kms is required by policy
# and SSE-S3 (AES256) is accepted with a warning. Other storage must set its encryption flag.

bucket_is_encrypted(b) if {
	some c in helpers.resources_of_type("aws_s3_bucket_server_side_encryption_configuration")
	helpers.targets_bucket(c, b)
	some r in helpers.as_list(c.change.after.rule)
	some d in helpers.as_list(r.apply_server_side_encryption_by_default)
	d.sse_algorithm in {"aws:kms", "aws:kms:dsse", "AES256"}
}

deny contains msg if {
	some b in helpers.resources_of_type("aws_s3_bucket")
	not bucket_is_encrypted(b)
	msg := sprintf("%s: bucket must have default encryption configured (aws:kms)", [b.address])
}

warn contains msg if {
	some c in helpers.resources_of_type("aws_s3_bucket_server_side_encryption_configuration")
	some r in helpers.as_list(c.change.after.rule)
	some d in helpers.as_list(r.apply_server_side_encryption_by_default)
	d.sse_algorithm == "AES256"
	msg := sprintf("%s: SSE-S3 (AES256) in use; prefer aws:kms with a customer managed key", [c.address])
}

encryption_flags := {
	"aws_ebs_volume": "encrypted",
	"aws_efs_file_system": "encrypted",
	"aws_db_instance": "storage_encrypted",
	"aws_rds_cluster": "storage_encrypted",
}

deny contains msg if {
	some rc in helpers.managed_changes
	attr := encryption_flags[rc.type]
	not helpers.is_unknown(rc, attr)
	not rc.change.after[attr] == true
	msg := sprintf("%s: %s must be true", [rc.address, attr])
}

# Customer managed symmetric keys must rotate automatically.
deny contains msg if {
	some rc in helpers.resources_of_type("aws_kms_key")
	object.get(rc.change.after, "key_usage", "ENCRYPT_DECRYPT") == "ENCRYPT_DECRYPT"
	not helpers.is_unknown(rc, "enable_key_rotation")
	not rc.change.after.enable_key_rotation == true
	msg := sprintf("%s: enable_key_rotation must be true", [rc.address])
}
