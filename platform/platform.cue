// The baked platform. Every render passes `--platform /opt/opm/platform`,
// which is 0006:D21 precedence source 1 and outranks both the cluster
// Platform CR and ~/.opm/platform (D3).
//
// Two reasons it is baked rather than resolved from the cluster. Resolving a
// Platform CR generates a platform module and pulls its dependency closure
// from a registry, which is a network call this image must not make. And the
// CR a fresh `opm operator install` seeds does not currently work at all
// (FINDINGS.md, 2026-09-22), so this is the only platform source that renders.
//
// Catalog builds are pinned in cue.mod/module.cue, never here. Those pins are
// what `task vendor:sync` vendors into ../vendor, and
// cue.mod/local-module.cue is what redirects them there.
package platform

import (
	core "opmodel.dev/core@v2"
	opm "opmodel.dev/catalogs/opm@v4"
	k8s "opmodel.dev/catalogs/k8s@v1"
)

core.#Platform

metadata: name: "cluster"
type: "kubernetes"

#registry: {
	"opmodel.dev/catalogs/opm@v4": #catalog: opm
	"opmodel.dev/catalogs/k8s@v1": #catalog: k8s
}
