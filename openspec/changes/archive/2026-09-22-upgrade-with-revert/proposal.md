## Why

An installer that can only install is half an installer. The interesting question for a
suite image is what happens on the second release: can the same `apply` verb carry an upgrade,
and when the upgrade fails, can the Job put the cluster back the way it found it before
exiting? `apply-bundled-suite` (prerequisite; this change builds on its `apply` verb and Job)
gives idempotent apply. It gives no notion of "what was there before".

This change answers: **can an immutable image, which knows only its own version, upgrade an
application and revert a failed upgrade using only what `opm` records on the cluster?** The
answer shapes the Gitea change that follows: if revert is expressible here with values alone,
the database-bearing case only has to add a backup and a restore around it.

Podinfo is the subject on purpose. It has no state, so a failed upgrade and its revert are
measured with nothing else in the picture.

## What Changes

- **A suite version is an image tag; an upgrade is a values change.** Between two suite
  releases, a bundled application's `values.cue` changes (an image tag, a replica count). The
  module CUE is expected to stay the same. Re-running `apply` with the new image is the
  upgrade; there is no separate `upgrade` verb.
- **Built-in revert.** Before applying an application that already has a `ModuleInstance` on
  the cluster, `apply` captures the values recorded in that CR. If the apply fails or the
  readiness wait times out, it re-applies the captured values and waits again. A reverted run
  exits non-zero; a run whose revert also failed exits with a different code.
- **Two optional per-application hook files**, `pre-apply` and `on-failure`, plain bash under
  `bundle/instances/<app>/`, run before the apply and before the built-in revert respectively.
  They receive the app, the namespace, the kubeconfig and the captured values as environment.
  Podinfo ships a `pre-apply` that only prints what it was given, so the mechanism is exercised;
  it ships no `on-failure`.
- `jq`, from Debian's package repository, joins the image: the captured values are JSON inside
  the CR and bash has no other honest way to extract one object from it.
- New exit codes: reverted after a failed upgrade, and revert itself failed.

Out of scope: any database, any backup, reverting a module CUE change, a version history
longer than one step, and reverting a first install (there is nothing to revert to; the run
fails as `apply-bundled-suite` specifies).

## Capabilities

### New Capabilities

- `bundle-lifecycle`: re-running `apply` with a new image upgrades a bundled application in
  place, captures the previous values from the cluster, runs the application's optional hooks,
  and reverts to the previous values when the upgrade fails.

### Modified Capabilities

None. `bundle-apply` keeps every requirement and scenario. On a first install the failure
codes it specifies still apply; the new codes only appear when there was something to revert
to.

## Impact

- **Modified**: `scripts/opm-suite` (capture, revert, hooks), `Containerfile` (`jq`),
  `Taskfile.yml` (`task lint` also shellchecks hook files), `README.md`, `CLAUDE.md`.
- **New**: `bundle/instances/podinfo/pre-apply`.
- **RBAC delta**: none beyond `apply-bundled-suite`. Reading the CR uses the same
  `moduleinstances` `get` the apply already needs, through the same service account token.
- **What `opm` cannot do**: nothing it records is missing, but nothing reads it back either.
  `opm instance status -o json` and `opm instance list -o json` carry the module version and
  health, not `spec.values`, so the entrypoint reads the CR from the API directly with `wget`.
  A `opm instance get -o json`, or `status` including the recorded values, is the finding for
  `cli/`. And once more: no readiness wait and no rollback exist in `opm instance apply`.

### Alternatives not chosen

- **Do nothing.** Leaves the Gitea change to invent revert and backup at the same time, and
  the database would hide whether the revert itself works.
- **Ship the previous values inside the image** (`values.cue` plus a `previous/values.cue`
  moved by hand on each release). No cluster read and no `jq`, but it reverts to what the
  release author believed was there rather than what the cluster recorded, and it is
  bookkeeping nobody will keep. The CR is the record `opm` already writes for this purpose.
- **`kubectl rollout undo`.** Needs a binary the constitution keeps out, reverts only the
  Deployment, and leaves the `ModuleInstance` record describing the failed version.
- **A separate `upgrade` verb.** Would fork the code path `apply-bundled-suite` just made
  idempotent. The absence of state in the image is the design; a verb that pretends otherwise
  would be lying.
