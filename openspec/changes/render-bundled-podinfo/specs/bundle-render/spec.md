## Purpose

The installer image carries OPM modules inside itself and turns them into Kubernetes manifests
on demand, selected by argument or environment variable, without reaching any module registry.
This is the half of the installer that proves a suite of applications can travel as one OCI
artifact; applying the manifests to a cluster is a separate capability.

## ADDED Requirements

### Requirement: Rendering needs no registry

The image SHALL render every bundled application to Kubernetes manifests with no network access
of any kind. Neither the bundled modules, nor the schema, catalogs and platform a render
depends on, SHALL be fetched at run time.

Rendering SHALL NOT contact a Kubernetes cluster. The image SHALL NOT require a kubeconfig, a
service account token or a cluster `Platform` object to render.

#### Scenario: Render with the network disabled

- **WHEN** the image is run with all networking disabled and asked to render `podinfo`
- **THEN** it exits `0` and writes the podinfo manifests to stdout

#### Scenario: Render on a host with no cluster

- **WHEN** the image is run with no kubeconfig present and asked to render `podinfo`
- **THEN** it exits `0` and no error mentions a cluster, a context or a platform

#### Scenario: The bundled module is the one that rendered

- **WHEN** a bundled application's module files are changed and the image is rebuilt
- **THEN** the rendered manifests reflect the change
- **AND** no published module of the same name is consulted, because the bundled module's path
  is served by no registry the image is configured with

### Requirement: Applications are selected by argument or environment

The entrypoint SHALL accept the applications to render as positional arguments. When no
positional argument is given, it SHALL read the ordered, comma-separated list in
`OPM_SUITE_APPS`. When neither is given, it SHALL render every bundled application.

Positional arguments SHALL take precedence over `OPM_SUITE_APPS`. Applications SHALL be
rendered in the order given, and an application named more than once SHALL be rendered once,
at its first position.

The target namespace SHALL come from `OPM_SUITE_NAMESPACE`, defaulting to `default`.

#### Scenario: Explicit argument

- **WHEN** the image is run with `render podinfo`
- **THEN** only podinfo is rendered

#### Scenario: Environment selection

- **WHEN** `OPM_SUITE_APPS=podinfo` is set and `render` is run with no positional argument
- **THEN** only podinfo is rendered

#### Scenario: Argument beats environment

- **WHEN** `OPM_SUITE_APPS=other` is set and the image is run with `render podinfo`
- **THEN** only podinfo is rendered, and `other` is not

#### Scenario: Unknown application

- **WHEN** the image is asked to render an application the bundle does not contain
- **THEN** it exits `65`, names the unknown application and lists the ones it does carry
- **AND** it renders nothing, including applications named before the unknown one

### Requirement: Output goes to stdout or a directory

Rendered manifests SHALL be written to stdout by default, as a single YAML stream, so the
output can be piped. When `OPM_SUITE_OUT` names a directory, the manifests SHALL be written
into it as files instead, one subdirectory per application, and stdout SHALL carry only
progress messages.

Progress and error messages SHALL be written to stderr, never to stdout, so a piped stream is
never corrupted by them.

#### Scenario: Default output is a pipeable stream

- **WHEN** the image renders `podinfo` with no `OPM_SUITE_OUT` set
- **THEN** stdout contains only YAML documents
- **AND** the stream is accepted by `kubectl apply --dry-run=client -f -`

#### Scenario: Directory output

- **WHEN** `OPM_SUITE_OUT=/out` is set and a volume is mounted there
- **THEN** the manifests are written under `/out/podinfo/`
- **AND** stdout contains no YAML

### Requirement: Rendering is deterministic

The same image rendering the same applications with the same inputs SHALL produce
byte-identical output. Output SHALL NOT embed a timestamp, a hostname, a run identifier or any
other value that changes between runs.

#### Scenario: Second run matches the first

- **WHEN** the image renders `podinfo` twice with identical inputs
- **THEN** the two outputs are byte-identical

### Requirement: The image describes what it carries

The entrypoint SHALL provide a subcommand that reports the bundled applications and the pinned
`opm` version, so the image can be interrogated without being run for effect. Invoked with no
subcommand, or with an unrecognised one, it SHALL print usage to stderr and exit `64`.

#### Scenario: Listing the bundle

- **WHEN** the image is run with `list`
- **THEN** it exits `0` and prints each bundled application name and the `opm` version

#### Scenario: No subcommand

- **WHEN** the image is run with no arguments and no environment
- **THEN** it exits `64` and prints usage to stderr
