#!/usr/bin/env bash
set -Eeuo pipefail
if (( EUID != 0 )); then
    echo '[error] must run as root' >&2
    exit 1
fi
systemctl disable --now certbot-renew.timer
systemctl stop certbot-renew.service
rm -f /etc/systemd/system/certbot-renew.service /etc/systemd/system/certbot-renew.timer
rm -f /usr/libexec/certbot-renewal/update-certbot.sh /usr/libexec/certbot-renewal/certbot-renew.sh /usr/libexec/certbot-renewal/certbot-deploy.sh
systemctl daemon-reload
echo '[info] configuration, venv, certificates and logs retained' >&2
