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
# v1.0.0-beta.2 because it is the first `cli` release that embeds the
# opm-operator beta (v1.0.0-beta.1): the CRDs `opm operator install --crds-only`
# applies come from the embedded operator, so the pin follows the operator line,
# not the newest `cli` tag. Only a tag that carries release assets can be pinned;
# both checksums are copied from that release's checksums.txt.
ARG OPM_VERSION=v1.0.0-beta.2
ARG OPM_SHA256_AMD64=af0d55c8141a2fb7298d66685728efac0c784642dd0e077ccd752a6a07886431
ARG OPM_SHA256_ARM64=ebe3f38175bfd20714178f7779c6d831738ab91953f9521db6db3dc69ca38be4
# Set by the builder for the target platform; defaulted so a plain
# `podman build .` on amd64 works with no arguments.
ARG TARGETARCH=amd64

# `jq` alongside `wget` (D1): the previous values the entrypoint reverts to are
# JSON inside the ModuleInstance CR, and bash has no honest way to lift one
# object out of JSON. Both come from the base image's own package repository,
# which is what the constitution's "the base image's own tools" is read to mean.
RUN set -eu; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates wget jq; \
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
# to ../modules/podinfo and the platform redirects core and the catalog to
# ../vendor/..., so bundle, modules, platform and vendor must stay siblings.
#
# Note what is NOT set anywhere in this image: CUE_REGISTRY. Nothing here is
# meant to resolve from a registry, so a resolution attempt should fail loudly
# rather than quietly succeed over the network.
COPY bundle/   /opt/opm/bundle/
COPY modules/  /opt/opm/modules/
COPY platform/ /opt/opm/platform/
COPY vendor/   /opt/opm/vendor/

# The suite version, as a file beside the bundle (D5). The image applies what
# it carries and compares nothing: this exists so a Job log can be matched to
# the release that produced it. `task build` passes TAG; a plain
# `podman build .` gets "dev".
ARG SUITE_VERSION=dev
RUN printf '%s\n' "$SUITE_VERSION" >/opt/opm/VERSION

# The entrypoint. As a Batch/Job this makes the job's `args` the subcommand and
# its applications: args: ["render", "podinfo"]. `opm` itself stays reachable
# for debugging with --entrypoint opm.
COPY scripts/opm-suite /usr/local/bin/opm-suite
ENTRYPOINT ["opm-suite"]
