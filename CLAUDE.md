# speq-examples

Canonical scenarios and fixtures for validation and e2e usage.

## Responsibilities
- Provide stable examples for docs and regression checks.
- Reflect current supported DSL capabilities.
- Serve as the acceptance gate for `speq-cli`: `test-repo-mode-jsonplaceholder` must stay green.

## Invariants
- Keep examples deterministic and easy to run.
- When DSL evolves, update examples in the same delivery cycle.
- `test-repo-mode-jsonplaceholder` must report `"failed": 0` after any `speq-cli` change. No regressions.
- Every new `speq-cli` feature needs at least one acceptance example here. Bug fixes do not.
- Clean `reports/allure/` and `reports/results/` before each run so stale output is not mistaken for results.

## Running

```bash
cd test-repo-mode-jsonplaceholder && speq run --env ci
```

## How we work

Full process: `speq-docs/docs/delivery/release-flow.md`. Read it before starting delivery work. Summary:

- **Issues live in [`speq-tms/speq-docs`](https://github.com/speq-tms/speq-docs/issues)**, not here. Work for
  this repository carries the `area/examples` label.
- **Milestone title == RC branch name.** Milestone `v1.1.0` means branch `v1.1.0` in this repository.
  `backlog` is not a release and has no branch.
- **Find the current RC** — GitHub state is authoritative, not any checked-in file:

  ```bash
  gh api repos/speq-tms/speq-docs/milestones \
    --jq '.[] | select(.state=="open" and .title != "backlog") | .title'
  git ls-remote --heads origin 'v*'
  ```

- **Branch from the RC, never from `main`:** `git switch -c feat/examples-<name> origin/<RC>`.
- **PR base is the RC**, never `main`. One final PR takes the RC into `main`.
- `Closes #N` does **not** work across repositories. Write `Part of speq-tms/speq-docs#N` in the PR, then close
  the issue manually after merge:
  `gh issue close N --repo speq-tms/speq-docs --comment "Landed in <PR url>."`
- Tick the checkbox in the epic issue when a child issue lands.
