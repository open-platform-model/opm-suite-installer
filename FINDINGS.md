# Findings

What the experiment taught us, including the negative results. Newest first.

Each entry: what was tried, what happened, what it means. A finding that kills an idea is worth
more than one that confirms it.

## Open questions

- Does a warm `CUE_CACHE_DIR` keep `opm instance build` off the network entirely? Everything
  offline depends on the answer and it is currently unverified.
- How wide does the Job's RBAC have to be in practice, for a realistic suite?
- Is losing operator ownership (drift correction, reconciliation) acceptable for the use cases
  an installer image would serve?

## Entries

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

