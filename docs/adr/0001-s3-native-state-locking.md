# 0001. Use S3 native state locking instead of a DynamoDB table

- Status: accepted
- Date: 2026-11-13
- Deciders: Adrian Garcia (platform)

## Context and Problem Statement

Every Terraform root in the platform stores its state in S3. Terraform must serialise writes to that state, so the backend needs a lock. The traditional S3 backend locks with a DynamoDB table. Terraform 1.10 added a second option, `use_lockfile = true`, which stores the lock as an object next to the state (`<key>.tflock`) and relies on S3 conditional writes to make acquisition atomic.

We need to decide which mechanism the platform standard uses, and whether the bootstrap root creates a DynamoDB table.

## Decision Drivers

- Fewer moving parts in the state path: every extra service is another thing that can fail during an incident.
- Least privilege: each additional resource means additional IAM grants for plan and apply roles.
- Consistency with the rest of the bucket's controls: state is encrypted, versioned and access-logged, and the lock should be too.
- Terraform 1.10+ must be the minimum version across all repositories (which the platform already requires).

## Considered Options

1. DynamoDB table with a `LockID` hash key (classic S3 backend locking).
2. S3 native locking with `use_lockfile = true`.
3. No locking (rejected outright).

## Decision Outcome

Chosen option: **S3 native locking (`use_lockfile = true`)**, with no DynamoDB table in the bootstrap root.

The bootstrap root creates the state bucket with versioning, SSE-KMS and a TLS-only policy. Every backend block sets `use_lockfile = true`. The minimum Terraform version is `>= 1.10`, enforced by `required_version` in every root and module.

### Consequences

- Positive: one fewer AWS resource to create, secure, monitor and pay for. No DynamoDB capacity or point-in-time-recovery decisions.
- Positive: the lock is covered by the same controls as the state. It is versioned, encrypted with the same CMK, and captured by the same access logs.
- Positive: IAM is simpler. Plan roles need `s3:PutObject` and `s3:DeleteObject` only on `*.tflock` under their own prefix, not `dynamodb:*` on a table ARN.
- Negative: lock files are ordinary S3 objects, so a crashed run can leave a stale `.tflock`. Recovery is `terraform force-unlock <id>`, which is the same procedure as with DynamoDB.
- Negative: the platform cannot run Terraform older than 1.10. Pinning `terraform-version` in the reusable workflow keeps this explicit.
- Neutral: the DynamoDB locking path is deprecated in the S3 backend documentation in favour of `use_lockfile`, so choosing it would mean adopting a path with a stated end of life.

## Pros and Cons of the Options

### DynamoDB table

- Good, because it is the long-standing, widely understood pattern.
- Bad, because it adds a service, a table ARN in every IAM policy, and a second place where locks and state can disagree.
- Bad, because the backend documentation now treats it as deprecated.

### S3 native locking

- Good, because it removes a whole service from the state path.
- Good, because the lock inherits the bucket's versioning, encryption and access logging.
- Bad, because it requires Terraform 1.10 or later, and S3 conditional writes must be available in the region.

## Links

- Terraform S3 backend: `use_lockfile` argument.
- `bootstrap/versions.tf` and `bootstrap/backend.hcl`.
