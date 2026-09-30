## Gates

Ticked by the supervisor only. Section 1 needs G1 and G3; section 2 onward needs G6.

- [ ] G1 `opmodel.dev/core@v2` v2.0.0-beta.1 is on GHCR
- [ ] G3 `opmodel.dev/catalogs/k8s@v1` v1.0.0-beta.1 (tag k8s-v1.0.0-beta.1) and `opmodel.dev/catalogs/opm@v4` v4.4.4 (tag opm-v4.4.4) are on GHCR
- [ ] G6 the first `cli` release embedding `opm-operator` v1.0.0-beta.1 exists (expected v1.0.0-beta.2; record the real tag here: `________`) and carries `opm-linux-amd64.tar.gz`, `opm-linux-arm64.tar.gz` and `checksums.txt`

No supervisor patch applies: this repo is outside every root task (`deps:update`,
`deps:pins:*`). All work below runs in the worktree
`.claude/worktrees/beta-bump-to-beta` on branch `beta/bump-to-beta`, with the registry env
exported on two separate lines.

## 1. CUE pins and vendored source

- [ ] 1.1 In `platform/` run `cue mod get opmodel.dev/core@v2.0.0-beta.1 opmodel.dev/catalogs/opm@v4.4.4 opmodel.dev/catalogs/k8s@v1.0.0-beta.1`, and in `modules/podinfo/` the same without the k8s catalog (design D1). Verify: `grep -A1` on each `cue.mod/module.cue` shows the three exact versions and no `alpha`; note any transitive pin `cue mod get` added or moved (`cue.dev/x/k8s.io`).
- [ ] 1.2 Set the two core/catalog lines in `bundle/cue.mod/module.cue` to the exact versions the platform now pins, leaving the podinfo placeholder and its `default: true` untouched (`cue mod get` cannot build the bundle's graph, design D1). Verify: the core and catalogs/opm versions in `bundle/` equal those in `platform/`. Commit 1.1 and 1.2 together as `chore(deps): pin core 2.0.0-beta.1, catalogs/opm 4.4.4 and catalogs/k8s 1.0.0-beta.1`.
- [ ] 1.3 Run `task vendor:sync` (design D2) and update the example version in the `hack/vendor-sync.sh` comment (lines 58-59) to the beta string. Verify: `vendor/VERSIONS` lists core v2.0.0-beta.1, catalogs/opm v4.4.4, catalogs/k8s v1.0.0-beta.1; `grep -rl alpha vendor/VERSIONS` is empty; `git status` shows no stray files. Commit as `chore(deps): regenerate vendor from the beta pins`.
- [ ] 1.4 Check whether core beta breaks the bundle (design D4): `cue vet ./...` in `platform/`, `modules/podinfo/` and `bundle/`, and diff `modules/podinfo` against `cli/tests/fixtures/modules/podinfo` at the G6 cli tag (read from a shallow clone of that tag in the scratchpad, `git clone --depth 1 --branch <tag> https://github.com/open-platform-model/cli`; never fetch into or check out the cli main checkout). If anything fails, make the smallest change that mirrors the fixture, keeping the `suite-installer.invalid` identity, and commit it as `fix(podinfo): adapt the bundled module to core 2.0.0-beta.1` (or `fix(platform): ...` for `platform.cue`). Verify: `cue vet` exits 0 in all three. If nothing fails, record "no change needed" in 3.2.

## 2. The pinned `opm` CLI

- [ ] 2.1 Read the G6 tag's assets with `gh release view <tag> --repo open-platform-model/cli --json assets` (always name the tag: the unqualified "latest" release reports `v0.6.0`), download both tarballs and `checksums.txt`, and confirm `sha256sum` of each tarball matches its `checksums.txt` line. Set `ARG OPM_VERSION=<tag>`, `OPM_SHA256_AMD64` and `OPM_SHA256_ARM64` in `Containerfile`, and replace the alpha.20-over-alpha.21 comment with the current rationale (the first `cli` embedding operator v1.0.0-beta.1). Verify: `grep -n alpha Containerfile` is empty. Commit as `chore(deps): install opm <tag> in the installer image`.

## 3. Documentation

- [ ] 3.1 Rewrite the last sentence of the glibc bullet in `AGENTS.md` (around line 189) to state the current pin and the rule behind it (pin the `cli` tag whose operator matches the beta line, and only a tag that carries release assets). Verify: `grep -n alpha AGENTS.md` shows only `v1alpha1` API references. Commit as `docs: record the beta opm pin in AGENTS.md`.
- [ ] 3.2 Add one new dated entry to `FINDINGS.md` at the top of `## Entries` (the log is newest first): what the move from core alpha.10 / `opm` alpha.20 to the beta line required (podinfo/platform changes or none, the bundle `cue mod get` limitation, any transitive pin, image size before and after, the `opm version` string and the operator version its CRDs carry). Do not edit any existing entry; touch `## Open questions` only if this run answers one. Verify: `git diff FINDINGS.md` shows only added lines. Commit as `docs: record the move to the OPM beta line in FINDINGS.md`.

## 4. Verification

- [ ] 4.1 `task check` (lint, build, image:render) passes. Verify: the build log's `opm version` line prints the G6 tag, and `image:render` reports an empty cache and byte-identical output across both runs.
- [ ] 4.2 Named cluster run on a fresh bare kind cluster (`CLUSTER=opm-suite`): `task cluster:up`, `task cluster:load`, `task job:run` completes and podinfo is Ready; run `task job:run` a second time and confirm it succeeds with no change (the idempotency scenario). Read `kubectl get crd moduleinstances.opmodel.dev -o jsonpath='{.spec.versions[*].name}'` and confirm it matches `MI_API` in `scripts/opm-suite` (expected `v1alpha1`); if it does not, stop and raise it, since that is a behavior change for a separate change. `task cluster:down` afterwards. Record the kind and Kubernetes versions in the 3.2 entry.
- [ ] 4.3 Residual scan: `grep -rn alpha --exclude-dir=vendor --exclude-dir=.git --exclude-dir=archive . | grep -v v1alpha` returns only dated historical `FINDINGS.md` entries.
- [ ] 4.4 `openspec validate bump-to-beta --strict` passes and `/opsx:verify bump-to-beta` (pointed at this worktree) reports no critical issue.

## 5. Archive

- [ ] 5.1 Archive the change with `openspec archive bump-to-beta --skip-specs --yes` (no spec delta). Verify: `openspec/changes/archive/<date>-bump-to-beta/` exists and `openspec/specs/` is unchanged. Commit as `chore(openspec): archive bump-to-beta`.

## 6. Pull request

- [ ] 6.1 `git merge origin/main` if main moved, push with `git push -u origin beta/bump-to-beta`, and open one PR. Scan title and body for bare `@` first.
  - **Title / squash commit:** `chore(deps): move the installer image to the OPM beta line` (type `chore(deps)`; the supervisor writes the final squash message).
  - **Carrier:** no. The repo has no release-please, so there is no footer (no `Release-As:`), and no release PR follows.
  - **Merge gate:** G6 ticked, 4.1 and 4.2 done, supervisor review. The supervisor merges; the worker never does.
  - **Expected release PR title:** none (nothing releases or publishes).
  - **Body (max 250 words of prose):** why (the beta cutover leaves this repo stranded outside the root pin tasks), where to look first (the podinfo/platform fix if 1.4 needed one, otherwise `Containerfile`), risk (the embedded CRDs are now operator v1.0.0-beta.1), and the kind cluster the run used.
