# quickstart

The smallest `.speq` project that runs green — three files, every line annotated.

This is the project built step by step in
[`speq-docs/docs/cli/quickstart.md`](https://github.com/speq-tms/speq-docs/blob/main/docs/cli/quickstart.md).
Read that document to follow the reasoning; read these files to see the finished result.

## Run it

```bash
cd quickstart
speq run --env ci --report all
```

```json
{
  "ok": true,
  "status": "passed",
  "totals": { "error": 0, "failed": 0, "passed": 1, "pending": 0, "total": 1 }
}
```

The test runs against [JSONPlaceholder](https://jsonplaceholder.typicode.com), a public API that needs no
key and no account. Only an internet connection is required.

## What is here

| File | Contains |
| --- | --- |
| `manifest.yaml` | The three required fields, the directory layout, and a note on every key deliberately left out |
| `environments/ci.yaml` | `baseUrl`, and what the other keys in an environment file actually do |
| `suites/smoke.yaml` | One `api` step with a `status`, two `json` and an `exists` assertion |

Nothing else. No modules, no fixtures, no generated data, no coverage — those live in
[`test-repo-mode-jsonplaceholder`](../test-repo-mode-jsonplaceholder), which exercises everything at once
and is the acceptance gate for the CLI. This example exists to be read first.

## Kept in step with the document

`suites/smoke.yaml` parses to exactly the test printed in `docs/cli/quickstart.md` — same keys, same
values. The comments here are the only difference, and comments do not survive parsing. If you change one,
change the other.

## Where to go next

Every construct this example leaves out is covered in
[`speq-docs/docs/cli/dsl.md`](https://github.com/speq-tms/speq-docs/blob/main/docs/cli/dsl.md): the other
five assertion types, variables, generated data, fixtures, modules, suite hooks and conditional waiting.
