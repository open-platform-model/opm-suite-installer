## Context

See `proposal.md` for motivation and `specs/bundle-apply/spec.md` for the contract. The
entrypoint today renders from a working copy under `TMPDIR` (D6 of the archived
`render-bundled-podinfo`), and that copy is where `apply` renders from too: `opm instance apply`
takes the same instance file and `--platform` as `opm instance build`.

`opm` on the host during verification: `v1.0.0-alpha.20-2-g2bfebd9`, CUE SDK v0.17.1. The
image pins v1.0.0-alpha.20; every claim below MUST be re-run inside the image before it is
relied on (task 1.1).

## Goals / Non-Goals

**Goals**

- One new subcommand, `apply`, reusing the render path unchanged.
- Bootstrap a bare cluster from inside a Job with nothing but `opm`.
- Measure the RBAC width for one application and write it down.

**Non-Goals**

- Upgrades, reverts, hooks, or reading anything back from the `ModuleInstance` CR. That is
  the next change.
- A full operator install. A bundled module cannot be operator-owned, so it would install
  something that has nothing to reconcile.
- Any binary beyond `opm`. No `kubectl`, no `jq`. If the wait cannot be expressed with `opm`,
  that is the finding, not a licence.

## Decisions

### D1: The Job writes its own kubeconfig from the service account token

`opm` has no in-cluster fallback. It resolves the kubeconfig as `flag > OPM_KUBECONFIG > config
> ~/.kube/config` (`cli/internal/config/resolver.go`), passes the result to client-go as an
**explicit** path, and client-go stats explicit paths. Run on the host with no such file:

```
$ HOME=/nonexistent-home opm instance status podinfo -n default
ERRO m:podinfo: connecting to cluster error="building kubernetes config:
  stat /nonexistent-home/.kube/config: no such file or directory: connectivity error"
exit=3
```

An empty `OPM_KUBECONFIG=` does not help: the resolver treats an empty value as unset and the
same error appears. So a pod with only `/var/run/secrets/kubernetes.io/serviceaccount/` never
gets as far as the token.

The entrypoint therefore synthesizes one. When neither `OPM_KUBECONFIG` nor `KUBECONFIG` is
set and `KUBERNETES_SERVICE_HOST` is, it writes `$WORK/kubeconfig`:

```yaml
apiVersion: v1
kind: Config
clusters:
- name: in-cluster
  cluster:
    server: https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT
    certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
users:
- name: sa
  user:
    tokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
contexts:
- name: in-cluster
  context: {cluster: in-cluster, user: sa}
current-context: in-cluster
```

and passes `--kubeconfig "$WORK/kubeconfig"` to every `opm` call. `tokenFile` rather than an
inlined token, so a rotated projected token is picked up. This is a plain heredoc, no new tool,
and it is the finding for `cli/`: an in-cluster fallback when the default path is absent is
what every other Kubernetes CLI does.

**Alternative rejected**: mounting a kubeconfig Secret into the Job. Moves a cluster credential
into a Secret nobody needs, for a pod that already has one.

### D2: CRDs come from the embedded manifest, with `--crds-only`

```
$ opm operator install --help
By default this applies the full embedded manifest (CRDs, RBAC, Deployment,
Service) and waits for the CRDs to reach Established and the operator
Deployment to complete its rollout. --crds-only applies just the CRDs, for
clusters where the CLI drives module lifecycle without a running operator.
      --crds-only            Install only the CustomResourceDefinitions
      --version string       Fetch this opm-operator release tag instead of the embedded pin
```

`--crds-only` with no `--version` uses the embedded pin, so bootstrap needs no network beyond
the API server. It also never seeds the broken cluster `Platform` (`FINDINGS.md`). Task 1.1
runs it inside the image with `--network=none` plus a kubeconfig pointing at the kind API
server, which is the only way to prove "embedded" from the outside.

`apply` runs it on every invocation, before the first application. The command is
server-side apply and waits for `Established`, so the second run is a no-op by construction.
A non-zero exit here is exit `71` and no application is touched.

### D3: The readiness wait is a loop on `opm instance status`

`opm instance apply` has a `--timeout`, but it bounds "the operator-reconcile wait
(operator-managed instances only)" (`opm instance apply --help`). A CLI-owned apply returns as
soon as the server has accepted the objects. There is no `--wait`.

`opm instance status` does carry the signal. Its print path returns a validation error when the
aggregate is anything but `Ready` or `Complete`
(`cli/internal/workflow/query/status.go`, "instance %q: %d resource(s) not ready"), and
validation errors exit `2` (`cli/internal/exit/exit.go`). So the wait is:

```bash
until opm instance status "$app" -n "$NAMESPACE" --kubeconfig "$kc" >/dev/null 2>&1; do
	[ "$SECONDS" -lt "$deadline" ] || { opm instance status "$app" -n "$NAMESPACE" --details >&2; exit 73; }
	sleep 5
done
```

The final `--details` call prints pod-level diagnostics for the reader before exiting. Task
3.2 verifies the exit codes against a live cluster, with a pod that never becomes ready, before
this is trusted. **Finding for `cli/`**: a `--wait` on `opm instance apply` for CLI-owned
instances would delete this loop.

### D4: `apply` is `render` plus three `opm` calls

```
opm-suite apply [app...]    bootstrap CRDs, then apply and wait, one application at a time

OPM_SUITE_TIMEOUT     per-application readiness bound, default 300s
OPM_KUBECONFIG        an explicit kubeconfig; KUBECONFIG is honoured too; else D1
(all render variables keep their meaning; OPM_SUITE_OUT is ignored by apply)

exit 71   CRD bootstrap failed
exit 72   opm instance apply failed for an application
exit 73   an application was applied but not ready within OPM_SUITE_TIMEOUT
```

Selection, validation, the working copy and the generated namespace file are shared with
`render` verbatim; `apply` differs only in the `opm` verb and the wait. Applications are
applied strictly in order and the run stops at the first failure, because a later application
may depend on an earlier one (the Gitea change relies on this).

The target namespace is not created by the entrypoint. `deploy/` creates it, and
`--create-namespace` stays off so the RBAC measurement stays honest.

### D5: RBAC delta, the thing being measured

The Job runs as ServiceAccount `opm-suite-installer` in namespace `opm-suite`, which is also
the target namespace. Starting point, to be trimmed or widened by the cluster run:

| Scope | Resource | Verbs | Why |
| --- | --- | --- | --- |
| cluster | `apiextensions.k8s.io/customresourcedefinitions` | get, list, create, patch | `--crds-only` |
| cluster | `opmodel.dev/platforms` | get | the operator-version gate; a Forbidden only warns, so this may be dropped |
| namespace | `opmodel.dev/moduleinstances` (+ `/status`) | get, list, create, patch, update, delete | inventory record |
| namespace | `apps/deployments` | get, list, create, patch, delete | podinfo |
| namespace | `core/services` | get, list, create, patch, delete | podinfo |
| namespace | `core/pods`, `core/events` | get, list | `opm instance status --details` |

`delete` is there because pruning is on by default. `list` is there because status resolves
inventory by label. Everything is namespaced except the CRD and Platform reads, so the
ClusterRole is two rules. Whatever the run proves necessary is what `deploy/` ships, and the
delta between this table and the shipped one is the finding.

### D6: The Job manifest

`restartPolicy: Never`, `backoffLimit: 0`: a retry would be a second apply, which is
idempotent, but a retry also hides which run produced which log. `imagePullPolicy: Never`
against the `kind load`ed image, `args: ["apply"]`, `OPM_SUITE_NAMESPACE` set to the Job's own
namespace, `TMPDIR=/tmp` with an `emptyDir` so the root filesystem can stay read-only.

`task job:run` applies `deploy/`, waits for the Job with `kubectl wait --for=condition=complete`
(host-side `kubectl`, allowed: the image is the thing under test, the host is not) and prints
the logs. `task job:run` MUST refuse if the image is not loaded, because a pull would fail
slowly. Re-running it deletes the previous Job first, so the second-run scenario is one command.

## Risks / Trade-offs

- **The polling wait misreads a transient state as ready.** A Deployment is briefly "ready"
  with old pods during a rollout. → Accepted for this change; the upgrade change measures it
  against a real rollout and tightens the check there if needed.
- **`--crds-only` may still need something from the network.** → Task 1.1 runs it with
  `--network=none` inside the image. If it fails, that is the finding and the image runs it
  with network, stated as a limitation.
- **The RBAC table is a guess until the run.** → It is the measurement. Ship what the run
  needs, record the diff.
- **`backoffLimit: 0` means a flaky API server fails the run.** → Intended for a PoC that is
  measuring; a product would retry.
