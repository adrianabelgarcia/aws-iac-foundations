# 0004. Bound CI apply roles with a permission boundary

- Status: accepted
- Date: 2026-11-13
- Deciders: Adrian Garcia (platform)

## Context and Problem Statement

The apply role must create IAM roles, policies and instance profiles, because EKS, ECS and the golden AMI pipeline all need them. Granting `iam:*` to a role that is itself driven by Terraform code is the classic path to privilege escalation: a change to the code can create a role with more power than the pipeline has, then assume it.

We need the apply role to manage the platform's IAM without being able to grant itself or any role it creates more power than the platform is allowed to have.

## Decision Drivers

- No role created by CI may exceed the apply role's own permissions.
- CI must not be able to alter its own trust, its own permissions, or the boundary itself.
- Security controls (CloudTrail, Config, GuardDuty, public access blocks) must not be switched off from a pipeline.
- Terraform state must be readable only by the apply role of the repository that owns it.

## Considered Options

1. Attach `AdministratorAccess` to the apply role and rely on environment protection rules.
2. Enumerate exact permissions for every resource type the platform creates.
3. A permission boundary used as a ceiling, with an identity policy that grants a service allowlist and scoped IAM.

## Decision Outcome

Chosen option: **option 3**.

- Every apply role has `permissions_boundary` set to a single managed policy, `<org>-gha-permission-boundary`.
- The boundary allows a service allowlist. Explicit `Deny` statements take precedence and:
  - block any change to CI roles and to the boundary policy itself (`<org>-gha-*`);
  - refuse `iam:CreateRole` and `iam:PutRolePermissionsBoundary` unless the boundary is attached to the new role, so every role CI creates is bounded by the same ceiling;
  - block identity creation (users, access keys, login profiles), trust changes (OIDC and SAML providers) and governance changes (Organizations, billing, account);
  - block turning off CloudTrail, AWS Config, GuardDuty and Security Hub, and disabling account-level S3 public access blocks;
  - block destructive changes to the state bucket and key, and block access to them for any principal that is not an apply role;
  - deny regional actions outside the configured region, except for global services.
- Identity policies grant the allowlist, scoped IAM for `<org>-*` names, and per-repository access to that repository's state prefix.

### Consequences

- Positive: a compromised or mistaken change in one repository cannot create an administrator. The worst a created role can do is what the boundary allows.
- Positive: the controls are in code, reviewed in pull requests, and visible in one policy document.
- Negative: adding a new AWS service requires adding it to the allowlist in two places, the boundary and the identity policy, by design. The effective permission is their intersection.
- Negative: the platform's own resource names must use the organisation prefix (`acme-`). Non-prefixed IAM names are not manageable by CI and must be created by an administrator.
- Negative: IAM policy size limits constrain how far the allowlist can grow. The current list stays well below them.

## Pros and Cons of the Options

### AdministratorAccess

- Good, because it never blocks a legitimate change.
- Bad, because any code change becomes a route to full account control.

### Enumerated permissions

- Good, because it is the tightest possible grant.
- Bad, because it is brittle and needs changes for every new resource type.

### Permission boundary

- Good, because it contains escalation even when identity policies are widened by mistake.
- Good, because the ceiling is one document that reviewers can read.
- Bad, because the allowlist must be maintained in two places.

## Links

- `github-oidc/permission_boundary.tf`, `github-oidc/apply_role.tf`.
- ADR 0002 for the trust model.
