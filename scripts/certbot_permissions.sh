#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "certbot_permissions.sh must run as root" >&2
    exit 1
fi

certbot_uid=${1:?certbot UID is required}
certbot_gid=${2:?certbot GID is required}

for runtime_id in "${certbot_uid}" "${certbot_gid}"; do
    case "${runtime_id}" in
        ""|*[!0-9]*)
            echo "certbot UID and GID must be positive integers" >&2
            exit 1
            ;;
    esac
    if [ "${runtime_id}" -eq 0 ]; then
        echo "certbot UID and GID must be greater than zero" >&2
        exit 1
    fi
done

certbot_owner="${certbot_uid}:${certbot_gid}"

# These paths are deliberately fixed. This script runs before privileges are
# dropped and must not accept path overrides from the container environment.
certbot_base_dir="/certbot"
certbot_config_dir="${certbot_base_dir}/etc/letsencrypt"
certbot_live_dir="${certbot_config_dir}/live"
certbot_archive_dir="${certbot_config_dir}/archive"
certbot_logs_dir="${certbot_base_dir}/var/log/letsencrypt"
certbot_work_dir="${certbot_base_dir}/var/lib/letsencrypt"
certbot_secrets_dir="${certbot_config_dir}/.secrets"

mkdir -p \
    "${certbot_live_dir}" \
    "${certbot_archive_dir}" \
    "${certbot_logs_dir}" \
    "${certbot_work_dir}"

chown "${certbot_owner}" "${certbot_base_dir}"

# Existing certificate volumes may come from an older image or a different
# UID. Do not traverse the read-only credentials mount while repairing them.
find "${certbot_config_dir}" \
    -path "${certbot_secrets_dir}" -prune -o \
    -exec chown -h "${certbot_owner}" {} \;

chown -hR "${certbot_owner}" \
    "${certbot_logs_dir}" \
    "${certbot_work_dir}"

chmod 0755 "${certbot_live_dir}" "${certbot_archive_dir}"
