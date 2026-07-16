#!/bin/sh
set -eu

: "${IONOS_CRONTAB:?IONOS_CRONTAB is required}"
: "${IONOS_CREDENTIALS:?IONOS_CREDENTIALS is required}"
: "${IONOS_DOMAINS:?IONOS_DOMAINS is required}"
: "${IONOS_PROPAGATION:?IONOS_PROPAGATION is required}"
: "${IONOS_EMAIL:?IONOS_EMAIL is required}"

case "${IONOS_PROPAGATION}" in
    *[!0-9]*)
        echo "IONOS_PROPAGATION must be a non-negative integer" >&2
        exit 1
        ;;
esac

/certbot_permissions.sh

cron_dir="/tmp/crontabs"
cron_file="${cron_dir}/certbot"

mkdir -p "${cron_dir}"
printf '%s /certbot_script.sh\n' "${IONOS_CRONTAB}" > "${cron_file}"
chown certbot:certbot "${cron_dir}" "${cron_file}"
chmod 0700 "${cron_dir}"
chmod 0600 "${cron_file}"

if ! su-exec certbot test -r "${IONOS_CREDENTIALS}"; then
    echo "IONOS credentials file is not readable by the certbot user: ${IONOS_CREDENTIALS}" >&2
    exit 1
fi

# Fail at startup rather than silently running with a malformed schedule.
su-exec certbot /usr/local/bin/supercronic -test "${cron_file}"

printf 'time="%s" level=info msg="docker-certbot-dns-ionos %s started"\n' \
    "$(date -Is || true)" "${IONOS_VERSION}"
printf 'time="%s" level=info msg="starting %s as certbot"\n' \
    "$(date -Is || true)" "$*"

exec su-exec certbot "$@"
