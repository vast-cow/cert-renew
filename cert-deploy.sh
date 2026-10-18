#!/usr/bin/env bash
set -Eeuo pipefail

if (( EUID != 0 )); then
    echo "[error] must run as root" >&2
    exit 1
fi

CONFIG_PATH="${CONFIG_PATH:-${STATE_DIRECTORY:?STATE_DIRECTORY is required}/config}"
FLAGFILE="${RUNTIME_DIRECTORY:?RUNTIME_DIRECTORY is required}/renewed"

if [[ ! -f "$FLAGFILE" ]]; then
    echo "[info] no certificate renewal; skip deploy" >&2
    exit 0
fi

echo "[info] deploying renewed certificates" >&2

CERTPATH="$CONFIG_PATH/live/$CERT_NAME"

CONFIG_REAL="$(realpath -e -- "$CONFIG_PATH")"
ARCHIVE_PREFIX="$CONFIG_REAL/archive/$CERT_NAME/"

check_cert_file() {
    local name="$1"
    local source

    source="$(realpath -e -- "$CERTPATH/$name")" \
        || return 1

    [[ "$source" == "$ARCHIVE_PREFIX"* ]] \
        || return 1

    [[ -f "$source" && -s "$source" ]] \
        || return 1

    printf '%s\n' "$source"
}

FULLCHAIN="$(check_cert_file fullchain.pem)" || exit 2
PRIVKEY="$(check_cert_file privkey.pem)" || exit 2
CHAIN="$(check_cert_file chain.pem)" || exit 2

echo "[info] preparing destination directories" >&2

install -d -m 0755 "$NGINX_CERTS"
install -d -m 0755 "$IPSEC_ETC/private"
install -d -m 0755 "$IPSEC_ETC/cacerts"
install -d -m 0755 "$IPSEC_ETC/certs"

echo "[info] installing Nginx certificates" >&2

install -m 0644 \
    "$FULLCHAIN" \
    "$NGINX_CERTS/fullchain.pem"

install -m 0600 \
    "$PRIVKEY" \
    "$NGINX_CERTS/privkey.pem"

echo "[info] installing StrongSwan certificates" >&2

install -m 0600 \
    "$PRIVKEY" \
    "$IPSEC_ETC/private/privkey.pem"

install -m 0644 \
    "$CHAIN" \
    "$IPSEC_ETC/cacerts/chain.pem"

install -m 0644 \
    "$FULLCHAIN" \
    "$IPSEC_ETC/certs/fullchain.pem"

echo "[info] validating Nginx configuration" >&2

nginx -t

echo "[info] restarting Nginx" >&2
systemctl restart nginx

echo "[info] restarting StrongSwan" >&2
systemctl restart strongswan-starter

echo "[info] certificate deployment completed" >&2
