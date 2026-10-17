# opm-suite-installer repository guide

A proof of concept: one OCI container image that carries the `opm` CLI, a bash entrypoint script
and one or more locally bundled OPM modules. It runs as a Kubernetes `Batch/Job` and installs a
whole suite of applications into the cluster it runs in. Input arrives as job arguments and
environment variables. The first milestone is small on purpose: podinfo, installed from a bundled
`#Module` through a `#ModuleInstance`.

The repo answers one question: is a self-contained installer image a useful way to ship a suite of
OPM applications? It is not a product and not a supported artifact. Nothing here is published for
anyone else to consume, and the only artifact the repo publishes is a container image. A clear
negative answer is a successful result.

## Branch model

`main` is the only long-lived branch. Every change lands on it by PR.

## Repository rules

These are hard constraints. They keep the experiment cheap to throw away.

- **Bash only.** No Go, no Python, no compiled helpers. The entrypoint and every helper is a bash
  script. If something is impossible in bash, that is a finding to write down, not a reason to
  reach for a language.
- **No new abstraction until the third repetition.** Copy-paste beats a framework here.
- **The `opm` CLI is a dependency, never a fork.** Render, validation, platform resolution and apply
  belong to `opm`. If a workflow needs behavior `opm` lacks, that is a gap in `cli/` (or in
  `library/`), recorded in the change. Never reimplement it in bash, and never parse and rewrite
  rendered manifests.
- **Every non-obvious discovery is written down.** The output of this repo is knowledge as much as
  an image. `FINDINGS.md` is the log, and negative results count. Claims about `opm`, CUE or
  Kubernetes behavior are verified by running them.
- **The test cluster starts bare, and only the image may prepare it.** `task cluster:up` creates a
  stock single-node kind cluster and stops: no OPM operator, no CRDs, no Platform. Bootstrapping
  those is the installer image's job and the thing under test; a cluster that arrives prepared
  proves nothing. Never add an operator install to the `cluster:*` tasks, not even behind a flag,
  and never run one by hand before a test. Recreating the cluster is the reset. No Flux, no SOPS,
  no local registry, no sample bundle: `opm-kind-demo` owns that ground.
- **Never publish a CUE module** under `opmodel.dev/*` or `testing.opmodel.dev/*`. Bundled modules
  live in this repo's own CUE module and are imported by local path, so they need no registry.
  Both domains resolve from GHCR, anonymously.
- **Never hand-edit `vendor/`.** `task vendor:sync` generates it from the published source of the
  versions the platform module pins. To change a pin, edit the platform module's `cue.mod/module.cue`
  and re-run the task. That task is the one action here that contacts a registry.
- **`bundle/`, `modules/`, `platform/` and `vendor/` stay siblings**, in the repo and at `/opt/opm`
  in the image. The `cue.mod/local-module.cue` replacements that make the image render offline are
  relative paths between them.
- **Exit codes of the entrypoint:** `74` an upgrade failed and the previous values came back and are
  ready; `75` the upgrade failed and the revert failed too; `76` a `pre-apply` hook refused, so
  nothing was applied.
- **A change that adds or alters installer behavior goes through OpenSpec.** A change that only
  records a finding, or fixes a typo, does not.

## Layout

| Path | What it is |
| --- | --- |
| `bundle/` | The bundle CUE module: one `instances/<app>/` folder per bundled application, with optional `pre-apply` and `on-failure` hooks that `task lint` shellchecks |
| `modules/` | The bundled OPM modules, each its own CUE module |
| `platform/` | The baked `#Platform` module, passed to `opm` as `--platform` |
| `vendor/` | Committed CUE source of every dependency, plus a manifest of the versions |
| `scripts/` | The bash entrypoint |
| `deploy/` | Namespace, ServiceAccount, the measured RBAC and the Job that runs the image |
| `hack/` | The kind cluster config and the `vendor:sync` and `image:render` scripts |
| `references/` | Detail files for the router |
| `openspec/` | OpenSpec workspace: constitution in `config.yaml`, specs, changes |
| `Containerfile` | The installer image build |
| `FINDINGS.md` | What the experiment taught, negative results included |

## Commands

| Command | Purpose |
| --- | --- |
| `task lint` | `shellcheck` every script and hook |
| `task cite-lint` | Check CUE comments against the enhancement citation rule (needs Go; CI runs the same tool) |
| `task build` | Build the installer image |
| `task vendor:sync` | Refresh `vendor/` from the published source of every platform pin |
| `task image:render` | Prove the built image renders offline: no network, empty CUE cache |
| `task check` | Everything a change must pass before it lands: lint, build, image:render |
| `task cluster:up` | Create a bare kind test cluster, no OPM anything |
| `task cluster:status` | Show what the test cluster runs |
| `task cluster:load` | Load the locally built image into the cluster |
| `task cluster:down` | Delete the test cluster |
| `task job:run` | Apply `deploy/` to the test cluster, run the installer Job, print its log |
| `task job:logs` | Print the installer Job's log |

`CLUSTER` renames the cluster, `NODE_IMAGE` pins a Kubernetes version, `REGISTRY` overrides the CUE
registry mapping, `JOB_TIMEOUT` bounds how long `job:run` waits for the Job.

@CONTEXT.md
