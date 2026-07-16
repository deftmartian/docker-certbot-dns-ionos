#!/bin/sh
set -eu

image=${1:-docker-certbot-dns-ionos:test}
container_runtime=${CONTAINER_RUNTIME:-docker}
expected_uid=${EXPECTED_UID:-1000}
expected_gid=${EXPECTED_GID:-${expected_uid}}
container_name="certbot-ionos-smoke-$$"
test_dir=$(mktemp -d)
certbot_dir="${test_dir}/certbot"
secrets_dir="${test_dir}/secrets"

cleanup() {
    "${container_runtime}" rm -f "${container_name}" >/dev/null 2>&1 || true

    restore_uid=$(id -u)
    restore_gid=$(id -g)
    if [ "${container_runtime}" = "podman" ] && \
        [ "$(podman info --format '{{.Host.Security.Rootless}}')" = "true" ]; then
        restore_uid=0
        restore_gid=0
    fi

    "${container_runtime}" run --rm \
        --entrypoint chown \
        --volume "${test_dir}:/cleanup:Z" \
        "${image}" \
        -R "${restore_uid}:${restore_gid}" /cleanup >/dev/null 2>&1 || true
    rm -rf "${test_dir}"
}
trap cleanup EXIT INT TERM

mkdir -p "${certbot_dir}" "${secrets_dir}"
cat > "${secrets_dir}/ionos.ini" <<'EOF'
dns_ionos_prefix = smoke-test
dns_ionos_secret = smoke-test
dns_ionos_endpoint = https://api.hosting.ionos.com
EOF
# This is fake test data. Production credentials should instead be mode 0600
# and owned by the configured certbot UID.
chmod 0644 "${secrets_dir}/ionos.ini"

"${container_runtime}" run --detach \
    --name "${container_name}" \
    --env IONOS_CREDENTIALS=/certbot/etc/letsencrypt/.secrets/ionos.ini \
    --env 'IONOS_CRONTAB=0 0 1 1 *' \
    --env IONOS_DOMAINS=smoke-test.example \
    --env IONOS_PROPAGATION=60 \
    --env IONOS_EMAIL=smoke-test@example.com \
    --env USER_UID="${expected_uid}" \
    --env USER_GID="${expected_gid}" \
    --volume "${certbot_dir}:/certbot:Z" \
    --volume "${secrets_dir}:/certbot/etc/letsencrypt/.secrets:ro,Z" \
    "${image}" >/dev/null

sleep 2

if [ "$("${container_runtime}" inspect --format '{{.State.Running}}' "${container_name}")" != "true" ]; then
    echo "container stopped during startup" >&2
    "${container_runtime}" logs "${container_name}" >&2
    exit 1
fi

# The awk expression runs inside the container; its $2 is not a shell variable.
# shellcheck disable=SC2016
actual_uid=$("${container_runtime}" exec "${container_name}" \
    awk '/^Uid:/{print $2}' /proc/1/status)
if [ "${actual_uid}" != "${expected_uid}" ]; then
    echo "scheduler runs as UID ${actual_uid}; expected ${expected_uid}" >&2
    exit 1
fi

# shellcheck disable=SC2016
actual_gid=$("${container_runtime}" exec "${container_name}" \
    awk '/^Gid:/{print $2}' /proc/1/status)
if [ "${actual_gid}" != "${expected_gid}" ]; then
    echo "scheduler runs as GID ${actual_gid}; expected ${expected_gid}" >&2
    exit 1
fi

cron_lines=$("${container_runtime}" exec "${container_name}" \
    sh -c 'wc -l < /tmp/crontabs/certbot')
if [ "${cron_lines}" -ne 1 ]; then
    echo "expected one cron entry before restart; found ${cron_lines}" >&2
    exit 1
fi

"${container_runtime}" restart "${container_name}" >/dev/null
sleep 2

cron_lines=$("${container_runtime}" exec "${container_name}" \
    sh -c 'wc -l < /tmp/crontabs/certbot')
if [ "${cron_lines}" -ne 1 ]; then
    echo "expected one cron entry after restart; found ${cron_lines}" >&2
    exit 1
fi

if ! "${container_runtime}" exec --user "${expected_uid}:${expected_gid}" \
    "${container_name}" sh -c "ps | grep -q '[s]upercronic'"; then
    echo "supercronic is not visible to the image healthcheck" >&2
    "${container_runtime}" exec "${container_name}" ps >&2 || true
    "${container_runtime}" logs "${container_name}" >&2
    exit 1
fi

"${container_runtime}" exec --user "${expected_uid}:${expected_gid}" \
    "${container_name}" certbot --version
"${container_runtime}" exec --user "${expected_uid}:${expected_gid}" \
    "${container_name}" certbot plugins | grep -q dns-ionos
"${container_runtime}" exec --user "${expected_uid}:${expected_gid}" \
    "${container_name}" pip check
"${container_runtime}" exec --user "${expected_uid}:${expected_gid}" \
    "${container_name}" supercronic -version

echo "smoke test passed for ${image}"
