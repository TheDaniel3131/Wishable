# PocketBase on Fly.io for Wishable (optional sync backend).
#
# PB_VERSION is pinned to match the binary committed under /pocketbase so the
# SQLite data format lines up. Bump it in step with pocketbase/CHANGELOG.md.
FROM alpine:3.20

ARG PB_VERSION=0.40.4

RUN apk add --no-cache ca-certificates unzip wget

# Download the official PocketBase release for linux/amd64 (Fly's default arch).
RUN wget -q https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip \
    && unzip pocketbase_${PB_VERSION}_linux_amd64.zip -d /pb \
    && rm pocketbase_${PB_VERSION}_linux_amd64.zip

EXPOSE 8090

# Bind to all interfaces so Fly's proxy can reach it; persist state to the
# volume mounted at /pb/pb_data (see fly.toml [[mounts]]).
CMD ["/pb/pocketbase", "serve", "--http=0.0.0.0:8090", "--dir=/pb/pb_data"]
