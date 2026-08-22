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

## Which binary the gate runs

`test-repo-mode-jsonplaceholder/` is the acceptance gate for `speq-cli`, so the binary it runs on decides
what the gate can prove.

| Situation | Binary |
| --- | --- |
| A pull request whose head or base names a release candidate (`v*`) that exists in `speq-cli` | built from that branch with `cargo build --release` |
| Anything else, including `main` | the released CLI, installed by `speq-tms/speq-github-runner@v1` |

The release candidate is resolved head → base → ref, the same way the conformance job resolves the
matching `speq-contracts` ref. So an example demonstrating unreleased runtime belongs in `suites/` like any
other: the pull request that adds it is a pull request into the RC, and the gate builds that RC.

On `main` the gate deliberately falls back to the released CLI — a release still has to work with what
users actually install. That makes the rollout order load-bearing: `speq-cli` is released before
`speq-examples` merges into `main`, and if it is not, this gate is what says so.

## Scripted acceptance tests

Some behaviour cannot be shown by a green run alone — either the case has to fail, or the check is about
what does *not* appear in the output. Those live under `scripts/`, run in the gate on whichever binary was
resolved above, and where a failing test is involved it sits outside `suitesDir` so the green suite stays
green:

| Script | Asserts |
| --- | --- |
| `scripts/at-http-timeout.sh` | A request that outlives its `timeoutMs` budget aborts the run quickly with a message naming the budget, instead of hanging. Covers `speq-tms/speq-docs#59`. |
| `scripts/at-error-status.sh` | An unreachable service and a blown timeout are reported as `error` — no answer arrived — while a wrong expectation against a live service stays `failed`, in `summary.json` and as `broken` in Allure. Covers `speq-tms/speq-docs#64`. |
| `scripts/at-failure-semantics.sh` | A failing step ends its group and the steps after it are reported `skipped` rather than failed and never sent; `continueOnError: true` overrides that for one step; a failed `setup` skips the body entirely; and `cleanup` runs in every one of those cases. Covers `speq-tms/speq-docs#63`. |
| `scripts/at-env-secrets.sh` | `${VAR}` resolves from the OS environment and is redacted everywhere the run writes; `${VAR:-default}` keeps the project runnable without it; a placeholder with neither is a load-time error naming the variable and the file. Covers `speq-tms/speq-docs#60`. |

```bash
SPEQ_BIN=/path/to/speq ./scripts/at-http-timeout.sh
SPEQ_BIN=/path/to/speq ./scripts/at-error-status.sh
SPEQ_BIN=/path/to/speq ./scripts/at-failure-semantics.sh
SPEQ_BIN=/path/to/speq ./scripts/at-env-secrets.sh
```

`negative-suites/` holds the cases those scripts drive. A test that is *meant* to fail cannot
live in a suite required to report `"failed": 0` — that is a property of the test, not of the gate, so it
stays outside `suitesDir` whichever binary runs it. Two questions share the directory, so each script
selects its own cases by tag: `error-status` for `#64`, `failure-semantics` for `#63`.

## CI secrets

GitHub Actions examples generate `environments/ci.yaml` from GitHub Secrets before running SPEQ. See `docs/ci-secrets.md` for the copy-paste workflow step and recommended secret names.

## Status

Bootstrap complete. Ready to add first canonical specs and envs.
