# The installer image: a pinned `opm` CLI, a bash entrypoint and a locally
# bundled suite of OPM modules with every CUE dependency vendored beside them.
#
# Debian rather than Alpine (D8 said Alpine, measurement said otherwise): the
# released `opm` linux binary is dynamically linked against glibc
# (`interpreter /lib64/ld-linux-x86-64.so.2`, `libc.so.6`), so it does not run
# on musl. D8 named debian:trixie-slim as the fallback for exactly this, and
# nothing else in the design changes. See FINDINGS.md.
FROM docker.io/library/debian:trixie-slim@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a

# The pinned CLI. An unpinned `opm` makes every finding in FINDINGS.md
# unreproducible, so the version and its checksum are both literals here.
#
# v1.0.0-alpha.20 rather than the newest tag on purpose: v1.0.0-alpha.21 exists
# but carries no release assets at all, so there is no tarball to install or to
# checksum. The delta between the two is `opm platform check`, which this image
# never calls.
ARG OPM_VERSION=v1.0.0-alpha.20
ARG OPM_SHA256_AMD64=2982d368229d8d8af8bf103cec13f3557c8131eee62bbb1cc609a2240b7298f5
ARG OPM_SHA256_ARM64=4c636f838229c8c1907e555050d3c27f9915e14bffdfb9d2158aba4bf19b27f0
# Set by the builder for the target platform; defaulted so a plain
# `podman build .` on amd64 works with no arguments.
ARG TARGETARCH=amd64

RUN set -eu; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates wget; \
    rm -rf /var/lib/apt/lists/*; \
    case "$TARGETARCH" in \
      amd64) sha="$OPM_SHA256_AMD64" ;; \
      arm64) sha="$OPM_SHA256_ARM64" ;; \
      *) echo "unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    url="https://github.com/open-platform-model/cli/releases/download/${OPM_VERSION}/opm-linux-${TARGETARCH}.tar.gz"; \
    wget -q -O /tmp/opm.tar.gz "$url"; \
    echo "$sha  /tmp/opm.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/opm.tar.gz -C /usr/local/bin opm; \
    rm -f /tmp/opm.tar.gz; \
    chmod 0755 /usr/local/bin/opm; \
    opm version

# The bundle and everything it resolves against, at the D7 paths. The sibling
# layout matters: bundle/cue.mod/local-module.cue redirects the bundled module
# to ../modules/podinfo and the platform redirects core and the catalogs to
# ../vendor/..., so bundle, modules, platform and vendor must stay siblings.
#
# Note what is NOT set anywhere in this image: CUE_REGISTRY. Nothing here is
# meant to resolve from a registry, so a resolution attempt should fail loudly
# rather than quietly succeed over the network.
COPY bundle/   /opt/opm/bundle/
COPY modules/  /opt/opm/modules/
COPY platform/ /opt/opm/platform/
COPY vendor/   /opt/opm/vendor/

# The entrypoint. As a Batch/Job this makes the job's `args` the subcommand and
# its applications: args: ["render", "podinfo"]. `opm` itself stays reachable
# for debugging with --entrypoint opm.
COPY scripts/opm-suite /usr/local/bin/opm-suite
ENTRYPOINT ["opm-suite"]
