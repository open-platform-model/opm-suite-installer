## Why

Podinfo has no state, so the revert in `upgrade-with-revert` (prerequisite, with
`apply-bundled-suite` before it) proves the mechanism and nothing else. A real suite has a
database, and a real upgrade migrates its schema. Reverting the pods without reverting the
schema leaves the old version running against tables it does not understand, which is worse
than the failed upgrade.

This change answers: **can the hook contract carry a database-backed application through an
upgrade that migrates its schema, and put both the pods and the database back when the
upgrade fails, using only `opm`-applied workloads?** It also answers a smaller question the
constitution raised on day one: what a second bundled application costs when it is a
copy-paste and not a framework.

Gitea is the subject, at the user's choice. It is a single binary, it supports PostgreSQL, it
has an explicit and idempotent `gitea migrate` subcommand, and consecutive minor releases
carry real schema migrations. The reservation stated during the discussion stands and is
recorded: Gitea also migrates on its own at startup, so the init container that runs
`gitea migrate` is what makes the migration a visible, separate step rather than a side
effect of the first pod.

## What Changes

- **`modules/gitea/`**: one module, two components. `postgres` as a stateful workload with a
  persistent volume, `gitea` (rootless image) as a stateless workload with a persistent
  volume, two init containers (wait for the database, run `gitea migrate`), and a readiness
  probe whose path is a value, so a failure can be injected without touching the module.
- **`modules/gitea-backup/`**: one task-workload module with a `mode` value: `none` renders
  only the backup volume, `dump` adds a Job that writes `pg_dump` output to it, `restore` adds
  a Job that restores from it. One instance, `gitea-backup`, toggled through modes by the
  hooks. Pruning is what retires the previous Job.
- **`bundle/instances/gitea/`** with `values.cue`, `pre-apply` (dump before an upgrade) and
  `on-failure` (restore after a failed one), and `bundle/instances/gitea-backup/`.
- **Ordering** through `OPM_SUITE_APPS=gitea-backup,gitea`: the backup instance exists before
  the application's hooks need it.
- **RBAC** widened to the kinds the two modules render: StatefulSet, PersistentVolumeClaim,
  Job.
- The Gitea database password lives in `values.cue` in clear. This is a proof of concept on a
  disposable cluster; the finding notes what a real suite would need instead.

Out of scope: a PostgreSQL major-version upgrade, Gitea SSH, ingress, object storage, any
backup retention beyond one dump, and any encryption of the values.

## Capabilities

### New Capabilities

- `bundle-gitea`: the installer installs Gitea with its PostgreSQL database, upgrades it with a
  schema migration, and after a failed upgrade restores the database dump taken before it
  and reverts the pods.

### Modified Capabilities

None. `bundle-apply` and `bundle-lifecycle` keep every requirement; this change is their
first real user.

## Impact

- **New files**: `modules/gitea/`, `modules/gitea-backup/`, four files under
  `bundle/instances/`, two `cue.mod/local-module.cue` entries, RBAC rules in `deploy/`.
- **Modified**: `deploy/` RBAC, `README.md`, `CLAUDE.md`. The entrypoint is expected to need
  no change; if it does, that is a finding about the hook contract.
- **RBAC delta**: `apps/statefulsets`, `core/persistentvolumeclaims`, `batch/jobs`, all
  namespaced, with the same verbs as the existing kinds.
- **What `opm` cannot do**: run a command inside a pod. Without `exec`, the dump and the
  restore are workloads, applied and waited for like anything else. That turned out to be the
  cleaner shape, and it is written down as such rather than as a gap.
- **Image pulls**: Gitea and PostgreSQL images are pulled by the cluster, not carried by the
  installer image. The installer stays offline; the cluster does not. Stated in the design.

### Alternatives not chosen

- **Do nothing.** The lifecycle would be proven only on a stateless application, which is
  the case where it is least needed.
- **Listmonk or Miniflux**, the recommendation during the discussion (lighter, migration
  explicit by design). The user chose Gitea; the design keeps the migration explicit with an
  init container, so the demonstration is the same.
- **Migrate in `pre-apply` from the installer pod.** Needs the Gitea binary in the installer
  image and runs the migration against the old pods. The init container ships with the
  application image and runs at the right moment.
- **Drop the dump and rely on the old version starting against the new schema.** Gitea may or
  may not tolerate a newer schema; either way it would prove nothing about restoring state.
- **Snapshot the volume instead of `pg_dump`.** Kind has no snapshot class, and a snapshot
  would hide the database in a way a dump file does not.
