## Context

`.github` PR 22 added the reusable workflow `cite-lint.yml`. Its tool commit is its default
`enh-ref`, so a caller passes only `paths` and `exclude`. The local task must run the same tool
commit.

## Goals / Non-Goals

**Goals:**
- `task cite-lint` and the CI job lint the same files with the same tool commit.

**Non-Goals:**
- No change to `task check` or the image build. No required-check ruleset change.

## Decisions

- **A separate small workflow file.** The repo has no CI yet; the call is the only job, so the
  file holds only it. The job keeps the plain-call shape the `.github` wiring check expects:
  `name`, `permissions` (`contents: read`), `uses`, `with`.
- **No excludes.** Both the task and the call lint `.`; the tool skips `vendor/` itself.
  If one is added later, the Taskfile comment and the workflow comment say to keep both lists equal.
- **The task is not part of `task check`.** `task check` builds an image and needs podman; the
  cite-lint task needs only Go. A reviewer runs it on its own.

## Risks / Trade-offs

- The task pins the tool commit in `Taskfile.yml` and the shared workflow pins it in `.github`;
  the two move together by hand. A comment in the task says so.
- This repo is not a cascade repo, so the `.github` wiring check does not watch the pin.
