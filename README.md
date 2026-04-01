# speq-examples

Reference examples for `speq` repository modes and onboarding.

## Scope

This repository provides fixtures and sample layouts for:

- `in-repo` mode (`.speq` inside service repository);
- `test-repo` mode (dedicated test repository root).

## Planned structure

```text
in-repo-mode/
  .speq/
    environments/
    suites/
    reports/
test-repo-mode/
  environments/
  suites/
  reports/
docs/
```

## Usage

Examples are used by:

- CLI smoke/e2e tests;
- GitHub runner compatibility checks;
- extension manual verification flows.

## Status

Bootstrap complete. Ready to add first canonical specs and envs.
