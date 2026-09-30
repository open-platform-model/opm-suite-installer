## Gates

Ticked by the supervisor only. Task 1.1 needs no gate; 1.2 to 1.4 need G1 and G3; section 2
onward needs G6. Each gate records the version actually published: if a version was burned and
the target moved (for example to `-beta.2`), every task below uses the recorded value, and the
`beta.1` / `4.4.4` written in them are only the expected values (design D6).

- [ ] G1 `opmodel.dev/core@v2` is on GHCR at the first core beta (expected v2.0.0-beta.1; record the real version: `________`)
- [ ] G3 `opmodel.dev/catalogs/k8s@v1` first beta (expected v1.0.0-beta.1, tag k8s-v1.0.0-beta.1) and `opmodel.dev/catalogs/opm@v4` on core beta (expected v4.4.4, tag opm-v4.4.4) are on GHCR (record the real versions: k8s `________`, opm `________`)
- [ ] G6 the first `cli` release embedding the first `opm-operator` beta exists (expected v1.0.0-beta.2; record the real tag: `________`, and the operator version it embeds: `________`) and carries `opm-linux-amd64.tar.gz`, `opm-linux-arm64.tar.gz` and `checksums.txt`

No supervisor patch applies: this repo is outside every root task (`deps:update`,
`deps:pins:*`). All work below runs in the worktree
`.claude/worktrees/beta-bump-to-beta` on branch `beta/bump-to-beta`, with the registry env
exported on two separate lines. `$SCRATCH` below is the worker's scratchpad directory.

## 1. Baseline and CUE pins

- [ ] 1.1 Baseline on the unmodified tree, before any edit. Run `cue vet ./...` in `platform/` and `modules/podinfo/` and `cue vet -c=false ./...` in `bundle/` (plain `cue vet` in `bundle/` fails by design: `metadata.namespace` is supplied at runtime, design "Measured behavior"). Build the unmodified image with `task build TAG=baseline`, record `podman image inspect --format '{{.Size}}' localhost/opm-suite-installer:baseline`, and save `podman run --rm --network=none localhost/opm-suite-installer:baseline render > $SCRATCH/render-before.yaml`. Verify: the three vets exit 0 and `render-before.yaml` is non-empty. No commit.
- [ ] 1.2 Move the CUE pins (design D1). In `platform/` run `cue mod get opmodel.dev/core@v<G1> opmodel.dev/catalogs/opm@v<G3 opm> opmodel.dev/catalogs/k8s@v<G3 k8s>`, and in `modules/podinfo/` the same without the k8s catalog. Then set the core and catalogs/opm lines in `bundle/cue.mod/module.cue` by hand to the exact versions the platform now pins, leaving the podinfo placeholder, its `default: true` and the comment above it untouched (not `cue mod edit`, which deletes that comment). Correct the comment in `platform/cue.mod/local-module.cue` (lines 6-8): `cue.dev/x/k8s.io` is needed by `catalogs/opm`, not the k8s catalog. Verify: each `cue.mod/module.cue` shows the recorded gate versions and no `alpha`; the bundle's core and catalogs/opm equal the platform's; note the `cue.dev/x/k8s.io` version written in `platform/` and `modules/podinfo/` (expected v0.12.0) and that the two agree. Commit as `fix(deps): pin the cue modules to the OPM beta line`.
- [ ] 1.3 Run `task vendor:sync` (design D2) and update the example version in the `hack/vendor-sync.sh` comment (lines 58-59) to the beta string. Verify: `vendor/VERSIONS` lists the recorded core, catalogs/opm and catalogs/k8s versions, and its `cue.dev/x/k8s.io` line equals the version pinned in `platform/` and `modules/podinfo/` (1.2); `grep alpha vendor/VERSIONS` is empty; `git status` shows no stray files. Commit as `fix(deps): regenerate vendor from the beta pins`.
- [ ] 1.4 Check whether core beta breaks the modules (design D4): rerun the three vets from 1.1 exactly as there (`-c=false` in `bundle/`). If all exit 0, record "no module change needed" for 4.1. If one fails, wait for G6, then pick the reference per D4: `cli/tests/fixtures/modules/podinfo` at the G6 tag only if that fixture's `cue.mod/module.cue` pins the G1 core version, otherwise `cli/templates` at the G4 tag. Read it from a shallow clone in `$SCRATCH` (`git clone --depth 1 --branch <tag> https://github.com/open-platform-model/cli`); never fetch into or check out the cli main checkout. Make the smallest change that mirrors it, keeping the `suite-installer.invalid` identity; nothing under `bundle/instances/` may gain a `metadata.namespace`. Commit as `fix(podinfo): adapt the bundled module to core beta` (or `fix(platform): ...` for `platform.cue`). Verify: the three vets exit 0.

## 2. The pinned `opm` CLI

- [ ] 2.1 Read the G6 tag's assets with `gh release view <tag> --repo open-platform-model/cli --json assets` (always name the tag: the unqualified "latest" release reports `v0.6.0`), download both tarballs and `checksums.txt`, and confirm `sha256sum` of each tarball matches its `checksums.txt` line. Set `ARG OPM_VERSION=<tag>`, `OPM_SHA256_AMD64` and `OPM_SHA256_ARM64` in `Containerfile`, and replace the alpha.20-over-alpha.21 comment with the current rationale (the first `cli` embedding the operator beta). Verify: `grep -n alpha Containerfile` is empty. Commit as `fix(deps): install opm <tag> in the installer image`.

## 3. Verification

- [ ] 3.1 `task check` (lint, build, image:render) passes. Verify: the build log's `opm version` line prints the G6 tag (record the string), and `image:render` reports an empty cache and byte-identical output across both runs. Record the new image size (`podman image inspect --format '{{.Size}}' localhost/opm-suite-installer:dev`). Save `podman run --rm --network=none localhost/opm-suite-installer:dev render > $SCRATCH/render-after.yaml` and `diff` it against `render-before.yaml` from 1.1. Any difference is either explained and recorded for 4.1 (for example a label value derived from a version) or, if it changes what lands in the cluster, stops the change: a behavior change is a new change.
- [ ] 3.2 Named cluster run on a fresh bare kind cluster (`CLUSTER=opm-suite`, context `kind-opm-suite`; every `kubectl` below passes `--context kind-opm-suite`). `task cluster:up`, `task cluster:load`, `task job:run`, then assert:
  - the Job log's install line (format `opm-operator <version> installed (<source>, <n> resource(s) applied)`, cli `internal/cmd/operator/install.go`) names the G6 operator version, source `embedded` and 4 resources; record the line (the operator version comes from it, not from the CRDs);
  - `kubectl get crd moduleinstances.opmodel.dev -o jsonpath='{.spec.versions[*].name}'` matches `MI_API` in `scripts/opm-suite` (expected `v1alpha1`; if not, stop and raise it, since that is a behavior change for a separate change);
  - `kubectl get moduleinstance podinfo -n opm-suite -o jsonpath='{.status.inventory.entries[?(@.kind=="Deployment")].name}'` is non-empty and `-o jsonpath='{.spec.values}'` is non-empty (the fields the rollout guard and revert read through `[]?`);
  - `kubectl get deploy -A` shows no operator Deployment and `kubectl get platform -A` returns none (bundle-apply "First apply on a bare cluster");
  - podinfo is Ready.
  Capture the podinfo pod UIDs (`kubectl get pod -n opm-suite -o jsonpath='{.items[*].metadata.uid}'`), run `task job:run` a second time, and confirm it succeeds and the UIDs are unchanged (bundle-apply "Re-run the same Job"). Optionally rerun bundle-lifecycle "Upgrade to a tag that does not exist" once and confirm exit `74`. Record the kind and Kubernetes versions for 4.1. `task cluster:down` afterwards.

## 4. Documentation

- [ ] 4.1 Update the docs from the recorded values of 1.1 to 3.2, as two commits. First, in `AGENTS.md`, rewrite the last sentence of the glibc bullet (around line 189) to state the current pin and the rule behind it (pin the `cli` tag whose embedded operator matches the beta line, and only a tag that carries release assets), and qualify the "cluster `Platform` that is currently broken" bullet (around line 170) as measured on operator v1.0.0-alpha.14; in `README.md` (around line 189) change "the three embedded CRDs" to four. Verify: `grep -n alpha AGENTS.md README.md` shows only `v1alpha1` API references and the alpha.14 qualifier. Commit as `docs: record the beta opm pin in AGENTS.md and README.md`. Second, add one new dated entry to `FINDINGS.md` at the top of `## Entries` (newest first): what the move from core alpha.10 / `opm` alpha.20 required (module changes or none, from 1.4); that `cue mod get` resolves from the registry without `local-module.cue`, so the bundle's unpublished podinfo placeholder blocks it while `cue vet` and `opm` load fine, and why the bundle was edited by hand (design "Measured behavior", D1); the `cue.dev/x/k8s.io` move and that it follows `catalogs/opm`; image size before (1.1) and after (3.1); the render diff result (3.1); the `opm version` string; the operator version from the Job log; the fourth embedded CRD (`transformerregistrations.opmodel.dev`) and that the Job's RBAC needed no change; the kind and Kubernetes versions. Do not edit any existing entry; touch `## Open questions` only if this run answers one. Verify: `git diff FINDINGS.md` shows only added lines. Commit as `docs: record the move to the OPM beta line in FINDINGS.md`.

## 5. Validation gate

- [ ] 5.1 Final gate. `task check` passes on the final tree (the 3.2 cluster run stands, since section 4 changed documentation only; if anything outside `*.md` changed after 3.2, rerun 3.2). Residual scan: `grep -rn alpha --exclude-dir=vendor --exclude-dir=.git --exclude-dir=archive --exclude-dir=bump-to-beta . | grep -v v1alpha` returns only dated historical `FINDINGS.md` entries and the alpha.14 qualifier in `AGENTS.md`. `openspec validate bump-to-beta --strict` passes and `/opsx:verify bump-to-beta` (pointed at this worktree) reports no critical issue.

## 6. Delivery

- [ ] 6.1 Archive the change with `openspec archive bump-to-beta --skip-specs --yes` (no spec delta). Verify: `openspec/changes/archive/<date>-bump-to-beta/` exists, `openspec/specs/` is unchanged, and `openspec validate --all --strict` still passes. Commit as `chore(openspec): archive bump-to-beta`.
- [ ] 6.2 `git merge origin/main` if main moved, push with `git push -u origin beta/bump-to-beta`, and open one PR. Scan title and body for bare `@` first.
  - **Title / squash commit:** `fix(deps): move the installer image to the OPM beta line` (design D5; the supervisor writes the final squash message).
  - **Carrier:** no. The repo has no release-please, so there is no footer (no `Release-As:`), and no release PR follows.
  - **Merge gate:** G6 ticked, 3.1, 3.2 and 5.1 done, supervisor review. The supervisor merges; the worker never does.
  - **Expected release PR title:** none (nothing releases or publishes).
  - **Body (max 250 words of prose):** why (the beta cutover leaves this repo stranded outside the root pin tasks), where to look first (the podinfo/platform fix if 1.4 needed one, otherwise `Containerfile`), risk (the embedded CRDs are now the operator beta's four, and `bundle-gitea-postgres` must re-read its catalog facts against catalogs/opm 4.4.4), and the kind cluster the run used.
