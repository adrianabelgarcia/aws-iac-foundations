# 0003. Standardise Terraform delivery with a reusable workflow and policy as code

- Status: accepted
- Date: 2026-11-13
- Deciders: Adrian Garcia (platform)

## Context and Problem Statement

The platform has several repositories that deploy AWS infrastructure: the EKS platform, an ECS Fargate service, and an EC2 golden AMI pipeline. Each of them needs the same guarantees: formatted and valid Terraform, linted and scanned code, a reviewed plan, and an apply that runs exactly what was reviewed. If every repository writes its own pipeline, the guarantees drift, and a control added to one repository is missing from the others.

We also need organisation-wide rules that developers cannot bypass by editing a local pipeline, such as required tags, no public buckets and no world-open ports other than 80 and 443.

## Decision Drivers

- One definition of "a safe Terraform change" that every repository inherits.
- Policies must be enforced at plan time, against the plan that will be applied, not against source code alone.
- Consuming repositories should be short and declarative.
- Changes to the standard must be versioned and reviewed, with clear compatibility rules.

## Considered Options

1. Copy a pipeline template into each repository.
2. A reusable workflow in the foundation repository, versioned with tags, plus policies in the same repository.
3. A third-party CI platform or a custom runner service.

## Decision Outcome

Chosen option: **a reusable workflow (`.github/workflows/terraform.yml`) with policies in `policies/`**.

- Static checks (fmt, init, validate, tflint, checkov) run for every root and never need AWS.
- The plan job assumes the plan role, runs `terraform plan -out`, evaluates the plan JSON with conftest against the policies from the `v1` tag, posts a sticky comment on the pull request, and uploads the binary plan.
- The apply job runs only when `apply` is true and `aws-role-arn` is set. It is attached to a GitHub environment, downloads the exact plan artifact, and applies it. It never plans again.

The workflow contract is versioned (`@v1`). Changing input names or required behaviour requires `v2`.

**Deviation recorded here:** the contract as first written had one role input. A single role cannot satisfy both trust policies, because plan runs carry `pull_request` or `ref` subjects while apply runs carry `environment` subjects. The workflow therefore takes an optional `aws-apply-role-arn`. It is an addition, not a rename, and when it is empty the workflow falls back to `aws-role-arn`, so existing callers keep working.

**Deviation recorded here:** the policy checkout uses the `v1` tag. GitHub does not expose the called workflow's own commit SHA to the job, so the policies cannot be pinned to exactly the same revision as the workflow file. The tag moves with the major version, which keeps the two in step for consumers that pin `@v1`.

### Consequences

- Positive: a new control is added once, reviewed once, and every consumer gets it on the next release.
- Positive: policies evaluate the same plan JSON that will be applied, so they see computed values and default_tags, and they catch problems that static analysis cannot see.
- Positive: production applies are gated by environment protection rules, not by a convention in each repository.
- Negative: every consumer depends on this repository. A bad release affects all of them, so releases are tagged and changes need review from `CODEOWNERS`.
- Negative: policies that depend on unknown values are skipped at plan time and re-checked when the value is known. This is documented in `policies/helpers.rego`.
- Neutral: plan output is posted to pull requests. Sensitive values are masked by Terraform, but non-sensitive values are visible to anyone with read access to the repository, so consumers must not place secrets in plain outputs.

## Pros and Cons of the Options

### Copied templates

- Good, because each repository is self-contained.
- Bad, because controls drift and there is no single place to fix a bug.

### Reusable workflow plus policies

- Good, because controls are centralised and versioned.
- Bad, because it creates a shared dependency that needs release discipline.

### Custom runner service

- Good, because it could enforce controls outside the repository.
- Bad, because it is a new production service to build and operate.

## Links

- `.github/workflows/terraform.yml`, `policies/`, `CONTRIBUTING.md` (versioning section).
