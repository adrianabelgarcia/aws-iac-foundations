package foundations.s3

import rego.v1

import data.foundations.helpers

# Buckets must never be reachable from the internet. Each check below closes one way that can happen.

public_access_block_attributes := [
	"block_public_acls",
	"block_public_policy",
	"ignore_public_acls",
	"restrict_public_buckets",
]

public_acls := {"public-read", "public-read-write", "authenticated-read"}

# 1. Every public access block turns on all four protections.
deny contains msg if {
	some rc in helpers.resources_of_type("aws_s3_bucket_public_access_block")
	some attr in public_access_block_attributes
	not helpers.is_unknown(rc, attr)
	not rc.change.after[attr] == true
	msg := sprintf("%s: %s must be true", [rc.address, attr])
}

# 2. Every bucket is covered by a public access block.
bucket_covered(b) if {
	some p in helpers.resources_of_type("aws_s3_bucket_public_access_block")
	helpers.targets_bucket(p, b)
}

deny contains msg if {
	some b in helpers.resources_of_type("aws_s3_bucket")
	not bucket_covered(b)
	msg := sprintf("%s: no aws_s3_bucket_public_access_block targets this bucket", [b.address])
}

# 3. No canned public ACLs.
deny contains msg if {
	some rc in helpers.resources_of_type("aws_s3_bucket_acl")
	rc.change.after.acl in public_acls
	msg := sprintf("%s: canned ACL %q makes the bucket public", [rc.address, rc.change.after.acl])
}

# 4. No bucket policy that grants Allow to everyone without a condition.
policy_statements(doc) := doc.Statement if is_array(doc.Statement)

policy_statements(doc) := [doc.Statement] if is_object(doc.Statement)

public_principal(st) if st.Principal == "*"

public_principal(st) if st.Principal.AWS == "*"

public_principal(st) if {
	some p in helpers.as_list(st.Principal.AWS)
	p == "*"
}

deny contains msg if {
	some rc in helpers.resources_of_type("aws_s3_bucket_policy")
	is_string(rc.change.after.policy)
	doc := json.unmarshal(rc.change.after.policy)
	some st in policy_statements(doc)
	st.Effect == "Allow"
	public_principal(st)
	not st.Condition
	msg := sprintf("%s: statement %q allows any principal without a condition", [rc.address, object.get(st, "Sid", "unnamed")])
}
