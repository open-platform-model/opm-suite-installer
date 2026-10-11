## Why

The OPM enhancements now live in an OpenSpec store, `opm-enhancements`. Every repo cites an
enhancement the same way: the id beside a reason in words, never alone and never with a decision
number. This repo cited three entries by decision number in two comments and one `AGENTS.md` line.
Its `openspec/config.yaml` also said nothing about the store, so an agent that writes a proposal
here had no rule for the `Delivers` line or the comment form.

This change answers no question about the installer-image idea. It only brings the repo rules
and four citations into line with the store.

Alternative not chosen: do nothing. The old form stays valid text, but the lint that the
workspace adds later would fail this repo, and the rules would stay out of reach of
`openspec instructions`.

## What Changes

- `openspec/config.yaml`: add `references:` (id `opm-enhancements` with its `remote`), an
  "Enhancements" section in `context`, the `Delivers` rule and the comment rule in
  `rules.proposal`, and one `operations.archive.guidance` line.
- `AGENTS.md`: same rules in the "Change Workflow" section; the platform precedence line names
  the enhancement and the reason in words.
- `modules/podinfo/module.cue` and `platform/platform.cue`: three comment citations lose their
  decision numbers and keep the enhancement id beside the reason.
- No behaviour change: comments, rule text and one Markdown line only. No script, image,
  manifest or CUE value changes.
- The vendored core copy under `vendor/opmodel.dev/core@v2/` and the active change
  `bundle-gitea-postgres` are left as they are. The first refreshes with a core release and
  `task vendor:sync`; the second is in flight.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
None. This change has no spec delta: no requirement changes, so `.openspec.yaml` declares
`skip_specs: true`. The repo has no live spec text that cites an enhancement.

## Enhancement

None.

## Impact

- Files: `AGENTS.md`, `openspec/config.yaml`, `modules/podinfo/module.cue`,
  `platform/platform.cue`.
- Owner action: this repo has no `REPO-LOCAL PATCH` block in `.claude/skills/`, so no
  `openspec update` is needed here.
- Verification: `task check`, `enh cite-lint` and `enh cite-rewrite --dry-run` (a local build).
