# Findings

What the experiment taught us, including the negative results. Newest first.

Each entry: what was tried, what happened, what it means. A finding that kills an idea is worth
more than one that confirms it.

## Open questions

- How wide does the Job's RBAC have to be in practice, for a realistic suite?
- Is losing operator ownership (drift correction, reconciliation) acceptable for the use cases
  an installer image would serve? This is now the central open question, because a bundled
  module *cannot* be operator-owned at all (see the local-replacement entry below).
- Does the image stay this small once a suite is more than one application? 2.3 MB of vendored
  CUE against a 171 MB image says the CUE half is not what costs.

Answered: *does a warm `CUE_CACHE_DIR` keep `opm instance build` off the network?* It does, but
the question stopped mattering. Vendoring makes the render offline by construction rather than by
cache warmth, and the vendored tree is a tenth the size and reviewable in a diff.

## Entries

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

