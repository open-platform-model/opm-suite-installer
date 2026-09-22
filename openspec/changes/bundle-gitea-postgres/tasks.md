## 1. The modules, rendered before any cluster

- [ ] 1.1 Create `modules/gitea/` (D1) and `modules/gitea-backup/` (D2) on
  `suite-installer.invalid/modules/...@v0` with their identity packages, add the bundle's
  `local-module.cue` entries and `bundle/instances/{gitea,gitea-backup}/{instance.cue,values.cue}`;
  verify `opm-suite render gitea-backup gitea` on the host renders one StatefulSet, one
  Deployment, two Services, three PVCs and no Job, and that `mode: dump` and
  `mode: restore` each render exactly one Job with the expected command. `task check` stays
  green, so the offline proof now covers three applications.
- [ ] 1.2 Widen `deploy/` RBAC by the D5 rows, `task cluster:up`, and apply `gitea-backup` in
  `mode: none` through the Job; verify the claim binds and `opm instance status gitea-backup`
  exits `0` for an instance that is only a PVC.

## 2. Install and the happy upgrade

- [ ] 2.1 Run the full Job with `OPM_SUITE_APPS=gitea-backup,gitea` on the bare cluster;
  verify exit `0`, both init containers completed in order, `/api/healthz` answers from a
  scratch pod, and `INSTALL_LOCK` skipped the web installer. Record the health path and the
  lock variable as verified. Re-run the Job and verify no pod restarts.
- [ ] 2.2 Write `bundle/instances/gitea/pre-apply` and `on-failure` (D2), shellchecked by
  `task lint`; verify on the running install that `pre-apply` with no previous values exits
  `0` without applying anything, and with previous values leaves a completed
  `gitea-backup-dump` Job and a dump file in the claim.
- [ ] 2.3 Create a repository through the API, build an image with the next minor Gitea tag,
  run it; verify exit `0`, the migrate init container log lists applied migrations, the
  repository is still returned by `GET /api/v1/repos/search`, and the CR shows the new tag.

## 3. The failed upgrade

- [ ] 3.1 Build the D3 failing image (newer tag, `readinessPath: "/no-such-path"`), reset to the
  installed state from 2.1 plus a repository, run with `OPM_SUITE_TIMEOUT=120s`; verify the
  dump completed before the apply, the new tag's migrate log shows migrations, the restore Job
  completed, the old tag's pod is ready, the repository is still listed, and the Job exit is
  `74`.
- [ ] 3.2 Measure the restore against open connections (D2) and the leftover-schema risk: read
  the restore Job log for waits or errors, and the old tag's migrate log after the revert;
  verify neither stalled, or implement the `pg_terminate_backend` fallback and re-verify.
  Run the failing image a second time and verify the outcome is identical.

## 4. Record and close

- [ ] 4.1 Add the `FINDINGS.md` entries: dump and restore as `opm`-applied task workloads
  toggled through a `mode` value, and pruning as the Job lifecycle; what the restore needed
  against live connections; whether the revert restored a schema Gitea accepted; what a second
  application cost in files and RBAC rows; the password-in-values seam. Report to `cli/`
  anything the hook contract needed that the entrypoint did not offer.
- [ ] 4.2 Update `README.md` and `CLAUDE.md` (three bundled applications, the ordering rule,
  the two hook files), then run `task check` and the named cluster run (`kind` cluster
  `opm-suite`, from `task cluster:up`, through install, the succeeding upgrade and the failing
  one) and confirm both are green.
