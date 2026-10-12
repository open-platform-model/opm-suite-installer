## 1. Task and CI

- [x] 1.1 Add the `cite-lint` task to `Taskfile.yml` (no excludes)
- [x] 1.2 Add `.github/workflows/cite-lint.yml` calling the shared workflow
- [x] 1.3 List `task cite-lint` in the `AGENTS.md` command table

## 2. Verify

- [x] 2.1 `task cite-lint` reports 0 findings; `task lint` passes
- [x] 2.2 `openspec validate wire-cite-lint --strict` passes; actionlint and zizmor are clean on the workflow
