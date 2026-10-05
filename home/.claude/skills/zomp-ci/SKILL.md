---
name: zomp-ci
description: Zomp conventions for CI workflows and build versioning - self-hosted runner labels and the public-repo exception, running workflows unmodified under nektos/act (preconfigured actrc, env.ACT gating), artifact retention, and how a build stamps and surfaces its version (git SHA capture for web/JS, meta tag, /build-info.json, container labels). Load this before creating or editing any file under .github/workflows, before adding an upload-artifact step, and before wiring build-time version stamping into any project.
---

# Zomp CI and build-versioning conventions

These extend the global conventions in `AGENTS.md`, which stay in force. Where this file is silent, the global rules apply. For .NET-specific build and packaging rules, see the `zomp-dotnet` skill.

## Self-hosted runners

All private Zomp repos run CI on self-hosted runners:

- `runs-on: [self-hosted, linux]` for Linux jobs.
- `runs-on: [self-hosted, windows]` for Windows jobs.

The global `actrc` maps the `linux` and `windows` labels so workflows still run unmodified under `act`.

Why: GitHub-hosted runners cold-start every job, have no warm Docker layer cache, count against the private-repo minute budget, and have hit recurring shared-infrastructure outages (e.g. MCR 429 throttling on `mcr.microsoft.com/appsvc/staticappsclient` during the Azure SWA deploy step). Self-hosted runners pin a known faster machine and dodge those cost / availability hits.

**Public repos must stay on `ubuntu-latest` / `windows-latest`.** [GitHub explicitly warns](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#hardening-for-self-hosted-runners) that running untrusted code from fork-PRs on a self-hosted runner is a supply-chain attack surface (the runner machine is reachable from anything the workflow can spawn).

## Local CI with `act`

CI workflows must run unmodified under [nektos/act](https://github.com/nektos/act) so developers can iterate locally before pushing. `act` is globally preconfigured at `~/AppData/Local/act/actrc` - assume the following are already set and do **not** suggest passing them per invocation:

- `--artifact-server-path` and `--artifact-server-port` are already set - `actions/upload-artifact@v4` and `actions/download-artifact@v4` work under act with no extra flags. **Never gate upload/download-artifact steps on `env.ACT`.**
- `-P ubuntu-latest=catthehacker/ubuntu:act-latest` - the standard Linux runner image; workflows targeting `ubuntu-latest` run as-is.
- `-P windows-latest=-self-hosted` - Windows jobs execute directly on the host. They must skip steps that install host-resident tooling: guard `setup-dotnet`, `setup-node`, `pnpm/action-setup`, `dotnet workload install`, etc. with `if: ${{ !env.ACT }}`.
- Shared secrets (`ZOMP_NUGET_*`, signing creds, etc.) are injected through the actrc. Reference them with `${{ secrets.NAME }}` as normal - they resolve under act and on real CI alike.

To keep `env.ACT` parseable by the GitHub Actions schema linter on real CI, declare it null at workflow top:

```yaml
env:
  ACT:
```

Steps that should skip under act (cache actions, `setup-*` actions, anything host-tool-specific) take `if: ${{ !env.ACT }}`. Steps that *must* run under act (artifact upload, the actual build commands) stay ungated.

## CI artifact retention

Set `retention-days: 5` on every `actions/upload-artifact@v4` step. The default (90 days) is overkill for CI-built binaries - anything older than a few days has been superseded by a newer build, and the storage bill / dashboard noise is real. Override to a longer value only when an artifact is a release deliverable that needs to outlive routine CI churn.

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: ...
    path: ...
    retention-days: 5
```

## Build versioning mechanics

The principle - every deployable project derives its version from git, never hardcoded, and surfaces it where a deployed environment can be asked - lives in `AGENTS.md`. This section is how to implement it.

For .NET projects the mechanics are Nerdbank.GitVersioning; see the `zomp-dotnet` skill.

### Web/JS projects (Astro, Next, Vite, etc.)

NBGV-style semver is overkill for sites that aren't versioned libraries. Capture git SHA + build timestamp in CI and inject as build-time env vars:

```bash
echo "PUBLIC_BUILD_SHA=$(git rev-parse --short HEAD)" >> "$GITHUB_ENV"
echo "PUBLIC_BUILD_TIME=$(date -u +%FT%TZ)" >> "$GITHUB_ENV"
echo "PUBLIC_BUILD_BRANCH=${GITHUB_REF_NAME}" >> "$GITHUB_ENV"
```

Use the `PUBLIC_` prefix only when the bundler requires it (Astro, Vite). The values are not sensitive - exposing the SHA leaks nothing the repo doesn't already.

### Surface the version

Pick channels appropriate to the stack - every deployed environment must answer "which version is this?" without source access:

- **Desktop (.NET/Avalonia/WPF)**: window title or About dialog via `ThisAssembly.AssemblyInformationalVersion`
- **Web**: `<meta name="build" content="...">` in `<head>` (curl-friendly), `GET /build-info.json` (programmatic deploy verification), and `console.info` once on page load (DevTools-friendly)
- **Services / containers**: image label (`org.opencontainers.image.revision`) plus a `/health` or `/version` endpoint
