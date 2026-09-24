## Why

The image renders, and nothing more. The half of the installer idea that has a cluster in it,
bootstrapping a bare cluster and applying what the bundle renders, is still an assertion. Every
later question this repo wants to ask (upgrades, reverts, a second application) needs an
`apply` verb to stand on, and the constitution forbids preparing the cluster any other way.

This change answers one question: **can the image, run as a `Batch/Job` on a bare cluster,
install the CRDs it needs and apply a bundled application with nothing but `opm` and bash?**
Three smaller questions fall out of it and get measured rather than guessed: whether `opm` can
authenticate from inside a pod at all, how wide the Job's RBAC has to be for one application
(an open question in `FINDINGS.md` since the first change), and whether "wait until it is
ready" is expressible without `kubectl`, which the constitution's bash-only rule keeps out of
the image.

One of them already has a partial answer from reading the CLI and running it once: `opm`
resolves its kubeconfig to `~/.kube/config` as an explicit path and refuses when the file is
absent, so a pod's service account token is not picked up on its own. The design says what the
image does about it and the tasks verify it in the cluster.

## What Changes

- `opm-suite apply [app...]`, the cluster-facing counterpart of `render`. Same application
  selection, same namespace source, same working-copy render. It installs the `ModuleInstance`
  CRD with `opm operator install --crds-only`, then for each application runs
  `opm instance apply` and waits until `opm instance status` reports the instance ready.
- In-cluster authentication: when the entrypoint runs inside a pod and no kubeconfig was given,
  it writes one from the mounted service account token and passes it to every `opm` call.
- `deploy/`: the Namespace, ServiceAccount, RBAC and `Job` manifests that run the image, plus
  `task job:run` and `task job:logs` to apply them to the test cluster and read the result.
- New exit codes for the new failure modes: CRD bootstrap failed, apply failed, readiness
  timeout.
- Nothing about the render path changes. `render` and `list` behave as before.

Out of scope: upgrades and reverts, a second application, a full `opm operator install`, any
hook mechanism, and pruning policy beyond what `opm instance apply` does by default.

## Capabilities

### New Capabilities

- `bundle-apply`: the installer image, run as a Job, bootstraps the OPM CRDs on a bare cluster
  and applies its bundled applications to the cluster it runs in, waiting for readiness, with
  an idempotent second run.

### Modified Capabilities

None. `bundle-render` keeps every requirement and scenario as is.

## Impact

- **New files**: `deploy/` manifests, `job:*` tasks in `Taskfile.yml`. **Modified**:
  `scripts/opm-suite` (new subcommand, kubeconfig synthesis), `README.md`, `CLAUDE.md`.
- **Nothing new in the image.** No `kubectl`, no `jq`, no extra binary. The readiness wait is
  `opm instance status`, which exits non-zero while any resource is not ready.
- **RBAC**: the Job's ServiceAccount is the first real measurement of how wide the installer's
  permissions must be. The design lists the delta; the cluster run confirms it.
- **What `opm` cannot do, recorded as findings for `cli/`**: it has no in-cluster
  authentication fallback, and `opm instance apply` has no readiness wait for CLI-owned
  instances (the `--timeout` it takes applies only to operator-managed ones). Neither is
  worked around beyond what bash needs to proceed: a kubeconfig written from the token, and a
  polling loop on `opm instance status`.

### Alternatives not chosen

- **Do nothing.** Leaves the cluster half untested and blocks every later change. The render
  proof alone does not answer the repo's question.
- **Apply the rendered YAML with `kubectl`.** Simpler on the surface, but it needs a binary the
  constitution keeps out of the image, and it throws away the inventory, pruning and the
  `ModuleInstance` record that `opm instance apply` writes, which the upgrade change depends
  on.
- **A full `opm operator install`.** Would give operator ownership, except a bundled module can
  never be operator-owned (`FINDINGS.md`, 2026-09-22), and the seeded cluster Platform is
  currently broken. `--crds-only` is the honest minimum.
- **Ship RBAC wide (`cluster-admin`).** Would make the measurement meaningless. The RBAC width
  is one of the things this change exists to measure.
