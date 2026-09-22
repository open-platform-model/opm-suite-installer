## Purpose

Re-running the installer with a newer image upgrades its bundled applications in place, and a
failed upgrade is reverted to what the cluster recorded before the Job exits. This is the half
of the installer that makes a second release safe to ship, using only the inventory `opm`
already keeps on the cluster.

## ADDED Requirements

### Requirement: An upgrade is a re-run with new values

`apply` SHALL treat an application that already has a `ModuleInstance` on the cluster as an
upgrade of that instance. Before applying it, `apply` SHALL capture the values that CR records
as the last applied values. The captured values SHALL be discarded when the run succeeds.

#### Scenario: Upgrade podinfo

- **WHEN** podinfo is installed at one image tag and an image whose `values.cue` names a newer
  tag runs `apply podinfo`
- **THEN** it exits `0`, the Deployment runs the newer tag, and the `ModuleInstance` records
  the newer values and a higher revision

#### Scenario: Re-run the upgrade

- **WHEN** the same newer image runs `apply podinfo` again
- **THEN** it exits `0` and no pod is restarted

### Requirement: A failed upgrade is reverted

When an upgrade's apply fails, or the application is not ready within `OPM_SUITE_TIMEOUT`,
`apply` SHALL re-apply the captured values and wait for readiness again. It SHALL then exit
`74` if the revert made the application ready, and `75` if it did not. It SHALL NOT continue
to later applications after a revert. Stderr SHALL say which values were reverted to.

#### Scenario: Upgrade to a tag that does not exist

- **WHEN** podinfo is ready at a working tag and an image whose values name a nonexistent tag
  runs `apply podinfo` with `OPM_SUITE_TIMEOUT=60s`
- **THEN** it exits `74`, the Deployment runs the working tag again with all replicas
  available, and the `ModuleInstance` records the working values

#### Scenario: Revert fails too

- **WHEN** the revert's own readiness wait times out
- **THEN** `apply` exits `75` and stderr carries the diagnostics of the reverted instance

#### Scenario: First install fails

- **WHEN** an application with no `ModuleInstance` on the cluster fails to become ready
- **THEN** `apply` exits `73` as `bundle-apply` specifies and no revert is attempted

### Requirement: Hook files run around the apply

If `bundle/instances/<app>/pre-apply` exists, `apply` SHALL run it with bash before applying
that application; a non-zero exit SHALL abort the run before the apply, with exit `76`. If
`bundle/instances/<app>/on-failure` exists, `apply` SHALL run it after a failed upgrade and
before the built-in revert; its exit status SHALL be reported but SHALL NOT stop the revert.

Both hooks SHALL receive `OPM_SUITE_APP`, `OPM_SUITE_NAMESPACE`, `OPM_SUITE_KUBECONFIG` (the
path `opm` is using) and `OPM_SUITE_PREVIOUS_VALUES` (the path of a JSON file holding the
captured values, or empty on a first install). Hook output SHALL go to stderr, prefixed with the
application name.

#### Scenario: Podinfo's pre-apply runs

- **WHEN** `apply podinfo` runs against a cluster where podinfo is installed
- **THEN** stderr carries a line from podinfo's `pre-apply` naming the previous image tag
  before the apply starts

#### Scenario: A pre-apply refuses

- **WHEN** a `pre-apply` exits non-zero
- **THEN** `apply` exits `76`, the cluster is unchanged for that application, and later
  applications are not applied

#### Scenario: No hooks

- **WHEN** an application directory has neither file
- **THEN** `apply` behaves exactly as `bundle-apply` specifies

### Requirement: The image knows its own version

`list` SHALL print the suite version baked into the image, and `apply` SHALL print it on
stderr at the start of every run, so a log always says which release did what.

#### Scenario: Listing the version

- **WHEN** an image built with `TAG=v2` is run with `list`
- **THEN** its output contains `v2`
