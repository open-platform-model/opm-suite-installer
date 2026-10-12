## 1. Task and CI

- [ ] 1.1 Add the `cite-lint` task to `Taskfile.yml` (no excludes)
- [ ] 1.2 Add `.github/workflows/cite-lint.yml` calling the shared workflow
- [ ] 1.3 List `task cite-lint` in the `AGENTS.md` command table

## 2. Verify

- [ ] 2.1 `task cite-lint` reports 0 findings; `task lint` passes
- [ ] 2.2 `openspec validate wire-cite-lint --strict` passes; actionlint and zizmor are clean on the workflow
