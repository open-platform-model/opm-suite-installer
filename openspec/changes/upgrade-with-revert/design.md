## Context

See `proposal.md` for motivation and `specs/bundle-lifecycle/spec.md` for the contract.
Builds on `apply-bundled-suite`: its `apply` loop, working copy, synthesized kubeconfig,
readiness wait and Job are all reused, and nothing there changes shape.

The one thing this change needs from the cluster is the previous values. `opm instance apply`
writes them: the CR's `spec.values` is "the unified values the last apply consumed, recorded
so a future ownership transfer can replay them" (`cli/internal/inventory/record.go`). Nothing
in `opm` prints them back:

```
$ opm instance status --help
  -o, --output string   Output format (table, wide, yaml, json) (default "table")
```

and the JSON shape (`cli/internal/kubernetes/status.go`) carries `instanceName`, `version`,
`owner`, `resources` and `aggregateStatus`; `opm instance list -o json` carries `module`,
`version`, `status` and `lastApplied`. No values in either.

## Goals / Non-Goals

**Goals**

- Revert with what the cluster recorded, not with what the image believes.
- Keep `apply` one code path: upgrade and install differ only in whether a capture exists.
- A hook contract small enough that the Gitea change can fill it with two scripts.

**Non-Goals**

- Reverting a module CUE change. If `modules/<app>` differs between releases, the previous
  values may not even unify with the new module; that case fails and says so.
- Multi-step history. One capture, taken at the start of the run, replaced by the next run.
- Making hooks a library. Two files per application, no shared source.

## Decisions

### D1: The previous values are read from the CR over the API, with `wget` and `jq`

The entrypoint already has a kubeconfig or a token. Reading the CR is one request:

```bash
wget -qO- \
  --ca-certificate=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  --header="Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  "https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/apis/opmodel.dev/v1alpha1/namespaces/$ns/moduleinstances/$app" \
  | jq -c '.spec.values' >"$WORK/$app.previous.json"
```

(The exact API group and version of `ModuleInstance` are read off the CRD in task 1.1; the
path above is the shape, not a verified string.) A `404` means first install: no capture, no
revert. On a developer host with a kubeconfig, the same read goes through
`--kubeconfig`-derived server, CA and token fields; if that turns out to be more bash than it
is worth, host runs simply skip the capture and say so, since the Job is the thing under
test.

`jq` is installed from Debian's package repository next to `wget`, which the `Containerfile`
already installs the same way. The constitution allows "the base image's own tools"; a
package from the base image's own repository is read as that, and it is stated here so the
reading can be argued with. `wget` alone cannot extract one object from JSON, and hand-rolled
`sed` over JSON is the kind of thing this repo exists to show is not worth doing.

**Alternative rejected**: `opm instance status -o json`. Verified above: no values in it. The
finding for `cli/` is that the record `opm` writes for replay has no read side.

### D2: Revert is `apply` with the captured values as `values.cue`

JSON is CUE. Verified on the host with the bundled podinfo: a `values.cue` of

```
package podinfo

values: {"image":{"repository":"ghcr.io/stefanprodan/podinfo","tag":"6.9.0","digest":""},"replicas":2}
```

rendered `replicas: 2` and `image: ghcr.io/stefanprodan/podinfo:6.9.0` (exit 0). So the revert
overwrites `values.cue` in the working copy with `package <pkg>` plus `values: <captured
JSON>` and re-runs exactly the apply-and-wait it just ran. `opm instance apply` loads
`values.cue` next to the instance file by default (`opm instance apply --help`, `-f`), so no
flag changes.

This is why an upgrade is defined as a values change: the captured values must unify with the
module in the image. When they do not, the revert fails at render, exits `75`, and the message
says the module changed. The Gitea change keeps its module stable across the two tags it
tests for exactly this reason.

**Alternative rejected**: capturing the rendered manifests instead of the values, and
re-applying those. It would survive a module change, but it needs `kubectl apply` or a
reimplementation of apply in bash, both forbidden, and it would leave the `ModuleInstance`
record describing the failed version.

### D3: Hooks are two optional files with an environment, not a framework

```
bundle/instances/<app>/pre-apply     runs before the apply; non-zero aborts (exit 76)
bundle/instances/<app>/on-failure    runs after a failed upgrade, before the built-in revert

OPM_SUITE_APP                the application name
OPM_SUITE_NAMESPACE          the target namespace
OPM_SUITE_KUBECONFIG         the kubeconfig path opm is using (synthesized or given)
OPM_SUITE_PREVIOUS_VALUES    path to the captured values JSON; empty on a first install
OPM_SUITE_WORK               the working copy, for scratch files
```

Run as `bash "$hook"` from the working copy (so the file needs no execute bit in git), stderr
and stdout both redirected to stderr with a `<app>:` prefix via `sed`, because stdout is the
manifest channel for `render` and nothing else may write to it. `task lint` shellchecks them.

`on-failure` runs before the built-in revert so a database restore (the Gitea case) happens
while the failed pods are the ones running, and the revert then brings back pods that expect
the restored state. Its exit status is logged and ignored: a revert that is skipped because a
restore printed a warning helps nobody.

Podinfo's `pre-apply` is three lines that print `OPM_SUITE_APP` and the previous tag read
with `jq` from `OPM_SUITE_PREVIOUS_VALUES`. It exists so the hook path is executed on every
Job run, not first exercised by Gitea.

### D4: Exit codes and the run shape

```
exit 74   an upgrade failed and the revert brought the previous values back and ready
exit 75   an upgrade failed and the revert also failed (render, apply or readiness)
exit 76   a pre-apply hook refused
```

Per application, in order:

1. capture previous values (D1); absent means first install
2. `pre-apply` if present (D3)
3. `opm instance apply` and the readiness wait, as before
4. on failure with a capture: `on-failure` if present, then revert (D2) and wait; exit 74/75
5. on failure without a capture: exit 72/73 as before

The run stops at the first failing application in every case.

### D5: The suite version is a file

`Containerfile` writes `TAG` into `/opt/opm/VERSION` (`ARG SUITE_VERSION`, passed by
`task build` from `TAG`). `list` prints it, `apply` logs it first. There is no version
comparison anywhere: the image applies what it carries. The file exists so a log can be
matched to a release.

### RBAC delta

None. `get` on `moduleinstances` in the target namespace is already required by
`apply-bundled-suite` D5, and the API read uses the same token.

## Risks / Trade-offs

- **The readiness wait returns early during a rollout** (a Deployment can be "ready" with the
  old pod still serving). → The nonexistent-tag scenario is the measurement: if the wait
  returns `0` while the new pod is in `ImagePullBackOff`, `opm instance status` is not a
  sufficient signal and the finding says what it misses. Task 2.3 checks this explicitly.
- **The captured values do not unify with a changed module.** → Exit `75` with a message
  naming the module; accepted, and defined as "not an upgrade" in the proposal.
- **`jq` stretches "base image's own tools".** → Stated in D1. If the reading is rejected,
  the fallback is the `previous/values.cue` alternative from the proposal, and this design's
  D1 is the only section that changes.
- **A revert that succeeds hides the failure from a casual reader.** → Exit `74` is non-zero
  and the Job shows `Failed`. The log says what happened in the first and last line.
