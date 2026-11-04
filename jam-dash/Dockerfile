# Pinned multi-arch Home Assistant base image (Alpine 3.24, s6-overlay v3, bashio).
FROM ghcr.io/home-assistant/base:3.24-2026.10.3

ARG BUILD_VERSION=0.1.0

RUN apk add --no-cache nginx \
    && mkdir -p /run/nginx /var/lib/nginx/tmp

COPY nginx.conf.tmpl render.sh run.sh /opt/jam-dash/
RUN chmod a+x /opt/jam-dash/render.sh /opt/jam-dash/run.sh

LABEL \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.type="app" \
    io.hass.arch="aarch64|amd64" \
    io.hass.name="Jam-Dash" \
    io.hass.description="Open your Jam-Dash dashboard inside Home Assistant." \
    io.hass.url="https://github.com/Starkkaman/jam-dash-ha" \
    org.opencontainers.image.source="https://github.com/Starkkaman/jam-dash-ha"

CMD [ "/opt/jam-dash/run.sh" ]
