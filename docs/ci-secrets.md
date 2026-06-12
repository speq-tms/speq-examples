# CI secrets environment

The JSONPlaceholder example keeps a checked-in `environments/ci.yaml` because it targets a public API. Real projects should keep secret values out of the repository and generate the CI environment file during the GitHub Actions job.

Recommended GitHub Secret names:

- `SPEQ_CI_BASE_URL`: API base URL used by CI.
- `SPEQ_CI_SOURCE_HEADER`: optional request source marker.
- `SPEQ_CI_AUTH_TOKEN`: optional bearer token for private APIs.

Minimal workflow step:

```yaml
- name: Materialize SPEQ CI environment
  env:
    SPEQ_CI_BASE_URL: ${{ secrets.SPEQ_CI_BASE_URL }}
    SPEQ_CI_SOURCE_HEADER: ${{ secrets.SPEQ_CI_SOURCE_HEADER }}
  run: |
    python3 - <<'PY'
    import json
    import os
    from pathlib import Path

    base_url = os.environ.get("SPEQ_CI_BASE_URL") or "https://jsonplaceholder.typicode.com"
    source = os.environ.get("SPEQ_CI_SOURCE_HEADER") or "speq-examples-jsonplaceholder"

    path = Path("test-repo-mode-jsonplaceholder/environments/ci.yaml")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "\n".join(
            [
                "name: ci",
                f"baseUrl: {json.dumps(base_url)}",
                "headers:",
                f"  x-source: {json.dumps(source)}",
                "",
            ]
        ),
        encoding="utf-8",
    )
    PY
```

Do not print the generated YAML and do not upload `environments/ci.yaml` as a workflow artifact. If you add sensitive headers, verify that request/response reports and logs do not expose those headers before uploading them.
