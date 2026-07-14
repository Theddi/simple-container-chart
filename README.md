# simple-container

A minimal, **strict-by-default** Helm chart for simple stateless web containers.
It renders to a Deployment + Service (+ optional Ingress/HTTPRoute + a dedicated
ServiceAccount) whose pod complies with the Kubernetes
[**Restricted** Pod Security Standard](https://kubernetes.io/docs/concepts/security/pod-security-standards/).

## Deploy a new app

Copy `values.yaml`, change the top block, install:

```yaml
image:
  registry: ghcr.io
  repository: my-org
  image: my-app
  tag: "1.4.2"
containerPort: 8080
```

```sh
helm install my-app ./simple-container -f my-app.values.yaml
```

The image reference is composed as `registry/repository/image:tag` (empty
`registry`/`repository` segments are skipped, so `docker.io` library images and
deep paths both work).

## What "strict" means here

| Control | Default | Source |
| --- | --- | --- |
| `runAsNonRoot` | `true` (uid/gid/fsGroup 1000) | pod + container |
| `allowPrivilegeEscalation` | `false` | container |
| `readOnlyRootFilesystem` | `true` | container |
| `capabilities.drop` | `[ALL]` | container |
| `seccompProfile` | `RuntimeDefault` | pod + container |
| ServiceAccount token | not mounted (`automountServiceAccountToken: false`) | pod + SA |
| Volumes | `emptyDir` scratch only (no `hostPath`) | — |
| Resources | memory limit set, requests set | — |

Dedicated (non-`default`) ServiceAccount, rolling updates with
`maxUnavailable: 0`, and liveness/readiness probes are on by default.

To enforce the standard at admission time, label the namespace:

```sh
kubectl label ns <ns> pod-security.kubernetes.io/enforce=restricted
```

## Things the strictness implies

- **Read-only root filesystem.** The container can't write to its image. Add any
  runtime-writable paths (temp, cache, pid/run dirs) under `emptyDirs` — `/tmp`
  is provided by default. The commented `nginx-cache` / `nginx-run` entries in
  values show the pattern for the example image.
- **Ports ≥ 1024.** All capabilities are dropped, so the process can't bind
  privileged ports. Keep `containerPort` ≥ 1024, or add `NET_BIND_SERVICE` under
  `securityContext.capabilities.add` (weakens hardening). The Service still
  exposes port 80 externally and targets the container port by name.
- **Non-root UID.** Defaults to 1000. If your image ships files owned by a
  different user, set `podSecurityContext.runAsUser` (and `runAsGroup`) to match,
  or remove them and rely on the image's own `USER` (still needs to be non-root).

## Config files

For apps that read internal config files, list them under `configs`:

```yaml
configs:
  - name: nginx.conf                 # file name (ConfigMap key)
    path: /etc/nginx/nginx.conf      # where it is mounted in the container
    content: |
      server { listen 8080; }
```

All entries go into one ConfigMap (`<release>-<name>-config`) and each is mounted
**read-only** at its `path` using `subPath`, so it lands as a single file inside
an existing directory (e.g. `/etc/nginx/`) without hiding the other files there.
This is compatible with `readOnlyRootFilesystem: true`. A checksum annotation
rolls the pod automatically when any content changes. `name` values must be
unique.

## Exposure

Enable **either** `ingress` or `httproute` (Gateway API `v1`); both are off by
default. With `httproute.rules` empty a default `/` rule forwards to the service.
