#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "certbot_permissions.sh must run as root" >&2
    exit 1
fi

# These paths are deliberately fixed. This script runs before privileges are
# dropped and must not accept path overrides from the container environment.
certbot_user="certbot"
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

chown "${certbot_user}:${certbot_user}" "${certbot_base_dir}"

# Existing certificate volumes may come from an older image or a different
# UID. Do not traverse the read-only credentials mount while repairing them.
find "${certbot_config_dir}" \
    -path "${certbot_secrets_dir}" -prune -o \
    -exec chown -h "${certbot_user}:${certbot_user}" {} \;

chown -hR "${certbot_user}:${certbot_user}" \
    "${certbot_logs_dir}" \
    "${certbot_work_dir}"

chmod 0755 "${certbot_live_dir}" "${certbot_archive_dir}"
