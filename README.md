# docker-certbot-dns-ionos

A scheduled, non-root Certbot container using the
[`certbot-dns-ionos`](https://github.com/helgeerbe/certbot-dns-ionos)
authenticator.

This repository is the maintained canonical source for the implementation
shared by the Authentik and MQTT stacks. It preserves their existing build
arguments. Until their vendored `certbot-build/` copies are replaced, changes
here do not propagate to those stacks automatically.

## Runtime model

The container starts as root only long enough to repair ownership on an
existing `/certbot` volume and create its crontab. It then uses `su-exec` to
replace itself with Supercronic as the unprivileged `certbot` user. There is no
persistent root helper inside the running container.

Supercronic 0.2.47 is built from source with Go 1.26.5 so the final binary does
not inherit the vulnerable Go standard library used by the upstream 0.2.47
release asset.

The scheduled command runs `certbot certonly` with `--keep-until-expiring`, so
it checks the requested certificate lineage on every schedule and only renews
when needed.

## Required configuration

| Variable | Description |
|---|---|
| `IONOS_CREDENTIALS` | Path to the IONOS credentials file inside the container |
| `IONOS_CRONTAB` | Five-field Supercronic schedule, such as `0 13 * * *` |
| `IONOS_DOMAINS` | Comma-separated certificate domains |
| `IONOS_PROPAGATION` | Seconds to wait for DNS propagation |
| `IONOS_EMAIL` | Email passed to Certbot for ACME registration |
| `IONOS_ARGS` | Optional whitespace-separated additional Certbot arguments |

Create the credentials file with permissions that allow only the configured
Certbot UID to read it:

```ini
dns_ionos_prefix = your-api-prefix
dns_ionos_secret = your-api-secret
dns_ionos_endpoint = https://api.hosting.ionos.com
```

The credentials directory should be mounted read-only at
`/certbot/etc/letsencrypt/.secrets`. Never commit the credentials file.

## Compose

Copy `ionos.ini.tmpl` to `${HOME}/certbot/etc/letsencrypt/.secrets/ionos.ini`,
fill in the credentials, then set at least `IONOS_DOMAINS` and `IONOS_EMAIL`:

```shell
export IONOS_DOMAINS='example.com,*.example.com'
export IONOS_EMAIL='admin@example.com'
docker compose up --build -d
```

The included [compose.yaml](compose.yaml) builds the maintained local source.
It does not pull the stale `gmmserv/docker-certbot-dns-ionos:2024.1.8` image.

## Build arguments

The arguments consumed by the Authentik and MQTT stacks remain supported:

| Argument | Default | Purpose |
|---|---|---|
| `VERSION` | `2024.11.09` | `certbot-dns-ionos` package version |
| `CERTBOT_VERSION` | `v5.7.0` | `certbot/certbot` base image tag |
| `USER_UID` | `1000` | Runtime `certbot` UID |
| `USER_GID` | `1000` | Runtime `certbot` GID |

The image also accepts maintenance arguments `SUPERCRONIC_VERSION` and
`GOLANG_VERSION`.

Build directly:

```shell
docker build \
  --build-arg VERSION=2024.11.09 \
  --build-arg CERTBOT_VERSION=v5.7.0 \
  --build-arg USER_UID=1000 \
  --build-arg USER_GID=1000 \
  --tag docker-certbot-dns-ionos:2024.11.09 \
  .
```

Or build the supported `linux/amd64`, `linux/arm64`, and `linux/arm/v6`
platforms with Bake:

```shell
IMAGE=ghcr.io/deftmartian/docker-certbot-dns-ionos \
docker buildx bake --file docker-bake.hcl --push
```

`linux/arm/v7` is intentionally omitted because the current official Certbot
image does not publish an arm/v7 base manifest.

## Validation

CI performs ShellCheck and Hadolint linting, builds every supported platform,
runs the scheduler through a real container restart, verifies the process UID
and plugin registration, and fails on fixed High or Critical image
vulnerabilities.

Run the same smoke test locally after building:

```shell
tests/smoke.sh docker-certbot-dns-ionos:2024.11.09
```

Set `CONTAINER_RUNTIME=podman` when using Podman.

## Credits

- [`certbot/certbot`](https://github.com/certbot/certbot)
- [`helgeerbe/certbot-dns-ionos`](https://github.com/helgeerbe/certbot-dns-ionos)
- [`aptible/supercronic`](https://github.com/aptible/supercronic)
- Original container implementation by
  [`gianmarco-mameli`](https://github.com/gianmarco-mameli/docker-certbot-dns-ionos)
