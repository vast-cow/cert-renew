#!/usr/bin/env bash
set -Eeuo pipefail
if (( EUID != 0 )); then
    echo '[error] must run as root' >&2
    exit 1
fi
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for dependency in curl openssl sh ip jq upnpc nginx systemctl install realpath mktemp; do
    command -v "$dependency" >/dev/null || { echo "[error] missing $dependency" >&2; exit 1; }
done
if [[ ! -f /etc/certbot-renewal/cert.env && ! -f /etc/certbot-renewal/certbot.env && ! -f "$SOURCE_DIR/cert.env" ]]; then
    echo '[error] copy cert.env.example to cert.env and configure it first' >&2
    exit 1
fi
install -d -o root -g root -m 0755 /usr/libexec/certbot-renewal
install -d -o root -g root -m 0700 /etc/certbot-renewal
for script in update-acme.sh cert-renew.sh cert-deploy.sh; do
    install -o root -g root -m 0755 "$SOURCE_DIR/$script" /usr/libexec/certbot-renewal/
done
if [[ ! -f /etc/certbot-renewal/cert.env ]]; then
    if [[ -f /etc/certbot-renewal/certbot.env ]]; then
        install -o root -g root -m 0600 /etc/certbot-renewal/certbot.env /etc/certbot-renewal/cert.env
    else
        install -o root -g root -m 0600 "$SOURCE_DIR/cert.env" /etc/certbot-renewal/cert.env
    fi
fi
for unit in cert-renew.service cert-renew.timer; do
    install -o root -g root -m 0644 "$SOURCE_DIR/$unit" /etc/systemd/system/
done
rm -f /usr/libexec/certbot-renewal/update-certbot.sh
systemctl daemon-reload
systemctl enable --now cert-renew.timer
