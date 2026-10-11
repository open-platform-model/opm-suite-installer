## 1. Rewrite the citations

- [x] 1.1 Run `enh cite-rewrite --write` with the worklist, excluding `bundle-gitea-postgres`; commit the result
- [x] 1.2 Clear the worklist by hand (`platform/platform.cue`, `AGENTS.md`)

## 2. Rules

- [x] 2.1 Add `references:`, the Enhancements context section, the `Delivers` and comment rules and the archive guidance line to `openspec/config.yaml`
- [x] 2.2 Add the same rules to `AGENTS.md`

## 3. Verify

- [x] 3.1 `enh cite-lint` reports 0 findings; `enh cite-rewrite --dry-run` reports 0 edits
- [x] 3.2 `openspec validate align-enhancement-store --strict` passes
- [x] 3.3 `task check` passes
