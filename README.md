# opm-suite-installer

A proof of concept. One container image carries the `opm` CLI, a bash script and a set of
bundled OPM modules. Run it as a Kubernetes `Batch/Job` and it installs a whole suite of
applications into the cluster it runs in.

Milestone 1 is podinfo, installed from a bundled `#Module` through a `#ModuleInstance`.

## Status

Bootstrap. No image, no scripts, no bundle yet. The repo currently holds its guide rails and an
OpenSpec workspace.

## The idea

```
                container image
  ┌───────────────────────────────────────┐
  │  opm CLI                              │
  │  bash entrypoint  <- args + env       │      Batch/Job
  │  bundle/  (local OPM modules)         │  ─────────────────>  cluster
  │  platform/ (baked #Platform)          │
  └───────────────────────────────────────┘
```

The Job's arguments and environment select which bundled applications to install, into which
namespace, with which values. The script drives `opm instance apply` once per application.

## What this is testing

- Whether a suite of OPM applications can ship as **one** versioned artifact.
- Whether that artifact can install itself **offline**, with no registry reachable.
- What it costs: the RBAC surface, the loss of operator ownership, the platform pinning.

The honest counter-argument is written down in `CLAUDE.md` and tracked in `FINDINGS.md`: OPM
already publishes modules as OCI artifacts, so an installer image duplicates a distribution
channel that exists. This repo exists to find out whether the duplication buys anything.

## Requirements

Any Kubernetes cluster you can reach. For a disposable one:

```bash
task cluster:up      # bare single-node kind cluster
task cluster:status
task cluster:down
```

`cluster:up` deliberately stops at a stock Kubernetes cluster: no OPM operator, no CRDs, no
Platform. Installing those is the installer image's job, and it is part of what the experiment
is testing. A cluster that arrives pre-prepared proves nothing.

For a full local OPM demo with Flux and a local registry, see `opm-kind-demo`.

## Layout

Directories appear as work lands. See `CLAUDE.md` for the target shape.
