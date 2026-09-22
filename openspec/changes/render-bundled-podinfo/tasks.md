## 1. Image skeleton

- [ ] 1.1 Write `Containerfile` on Alpine with bash and ca-certificates, installing `opm`
  v1.0.0-alpha.21 from its release tarball with a SHA-256 checksum check (D8); verify
  `task build` succeeds and `podman run --rm <image> opm version` prints the pinned version.

## 2. The bundle

- [ ] 2.1 Create `modules/podinfo/` from the CLI fixture at
  `cli/tests/fixtures/modules/podinfo`, re-identified to
  `suite-installer.invalid/modules/podinfo@v0` in `cue.mod/module.cue`,
  `identity/identity.cue` and the module's own self-import (D2); verify all three agree by
  grepping for the old path and finding no hit.
- [ ] 2.2 Create `bundle/` with `cue.mod/module.cue` (core, catalog, and the bundled module
  with a placeholder version and `default: true`), `cue.mod/local-module.cue` redirecting it to
  `../modules/podinfo`, and `instances/podinfo/{instance.cue,values.cue}` with no
  `metadata.namespace` (D1, D5, D6).
- [ ] 2.3 Create `platform/` as a `#Platform` module pinning core and the first-party catalog,
  modelled on `cli/hack/platform/` (D3); verify
  `opm instance build bundle/instances/podinfo/instance.cue --platform ./platform` on the host
  renders a Deployment and a Service, after adding a temporary namespace file.
- [ ] 2.4 Copy the bundle, modules and platform into the image at the D7 paths and verify the
  same render succeeds inside the container, before any script exists. If the binary misbehaves
  on musl, switch the base to `debian:trixie-slim` and say so in the commit.

## 3. The entrypoint

- [ ] 3.1 Write `scripts/opm-suite` with `set -euo pipefail`, the D7 usage text, the `list`
  subcommand and the exit codes; verify `list` exits 0 and prints podinfo and the `opm`
  version, and that no subcommand exits 64 with usage on stderr.
- [ ] 3.2 Add `render`: resolve the application list from arguments then `OPM_SUITE_APPS` then
  the whole bundle, deduplicate preserving first position, and validate every name against the
  bundle before rendering anything; verify an unknown application exits 65, names it, lists the
  known ones and renders nothing.
- [ ] 3.3 Add the render itself: copy `/opt/opm` to a working directory under `TMPDIR`, write
  the generated namespace file into the instance package, and run `opm instance build
  --platform` (D6); verify `OPM_SUITE_NAMESPACE=demo` yields `namespace: demo` and the default
  yields `namespace: default`.
- [ ] 3.4 Add output handling: a YAML stream on stdout by default, split files under
  `$OPM_SUITE_OUT/<app>/` when set (D7); verify the default stream is accepted by
  `kubectl apply --dry-run=client -f -`, that stdout carries no YAML when `OPM_SUITE_OUT` is
  set, and that `shellcheck -x` passes.

## 4. The offline proof

- [ ] 4.1 Warm the CUE cache during the image build and point `CUE_CACHE_DIR` at it in the
  final image (D4); verify the image layer holds the cache and the build fetched it once.
- [ ] 4.2 Add `task image:render` running the image with `--network=none`, wire it into
  `task check`, and verify it exits 0 and that two consecutive runs produce byte-identical
  output.

## 5. Record and close

- [ ] 5.1 Add the `FINDINGS.md` entries this change earned: offline rendering works from a warm
  cache; `instance build` ignores `-n` for instance files while warning about `--name`, which is
  a reportable CLI inconsistency; `debugValues` does not reach an instance-file render; local
  replacements are CLI-only, so a bundled module can never be operator-owned.
- [ ] 5.2 Update `README.md` and `CLAUDE.md` for the delivered layout and the `image:*` tasks,
  then run `task check` and confirm it is green.
