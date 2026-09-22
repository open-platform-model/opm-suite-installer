#!/usr/bin/env bash
# The standing proof that the built image still renders with no registry
# reachable.
#
# The offline claim is the whole point of vendoring, and it is exactly the kind
# of claim that rots silently: someone adds a dependency nothing vendors, every
# development machine renders it from a warm cache, and the failure surfaces
# only in an airgapped run months later. So this runs on every `task check`.
#
# What it pins down, all in one run of the real image:
#   - no network at all (--network=none)
#   - a CUE module cache that starts empty and MUST still be empty afterwards,
#     because an empty cache is the only evidence that nothing was fetched
#   - a read-only root filesystem, because the Job this becomes should not need
#     to write to its own image
#   - no kubeconfig and no cluster, anywhere
#   - byte-identical output across two runs
set -euo pipefail

IMAGE="${IMAGE:-localhost/opm-suite-installer}"
TAG="${TAG:-dev}"
ref="$IMAGE:$TAG"

work=$(mktemp -d -t opm-suite-image-render-XXXXXX)
trap 'chmod -R u+w "$work" 2>/dev/null || true; rm -rf "$work"' EXIT

cache="$work/cue-cache"
mkdir -p "$cache"

# No application named: render everything the bundle carries. That is the
# claim worth guarding, not one hand-picked name.
run() {
	podman run --rm \
		--network=none \
		--read-only --tmpfs /tmp \
		-e CUE_CACHE_DIR=/cue-cache \
		-v "$cache:/cue-cache:Z" \
		"$ref" render
}

echo "rendering with $ref, no network, empty CUE cache" >&2
run >"$work/first.yaml" 2>"$work/first.err" || {
	echo "FAIL: the image could not render offline" >&2
	cat "$work/first.err" >&2
	exit 1
}

cached=$(find "$cache" -mindepth 1 | wc -l)
if [ "$cached" -ne 0 ]; then
	echo "FAIL: the CUE cache is no longer empty: $cached entries" >&2
	echo "something resolved from a registry; the image is not self-contained" >&2
	find "$cache" -mindepth 1 -maxdepth 3 >&2
	exit 1
fi

run >"$work/second.yaml" 2>/dev/null || {
	echo "FAIL: the second render did not succeed" >&2
	exit 1
}

if ! cmp -s "$work/first.yaml" "$work/second.yaml"; then
	echo "FAIL: two identical runs produced different manifests" >&2
	diff "$work/first.yaml" "$work/second.yaml" >&2 || true
	exit 1
fi

if ! grep -q '^kind:' "$work/first.yaml"; then
	echo "FAIL: the render produced no Kubernetes objects" >&2
	exit 1
fi

echo >&2
echo "offline render OK: $(grep -c '^kind:' "$work/first.yaml") objects," \
	"CUE cache still empty, two runs byte-identical" >&2
