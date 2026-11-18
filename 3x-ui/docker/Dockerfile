FROM ghcr.io/mhsanaei/3x-ui:v3.11.0

ARG ACME_VERSION=3.1.6
RUN apk add --no-cache socat \
    && mkdir -p /opt/acme \
    && curl --fail --show-error --silent --location \
        "https://raw.githubusercontent.com/acmesh-official/acme.sh/${ACME_VERSION}/acme.sh" \
        --output /opt/acme/acme.sh \
    && chmod 755 /opt/acme/acme.sh

COPY --chmod=755 docker/https-entrypoint.sh docker/reload-panel.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/https-entrypoint.sh"]
