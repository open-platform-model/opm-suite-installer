// Concrete values for the podinfo instance. See #config in
// ../../../modules/podinfo/module.cue for the full surface.
//
// This file is not optional. A module's `debugValues` is used only when the
// CLI synthesizes an instance around a module directory, never when it renders
// an instance file, so an instance without its own values fails the render as
// `not fully concrete: values: incomplete value _` (D5).
package podinfo

values: {
	replicas: 1
}
