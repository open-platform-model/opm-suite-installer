## Context

The workspace moved enhancements into the store `opm-enhancements`. The repo rules must live in
`openspec/config.yaml`, because `openspec update` does not overwrite it. This repo carries no
local patch in its skill files, so the config is the only place to change.

## Goals / Non-Goals

**Goals:**
- `config.yaml` and `AGENTS.md` carry `references:`, the `Delivers` rule and the comment rule.
- Every own citation reads as an id beside a reason in words.

**Non-Goals:**
- No change to the vendored core copy or to `bundle-gitea-postgres`.
- No `cite-lint` task and no CI call. The workspace adds both after the lint merges.

## Decisions

- **Rules in `config.yaml`, mirrored in `AGENTS.md`.** One source for agents that read
  instructions, one for agents that read the repo guide. Alternative: `AGENTS.md` only. Not
  chosen, because `openspec instructions` serves only `config.yaml`.
- **The tool pass, then a hand pass.** `enh cite-rewrite` made two edits. One put a full
  decision title into `AGENTS.md`; it is rewritten as a short reason in words.
- **Local `D3` stays in `platform/platform.cue`.** It names a decision of this repo's own
  archived change `render-bundled-podinfo`, not an enhancement decision.

## Risks / Trade-offs

- `references.remote` follows the form of the other repos; it was not run against
  `openspec store register` here.
- Wording only: no check can show a behaviour change, so `task check` stands as the guard.
