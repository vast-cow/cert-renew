#!/usr/bin/env bash
set -Eeuo pipefail

if (( EUID == 0 )); then
    echo "[error] must run as non-root" >&2
    exit 1
fi

# Paths default to directories managed by systemd.
ACME_HOME="${CACHE_DIRECTORY:?CACHE_DIRECTORY is required}/acme.sh"
CONFIG_PATH="${CONFIG_PATH:-${STATE_DIRECTORY:?STATE_DIRECTORY is required}/acme}"
LOGS_DIR="${LOGS_DIR:-${LOGS_DIRECTORY:?LOGS_DIRECTORY is required}}"
WEB_ROOT="${WEB_ROOT:-${RUNTIME_DIRECTORY:?RUNTIME_DIRECTORY is required}/webroot}"
FLAGFILE="${RUNTIME_DIRECTORY:?RUNTIME_DIRECTORY is required}/renewed"
PENDING="${STATE_DIRECTORY}/acme-deploy-pending"
STAGING="${STATE_DIRECTORY}/acme-deploy"

# Certbot certificate names are retained for configuration compatibility only.
[[ "$DOMAINLIST" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] || {
    echo "[error] DOMAINLIST must contain one DNS name" >&2
    exit 1
}
rm -f -- "$FLAGFILE"
install -d -m 0700 "$CONFIG_PATH" "$STAGING" "$LOGS_DIR"
common=(--home "$ACME_HOME" --config-home "$CONFIG_PATH"
        --server letsencrypt --log "$LOGS_DIR/acme.sh.log")

# Prepare writable runtime directories.
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

echo "[info] running acme.sh" >&2

status=0
"$ACME_HOME/acme.sh" "${common[@]}" --issue \
    --webroot "$WEB_ROOT" --domain "$DOMAINLIST" \
    --keylength 4096 --accountemail "$EMAIL" || status=$?
# acme.sh returns 2 when the certificate is not due for renewal.
if (( status != 0 && status != 2 )); then
    exit "$status"
fi

# Mark pending before copying, so failed installation/deployment is retried.
if (( status == 0 )); then
    touch "$PENDING"
fi
if [[ -f "$PENDING" || ! -s "$STAGING/fullchain.pem" ]]; then
    touch "$PENDING"
    "$ACME_HOME/acme.sh" "${common[@]}" --install-cert \
        --domain "$DOMAINLIST" \
        --fullchain-file "$STAGING/fullchain.pem" \
        --key-file "$STAGING/privkey.pem" \
        --ca-file "$STAGING/chain.pem"
    touch "$FLAGFILE"
fi

echo "[info] acme.sh completed successfully" >&2
