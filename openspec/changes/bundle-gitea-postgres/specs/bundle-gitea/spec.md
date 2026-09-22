## Purpose

The installer carries Gitea with its own PostgreSQL database, installs both on a bare
cluster, upgrades Gitea through a schema migration, and after a failed upgrade restores the
database from the dump it took beforehand and reverts the pods. This is the first bundled
application with state, and the measurement of what the lifecycle costs when state exists.

## ADDED Requirements

### Requirement: Gitea installs with its database

`apply gitea-backup gitea` on a bare cluster SHALL leave a PostgreSQL StatefulSet with a
persistent volume, a Gitea Deployment with a persistent volume, a backup volume, and no
backup Job, all in the target namespace. Gitea SHALL be ready only after its database is
reachable and `gitea migrate` has completed. Gitea SHALL answer its health endpoint from
inside the cluster.

#### Scenario: First install

- **WHEN** the image runs as a Job with `OPM_SUITE_APPS=gitea-backup,gitea` on a bare cluster
- **THEN** it exits `0`, the `ModuleInstance` objects `gitea-backup` and `gitea` exist, Gitea's
  pod shows the migrate init container completed, and an in-cluster request to Gitea's health
  endpoint succeeds

#### Scenario: Second run

- **WHEN** the same Job runs again
- **THEN** it exits `0`, no pod is restarted, and the database keeps every row

### Requirement: An upgrade dumps the database first

Before an upgrade of `gitea`, the installer SHALL take a dump of the database into the backup
volume and SHALL NOT proceed to the apply unless the dump completed. A dump SHALL replace the
previous one.

#### Scenario: Dump before upgrade

- **WHEN** Gitea is installed and an image with a newer Gitea tag runs `apply gitea-backup gitea`
- **THEN** stderr shows the dump Job completing before the `gitea` apply starts, and the backup
  volume holds one dump file newer than the run's start

#### Scenario: Dump fails

- **WHEN** the dump Job does not complete within the timeout
- **THEN** `apply` exits `76`, and Gitea still runs the previous tag with no rollout started

### Requirement: A successful upgrade migrates the schema

Upgrading to a newer Gitea tag SHALL run the schema migration before the new pod serves, and
SHALL leave the new version ready with the repository data created before the upgrade still
present.

#### Scenario: Minor version upgrade

- **WHEN** a repository was created on the installed version and an image with the next minor
  Gitea tag runs the apply
- **THEN** it exits `0`, the Deployment runs the newer tag, the migrate init container log
  shows migrations applied, and the repository is still listed by the API

### Requirement: A failed upgrade restores the database and reverts the pods

When the upgraded Gitea does not become ready within the timeout, the installer SHALL restore
the database from the dump taken before the upgrade, then revert Gitea to the previous
values, and SHALL exit `74` once the previous version is ready again. Data written to the
database between the dump and the restore is lost, and the log SHALL say so.

#### Scenario: Upgrade whose pod never becomes ready

- **WHEN** Gitea is installed, a repository exists, and an image with a newer Gitea tag and a
  readiness path that cannot succeed runs the apply with a short timeout
- **THEN** the migrate init container completed on the new tag, the restore Job completed, the
  Deployment runs the previous tag with its pod ready, the repository is still listed by the
  API, and the Job exits `74`

#### Scenario: Restore fails

- **WHEN** the restore Job does not complete
- **THEN** the revert of the pods still runs, `apply` exits `74` or `75` according to the
  revert's outcome, and stderr names the failed restore first

#### Scenario: Run the failed upgrade again

- **WHEN** the same failing image runs a second time after a revert
- **THEN** a fresh dump is taken, the same failure and restore happen, and the outcome is
  identical to the first attempt
