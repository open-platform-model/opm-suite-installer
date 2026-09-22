module: "suite-installer.invalid/bundle@v0"
language: {
	version: "v0.17.0"
}
deps: {
	"opmodel.dev/catalogs/opm@v4": {
		v: "v4.4.0"
	}
	"opmodel.dev/core@v2": {
		v: "v2.0.0-alpha.10"
	}
	// The bundled application. The version is a placeholder: nothing publishes
	// this module and cue.mod/local-module.cue redirects the path to a
	// directory, so the number is never resolved. `default: true` is load
	// bearing, not decoration — it is what lets the bundled module's own
	// unqualified self-import of .../podinfo/identity resolve (D1).
	"suite-installer.invalid/modules/podinfo@v0": {
		v:       "v0.1.10"
		default: true
	}
}
