## Why

The repo asserts that a container image can carry OPM modules and install them, but nothing has
been built, so the assertion is untested. The riskiest part is not the Kubernetes plumbing, it is
whether a CUE module bundled inside an image can be rendered at all without a registry: OPM
modules are normally resolved from GHCR, and every render also needs `core`, a catalog and a
platform.

This change answers one question: **can an image render a locally bundled OPM module to
Kubernetes manifests with no registry reachable?** If the answer is no, the installer-image idea
is dead and the remaining work is cancelled. If yes, the cluster-facing half becomes worth
building.

The first finding already narrowed this. `opm operator install` seeds a cluster `Platform` the
operator refuses to materialize (`FINDINGS.md`, 2026-09-22), so resolving a platform from the
cluster is not currently an option. A baked platform module is not just the offline-friendly
choice here, it is the only working one.

## What Changes

- A `Containerfile` producing an installer image: a pinned `opm` release, a bash entrypoint, the
  bundle, a baked `#Platform` module and a vendored copy of every CUE dependency.
- A `bundle/` CUE module that reaches its bundled modules through a `cue.mod/local-module.cue`
  directory replacement, so nothing about the bundled module is resolved from a registry.
- `vendor/`, the committed source of `core`, both catalogs and their one third-party dependency,
  reached by the same directory-replacement mechanism, so the image resolves nothing from a
  registry at run time or at build time.
- `bundle/modules/podinfo/`, a podinfo `#Module` copied from the CLI's published test fixture and
  re-identified onto a module path no registry serves, so a successful render cannot be the
  published copy in disguise.
- `platform/`, a `#Platform` module pinning `core` and the first-party catalog, passed to every
  render as `--platform`.
- `scripts/opm-suite`, a bash entrypoint with one subcommand, `render`, selecting applications
  from arguments or environment variables and writing manifests to stdout or a directory.
- `task image:render`, running the built image against `--network=none` as the standing proof
  that the offline claim still holds.

No Kubernetes objects are applied and no cluster is contacted. `deploy/`, the Job, the
ServiceAccount and RBAC are the next change.

## Capabilities

### New Capabilities

- `bundle-render`: the installer image renders its bundled OPM modules to Kubernetes manifests,
  selected by argument or environment variable, with no registry reachable.

### Modified Capabilities

None. This is the repo's first capability.

## Impact

- **New files**: `Containerfile`, `bundle/`, `platform/`, `scripts/opm-suite`, tasks in
  `Taskfile.yml`.
- **Pinned dependencies**: `opm` v1.0.0-alpha.20 by release tarball and SHA-256 checksum, plus
  whatever `core` and catalog versions `platform/cue.mod/module.cue` names. An unpinned CLI would
  make every finding here unreproducible.
- **Nothing published**: no CUE module is published under any domain. The bundle module and the
  bundled podinfo module both sit on a path no registry mapping serves, and they are always the
  main module or a directory replacement of the build.
- **No registry at all**: with every dependency vendored, neither running the image nor building
  it contacts a registry. Refreshing `vendor/` does, and that is a deliberate, separate act.
- **Needs nothing `opm` does not have.** `opm instance build --platform <dir>` covers the whole
  render path, and CUE's own `cue.mod/local-module.cue` `replaceWith` covers every dependency,
  first-party and third-party alike.

### Alternatives not chosen

- **Do nothing.** The cheapest option, and wrong: every later change assumes offline rendering
  works, so an unverified assumption would propagate into the Job, the RBAC and the suite layout
  before anyone tested it.
- **Build the whole end-to-end Job at once.** Answers more questions per change, but the task
  list runs past the limit Principle VI sets, and a failure in the render layer would be
  discovered while debugging RBAC.
- **Resolve modules from GHCR instead of bundling them.** A thinner image that keeps operator
  ownership, and a legitimate design. It is what this repo exists to compare against, so it
  cannot also be the thing this change builds.
- **Keep the bundled module on its published coordinate
  (`testing.opmodel.dev/modules/cli/podinfo@v0`).** Less work, but a successful render would not
  prove local resolution: the same path also resolves from GHCR, so the test could pass for the
  wrong reason.
