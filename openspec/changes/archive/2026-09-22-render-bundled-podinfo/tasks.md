## 1. Image skeleton

- [x] 1.1 Write `Containerfile` on Alpine with bash and ca-certificates, installing `opm`
  v1.0.0-alpha.20 from its release tarball with a SHA-256 checksum check (D8); verify
  `task build` succeeds and `podman run --rm <image> opm version` prints the pinned version.

## 2. The bundle

- [x] 2.1 Add `task vendor:sync`, populating `vendor/` with `core`, both catalogs and
  `cue.dev/x/k8s.io` from `<CUE cache>/mod/extract/` at their pinned versions, and writing a
  `vendor/VERSIONS` manifest (D4); verify a clean re-run reproduces the identical tree and that
  no vendored path came from a local working copy.
- [x] 2.2 Create `modules/podinfo/` from `cli/tests/fixtures/modules/podinfo`, re-identified to
  `suite-installer.invalid/modules/podinfo@v0` in `cue.mod/module.cue`, `identity/identity.cue`
  and the module's own self-import (D2), and `bundle/` around it: `cue.mod/module.cue` (core,
  catalog, and the bundled module with a placeholder version and `default: true`), a
  `cue.mod/local-module.cue` redirecting the bundled module plus core and the first-party
  catalog, and `instances/podinfo/{instance.cue,values.cue}` carrying no `metadata.namespace`
  (D1, D4, D5, D6); verify grepping for the old module path finds no hit.
- [x] 2.3 Create `platform/` as a `#Platform` module pinning core and both catalogs, modelled on
  `cli/hack/platform/`, with a `cue.mod/local-module.cue` redirecting core, both catalogs and
  `cue.dev/x/k8s.io` into `vendor/` (D3, D4); verify the fully local render on the host: with an
  empty `CUE_CACHE_DIR` and no network,
  `opm instance build bundle/instances/podinfo/instance.cue --platform ./platform` renders a
  Deployment and a Service and leaves the cache at zero bytes.
- [x] 2.4 Copy the bundle, modules, platform and vendor tree into the image at the D7 paths and
  verify the same render succeeds inside the container, before any script exists. If the binary
  misbehaves on musl, switch the base to `debian:trixie-slim` and say so in the commit.

## 3. The entrypoint

- [x] 3.1 Write `scripts/opm-suite` with `set -euo pipefail`, the D7 usage text, `list`, the
  exit codes, and application selection (arguments, then `OPM_SUITE_APPS`, then the whole
  bundle; deduplicated preserving first position; every name validated before anything renders);
  verify `list` exits 0 and names podinfo and the `opm` version, no subcommand exits 64 with
  usage on stderr, and an unknown application exits 65 having rendered nothing.
- [x] 3.2 Add `render`: copy `/opt/opm` to a working directory under `TMPDIR`, write the
  generated namespace file into the instance package, run `opm instance build --platform`, and
  handle both output modes (D6, D7); verify `OPM_SUITE_NAMESPACE=demo` yields `namespace: demo`,
  the default stream is accepted by `kubectl apply --dry-run=client -f -`, `OPM_SUITE_OUT` puts
  files under `<dir>/<app>/` with no YAML on stdout, and `shellcheck -x` passes.

## 4. The offline proof

- [x] 4.1 Add `task image:render` running the image with `--network=none` and an empty cache,
  wire it into `task check`, and verify it exits 0, leaves the cache empty, and produces
  byte-identical output across two runs. Record whether the image also *builds* with no network
  once `vendor/` is committed.

## 5. Record and close

- [x] 5.1 Add the `FINDINGS.md` entries this change earned: a fully vendored bundle renders with
  an empty cache and no network; a replacement the CLI reports as "ignored" because the platform
  names that path is still required in the bundle module to load the instance package, a
  reportable message defect; `instance build` ignores `-n` for instance files while warning
  about `--name`, another reportable inconsistency; `debugValues` does not reach an
  instance-file render; local replacements are CLI-only, so a bundled module can never be
  operator-owned.
- [x] 5.2 Update `README.md` and `CLAUDE.md` for the delivered layout, `vendor/` and the
  `image:*` tasks, then run `task check` and confirm it is green.
