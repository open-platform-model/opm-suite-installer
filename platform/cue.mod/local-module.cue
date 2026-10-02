// The platform's dependency list wins the render, so this is the file that
// decides where core and the catalog come from (D4). Every entry points into
// vendor/, the committed copy of the published source; nothing is resolved
// from a registry.
//
// cue.dev/x/k8s.io is here too. It is nobody's direct import in this repo, but
// catalogs/opm needs it, and an unvendored transitive dependency is exactly the
// kind of rot that only shows up in an airgapped run.
//
// The exact versions behind these paths are in ../vendor/VERSIONS, and
// `task vendor:sync` is what refreshes them.
deps: {
	"opmodel.dev/core@v2": replaceWith:         "../vendor/opmodel.dev/core@v2"
	"opmodel.dev/catalogs/opm@v4": replaceWith: "../vendor/opmodel.dev/catalogs/opm@v4"
	"cue.dev/x/k8s.io@v0": replaceWith:         "../vendor/cue.dev/x/k8s.io@v0"
}
