## Purpose

The installer image, run as a Kubernetes Job, bootstraps the OPM CRDs on a bare cluster and
applies its bundled applications to the cluster it runs in, then waits until they are ready.
This is the half of the installer that proves the image can install, not only render, and
that a second run changes nothing.

## Requirements

### Requirement: The image applies from inside the cluster with no kubeconfig

When run inside a pod with a mounted service account token and no kubeconfig supplied, the
image SHALL authenticate to the cluster it runs in using that token. When `OPM_KUBECONFIG` or
`KUBECONFIG` names a file, that file SHALL be used instead, so the same image works from a
developer host against any cluster.

#### Scenario: Apply as a Job

- **WHEN** the image runs as a Job with a ServiceAccount and no kubeconfig anywhere
- **THEN** it reaches the API server of the cluster it runs in and no error mentions
  `~/.kube/config`

#### Scenario: Apply from a host

- **WHEN** the image is run on a developer host with `KUBECONFIG` pointing at the test cluster
- **THEN** it applies to that cluster and never consults a service account token

### Requirement: A bare cluster is bootstrapped by the image

`apply` SHALL install the OPM CustomResourceDefinitions before applying any application, using
only the CRD manifest embedded in the pinned `opm` binary, so bootstrapping needs no network
beyond the API server. It SHALL NOT install the operator or seed a cluster `Platform`.

#### Scenario: First apply on a bare cluster

- **WHEN** `apply podinfo` runs against a cluster with no `opmodel.dev` CRDs
- **THEN** the `ModuleInstance` CRD exists afterwards, no operator Deployment exists, no
  `Platform` object exists, and podinfo is running

#### Scenario: CRDs already present

- **WHEN** `apply podinfo` runs against a cluster that already has the OPM CRDs
- **THEN** the CRDs are left as they are and the run proceeds to the applications

#### Scenario: Bootstrap denied

- **WHEN** the ServiceAccount may not create CustomResourceDefinitions
- **THEN** `apply` exits `71`, names the CRD step, and applies no application

### Requirement: Applications are applied in order and waited for

`apply` SHALL select applications exactly as `render` does (arguments, then `OPM_SUITE_APPS`,
then the whole bundle) and validate the whole selection before touching the cluster. It SHALL
apply them one at a time in the given order, into `OPM_SUITE_NAMESPACE`, through `opm instance
apply` with the baked platform, and after each apply SHALL wait until every resource of that
instance reports ready, bounded by `OPM_SUITE_TIMEOUT` (default `300s`).

A failure SHALL stop the run at that application: later applications SHALL NOT be applied. A
failed apply SHALL exit `72`; an application that is applied but not ready within the timeout
SHALL exit `73`. Progress and errors go to stderr.

#### Scenario: Podinfo becomes ready

- **WHEN** `apply podinfo` runs with the image loaded into the test cluster
- **THEN** it exits `0` and a `ModuleInstance` named `podinfo` exists in the target namespace
  with a Deployment and a Service recorded as its inventory
- **AND** the Deployment reports all replicas available before the command returns

#### Scenario: Readiness timeout

- **WHEN** the bundled podinfo values name an image tag that does not exist and
  `OPM_SUITE_TIMEOUT=60s`
- **THEN** `apply podinfo` exits `73` after about a minute and its stderr names podinfo and the
  resources that are not ready

#### Scenario: Unknown application

- **WHEN** `apply podinfo other` runs and `other` is not bundled
- **THEN** it exits `65` before contacting the cluster, and no CRD or application is applied

### Requirement: The second run is a no-op

Running `apply` again with the same image and the same inputs SHALL leave the cluster in the
same state, exit `0`, and report the instance as up to date rather than changed.

#### Scenario: Re-run the same Job

- **WHEN** the same Job is run a second time against the cluster the first run prepared
- **THEN** it exits `0`, no resource of the instance is recreated or restarted, and the
  Deployment's pods are the same pods as before the second run

#### Scenario: Re-run after a manual drift

- **WHEN** a field the module renders is changed by hand on the cluster and the Job re-runs
- **THEN** the field is set back to the rendered value, because the Job owns it through
  server-side apply
