# Contributing

This repository is the shared foundation for the AWS platform repositories. Changes here reach every consumer, so the bar is higher than in an application repository.

## Workflow

1. Open an issue or an ADR for anything that changes a contract, a security boundary or a default.
2. Branch from `main`: `feat/<short-topic>`, `fix/<short-topic>`, `docs/<short-topic>`.
3. Run `make check` before pushing. It runs the same checks as CI. Install the hooks with `pre-commit install`.
4. Open a pull request using the template. CI must be green. Every PR needs one approval from `CODEOWNERS`.
5. Squash-merge. The PR title becomes the commit subject, so it must follow Conventional Commits.

## Commit messages

Conventional Commits:

```
<type>(<optional scope>): <imperative summary, lower case, no period>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`, `build`.

Scopes used in this repository: `bootstrap`, `github-oidc`, `vpc`, `tags`, `policies`, `workflow`, `adr`.

Examples:

- `feat(vpc): add interface endpoint for ssmmessages`
- `fix(workflow): use the apply role for the apply job`
- `docs(adr): record the decision to drop DynamoDB locking`

## Versioning and the reusable workflow

- Modules and policies are released with semantic version tags (`v1.4.0`).
- The reusable workflow is consumed as `@v1`. The `v1` tag moves to the latest compatible release.
- Any change to the reusable workflow contract (input names, required inputs, job names, default behaviour) is a breaking change and needs a new major version, `v2`.
- Adding an optional input is non-breaking and goes into the current major version.

## Standards

- Terraform `>= 1.10`. Provider pins use the pessimistic operator, for example `~> 6.73`.
- Every resource is tagged through `default_tags`. Use `modules/tags` for the tag set.
- Variables have a description, a type and validation. Outputs have descriptions.
- Files stay under 400 lines. Split by concern, not by resource type.
- Checkov findings are fixed. A skip needs an inline justification, for example `#checkov:skip=CKV_AWS_18: <reason>`. A skip without a reason fails review.
- Never commit account IDs that are not placeholders, credentials, emails or customer names. Examples use `111111111111`, `222222222222` and the `acme` organization.

## Tests

- Module tests use `mock_provider "aws"` and run offline. Add a test for every new variable validation and every new branch.
- Policy tests live next to each policy as `*_test.rego`. Add a fixture under `policies/fixtures/` when a rule changes what a real plan looks like.

## Reporting security issues

Do not open a public issue for a vulnerability. Contact the maintainer directly through GitHub.
