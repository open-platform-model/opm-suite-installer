## 1. Prove the two cluster claims inside the image

- [ ] 1.1 `task cluster:up`, then from the built image (not the host) run `opm operator install
  --crds-only` with `--network=none` and a kubeconfig pointing at the kind API server (D2), and
  `opm instance status` with no kubeconfig at all (D1); verify the CRD reaches `Established`
  without network and that the missing-kubeconfig error reproduces inside the image. Write both
  results down for the findings task.

## 2. The entrypoint

- [ ] 2.1 Add the in-cluster kubeconfig synthesis to `scripts/opm-suite` (D1): written under
  `$WORK`, only when no kubeconfig is configured and `KUBERNETES_SERVICE_HOST` is set, passed
  as `--kubeconfig` to every cluster-facing `opm` call; verify with a scratch pod that
  `opm-suite apply` reaches the API server, and that `KUBECONFIG=...` on the host bypasses it.
- [ ] 2.2 Add the `apply` subcommand: shared selection and validation, CRD bootstrap with exit
  `71`, then per application `opm instance apply --platform` with exit `72` (D4); verify against
  the test cluster that `apply podinfo` creates the `ModuleInstance`, Deployment and Service in
  `OPM_SUITE_NAMESPACE`, and that `apply podinfo other` exits `65` before any cluster call.
- [ ] 2.3 Add the readiness wait on `opm instance status`, `OPM_SUITE_TIMEOUT`, and exit `73`
  with `--details` on stderr (D3); verify a nonexistent podinfo tag with `OPM_SUITE_TIMEOUT=60s`
  exits `73` in about a minute and that the normal tag returns only after the Deployment reports
  available replicas. `shellcheck -x` passes.

## 3. Run it as a Job

- [ ] 3.1 Write `deploy/`: Namespace `opm-suite`, ServiceAccount, the D5 ClusterRole and Role
  with their bindings, and the D6 Job; add `task job:run` and `task job:logs`; verify
  `task cluster:up && task build && task cluster:load && task job:run` on a bare kind cluster
  ends with the Job `Complete` and podinfo available, using only the image to prepare the
  cluster.
- [ ] 3.2 Measure RBAC: start from the D5 table, run the Job, remove every rule the run did not
  need and add every rule it did, one Forbidden at a time; verify the shipped rules are the
  minimum by confirming that removing any one of them fails the Job. Record the final table.
- [ ] 3.3 Verify the second-run scenarios: `task job:run` again exits `0` with the same pods
  running (compare pod UIDs before and after), and a hand-edited replica count is set back by
  the re-run.

## 4. Record and close

- [ ] 4.1 Add the `FINDINGS.md` entries: `opm` has no in-cluster kubeconfig fallback and how
  the image works around it; `opm instance apply` has no readiness wait for CLI-owned instances
  and `opm instance status` exit codes serve instead; whether `--crds-only` is truly offline;
  the measured RBAC width for one application, answering the open question. Report the first
  two to `cli/` as issues.
- [ ] 4.2 Update `README.md` and `CLAUDE.md` for `apply`, `deploy/` and the `job:*` tasks, then
  run `task check` and the named cluster run (`kind` cluster `opm-suite`, from `task cluster:up`)
  and confirm both are green.
