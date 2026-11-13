## Summary

<!-- What changes, and why. Link the ticket or ADR. -->

## Type of change

- [ ] Feature (new module, root, policy or workflow input)
- [ ] Fix
- [ ] Refactor or chore (no behaviour change)
- [ ] Documentation or ADR
- [ ] Breaking change to the reusable workflow contract (requires a new major version)

## Checklist

- [ ] `make check` passes locally (fmt, validate, tflint, checkov, terraform test, opa test, conftest fixtures)
- [ ] New or changed module behaviour has a `tests/*.tftest.hcl` case
- [ ] New or changed policy has a `*_test.rego` case and a fixture where relevant
- [ ] Any new checkov skip has an inline `#checkov:skip=...: <justification>` and is explained in the PR
- [ ] Architecture or security decisions are recorded in `docs/adr/`
- [ ] No account IDs, secrets, personal data or real company names are added
- [ ] Workflow changes were linted with actionlint
