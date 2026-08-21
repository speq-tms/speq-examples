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

## Negative acceptance tests

Some behaviour can only be demonstrated by a run that fails. Those cases live outside `suitesDir` so the
green suite stays green, and a script asserts the failure is the one intended:

| Script | Asserts |
| --- | --- |
| `scripts/at-http-timeout.sh` | A request that outlives its `timeoutMs` budget aborts the run quickly with a message naming the budget, instead of hanging. Covers `speq-tms/speq-docs#59`. |

```bash
SPEQ_BIN=/path/to/speq ./scripts/at-http-timeout.sh
```

They need a `speq` binary that supports the feature under test, so they are run manually (or against a
locally built CLI) until the corresponding release ships.

## CI secrets

GitHub Actions examples generate `environments/ci.yaml` from GitHub Secrets before running SPEQ. See `docs/ci-secrets.md` for the copy-paste workflow step and recommended secret names.

## Status

Bootstrap complete. Ready to add first canonical specs and envs.
