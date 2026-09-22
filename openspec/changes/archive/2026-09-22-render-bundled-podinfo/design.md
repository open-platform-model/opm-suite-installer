## Context

See `proposal.md` for motivation and `specs/bundle-render/spec.md` for the behavior contract.

Every claim below was verified by running it. The scratch tree used for verification mirrors the
image layout: a bundle CUE module, a bundled podinfo module beside it, and a platform module,
rendered with `opm instance build --platform`. `opm` was v1.0.0-alpha.20-2-g2bfebd9 with CUE SDK
v0.17.1.

## Goals / Non-Goals

**Goals**

- Prove offline rendering of a locally bundled module, with evidence that survives a rebuild.
- Establish the bundle layout and the script contract that the cluster-facing change inherits.

**Non-Goals**

- Applying anything, contacting a cluster, RBAC, or the `Batch/Job` manifest. **RBAC delta: none.**
  This change creates no Kubernetes object and needs no ServiceAccount.
- A second bundled application. One is enough to prove the mechanism; a second proves only that
  copy-paste works.
- Suppressing or prettifying `opm` output. The script orchestrates and does not filter.

## Decisions

### D1: Bundled modules reach the bundle through `cue.mod/local-module.cue`

Each bundled module keeps its own `cue.mod` and stays a real CUE module. The bundle module names
it as a dependency with a placeholder version and `default: true`, and redirects it to a
directory in `cue.mod/local-module.cue`:

```cue
// bundle/cue.mod/local-module.cue
deps: "suite-installer.invalid/modules/podinfo@v0": replaceWith: "../modules/podinfo"
```

The `default: true` entry in `module.cue` is required, not decoration: it is what lets the
bundled module's own unqualified self-import (`.../podinfo/identity`) resolve.

Verified. The render succeeded and `opm` reported the redirection on stderr:

```
WARN local replacement in effect: suite-installer.invalid/modules/podinfo@v0 served from
  /.../bundletest/modules/podinfo (instance); rendered bytes may not correspond to any
  published build
```

That warning is emitted on every render and MUST NOT be suppressed. It is the mechanism
announcing itself, and it is accurate: these bytes correspond to no published build.

**Alternatives.** Vendoring the modules as plain packages inside one CUE module fails: a module's
identity package must carry the enclosing `cue.mod` module path, so a sub-package cannot be a
`#Module`. Publishing the modules to a registry is the design this repo exists to compare
against, not an implementation of it.

**Consequence to carry into the next change.** Local replacements are a switch a frontend sets,
and `opm` sets it for every render. The operator does not. Anything the bundle renders is
therefore permanently CLI-owned; there is no path by which an operator reconciles it. The warning
above is the observable proof that the switch is on.

### D2: The bundled module sits on a path no registry serves

The bundled podinfo is the CLI's published fixture re-identified from
`testing.opmodel.dev/modules/cli/podinfo@v0` to `suite-installer.invalid/modules/podinfo@v0`
(`cue.mod/module.cue`, `identity/identity.cue` and the module's self-import, which must agree).

`.invalid` is a reserved TLD, so the path cannot resolve anywhere by accident. Verified: CUE
accepts it as a module path and the render produced a Deployment and a Service.

Without this, a successful render would prove nothing: the published coordinate also resolves
from GHCR, so the test could pass for the wrong reason.

### D3: The platform is baked and passed as `--platform`

`platform/` is a `#Platform` module pinning `core` and the first-party catalog, modelled on
`cli/hack/platform/`. Every render passes `--platform /opt/opm/platform`, the highest-precedence
platform source.

Verified: `INFO platform: ./platform (--platform)`.

Beyond offline operation, `FINDINGS.md` (2026-09-22) records that the cluster `Platform` CR a
fresh `opm operator install` seeds never becomes ready, so the baked module is currently the only
platform source that works at all.

### D4: Every dependency is vendored, not cached

Nothing is resolved from a registry, at run time or at build time. `core`, both catalogs and
their one third-party dependency (`cue.dev/x/k8s.io`) are committed under `vendor/` as CUE
source and reached by the same directory-replacement mechanism as the bundled module.

Verified with an **empty** cache directory, in a network namespace with no routable interface:

```
$ CUE_CACHE_DIR=<empty dir> unshare -rn opm instance build \
    ./bundle/instances/podinfo/instance.cue --platform ./platform
exit=0, 80 lines of YAML
$ du -sh <empty dir>
0
```

The cache stayed at zero bytes, so nothing was fetched and nothing was written. Two consecutive
runs were byte-identical. Total vendored source is about 2.3 MB, against 35 MB for a warm cache
of the same dependency set.

**The replacements must be declared in two places, for two different reasons.**

- The **platform module's** `cue.mod/local-module.cue` must name `core`, both catalogs and
  `cue.dev/x/k8s.io`. The platform's dependency list wins the render, and `opm` says so out loud
  when the bundle also names one: `local replacement of opmodel.dev/core@v2 in
  bundle/cue.mod/local-module.cue is ignored: the platform names that path; redirect it in the
  platform module's cue.mod/local-module.cue`.
- The **bundle module's** `cue.mod/local-module.cue` must *also* name `core` and the first-party
  catalog, despite that warning. Loading and validating the instance package happens before the
  render module is staged, and it uses the bundle module's own view. Verified: removing those
  two entries fails with `import failed ... instance.cue:4:2`, the `core` import, even with the
  platform's replacements in place.

That the CLI calls an entry "ignored" while removing it breaks the build is confusing, and is
recorded as a finding rather than worked around.

**Refreshing the vendor tree.** `task vendor:sync` fetches the pinned versions into the CUE cache
and copies each one out of `<cache>/mod/extract/<module>@<version>`, which is the published
source verbatim. A `vendor/VERSIONS` manifest records exactly what is vendored. Vendoring from a
local working tree instead would silently ship unpublished bytes: during verification the working
tree rendered catalog `4.4.1` where the published pin was `4.4.0`.

**Alternative rejected: warming the CUE cache at image build.** It works (also verified), but it
is offline by cache warmth rather than by construction. A dependency added later that nobody
fetched at build time fails only in an airgapped run, the cache is 15 times larger, and its
contents are not reviewable in a diff. Vendoring makes the dependency set visible in the repo.

### D5: Instance files carry their own values; `debugValues` does not apply

The first render attempt failed:

```
ERRO render failed error="Kernel.AcquireInstanceFromDir: instance \"podinfo\":
  not fully concrete: values: incomplete value _"
```

A module's `debugValues` is used when the CLI synthesizes an instance around a module directory,
not when it renders an instance file. Every bundled application therefore ships a `values.cue`
beside its `instance.cue`. This is also the seam a later change uses for per-deployment values.

### D6: The namespace is supplied by a generated CUE file, not by `-n`

`opm instance build -n demo` does **not** set the namespace. Verified twice:

- With `metadata.namespace: "default"` in the instance file, `-n demo` rendered `namespace: default`.
- With `metadata.namespace` absent, both with and without `-n demo`, the render failed:
  `required field "metadata.namespace" is absent`.

`-f` does not work either: the values file is loaded as its own package and the render fails or
shifts the package root.

What does work is CUE package unification. A `.cue` file dropped into the instance package
directory declaring `metadata: namespace: "demo"` renders `namespace: demo`. So:

- A bundled `instance.cue` MUST NOT set `metadata.namespace`.
- The script writes a generated file into the instance package directory before rendering.

To keep that write off the image filesystem, the script copies `/opt/opm` to a working directory
under `TMPDIR` and renders from the copy. The copy is small (the cache lives outside it) and it
keeps the image usable with a read-only root filesystem. The sibling layout is preserved by
copying `/opt/opm` whole, which is what makes the relative `../modules/podinfo` redirection keep
resolving.

### D7: Image layout and the script contract

```
/usr/local/bin/opm            pinned release, installed by tarball + SHA-256 checksum
/usr/local/bin/opm-suite      the entrypoint
/opt/opm/bundle/              CUE module suite-installer.invalid/bundle@v0
    cue.mod/module.cue
    cue.mod/local-module.cue
    instances/podinfo/instance.cue   (no metadata.namespace)
    instances/podinfo/values.cue
/opt/opm/modules/podinfo/     its own CUE module, reached by directory replacement
/opt/opm/platform/            CUE module, the baked #Platform
/opt/opm/vendor/              core, catalogs and cue.dev/x/k8s.io as CUE source
```

```
opm-suite render [app...]     render bundled applications to manifests
opm-suite list                bundled applications and the pinned opm version

OPM_SUITE_APPS        ordered, comma-separated; used when no positional app is given
OPM_SUITE_NAMESPACE   target namespace, default "default"
OPM_SUITE_OUT         unset: YAML stream on stdout. A directory: split files under <dir>/<app>/
OPM_SUITE_BUNDLE      default /opt/opm/bundle
OPM_SUITE_PLATFORM    default /opt/opm/platform

exit 0    success
exit 64   no subcommand, or one that is not recognised
exit 65   an application the bundle does not carry
exit 70   a render failed
```

`opm` already writes manifests to stdout and everything else to stderr, verified by capturing the
two separately, so the script only has to avoid printing to stdout itself.

Applications are validated against the bundle before any render runs, so an unknown application
named last cannot leave the first ones already rendered.

### D8: Alpine plus bash as the base image

`opm` is built with CGO disabled, so it does not need glibc, and the entrypoint needs bash
rather than ash. Alpine plus the `bash` and `ca-certificates` packages is the smallest base that
satisfies both, and image size is part of what "ship a suite as one artifact" is claiming.

The pinned release is **v1.0.0-alpha.20**, not the newest tag. `v1.0.0-alpha.21` exists but
carries no assets at all (`gh api repos/open-platform-model/cli/releases/tags/v1.0.0-alpha.21`
returns `"assets": []`), so there is no tarball to install or checksum. The delta between the two
is one feature commit, `opm platform check`, plus OpenSpec bookkeeping; nothing on the
`instance build` render path. Building the CLI from source in a builder stage was rejected: the
constitution treats `opm` as a pinned released dependency, not something this repo compiles.

The risk is a musl surprise in a dependency that host testing would not show. The first task
builds the image and re-runs the verified render inside it, before any script is written; if the
binary misbehaves there, the fallback is `debian:trixie-slim` and nothing else in this design
changes.

**Measured: the fallback is what shipped.** Alpine got as far as `opm version` and failed with
`/bin/sh: opm: not found`, which is what a missing dynamic loader looks like. The released binary
is `ELF 64-bit LSB executable ... dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2`
and wants `libc.so.6`, so despite GoReleaser's usual CGO-free default it does not run on musl at
all. The base is `debian:trixie-slim`, pinned by digest; the image is 171 MB, of which the `opm`
binary is 79 MB. Nothing else in this design changed.

## Risks / Trade-offs

- **The offline proof rots silently.** A later change adds a dependency nothing vendors and
  nobody notices until an airgapped run. → `task image:render` runs the image with
  `--network=none` and an empty cache, and is part of `task check` once the image exists.
- **`vendor/` rots against upstream.** It is a committed copy that no dependency bot updates, and
  `task deps:update` at the workspace root does not know it exists. → `vendor/VERSIONS` records
  what is vendored and `task vendor:sync` refreshes it. Accepted: a PoC pinned to a known-good
  dependency set is a feature, not a liability.
- **The baked platform pins catalog versions that drift from any real cluster.** → Accepted for
  now and recorded. It is the point of comparison the cluster-facing change has to argue with.
- **`.invalid` makes the bundled module unpublishable as-is.** → Intended. A module that could be
  published is a module that could have been resolved from a registry.
- **The verification ran on a host, not in the image.** Base image, musl or glibc, and `TMPDIR`
  behavior are unverified. → The first task builds the image and re-runs the same render inside
  it before anything else is written.
- **`opm-suite` copies the bundle on every invocation.** Wasteful, and invisible at this size. →
  Left alone until a bundle is large enough for it to matter.
