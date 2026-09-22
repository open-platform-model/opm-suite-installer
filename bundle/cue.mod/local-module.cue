// Everything this bundle depends on is served from a directory beside it.
// Nothing is resolved from a registry, at build time or at run time (D4).
//
// `opm` reports the podinfo redirection on every render:
//
//	WARN local replacement in effect: suite-installer.invalid/modules/podinfo@v0
//	     served from .../modules/podinfo (instance); rendered bytes may not
//	     correspond to any published build
//
// That warning is the mechanism announcing itself and MUST NOT be suppressed.
// It is also accurate: these bytes correspond to no published build.
//
// The core and catalog entries below look redundant, and `opm` says so:
//
//	local replacement of opmodel.dev/core@v2 in bundle/cue.mod/local-module.cue
//	is ignored: the platform names that path; redirect it in the platform
//	module's cue.mod/local-module.cue
//
// They are required anyway. Loading and validating the instance package
// happens before the render module is staged, and that step uses the bundle
// module's own view. Removing these two entries fails the load at the core
// import in instance.cue, even with the platform's replacements in place.
// Recorded in FINDINGS.md rather than worked around.
deps: {
	"suite-installer.invalid/modules/podinfo@v0": replaceWith: "../modules/podinfo"
	"opmodel.dev/core@v2": replaceWith:                        "../vendor/opmodel.dev/core@v2"
	"opmodel.dev/catalogs/opm@v4": replaceWith:                "../vendor/opmodel.dev/catalogs/opm@v4"
}
