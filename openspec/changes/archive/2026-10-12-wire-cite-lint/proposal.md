## Why

Every OPM repo now runs the same comment rule: an enhancement id only beside a reason in words,
never with a decision number, never alone. The rule is checked by `enh cite-lint`. This repo had
no local task and no CI check for it, so a later citation in the wrong form would merge unseen.

This change answers no question about the installer-image idea. It only adds the check.

Alternative not chosen: do nothing. The repo then drifts from the other repos again.

## What Changes

- `Taskfile.yml`: a task `cite-lint` that runs `enh cite-lint` at the commit `e0335b2e`, the
  commit the shared workflow uses.
- `.github/workflows/cite-lint.yml`: a new workflow with one job that calls the shared reusable
  workflow of `open-platform-model/.github`, pinned by SHA, on `pull_request` and on `push` to
  `main`. The token is read-only; no secret is passed.
- `AGENTS.md`: the command table lists `task cite-lint`.
- No excludes: the tool reports 0 findings (11 files checked, `vendor/` skipped by the tool).
- This repo pins no OpenSpec CLI, so there is no pin to move.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
None. No behaviour of the installer changes, so `.openspec.yaml` declares `skip_specs: true`.

## Enhancement

None.

## Impact

- Files: `Taskfile.yml`, `.github/workflows/cite-lint.yml`, `AGENTS.md`.
- Constitution III (no CI-published artifacts) is not touched: the workflow publishes nothing.
- Verification: `task cite-lint`, `task lint`, actionlint and zizmor on the workflow. `task check`
  is not run here: it builds the shared image tag `localhost/opm-suite-installer:dev`.
