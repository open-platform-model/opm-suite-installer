# Constraints the opm CLI puts on the installer

Covers what `opm` does and does not do inside the installer Job, and why the entrypoint, the image
and the RBAC look the way they do. These were measured against `cli/` when the repo was
bootstrapped. They describe a moving codebase and are not a contract: re-verify one before you
rely on it, and record any change in `FINDINGS.md`.

## Apply and ownership

- **Bundling modules locally forces CLI-owned apply.** A local render stamps
  `module-instance.opmodel.dev/source: local` on the `ModuleInstance` CR, and the operator handoff
  path refuses it. The Job therefore does the server-side apply itself and keeps ownership: no
  operator reconcile loop and no drift correction after the Job exits.
- **The Job's ServiceAccount needs RBAC for every kind any bundled module renders**, plus the
  `ModuleInstance` CR it writes as inventory. Measured for podinfo: `get`, `create` and `patch` per
  rendered kind and on `moduleinstances`; `patch` on `moduleinstances/status`; `get`, `create` and
  `patch` on CRDs cluster-wide; `list` on pods for `--details`. No `delete` yet, because nothing has
  pruned.
- **`opm instance apply` needs the `ModuleInstance` CRD to exist.** It fails fast with a hint when
  it is missing. On a bare cluster the image installs the CRDs itself with
  `opm operator install --crds-only`. The CRDs are embedded in the binary, so this needs no network
  beyond the API server.
- **`opm` has no in-cluster kubeconfig fallback** (cli#227). In a pod with no kubeconfig, the
  entrypoint writes one from the service account token under `TMPDIR` and passes `--kubeconfig`.
  `OPM_KUBECONFIG` or `KUBECONFIG`, when set, win.

## Waiting and upgrades

- **`opm instance apply` does not wait for CLI-owned instances** (cli#228), so the entrypoint polls
  `opm instance status`. That signal is sound for a first install and wrong for a broken rollout:
  Deployment health is the `Available` condition alone, so an upgrade to a bad image stays Ready.
  The entrypoint therefore also requires a finished rollout, read off each inventory Deployment.
  `updatedReplicas` does not catch it (measured: desired 1, updated 1, available 1, total 2 on a
  wedged rollout); `status.replicas == status.updatedReplicas` does. Deployments only.
- **`opm` records an instance's values and prints them back nowhere.** `spec.values` on the
  `ModuleInstance` is what the last apply consumed, but neither `opm instance status -o json` nor
  `opm instance list -o json` carries it. The entrypoint reads the CR over the API with `wget` and
  `jq`, which needs no RBAC beyond the `get` that apply already needs. The record holds the values
  the instance declared, not the module's resolved config: whatever a bundled application does not
  write into its `values.cue` is not in the record, and is not what a failed upgrade reverts to.
- **An upgrade is a values change, and there is no `upgrade` verb.** Re-running `apply` from a newer
  image is the upgrade. A failed one re-applies the captured JSON as `values.cue` (JSON is CUE) and
  waits again. A module that moved between two releases can make its own revert fail at render.

## Platform and offline rendering

- **A full `opm operator install` also seeds a cluster `Platform`**, which was broken when measured
  on an alpha operator and has not been re-tested. `--crds-only` or `--skip-platform` avoids it.
- **Platform precedence is `--platform <dir>`, then the cluster `Platform` CR, then
  `~/.opm/platform/`** (enhancement 0006, the platform-source flag). The cluster-CR path generates a
  platform module and resolves its dependency closure from the registry, which is a network call.
  A self-contained image bakes a platform module and passes `--platform`.
- **Offline operation does not depend on a warm `CUE_CACHE_DIR`.** Vendoring every dependency and
  redirecting it with `cue.mod/local-module.cue` renders with an empty cache and no network. The
  `image:render` task keeps this verified.
- **A local replacement the CLI calls "ignored" can still be required.** The bundle module must
  redirect `core` and the first-party catalog even though `opm` warns that the platform's
  replacement wins. Removing it breaks the instance-package load.
- **`opm instance build -n <ns>` does not set the namespace for an instance file**, and unlike
  `--name` it does not warn. The namespace arrives as a generated `.cue` file unified into the
  instance package, which is why the entrypoint renders from a copy under `TMPDIR`.
- **A module's `debugValues` does not reach an instance-file render.** Every bundled application
  ships its own `values.cue`.

## The image

- **The released `opm` binary is dynamically linked against glibc**, so the base is
  `debian:trixie-slim`, not Alpine.
- **Pin the `cli` tag whose embedded operator matches the OPM beta line**, because the embedded
  operator decides which CRDs the Job installs. Pin only a tag that carries release assets: without
  them there is no tarball to install or checksum.

## Pitfalls

- Trusting `Ready` from `opm instance status` after an upgrade. Check the rollout.
- Assuming the instance record holds defaults a module resolves. It holds only declared values.
- Removing a local replacement because `opm` warns it is ignored.

## Check before you finish

- [ ] A new bundled kind has an RBAC row in `deploy/`.
- [ ] Each bundled application writes every value a revert needs into its own `values.cue`.
- [ ] `task image:render` passes with no network and an empty CUE cache.
- [ ] A new finding about `opm` is in `FINDINGS.md`, and a missing behavior is reported to `cli/`.
