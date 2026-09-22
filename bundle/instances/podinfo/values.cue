// Concrete values for the podinfo instance. See #config in
// ../../../modules/podinfo/module.cue for the full surface.
//
// This file is not optional. A module's `debugValues` is used only when the
// CLI synthesizes an instance around a module directory, never when it renders
// an instance file, so an instance without its own values fails the render as
// `not fully concrete: values: incomplete value _` (D5).
//
// The image tag is pinned here rather than left to the module's default
// because this file is what a suite release changes: an upgrade is a values
// change, and `opm` records exactly this block as the instance's `spec.values`
// on the cluster. What is not written here is not in the record, and so is not
// what a failed upgrade reverts to.
package podinfo

values: {
	image: {
		repository: "ghcr.io/stefanprodan/podinfo"
		tag:        "6.7.1"
		digest:     ""
	}
	replicas: 1
}
