# 0002. Authenticate GitHub Actions to AWS with OIDC, not static keys

- Status: accepted
- Date: 2026-11-13
- Deciders: Adrian Garcia (platform)

## Context and Problem Statement

CI pipelines must call AWS to plan and apply infrastructure. The traditional approach stores an IAM user's access key in GitHub secrets. Long-lived keys are easy to leak through logs, forks, developer machines and backups, and they do not expire unless someone rotates them. Rotation is a manual process that tends to be skipped.

We need a way for GitHub Actions jobs to obtain short-lived AWS credentials that are scoped to a specific repository, branch or environment, with no secret stored in GitHub.

## Decision Drivers

- No long-lived credentials anywhere in GitHub or in AWS IAM users.
- Trust must be narrow: a token from another repository, branch or environment must be unable to assume the role.
- Auditability: CloudTrail must show which repository, workflow run and environment assumed which role.
- Operational simplicity for consuming repositories.

## Considered Options

1. IAM user with an access key stored as a GitHub secret.
2. GitHub OIDC identity provider with one role per trust scope.
3. Self-hosted runners with instance profiles.

## Decision Outcome

Chosen option: **GitHub OIDC**. The `github-oidc` root creates one IAM OIDC provider per account and, for every consuming repository, two roles:

- a **plan role** (read-only) that trusts `pull_request` runs and default-branch pushes;
- an **apply role** that trusts only `environment:<name>` subject claims, so the token is issued only after the GitHub environment's protection rules pass.

Trust conditions check `aud`, `repository_owner` and the exact `sub`. No wildcard subject is used.

### Consequences

- Positive: no AWS secret exists in GitHub. Credentials last one hour (`max_session_duration = 3600`).
- Positive: CloudTrail records the role session name `gha-plan-<run_id>-<attempt>` or `gha-apply-<run_id>-<attempt>`, which links every API call to a workflow run.
- Positive: production applies are gated by GitHub environment reviewers. The OIDC token itself is the enforcement point.
- Negative: the OIDC provider and the roles must be created by a human admin once per account. CI cannot bootstrap its own trust.
- Negative: a misconfigured `sub` condition fails closed, which shows up as `AccessDenied` in a plan. Documentation in the README lists the expected subjects.
- Neutral: AWS no longer requires a pinned certificate thumbprint for the GitHub provider, so the provider resource does not hard-code one.

## Pros and Cons of the Options

### IAM user access key

- Good, because it works with any CI system.
- Bad, because the key is long-lived, shared across pipelines, and a common source of incidents.

### OIDC roles

- Good, because credentials are short-lived and scoped by claim.
- Good, because trust is auditable in code.
- Bad, because it requires a one-time admin setup per account.

### Self-hosted runners

- Good, because the runner's instance profile holds the credentials.
- Bad, because it adds a fleet to operate, patch and secure, which the platform team is not asking for.

## Links

- `github-oidc/oidc.tf`, `github-oidc/plan_role.tf`, `github-oidc/apply_role.tf`.
- ADR 0004 for the permission boundary that limits the apply role.
