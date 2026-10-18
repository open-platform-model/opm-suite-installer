# opm-suite-installer: where do I go?

Router only. Facts and rules are in `AGENTS.md`.

| Task | Read first | Then |
| --- | --- | --- |
| Change the entrypoint, the rollout wait, the revert or an exit code, or learn why `opm` behaves as it does in the Job | `references/cli-constraints.md` | `scripts/`, `bundle/` |
| Add or change a bundled application or module | `references/cli-constraints.md` | `modules/`, `bundle/` |
| Change the platform module, a CUE pin or `vendor/` | `AGENTS.md` | `platform/`, `vendor/` |
| Change the Job, its RBAC, the image build or the opm CLI pin | `references/cli-constraints.md` | `Containerfile`, `deploy/` |
| Create, reset or debug the test cluster | `AGENTS.md` | `hack/` |
| Start a feature change or alter installer behavior | `openspec/config.yaml` | `openspec/changes/` |
| Record a finding | `FINDINGS.md` | |
| Write a comment that cites an enhancement, or fix the lint that checks it | `references/enhancements.md` at the workspace root | `.github/workflows/` |
| Deliver an enhancement | `references/enhancements.md` at the workspace root | |
| Look up a registry mapping or a CUE resolution problem | `references/registry.md` at the workspace root | |
| Commit, open a PR or write GitHub text | `references/git-text.md` at the workspace root | |
