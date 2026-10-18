#!/usr/bin/env bash
set -Eeuo pipefail
if (( EUID != 0 )); then
    echo '[error] must run as root' >&2
    exit 1
fi
systemctl disable --now cert-renew.timer
systemctl stop cert-renew.service
rm -f /etc/systemd/system/cert-renew.service /etc/systemd/system/cert-renew.timer
rm -f /usr/libexec/certbot-renewal/update-certbot.sh /usr/libexec/certbot-renewal/update-acme.sh /usr/libexec/certbot-renewal/cert-renew.sh /usr/libexec/certbot-renewal/cert-deploy.sh
systemctl daemon-reload
echo '[info] configuration, cached clients, certificates and logs retained' >&2
