# opm-suite-installer: where do I go?

Router only. Facts and rules are in `AGENTS.md`.

| Task | Read first | Then |
| --- | --- | --- |
| Change the entrypoint, a hook, the rollout wait, the revert or an exit code, or learn why `opm` behaves as it does in the Job | `references/cli-constraints.md` | `scripts/`, `bundle/` |
| Add or change a bundled application or module | `openspec/config.yaml` | `modules/`, `bundle/` |
| Change the platform module, a pin or `vendor/` | `AGENTS.md` | `platform/`, `vendor/` |
| Change the Job, its RBAC or the image build | `references/cli-constraints.md` | `deploy/`, `hack/` |
| Create, reset or debug the test cluster | `AGENTS.md` | `hack/` |
| Start a feature change or alter installer behavior | `openspec/config.yaml` | `openspec/changes/` |
| Record a finding | `FINDINGS.md` | |
| Fix a `cite-lint` failure or write a comment that cites an enhancement | `references/enhancements.md` at the workspace root | `.github/workflows/` |
| Deliver or cite an enhancement | `references/enhancements.md` at the workspace root | |
| Look up a registry mapping or a CUE resolution problem | `references/registry.md` at the workspace root | |
| Commit, open a PR or write GitHub text | `references/git-text.md` at the workspace root | |
