// The podinfo instance. Binds the bundled podinfo #Module to a
// #ModuleInstance; `opm instance build` turns this into a Deployment and a
// Service.
//
// metadata.namespace is deliberately absent. `opm instance build -n <ns>` does
// not set it (D6): with a namespace here, -n is ignored; without one, the
// render fails on the required field. The entrypoint therefore writes a
// generated .cue file into this package directory carrying
// `metadata: namespace: ...`, and CUE unification supplies the value.
package podinfo

import (
	core "opmodel.dev/core@v2"
	podinfo "suite-installer.invalid/modules/podinfo@v0"
)

core.#ModuleInstance

metadata: name: "podinfo"

#module: podinfo
