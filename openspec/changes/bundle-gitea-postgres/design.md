## Context

See `proposal.md` for motivation and `specs/bundle-gitea/spec.md` for the contract. Builds on
`upgrade-with-revert`'s hook contract (`pre-apply`, `on-failure`, the `OPM_SUITE_*`
environment) and its rule that an upgrade is a values change. Everything here is either CUE
in the bundle or one of those two hook files.

Catalog facts, read from the vendored `opmodel.dev/catalogs/opm@v4`: `#StatefulWorkload`
composes container, volumes, scaling, restart policy, update strategy, sidecar and init
containers; `#StatelessWorkload` and `#TaskWorkload` (a Job) compose init containers too;
`#VolumeSchema` takes exactly one of `emptyDir` or `persistentClaim`, and the PVC transformer
"creates standalone PersistentVolumeClaims from Volume resources". Containers take `env`,
`command`, `args`. Nothing below assumes more than that; task 1.1 renders the modules before
anything touches a cluster.

Gitea facts, from `docs.gitea.com`: `gitea migrate` "migrates the database ... This command is
idempotent"; configuration through `GITEA__section__KEY` environment variables, with the
PostgreSQL set being `GITEA__database__DB_TYPE=postgres`, `HOST`, `NAME`, `USER`, `PASSWD`;
the rootless image is `docker.gitea.com/gitea:<version>-rootless`, listening on 3000, with
`/var/lib/gitea` and `/etc/gitea` writable. The health endpoint (`/api/healthz`) and
`GITEA__security__INSTALL_LOCK=true` are well-known but not quoted from the docs; task 2.1
verifies both against the running pod.

## Goals / Non-Goals

**Goals**

- Two copy-paste modules and two hook files, nothing shared with podinfo.
- Every step of the lifecycle is an `opm`-applied workload or an `opm` verb.
- One failure injection that migrates the schema and then fails, so the restore is load-bearing.

**Non-Goals**

- Secrets handling. The password is a value. Recorded, not solved.
- A PostgreSQL version change. `postgres:16` on both sides of every test.
- Gitea SSH, ingress, mail, or an admin user beyond what the API test needs.

## Decisions

### D1: `modules/gitea` is two components in one module

```
postgres   #StatefulWorkload + #Expose
           image postgres:16, volume pgdata (persistentClaim) at /var/lib/postgresql/data,
           env POSTGRES_USER/POSTGRES_PASSWORD/POSTGRES_DB from #config.db,
           readiness: exec pg_isready
gitea      #StatelessWorkload + #Expose
           image docker.gitea.com/gitea:<#config.image.tag>-rootless, port 3000,
           volume data (persistentClaim) at /var/lib/gitea,
           initContainers:
             wait-for-db  postgres:16, `until pg_isready -h gitea-postgres; do sleep 2; done`
             migrate      the gitea image, `gitea migrate`, same env as the main container
           env GITEA__database__{DB_TYPE,HOST,NAME,USER,PASSWD}, GITEA__security__INSTALL_LOCK=true
           readinessProbe: httpGet #config.readinessPath on 3000 (default /api/healthz)
           scaling 1, updateStrategy RollingUpdate
```

`#config`: `image.tag`, `db.{name,user,password}`, `readinessPath`. Only `image.tag` and
`readinessPath` change between the test images; the module stays identical, which is what
`upgrade-with-revert` D2 requires for the revert to render.

One module rather than two (`postgres` and `gitea` as separate instances) because the
database has no life of its own here, and one `ModuleInstance` means one capture, one revert.
The rolling update with one replica keeps the old Gitea pod serving until the new one is
ready, which is what makes the failed-upgrade scenario observable rather than an outage.

**Alternative rejected**: a Job component for the migration inside the same module. The
catalog can render it, but nothing orders a Job before a Deployment inside one apply, and a
completed Job with an unchanged spec never re-runs. The init container runs exactly once per
rollout, in order, by Kubernetes' own rules.

### D2: `modules/gitea-backup` is one task workload with a `mode`

```
#config: mode: "none" | "dump" | "restore", db: {host, name, user, password}

mode none     renders only the backup volume (persistentClaim `gitea-backup`)
mode dump     adds task workload `gitea-backup-dump`:
                postgres:16, `pg_dump -Fc -h $host -U $user -d $name -f /backup/gitea.dump`
mode restore  adds task workload `gitea-backup-restore`:
                postgres:16, `pg_restore --clean --if-exists -h $host -U $user -d $name /backup/gitea.dump`
```

Both Jobs mount the same claim. The instance is applied once with `mode: none` at install
(`OPM_SUITE_APPS=gitea-backup,gitea`), and the hooks toggle it:

```bash
# bundle/instances/gitea/pre-apply (the shape; the file is a plain script)
[ -n "$OPM_SUITE_PREVIOUS_VALUES" ] || exit 0          # first install: nothing to dump
backup_apply none                                       # prunes any previous Job
backup_apply dump && backup_wait                        # a fresh Job, waited to Complete
```

where `backup_apply` writes `values: {mode: "<m>", db: ...}` as the `gitea-backup` instance's
`values.cue` in `$OPM_SUITE_WORK` and runs `opm instance apply` with `--kubeconfig
"$OPM_SUITE_KUBECONFIG"`, and `backup_wait` polls `opm instance status gitea-backup` exactly
as the entrypoint does (exit `0` on `Complete`). `on-failure` does the same with `restore`.
The second script is a copy of the first with one word changed: the constitution's rule.

The `none` step is what makes re-runs work. A Job is immutable and a completed one never
runs again on an identical apply; applying `none` first lets `opm`'s pruning delete the old
Job, and the next apply creates a new object. `opm instance delete` would also delete the
volume, which holds the dump. **`opm instance apply` prunes by default**
(`opm instance apply --help`: `--no-prune  Skip stale resource pruning`), so no flag is
needed.

The restore runs `--clean --if-exists` while the failed new pod and the still-serving old
pod may both hold connections. PostgreSQL drops tables under an idle connection; a connection
inside a transaction blocks the drop until it ends. Task 3.2 measures whether that ever
stalls the restore in practice; if it does, the restore Job first terminates other sessions
with `pg_terminate_backend`, and the finding says so.

**Alternative rejected**: dump to the installer pod's own disk. Needs `exec`, which nothing
in the image can do, and the dump dies with the pod.

### D3: The failure injection migrates first, then fails

The failing image is the newer Gitea tag with `readinessPath: "/no-such-path"`. The
`wait-for-db` and `migrate` init containers run to completion, the schema is migrated to the
new version, the main container starts and never becomes ready. The rolling update leaves the
old pod serving. The entrypoint times out, `on-failure` restores the dump, the built-in revert
re-applies the previous values, the old tag rolls again, `gitea migrate` on the old tag finds a
schema at its own version, and the pod becomes ready.

This is the only injection that makes the restore load-bearing. A bad image tag, as in
`upgrade-with-revert`, would fail before the migration and prove only the pod revert again.

Evidence the restore mattered, collected in task 3.2: the migrate init container log on the
new tag lists applied migrations; the restore Job log shows the restore; after the revert the
old tag's migrate log shows nothing to do, and a repository created before the upgrade is still
returned by `GET /api/v1/repos/search`.

### D4: Ordering and what is asked of the entrypoint

`OPM_SUITE_APPS=gitea-backup,gitea` is set in the Job manifest. `gitea-backup` in `mode:
none` applies first and needs no wait beyond the volume being bound (`opm instance status`
reports a PVC as ready when bound; verified in task 1.2). `gitea` follows, and its hooks can
rely on the backup instance existing.

Nothing new is asked of `scripts/opm-suite`. If a task finds otherwise, the change to the
entrypoint is recorded as a finding about the hook contract, and made there.

### D5: RBAC delta

All namespaced, verbs `get, list, create, patch, delete` as for the existing kinds:

| Resource | Rendered by |
| --- | --- |
| `apps/statefulsets` | `postgres` component |
| `core/persistentvolumeclaims` | both modules |
| `batch/jobs` | `gitea-backup` |

`core/pods` `list` (already present) covers `status --details` for the Jobs' pods.

### D6: Images the cluster pulls

`docker.gitea.com/gitea:1.24.x-rootless`, `docker.gitea.com/gitea:1.25.x-rootless` (the
exact patch tags are pinned in `values.cue` at implementation time, chosen as the two newest
consecutive minors) and `postgres:16`. The installer image remains offline; the kind node
pulls these from the internet. Pre-pulling them with `kind load` is an accepted shortcut for
the timeout tests so a slow pull does not masquerade as a failed upgrade.

## Risks / Trade-offs

- **`pg_restore --clean` blocks on an open transaction.** → Measured in task 3.2; fallback
  named in D2.
- **The old Gitea tag refuses a newer schema even after restore**, because of a leftover
  migration row. → The dump is a full `pg_dump -Fc` and `--clean` drops the tables, so the
  migration table comes back at the old version. If Gitea keeps version state elsewhere, that
  is the finding.
- **Gitea self-migrates at startup, so the init container is redundant.** → It is: the init
  container exists to make the step visible and to put the failure before the main container.
  Stated in the proposal.
- **Two RWO claims mounted by two pods.** → Same node on kind; on a multi-node cluster the
  dump Job could land elsewhere and fail to mount. Accepted for a single-node PoC and
  recorded.
- **The password is in `values.cue` and in the CR's `spec.values`.** → Accepted for this
  repo; the finding names the seam (a Secret resource plus `envFrom`) a real suite would use.
- **The hook scripts duplicate the entrypoint's wait loop.** → Second repetition. The third
  is when a helper is extracted, per the constitution.
