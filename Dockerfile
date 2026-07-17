ARG GOLANG_VERSION=1.26.5-alpine
ARG CERTBOT_VERSION=v5.7.0
ARG SUPERCRONIC_VERSION=v0.2.47

FROM golang:${GOLANG_VERSION} AS supercronic-builder

ARG SUPERCRONIC_VERSION

# Build Supercronic with the patched Go toolchain rather than shipping the
# upstream release binary, which was built with an older Go standard library.
RUN CGO_ENABLED=0 GOBIN=/out \
    go install -ldflags "-X main.Version=${SUPERCRONIC_VERSION}" \
    "github.com/aptible/supercronic@${SUPERCRONIC_VERSION}"

FROM certbot/certbot:${CERTBOT_VERSION}

ARG CERTBOT_VERSION
ARG SUPERCRONIC_VERSION
ARG VERSION=2024.11.09
ARG USER_UID=1000
ARG USER_GID=1000

LABEL org.opencontainers.image.url="https://github.com/deftmartian/docker-certbot-dns-ionos" \
      org.opencontainers.image.source="https://github.com/deftmartian/docker-certbot-dns-ionos" \
      org.opencontainers.image.base.name="certbot/certbot:${CERTBOT_VERSION}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.description="Scheduled Certbot renewals using the IONOS DNS authenticator"

ENV IONOS_VERSION="${VERSION}" \
    SUPERCRONIC_VERSION="${SUPERCRONIC_VERSION}" \
    USERNAME="certbot" \
    USER_UID="${USER_UID}" \
    USER_GID="${USER_GID}" \
    HOME="/certbot" \
    CERTBOT_BASE_DIR="/certbot" \
    CERTBOT_CONFIG_DIR="/certbot/etc/letsencrypt" \
    CERTBOT_LIVE_DIR="/certbot/etc/letsencrypt/live" \
    CERTBOT_ARCHIVE_DIR="/certbot/etc/letsencrypt/archive" \
    CERTBOT_LOGS_DIR="/certbot/var/log/letsencrypt" \
    CERTBOT_WORK_DIR="/certbot/var/lib/letsencrypt"

# hadolint ignore=DL3018
RUN set -eux; \
    apk add --no-cache su-exec; \
    mkdir -p "${CERTBOT_BASE_DIR}"; \
    addgroup -g "${USER_GID}" -S "${USERNAME}"; \
    adduser -u "${USER_UID}" -S "${USERNAME}" -G "${USERNAME}" -h "${CERTBOT_BASE_DIR}"; \
    chown "${USERNAME}:${USERNAME}" "${CERTBOT_BASE_DIR}"

COPY --from=supercronic-builder /out/supercronic /usr/local/bin/supercronic

RUN pip install --no-cache-dir "certbot-dns-ionos==${VERSION}"

COPY scripts/*.sh /

RUN set -eux; \
    chmod 0555 /*.sh /usr/local/bin/supercronic; \
    mkdir -p \
        "${CERTBOT_LIVE_DIR}" \
        "${CERTBOT_ARCHIVE_DIR}" \
        "${CERTBOT_LOGS_DIR}" \
        "${CERTBOT_WORK_DIR}" \
        /tmp/crontabs; \
    chown -R "${USERNAME}:${USERNAME}" "${CERTBOT_BASE_DIR}" /tmp/crontabs

WORKDIR ${CERTBOT_BASE_DIR}

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["sh", "-c", "ps | grep -q '[s]upercronic'"]

STOPSIGNAL SIGTERM

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/local/bin/supercronic", "-passthrough-logs", "/tmp/crontabs/certbot"]
