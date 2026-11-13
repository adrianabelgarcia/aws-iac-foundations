package foundations.encryption_test

import rego.v1

import data.foundations.encryption

bucket_with_sse(name, algorithm) := [
	{
		"mode": "managed",
		"type": "aws_s3_bucket",
		"address": sprintf("aws_s3_bucket.%s", [name]),
		"change": {"actions": ["create"], "after": {"bucket": name}, "after_unknown": {}},
	},
	{
		"mode": "managed",
		"type": "aws_s3_bucket_server_side_encryption_configuration",
		"address": sprintf("aws_s3_bucket_server_side_encryption_configuration.%s", [name]),
		"change": {
			"actions": ["create"], "after": {
				"bucket": name,
				"rule": [{"apply_server_side_encryption_by_default": [{"sse_algorithm": algorithm}]}],
			},
			"after_unknown": {},
		},
	},
]

test_kms_encrypted_bucket_passes if {
	count(encryption.deny) == 0 with input as {"resource_changes": bucket_with_sse("data", "aws:kms")}
}

test_sse_s3_bucket_only_warns if {
	count(encryption.deny) == 0 with input as {"resource_changes": bucket_with_sse("logs", "AES256")}
	count(encryption.warn) == 1 with input as {"resource_changes": bucket_with_sse("logs", "AES256")}
}

test_bucket_without_encryption_is_denied if {
	result := encryption.deny with input as {"resource_changes": [{
		"mode": "managed",
		"type": "aws_s3_bucket",
		"address": "aws_s3_bucket.plain",
		"change": {"actions": ["create"], "after": {"bucket": "plain"}, "after_unknown": {}},
	}]}
	count(result) == 1
}

test_unencrypted_ebs_volume_is_denied if {
	result := encryption.deny with input as {"resource_changes": [{
		"mode": "managed",
		"type": "aws_ebs_volume",
		"address": "aws_ebs_volume.data",
		"change": {"actions": ["create"], "after": {"encrypted": false}, "after_unknown": {}},
	}]}
	count(result) == 1
}

test_encrypted_rds_instance_passes if {
	count(encryption.deny) == 0 with input as {"resource_changes": [{
		"mode": "managed",
		"type": "aws_db_instance",
		"address": "aws_db_instance.db",
		"change": {"actions": ["create"], "after": {"storage_encrypted": true}, "after_unknown": {}},
	}]}
}

test_kms_key_without_rotation_is_denied if {
	result := encryption.deny with input as {"resource_changes": [{
		"mode": "managed",
		"type": "aws_kms_key",
		"address": "aws_kms_key.app",
		"change": {"actions": ["create"], "after": {"enable_key_rotation": false}, "after_unknown": {}},
	}]}
	count(result) == 1
}

test_asymmetric_kms_key_is_exempt_from_rotation if {
	count(encryption.deny) == 0 with input as {"resource_changes": [{
		"mode": "managed",
		"type": "aws_kms_key",
		"address": "aws_kms_key.sign",
		"change": {"actions": ["create"], "after": {"enable_key_rotation": false, "key_usage": "SIGN_VERIFY"}, "after_unknown": {}},
	}]}
}
