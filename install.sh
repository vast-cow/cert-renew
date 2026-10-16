#!/usr/bin/env bash
set -Eeuo pipefail
if (( EUID != 0 )); then
    echo '[error] must run as root' >&2
    exit 1
fi
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for dependency in python3 ip jq upnpc nginx systemctl install; do
    command -v "$dependency" >/dev/null || { echo "[error] missing $dependency" >&2; exit 1; }
done
if [[ ! -f /etc/certbot-renewal/certbot.env && ! -f "$SOURCE_DIR/certbot.env" ]]; then
    echo '[error] copy certbot.env.example to certbot.env and configure it first' >&2
    exit 1
fi
install -d -o root -g root -m 0755 /usr/libexec/certbot-renewal
install -d -o root -g root -m 0700 /etc/certbot-renewal
for script in update-certbot.sh certbot-renew.sh certbot-deploy.sh; do
    install -o root -g root -m 0755 "$SOURCE_DIR/$script" /usr/libexec/certbot-renewal/
done
if [[ ! -f /etc/certbot-renewal/certbot.env ]]; then
    install -o root -g root -m 0600 "$SOURCE_DIR/certbot.env" /etc/certbot-renewal/certbot.env
fi
for unit in certbot-renew.service certbot-renew.timer; do
    install -o root -g root -m 0644 "$SOURCE_DIR/$unit" /etc/systemd/system/
done
systemctl daemon-reload
systemctl enable --now certbot-renew.timer
