// Package identity is the single source of this module's path and version
// (core #IdentityPackage). It sits at the bottom of the module's import graph
// — no intra-module imports, no core import.
package identity

// ModulePath is the module's complete CUE module path, major suffix included
// — byte-identical to cue.mod's `module:` field.
//
// `.invalid` is a reserved TLD (RFC 2606), so this path resolves nowhere, on
// purpose (D2). The bundled module is reached only through the directory
// replacement in bundle/cue.mod/local-module.cue. If this kept the fixture's
// upstream coordinate on the testing domain, a successful render would prove
// nothing: that path also resolves from GHCR, so the offline test could pass
// for the wrong reason.
ModulePath: "suite-installer.invalid/modules/podinfo@v0"

// Version is the module's bare SemVer; its major must agree with ModulePath's.
// Nothing publishes this module, so the version is a label, not a coordinate.
Version: "0.1.10"
