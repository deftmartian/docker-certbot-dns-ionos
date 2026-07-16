#!/bin/sh
set -eu

: "${IONOS_CREDENTIALS:?IONOS_CREDENTIALS is required}"
: "${IONOS_DOMAINS:?IONOS_DOMAINS is required}"
: "${IONOS_PROPAGATION:?IONOS_PROPAGATION is required}"
: "${IONOS_EMAIL:?IONOS_EMAIL is required}"

if [ ! -r "${IONOS_CREDENTIALS}" ]; then
    echo "IONOS credentials file is not readable: ${IONOS_CREDENTIALS}" >&2
    exit 1
fi

set -- \
    /usr/local/bin/certbot certonly \
    --config-dir "${CERTBOT_CONFIG_DIR}" \
    --logs-dir "${CERTBOT_LOGS_DIR}" \
    --work-dir "${CERTBOT_WORK_DIR}" \
    --authenticator dns-ionos \
    --dns-ionos-credentials "${IONOS_CREDENTIALS}" \
    --dns-ionos-propagation-seconds "${IONOS_PROPAGATION}" \
    --non-interactive \
    --keep-until-expiring \
    --expand \
    --agree-tos \
    --email "${IONOS_EMAIL}" \
    --rsa-key-size 4096

domain_count=0
old_ifs=${IFS}
IFS=,
set -f
for domain in ${IONOS_DOMAINS}; do
    case "${domain}" in
        ""|-*|*[!A-Za-z0-9._*-]*)
            echo "Invalid domain in IONOS_DOMAINS: ${domain}" >&2
            exit 1
            ;;
    esac

    set -- "$@" -d "${domain}"
    domain_count=$((domain_count + 1))
done
set +f
IFS=${old_ifs}

if [ "${domain_count}" -eq 0 ]; then
    echo "IONOS_DOMAINS does not contain a domain" >&2
    exit 1
fi

# IONOS_ARGS is retained for compatibility with the existing Authentik and
# MQTT definitions. It is parsed as whitespace-separated arguments; shell
# evaluation and pathname expansion are intentionally disabled.
if [ -n "${IONOS_ARGS:-}" ]; then
    set -f
    # shellcheck disable=SC2086
    set -- "$@" ${IONOS_ARGS}
    set +f
fi

exec "$@"
