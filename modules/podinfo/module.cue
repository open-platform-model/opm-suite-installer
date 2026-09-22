// podinfo — the bundle's first application. Copied from the CLI's published
// test fixture (cli/tests/fixtures/modules/podinfo) and re-identified onto
// suite-installer.invalid, a path no registry mapping serves (D2).
//
// This module is never published. It travels inside the installer image and
// is reached by the directory replacement in bundle/cue.mod/local-module.cue.
//
// Stateless web example module (opmodel.dev/core@v2). Renders a Deployment +
// Service via the catalog's deployment- and service-transformers, with an HTTP
// livenessProbe (/healthz) and readinessProbe (/readyz) on the podinfo HTTP
// port (9898). Serves as a real-world "getting started" example a newcomer can
// apply against a running operator to see OPM work end-to-end.
package podinfo

import (
	"strings"

	m "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"

	id "suite-installer.invalid/modules/podinfo/identity"
)

m.#Module

// Module metadata — modulePath and version are the identity package's values,
// and name is the path's leaf (0010:D8, 0011:D12). Edit
// identity/identity.cue, not this block.
metadata: {
	_segments:   strings.Split(strings.SplitN(id.ModulePath, "@", 2)[0], "/")
	name:        _segments[len(_segments)-1]
	modulePath:  id.ModulePath
	version:     id.Version
	description: "Stateless web example — Deployment + Service with HTTP liveness/readiness probes"
}

#config: {
	// Container image. Defaults to upstream podinfo; override repository/tag/digest
	// via the ModuleRelease values to pin a specific build.
	image: res.#Image & {repository: string | *"ghcr.io/stefanprodan/podinfo", tag: string | *"6.7.1", digest: string | *""}

	// Number of Deployment replicas.
	replicas: int | *1
}

debugValues: {
	image: {repository: "ghcr.io/stefanprodan/podinfo", tag: "6.7.1", digest: ""}
	replicas: 1
}
