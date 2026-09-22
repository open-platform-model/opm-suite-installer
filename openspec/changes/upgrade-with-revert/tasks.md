## 1. Read the record back

- [ ] 1.1 With podinfo applied by `apply-bundled-suite` on the `opm-suite` kind cluster, read
  the `ModuleInstance` API group and version off the installed CRD and fetch the CR with
  `wget` plus the service account token from inside the Job image (D1); verify `spec.values`
  holds the podinfo values the last apply used and note the exact API path.
- [ ] 1.2 Add `jq` to the `Containerfile` alongside `wget`, `SUITE_VERSION` into
  `/opt/opm/VERSION`, and `task build` passing `TAG` (D5); verify `task check` stays green,
  `list` prints the tag, and the image size delta is recorded.

## 2. Capture, hooks and revert

- [ ] 2.1 Add the capture step to `apply` (D1, D4): CR read into `$WORK/<app>.previous.json`,
  a `404` meaning first install, any other failure meaning exit `72`; verify against the
  cluster that a re-run of the same image logs the captured tag and still exits `0` with no
  pod restarted.
- [ ] 2.2 Add the hook runner (D3) and `bundle/instances/podinfo/pre-apply`; extend `task lint`
  to shellcheck `bundle/instances/*/pre-apply` and `on-failure`; verify the Job log carries
  podinfo's previous tag before the apply line, and that a `pre-apply` made to `exit 1` gives
  exit `76` with nothing applied.
- [ ] 2.3 Add the revert (D2, D4): on failed upgrade, `on-failure` if present, then
  `values.cue` rewritten from the capture, apply and wait again, exit `74` or `75`; verify on
  the cluster by building a second image whose podinfo tag does not exist and running it with
  `OPM_SUITE_TIMEOUT=60s`: the Job fails with `74`, the Deployment runs the working tag with
  all replicas available, and the CR records the working values. Also check whether the wait
  ever returned `0` while the new pod was in `ImagePullBackOff`; if it did, record it.
- [ ] 2.4 Verify the happy upgrade: build an image with a newer real podinfo tag, run it over
  the working install, confirm exit `0`, the new tag running, a higher revision in the CR, and
  a second run of the same image restarting nothing.

## 3. Record and close

- [ ] 3.1 Add the `FINDINGS.md` entries: `opm` records `spec.values` but nothing prints it
  back, so the entrypoint reads the CR over the API; JSON as `values.cue` is a working revert
  mechanism; whether `opm instance status` is a sufficient readiness signal during a rollout;
  and what the `jq` decision cost. Report the read-side gap to `cli/`.
- [ ] 3.2 Update `README.md` and `CLAUDE.md` (hooks, exit codes, the "an upgrade is a values
  change" rule), then run `task check` and the named cluster run (`kind` cluster `opm-suite`,
  from `task cluster:up`, through both the failing and the succeeding upgrade) and confirm
  both are green.
