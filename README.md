# docker-certbot-dns-ionos

[![CI](https://github.com/deftmartian/docker-certbot-dns-ionos/actions/workflows/ci.yml/badge.svg)](https://github.com/deftmartian/docker-certbot-dns-ionos/actions/workflows/ci.yml)
[![GHCR](https://img.shields.io/badge/container-ghcr.io-blue)](https://github.com/deftmartian/docker-certbot-dns-ionos/pkgs/container/docker-certbot-dns-ionos)

A maintained, multi-platform Certbot container that schedules certificate
renewals with the
[`certbot-dns-ionos`](https://github.com/helgeerbe/certbot-dns-ionos)
DNS authenticator.

The public image is available from the
[GitHub Container Registry](https://github.com/deftmartian/docker-certbot-dns-ionos/pkgs/container/docker-certbot-dns-ionos):

```text
ghcr.io/deftmartian/docker-certbot-dns-ionos:2026.07.16
```

This repository is the canonical source for the published image. Pull requests,
pushes to `main`, and release tags are linted, smoke-tested with multiple
runtime identities, vulnerability-scanned, and built for all supported
platforms. Matching release tags publish the tested image to GHCR and create a
GitHub release.

## Published image

Pull the current image without registry authentication:

```shell
docker pull ghcr.io/deftmartian/docker-certbot-dns-ionos:2026.07.16
```

Successful release builds publish three tags for the same image:

- `2026.07.16` — the immutable container release
- `latest` — the current container release
- `sha-<full-commit-sha>` — an immutable source-specific image

Published platforms are `linux/amd64`, `linux/arm64`, and `linux/arm/v6`.
`linux/arm/v7` is intentionally omitted because the official Certbot base
image does not publish an arm/v7 manifest.

## Runtime model

The container starts as root only long enough to repair ownership on an
existing `/certbot` volume and create its crontab. It then uses `su-exec` to
replace itself with Supercronic as the configured unprivileged UID and GID.
There is no persistent root helper inside the running container.

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
| `USER_UID` | Runtime UID for Supercronic and Certbot (default `1000`) |
| `USER_GID` | Runtime GID for Supercronic and Certbot (default `1000`) |

Create the credentials file with permissions that allow only the configured
Certbot UID to read it:

```ini
dns_ionos_prefix = your-api-prefix
dns_ionos_secret = your-api-secret
dns_ionos_endpoint = https://api.hosting.ionos.com
```

The credentials directory should be mounted read-only at
`/certbot/etc/letsencrypt/.secrets`. Never commit the credentials file.

## Quick start

Copy `ionos.ini.tmpl` to `${HOME}/certbot/etc/letsencrypt/.secrets/ionos.ini`,
fill in the credentials, and restrict access to the configured runtime UID:

```shell
mkdir -p "${HOME}/certbot/etc/letsencrypt/.secrets"
cp ionos.ini.tmpl "${HOME}/certbot/etc/letsencrypt/.secrets/ionos.ini"
chmod 600 "${HOME}/certbot/etc/letsencrypt/.secrets/ionos.ini"
```

Then start the published image:

```shell
docker run --detach \
  --name certbot-ionos \
  --restart unless-stopped \
  --env USER_UID="$(id -u)" \
  --env USER_GID="$(id -g)" \
  --env IONOS_CREDENTIALS=/certbot/etc/letsencrypt/.secrets/ionos.ini \
  --env 'IONOS_CRONTAB=0 13 * * *' \
  --env 'IONOS_DOMAINS=example.com,*.example.com' \
  --env IONOS_PROPAGATION=300 \
  --env IONOS_EMAIL=admin@example.com \
  --volume "${HOME}/certbot:/certbot" \
  --volume "${HOME}/certbot/etc/letsencrypt/.secrets:/certbot/etc/letsencrypt/.secrets:ro" \
  ghcr.io/deftmartian/docker-certbot-dns-ionos:2026.07.16
```

The credentials mount remains read-only. Certificate state is persisted below
`${HOME}/certbot/etc/letsencrypt`.

## Local development with Compose

The included [compose.yaml](compose.yaml) builds the current checkout so local
changes can be tested before they are published:

```shell
export IONOS_DOMAINS='example.com,*.example.com'
export IONOS_EMAIL='admin@example.com'
docker compose up --build -d
```

This does not pull the obsolete `gmmserv/docker-certbot-dns-ionos:2024.1.8`
image.

## Build arguments

The original build argument interface remains supported. `USER_UID` and
`USER_GID` also work as runtime environment variables, allowing one published
image to serve deployments with different ownership requirements:

| Argument | Default | Purpose |
|---|---|---|
| `IMAGE_VERSION` | `2026.07.16` | Container release version |
| `VERSION` | `2024.11.09` | Upstream `certbot-dns-ionos` package version |
| `CERTBOT_VERSION` | `v5.7.0` | `certbot/certbot` base image tag |
| `USER_UID` | `1000` | Runtime `certbot` UID |
| `USER_GID` | `1000` | Runtime `certbot` GID |

The image also accepts maintenance arguments `SUPERCRONIC_VERSION` and
`GOLANG_VERSION`.

Build directly:

```shell
docker build \
  --build-arg IMAGE_VERSION=2026.07.16 \
  --build-arg VERSION=2024.11.09 \
  --build-arg CERTBOT_VERSION=v5.7.0 \
  --build-arg USER_UID=1000 \
  --build-arg USER_GID=1000 \
  --tag docker-certbot-dns-ionos:2026.07.16 \
  .
```

Or build all supported platforms with Bake:

```shell
IMAGE=ghcr.io/deftmartian/docker-certbot-dns-ionos \
docker buildx bake --file docker-bake.hcl --push
```

## Validation

CI performs ShellCheck and Hadolint linting, builds every supported platform,
runs the scheduler through a real container restart, verifies the process UID
and plugin registration, and fails on fixed High or Critical image
vulnerabilities.

Run the same smoke test locally after building:

```shell
tests/smoke.sh docker-certbot-dns-ionos:2026.07.16
```

Set `CONTAINER_RUNTIME=podman` when using Podman.

## Releasing

The container release and upstream plugin use separate version numbers. To
release the container, update `IMAGE_VERSION` in the Dockerfile, Bake file,
Compose example, README, and changelog. Commit those changes, then push a tag
whose name exactly matches `IMAGE_VERSION`. CI rejects mismatched tags before
publishing and creates the GitHub release from the matching changelog section.

## Credits

- [`certbot/certbot`](https://github.com/certbot/certbot)
- [`helgeerbe/certbot-dns-ionos`](https://github.com/helgeerbe/certbot-dns-ionos)
- [`aptible/supercronic`](https://github.com/aptible/supercronic)
- Original container implementation by
  [`gianmarco-mameli`](https://github.com/gianmarco-mameli/docker-certbot-dns-ionos)
