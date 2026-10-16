#!/usr/bin/env bash
set -Eeuo pipefail

if (( EUID == 0 )); then
    echo "[error] must run as non-root" >&2
    exit 1
fi

# Paths default to directories managed by systemd.
CONFIG_PATH="${CONFIG_PATH:-${STATE_DIRECTORY:?STATE_DIRECTORY is required}/config}"
WORK_DIR="${WORK_DIR:-${RUNTIME_DIRECTORY:?RUNTIME_DIRECTORY is required}/work}"
LOGS_DIR="${LOGS_DIR:-${LOGS_DIRECTORY:?LOGS_DIRECTORY is required}}"
WEB_ROOT="${WEB_ROOT:-${RUNTIME_DIRECTORY:?RUNTIME_DIRECTORY is required}/webroot}"
FLAGFILE="${RUNTIME_DIRECTORY:?RUNTIME_DIRECTORY is required}/renewed"

# Prepare writable runtime directories.
install -d -m 0700 "$WORK_DIR"
install -d -m 0755 "$WEB_ROOT"

echo "[info] detecting local IP address" >&2

local_ip="$(
    ip -j route get 1.1.1.1 |
        jq -r '.[0].prefsrc // empty'
)"

if [[ -z "$local_ip" ]]; then
    echo "[error] failed to detect local IP" >&2
    exit 1
fi

echo "[info] local IP: $local_ip" >&2

mapping_attempted=0

cleanup() {
    if (( mapping_attempted )); then
        echo "[info] closing UPnP port" >&2
        upnpc -d 80 tcp || true
    fi
}

trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

echo "[info] opening UPnP port" >&2

# WAN:80 -> LAN:80, lease: 600 seconds
mapping_attempted=1
upnpc -a "$local_ip" 80 80 tcp 600

echo "[info] running Certbot" >&2

"$CERTBOT_VENV/bin/certbot" \
    certonly \
    --non-interactive \
    --quiet \
    --webroot \
    -w "$WEB_ROOT" \
    --cert-name "$CERT_NAME" \
    --key-type rsa \
    --rsa-key-size 4096 \
    -d "$DOMAINLIST" \
    --agree-tos \
    --no-eff-email \
    --email "$EMAIL" \
    --deploy-hook "/usr/bin/touch $FLAGFILE" \
    --config-dir "$CONFIG_PATH" \
    --work-dir "$WORK_DIR" \
    --logs-dir "$LOGS_DIR"

echo "[info] Certbot completed successfully" >&2
