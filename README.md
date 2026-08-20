# speq-examples

Reference examples for `speq` repository modes and onboarding.

## Scope

This repository provides fixtures and sample layouts for:

- `in-repo` mode (`.speq` inside service repository);
- `test-repo` mode (dedicated test repository root).
- `test-repo` mode for public JSONPlaceholder API with entity-based suites.
- `quickstart` — the minimal annotated project backing the CLI quickstart document.

## Planned structure

```text
quickstart/
  manifest.yaml
  environments/
  suites/
in-repo-mode/
  .speq/
    environments/
    suites/
    reports/
test-repo-mode/
  environments/
  suites/
  reports/
test-repo-mode-jsonplaceholder/
  environments/
  suites/
    users/
    posts/
  reports/
docs/
```

## Start here

New to SPEQ? Read [`quickstart/`](quickstart/) — three files, every line annotated, one green test against
a public API. It is the smallest thing here that runs.

`test-repo-mode-jsonplaceholder/` is the opposite: it exercises fixtures, generators, modules, coverage
and ATDD together, which makes it the acceptance gate for `speq-cli` and a poor first read.

## Usage

Examples are used by:

- CLI smoke/e2e tests;
- GitHub runner compatibility checks;
- extension manual verification flows.

## CI secrets

GitHub Actions examples generate `environments/ci.yaml` from GitHub Secrets before running SPEQ. See `docs/ci-secrets.md` for the copy-paste workflow step and recommended secret names.

## Status

Bootstrap complete. Ready to add first canonical specs and envs.
