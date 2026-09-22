# Findings

What the experiment taught us, including the negative results. Newest first.

Each entry: what was tried, what happened, what it means. A finding that kills an idea is worth
more than one that confirms it.

## Open questions

- Does the measured RBAC width for one application (below) stay proportional once a suite
  renders more kinds, and what does pruning add? No run in this repo has pruned yet.
- Is losing operator ownership (drift correction, reconciliation) acceptable for the use cases
  an installer image would serve? This is now the central open question, because a bundled
  module *cannot* be operator-owned at all (see the local-replacement entry below).
- Does the image stay this small once a suite is more than one application? 2.3 MB of vendored
  CUE against a 171 MB image says the CUE half is not what costs.

Answered: *how wide does the Job's RBAC have to be for one application?* Fourteen verbs, all
but three namespaced, measured one omission at a time; see the RBAC entry below.

Answered: *can an immutable image revert a failed upgrade with only what `opm` records on the
cluster?* Yes, and the record is enough on its own — but only once the readiness signal is
something other than `opm instance status`. See the top two entries.

Answered: *does a warm `CUE_CACHE_DIR` keep `opm instance build` off the network?* It does, but
the question stopped mattering. Vendoring makes the render offline by construction rather than by
cache warmth, and the vendored tree is a tenth the size and reviewable in a diff.

## Entries

## 2026-09-22: `updatedReplicas` is not the number that catches a stuck rollout; `replicas` is

**Tried.** Upgrading the bundled podinfo from `6.7.1` to a tag that does not exist, on the kind
cluster `opm-suite`, with `OPM_SUITE_TIMEOUT=60s`, and reading every rollout number off the
Deployment at the moment the wait gave up.

**Happened.** `opm instance status` reported `Ready`, as the entry below predicts. What is new is
which of the Deployment's own numbers disagreed:

```
Instance: podinfo   Status: Ready   Deployment podinfo-podinfo  Ready
  Deployment/podinfo-podinfo: desired=1 updated=1 available=1 total=2 generation=2 observed=2
```

`observedGeneration` is current, `updatedReplicas` equals the desired count, and
`availableReplicas` equals it too. A check built from those three — which is what the entry below
proposed — passes a rollout that is permanently wedged. The only number that gives it away is
`status.replicas`: **2**, because the old ReplicaSet's pod is still there keeping `Available`
true while the new pod sits in `ErrImagePull`.

**Means.** The condition that actually decides "this rollout finished" is
`status.replicas == status.updatedReplicas` — no replicas left that are not the new ones. The
entrypoint now requires all four (`observed >= generation`, `updated == desired`,
`available == desired`, `total == updated`) after `opm instance status` agrees, and that is what
makes the revert fire: exit `74` measured at 61s, image back to `6.7.1`, all replicas available,
and the `ModuleInstance` recording the working values again. The revert path's own failure was
measured too, by upgrading one nonexistent tag to another: exit `75`, with the reverted
instance's diagnostics on stderr. Deployments only; a StatefulSet or DaemonSet in a later bundle
falls back to the weaker signal and would need its own arm. Sharpens what open-platform-model/cli#228 should ask for:
`Available` alone is wrong, and `updatedReplicas` alone is also wrong.

## 2026-09-22: `opm` records the values it applied and prints them back nowhere

**Tried.** Finding the previous values to revert to, first through the CLI
(`opm instance status -o json`, `opm instance list -o json`), then by reading the
`ModuleInstance` CR from inside the Job pod with `wget` and the mounted service account token.

**Happened.** `opm instance apply` writes the values into the CR's `spec.values` so a later
ownership transfer can replay them (`cli/internal/inventory/record.go`), and nothing in the CLI
prints them: `status -o json` carries `instanceName`, `version`, `owner`, `resources` and
`aggregateStatus`; `list -o json` carries `module`, `version`, `status` and `lastApplied`. No
values in either. The CR read is one request and needs no new RBAC — the `get` on
`moduleinstances` the apply already requires covers it:

```
GET /apis/opmodel.dev/v1alpha1/namespaces/<ns>/moduleinstances/<app>
```

Two things it cost. `wget` exits `8` for every error status alike (measured for `404`;
documented as "server issued an error response" for the rest), so `-S` and the status line are
the only way to tell "not installed yet" from "not allowed" — the difference between a first
install and a run that must refuse to apply blind. And lifting one object out of JSON needs
`jq`: **1.1 MB** on a 173 MB image, from the base image's own package repository.

The record is also narrower than it looks. `spec.values` is the block the instance *declared*,
not the config the module resolved: with `values: {replicas: 1}` and the image left to the
module's default, the CR recorded `{"replicas":1}` and the image tag was simply absent. What a
release does not write into `values.cue` is not in the record, and so is not what a failed
upgrade reverts to. The bundled podinfo now pins its tag explicitly for that reason.

**Means.** For `cli/`: the record `opm` writes for replay has no read side. Either
`opm instance status -o json` should carry `spec.values`, or there should be an
`opm instance get -o json`. Until then any consumer that wants to know what it last applied
talks to the API server itself, which is a strange thing for a CLI to push its callers into.

## 2026-09-22: JSON is CUE, so the recorded values are a usable revert

**Tried.** Writing the captured `spec.values` JSON straight into the working copy's `values.cue`
as `package <pkg>` plus `values: <the JSON>`, and re-running the same `opm instance apply`.

**Happened.** It renders and applies unchanged. JSON is a subset of CUE, so no translation step
exists to get wrong, and `opm instance apply` loads `values.cue` from beside the instance file by
default, so not one flag changes between an apply and a revert. Measured end to end: a failed
upgrade reverted and the cluster came back to the tag it had, with the `ModuleInstance` recording
those values again.

**Means.** The revert needs no format of its own and no bookkeeping in the image. Its one
precondition is that an upgrade is a *values* change: the captured values have to unify with the
module this image carries, so a module that moved between two releases can make its own revert
fail at render. That is reported (exit `75`) rather than hidden, and it is why "an upgrade is a
values change" is a rule here and not a description.

## 2026-09-22: `status.inventory.revision` counts applies, not changes

**Tried.** Running the same installer image twice over an instance that was already up to date.

**Happened.** `opm` printed `✔ Instance up to date` and `2 unchanged` both times, no pod was
restarted, and the revision still went `7 -> 8`.

**Means.** A higher revision is evidence that an apply happened, not that anything changed. It
dates a run; it does not detect a drift or an upgrade. The signals that do are the inventory
digests and the rendered objects themselves.

## 2026-09-22: `opm` has no in-cluster kubeconfig fallback

**Tried.** `opm instance status` inside the installer image with no kubeconfig anywhere, first
on the host with `--network=none`, then as a pod on the kind cluster `opm-suite` with only the
mounted service account token.

**Happened.** Exit 3 both times, before any request:

```
ERRO m:podinfo: connecting to cluster error="building kubernetes config:
  stat /root/.kube/config: no such file or directory: connectivity error"
```

`OPM_KUBECONFIG=` (empty) gives the same error; the resolver treats empty as unset. The token
at `/var/run/secrets/kubernetes.io/serviceaccount/` is never consulted.

**Means.** `opm` resolves its kubeconfig to `~/.kube/config` as an explicit path and hands it to
client-go, which stats explicit paths. Every other Kubernetes CLI falls through to in-cluster
config when that file is absent; `opm` does not, so it cannot run in a pod unmodified. The
entrypoint works around it with a heredoc: when neither `OPM_KUBECONFIG` nor `KUBECONFIG` is
set and `KUBERNETES_SERVICE_HOST` is, it writes a kubeconfig under `TMPDIR` whose user is
`tokenFile: .../serviceaccount/token` (so a rotated projected token is read fresh) and passes
`--kubeconfig` to every call. Verified as a Job: the same image, no kubeconfig, reaches the API
server and installs podinfo. Reported as open-platform-model/cli#227.

## 2026-09-22: `opm instance apply` has no readiness wait for CLI-owned instances, and `opm instance status` misreads a broken rollout as ready

**Tried.** `opm instance apply` on the bundled podinfo, then watching what it waits for. Then
`opm instance status` as the wait signal, against a fresh install with a nonexistent image tag
and against an upgrade to a nonexistent tag.

**Happened.** `apply` returns as soon as the server accepts the objects: its `--timeout` bounds
"the operator-reconcile wait (operator-managed instances only)", and a bundled instance is never
operator-managed. `status` exits `2` while any resource is not `Ready` and `0` once all are, so
a loop on it is the wait. On the fresh broken install that works: exit `73` after 61s with
`OPM_SUITE_TIMEOUT=60s`, and `--details` names the `ErrImagePull` pod. On the broken *upgrade*
it does not:

```
$ kubectl get deploy podinfo-podinfo -o jsonpath='{.status}'
availableReplicas:1 readyReplicas:1 replicas:2 unavailableReplicas:1 updatedReplicas:1
  Available=True (MinimumReplicasAvailable)  Progressing=True (ReplicaSetUpdated)
$ opm instance status podinfo -n default
Status: Ready   Deployment podinfo-podinfo  Ready
```

`cli/internal/kubernetes/health.go` judges a Deployment by its `Available` condition alone,
which stays `True` for as long as the old ReplicaSet keeps serving, which for a rollout that
never completes is forever.

**Means.** The design's accepted risk ("briefly ready during a rollout") is understated: a
broken upgrade is reported ready for good, not briefly. For a first install the loop is sound;
for the upgrade change it is not a readiness signal at all, and that change has to measure
`updatedReplicas`/`Progressing` or wait on a rollout condition instead. Two things for `cli/`:
a `--wait` on `opm instance apply` for CLI-owned instances would delete the loop, and Deployment
health should consider `Progressing`/`updatedReplicas`, not `Available` alone. Reported as open-platform-model/cli#228.

## 2026-09-22: `--crds-only` is offline, and it is the whole bootstrap

**Tried.** `opm operator install --crds-only` from the image against the bare kind cluster with
name resolution dead (`/etc/resolv.conf` pointing at `127.0.0.1`; `getent hosts github.com`
fails) and only the API server's IP reachable. `--network=none` first, to see what it does
before it can reach anything.

**Happened.** With no network the first and only action is a `GET` on the `moduleinstances`
CRD, which fails with `network is unreachable`; nothing is fetched before that. With DNS dead
and the API reachable it creates the three CRDs (`moduleinstances`, `modulepackages`,
`platforms`), all `Established`, in about 2s, and prints `installed (embedded, 3 resource(s)
applied)`. No Deployment, no Platform. A second run reports all three `= unchanged`.

**Means.** The bootstrap is self-contained: the CRDs live in the binary, and a bare cluster
needs nothing but its own API server to become one `opm instance apply` can target. This is
the last piece of the "one artifact, nothing reachable" claim; the render half was proven in
the previous change. `podman --dns none` did *not* produce a DNS-less container under pasta
(the host's resolvers were copied in anyway); mounting a `resolv.conf` did.

## 2026-09-22: the RBAC width for one application, measured

**Tried.** The design's D5 table as a ClusterRole and a Role, then one Job run per omitted verb
(and per omitted resource), first on a steady-state cluster and then with the CRDs and the
workload deleted before each run, plus `opm instance status` run as the ServiceAccount from the
host with individual read verbs removed. kind cluster `opm-suite`, Kubernetes v1.36.1.

**Happened.** What the runs needed, and what ships in `deploy/rbac.yaml`:

| Scope | Resource | Verbs |
| --- | --- | --- |
| cluster | `apiextensions.k8s.io/customresourcedefinitions` | get, create, patch |
| namespace | `opmodel.dev/moduleinstances` | get, create, patch |
| namespace | `opmodel.dev/moduleinstances/status` | patch |
| namespace | `apps/deployments` | get, create, patch |
| namespace | `core/services` | get, create, patch |
| namespace | `core/pods` | list |

Against the D5 guess: no `list` anywhere except pods, no `update`, no `delete`, no `events`, no
Platform read. `create` is needed even though every write is a server-side-apply `PATCH`, because
the API server checks `create` when the patched object does not exist yet. Three warnings
appear on every run and change nothing:

- `could not read/delete legacy inventory Secret ... cannot get/delete resource "secrets"`:
  a pre-CRD inventory format `opm` still probes for. Granting `secrets` would silence it and
  prove nothing.
- `skipping operator-version ceiling check: reading the Platform was denied by RBAC`: the gate
  the D5 table budgeted a Platform read for. Denied is a warning, so the read is not granted.
- Without `moduleinstances/status`, apply fails clearly: `cannot record inventory: patching
  moduleinstances/status is denied ... grant the moduleinstances/status subresource`.

Two things `opm instance status` does with a denied read. Without `get` on the workload kinds
it fails with exit `5`, `no resources found for instance`, rather than reporting ready, so a
too-narrow Role fails the wait instead of fooling it. Without `pods list`, `--details` prints the
resource table and no pod lines, silently; `events` is never read.

**Means.** Fourteen verbs, three of them cluster-scoped, for one application: narrow enough to
ship as a Role plus a two-line ClusterRole, and every one of them earned by a Forbidden. The
open question is now about scale, not shape: each new rendered kind adds a namespaced
`get/create/patch` triple, and the first render that drops a resource will need `delete` for
pruning, which no run here exercised. The Job runs as a non-root user with a read-only root
filesystem and all capabilities dropped; `opm` needed only `TMPDIR` and `HOME` pointed at the
`emptyDir`.

## 2026-09-22: a fully vendored bundle renders with no network and an empty cache

**Tried.** An installer image carrying a bundle CUE module, the bundled podinfo module beside it,
a baked `#Platform` module and `vendor/` — the committed source of `core`, both catalogs and
`cue.dev/x/k8s.io`, copied out of the CUE module cache's `extract/` tree. Everything reached by
`cue.mod/local-module.cue` directory replacements. Then `opm instance build` against it, in a
container with `--network=none`, a read-only root filesystem, no kubeconfig, and a `CUE_CACHE_DIR`
mounted from an empty host directory.

**Happened.** Exit 0, a Deployment and a Service, and the cache directory still holding zero
entries afterwards. Byte-identical across two runs, and byte-identical to the same render on the
host. The whole vendored tree is 2.3 MB, against 171 MB for the image it sits in.

**Means.** The load-bearing assumption of this repo holds: a suite of OPM applications can travel
as one OCI artifact and render with nothing reachable. The empty cache is the part that matters —
it is the only evidence that distinguishes "offline" from "offline because someone's cache was
warm". `task image:render` re-runs exactly this on every `task check`, because a dependency added
later that nobody vendors would otherwise fail only in an airgapped run.

Building the image is a different question, and the answer is no: `podman build --no-cache
--network=none` fails at `apt-get`, before it can fail at the `opm` release tarball. Nothing about
the bundle, the modules, the platform or the vendor tree needs a network at build time — those are
plain `COPY`s — but the base image and the CLI do.

## 2026-09-22: the released `opm` binary needs glibc, so it does not run on Alpine

**Tried.** Alpine plus `bash` and `ca-certificates` as the installer image base. It is the obvious
choice: `opm` is a Go binary, Go binaries are usually static, and image size is part of what
"ship a suite as one artifact" is claiming.

**Happened.** The build got as far as `opm version` and died with `/bin/sh: opm: not found`, which
is what a missing dynamic loader looks like rather than a missing file. `file` on the released
tarball's binary says it all:

```
opm: ELF 64-bit LSB executable, x86-64, dynamically linked,
  interpreter /lib64/ld-linux-x86-64.so.2, ... not stripped
```

It wants `libc.so.6`. Neither `cli/.goreleaser.yml` nor `cli/.github/workflows/release.yml` sets
`CGO_ENABLED` either way, so why the published binary came out dynamically linked is not something
this repo established; it is a question for `cli/`, not an inference to make from here. What is
measured is the linkage and the failure.

**Means.** The base is `debian:trixie-slim`, pinned by digest. The image is 171 MB, of which the
unstripped `opm` binary is 79 MB. Worth reporting to `cli/`: a statically linked, stripped release
binary would roughly halve the image and make the Alpine option real.

Two smaller things fell out of the same task. `v1.0.0-alpha.21`, the newest CLI tag, carries **no
release assets at all** — the tag exists, the GoReleaser output does not — so the pin is
`v1.0.0-alpha.20`. And a `RUN ... && opm version` at the end of the install step is what caught
this; an install step that only unpacks a binary would have shipped a broken image.

## 2026-09-22: a local replacement the CLI calls "ignored" is still required

**Tried.** Declaring the same replacements in both `platform/cue.mod/local-module.cue` and
`bundle/cue.mod/local-module.cue`, which looked redundant.

**Happened.** `opm` says it is:

```
WARN local replacement of opmodel.dev/core@v2 in .../bundle/cue.mod/local-module.cue is ignored:
  the platform names that path; redirect it in the platform module's cue.mod/local-module.cue
```

Removing the entry it calls ignored breaks the build:

```
import failed
  values.suite-installer.invalid/bundle/instances/podinfo@v0
    > instance.cue:13:2
```

which is the `core` import in the instance file, with the platform's replacements untouched.

**Means.** Both are true at once and the message only describes one of them. Loading and validating
the instance package happens before the render module is staged, and that step uses the bundle
module's own view; only the *render* honours the platform's list. So the entry is ignored for the
render and required for the load. Reportable to `cli/`: the warning should say "ignored for the
render" or stay quiet when the two agree, because as written it tells a reader to delete something
that breaks their build.

## 2026-09-22: `opm instance build` ignores `-n` silently but warns about `--name`

**Tried.** Setting the target namespace for an instance-file render the obvious way, with
`opm instance build ... -n demo`.

**Happened.** Three measurements:

- With `metadata.namespace: "default"` in the instance file, `-n demo` rendered `namespace:
  default`. No warning, no error, exit 0.
- With `metadata.namespace` absent, the render fails with `required field "metadata.namespace" is
  absent`, with or without `-n`.
- `--name other` on the same command prints `WARN --name is ignored for instance-file builds; it
  only applies to module-directory builds`.

**Means.** Two flags are ignored in the same mode; one says so and the other does not, and the
silent one is the one that changes where your workload lands. Reportable to `cli/`: either `-n`
should apply to instance-file builds or it should warn exactly like `--name` does.

What works instead is CUE unification. A generated `.cue` file dropped into the instance package
directory declaring `metadata: namespace: "demo"` renders `namespace: demo`. `scripts/opm-suite`
therefore copies the bundle to `TMPDIR`, writes that file and renders from the copy — which also
keeps the image usable with a read-only root filesystem. `-f` is not an alternative: the values
file is loaded as its own package.

## 2026-09-22: `debugValues` does not reach an instance-file render

**Tried.** Bundling a module that carries `debugValues` and rendering an instance file that binds
it, with no `values.cue` beside the instance.

**Happened.** `ERRO render failed error="Kernel.AcquireInstanceFromDir: instance \"podinfo\": not
fully concrete: values: incomplete value _"`. The same module rendered from its *directory*
(`opm instance build ./modules/podinfo`) succeeds, using exactly those `debugValues`.

**Means.** `debugValues` is for the synthesized instance the CLI builds around a module directory,
not for a real `#ModuleInstance`. Correct, and worth writing down because the failure message never
mentions `debugValues` and the module looks complete. Every bundled application ships its own
`values.cue`. That is also the seam a later change uses for per-deployment values.

## 2026-09-22: a bundled module can never be operator-owned

**Tried.** Nothing new — this is what the local-replacement machinery implies, stated plainly
because it decides the shape of the next change.

**Happened.** Every render of the bundle emits, on stderr:

```
WARN local replacement in effect: suite-installer.invalid/modules/podinfo@v0 served from
  .../modules/podinfo (instance); rendered bytes may not correspond to any published build
```

**Means.** A local replacement is a switch a frontend sets, and `opm` sets it for every render. The
operator does not, and cannot: it resolves modules from a registry, and
`suite-installer.invalid/...` resolves nowhere on purpose. So anything the bundle renders is
permanently CLI-owned. The Job applies it and keeps ownership; there is no reconcile loop, no drift
correction after the Job exits, and no later change can bolt one on without giving up the bundling
that makes the image self-contained.

That is the real trade the experiment is measuring, and it is now concrete rather than predicted.
The warning above is the observable proof that the switch is on, which is why the entrypoint does
not suppress it.

## 2026-09-22: `opm operator install` leaves the cluster Platform unusable

**Tried.** A fresh kind v0.32.0 cluster (Kubernetes v1.36.1), then a full `opm operator install`
with the CLI at v1.0.0-alpha.20-2-g2bfebd9. (`task cluster:up` ran that install at the time; it
no longer does, and must not, see constitution principle V.)

**Happened.** Install reported success and seeded the Platform, then the operator refused to
reconcile it:

```
$ kubectl get platform cluster
NAME      TYPE         READY   REASON              OPERATOR
cluster   kubernetes   False   MaterializeFailed   v1.0.0-alpha.14

materialize failed: kind=catalog subscription="opmodel.dev/catalogs/opm@v4" version="":
subscription version is not a concrete string:
platform.#registry."opmodel.dev/catalogs/opm@v4".version: required field missing: version
```

The CR itself is correct. `spec.registry["opmodel.dev/catalogs/opm@v4"]` holds
`{enable: true, version: "4.4.1"}`, and the CRD marks `version` required with `minLength: 1`.
The missing field is in the CUE the operator generates from the CR, not in the CR.

The operator log names the cause:

```
INFO  setup  OPM core schema resolved  {"version": "v2.0.0-alpha.10"}
```

**Means.** Operator v1.0.0-alpha.14 resolves `opmodel.dev/core@v2` unpinned at startup, so a
released operator silently picks up whatever core is newest. Core alpha.10 requires `version`
on a `#registry` subscription; the operator's projection does not supply it. Nothing was
committed in any repo to break this, which is what makes it hard to notice: the same operator
image worked before core alpha.10 was published. This is an upstream defect in `opm-operator`
(or in `library`'s unpinned `DefaultSchemaModule`), not something this repo can fix.

**Consequence for the installer image.** Two things follow. The cluster `Platform` CR is not a
usable platform source, which removes the main argument against baking a `#Platform` module into
the image and passing `--platform`: the baked platform is not just the offline-friendly choice,
it is currently the only working one. And when the image bootstraps a bare cluster it should
install CRDs only (`opm operator install --crds-only`, or `--skip-platform` for a full install)
rather than seeding a Platform that will sit `Stalled` forever. Re-test once the operator pins
core.

