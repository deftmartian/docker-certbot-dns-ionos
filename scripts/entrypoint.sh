#!/bin/sh
set -eu

: "${IONOS_CRONTAB:?IONOS_CRONTAB is required}"
: "${IONOS_CREDENTIALS:?IONOS_CREDENTIALS is required}"
: "${IONOS_DOMAINS:?IONOS_DOMAINS is required}"
: "${IONOS_PROPAGATION:?IONOS_PROPAGATION is required}"
: "${IONOS_EMAIL:?IONOS_EMAIL is required}"
: "${USER_UID:?USER_UID is required}"
: "${USER_GID:?USER_GID is required}"

case "${IONOS_PROPAGATION}" in
    *[!0-9]*)
        echo "IONOS_PROPAGATION must be a non-negative integer" >&2
        exit 1
        ;;
esac

validate_runtime_id() {
    runtime_id_name=$1
    runtime_id=$2

    case "${runtime_id}" in
        ""|*[!0-9]*)
            echo "${runtime_id_name} must be a positive integer" >&2
            exit 1
            ;;
    esac
    if [ "${runtime_id}" -eq 0 ]; then
        echo "${runtime_id_name} must be greater than zero" >&2
        exit 1
    fi
}

validate_runtime_id USER_UID "${USER_UID}"
validate_runtime_id USER_GID "${USER_GID}"
runtime_user="${USER_UID}:${USER_GID}"

/certbot_permissions.sh "${USER_UID}" "${USER_GID}"

cron_dir="/tmp/crontabs"
cron_file="${cron_dir}/certbot"

mkdir -p "${cron_dir}"
printf '%s /certbot_script.sh\n' "${IONOS_CRONTAB}" > "${cron_file}"
chown "${runtime_user}" "${cron_dir}" "${cron_file}"
chmod 0700 "${cron_dir}"
chmod 0600 "${cron_file}"

if ! su-exec "${runtime_user}" test -r "${IONOS_CREDENTIALS}"; then
    echo "IONOS credentials file is not readable by the certbot user: ${IONOS_CREDENTIALS}" >&2
    exit 1
fi

# Fail at startup rather than silently running with a malformed schedule.
su-exec "${runtime_user}" /usr/local/bin/supercronic -test "${cron_file}"

printf 'time="%s" level=info msg="docker-certbot-dns-ionos %s started"\n' \
    "$(date -Is || true)" "${IONOS_VERSION}"
printf 'time="%s" level=info msg="starting %s as UID:GID %s"\n' \
    "$(date -Is || true)" "$*" "${runtime_user}"

exec su-exec "${runtime_user}" "$@"
