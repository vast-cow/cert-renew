# acme.sh renewal

acme.sh and UPnP run under systemd DynamicUser. Before each run, the dynamic user downloads the current upstream acme.sh script into systemd's cache directory. Root deploys certificates to Nginx and StrongSwan afterward. The persistent timer runs twice daily with up to an hour of random delay.

The existing `certbot-renew` unit names, script names and configuration path remain for compatibility. No Certbot or Python environment is used.

## Setup

Requires Linux with systemd, Bash, POSIX sh, curl, OpenSSL, coreutils, iproute2, jq, miniupnpc, Nginx and StrongSwan (`strongswan-starter`). Public DNS must resolve to your router, which must support UPnP and forward public TCP port 80 to this host. The mapping must be dedicated to this process: cleanup deletes it.

Configure Nginx to serve HTTP challenges before installing:

```nginx
server {
    listen 80;
    server_name example.com;
    location ^~ /.well-known/acme-challenge/ {
        root /run/certbot-renewal/webroot;
        default_type text/plain;
        try_files $uri =404;
    }
}
```

Replace example.com with your domain. Keep redirects outside the challenge location. Do not enable TLS configuration referencing nonexistent certificates before first issuance.

```sh
cp certbot.env.example certbot.env
# Edit certbot.env for your domain, email and destination paths.
sudo ./install.sh
sudo systemctl start certbot-renew.service
sudo journalctl -u certbot-renew.service -n 100 --no-pager
systemctl list-timers certbot-renew.timer
```

The installer enables the timer immediately; a missed schedule can trigger a prompt run. Prepare networking and Nginx first. Existing installed configuration is preserved on reinstall. Edit `/etc/certbot-renewal/certbot.env` to change it. `DOMAINLIST` supports one DNS name. acme.sh uses Let's Encrypt explicitly and requests RSA 4096-bit keys. Using this automation implies acceptance of the CA's subscriber agreement.

Configure Nginx TLS to use `/etc/nginx/pki/certs/fullchain.pem` and `/etc/nginx/pki/certs/privkey.pem`, and StrongSwan to use the deployed files under `/etc/ipsec.d`, adjusting for configured destination overrides. Scripts, configuration and deployment destinations must remain root-owned and unwritable by the renewal user.

Systemd manages the client at `$CACHE_DIRECTORY/acme.sh/acme.sh`, private account and certificate state at `$STATE_DIRECTORY/acme`, deployment staging at `$STATE_DIRECTORY/acme-deploy`, logs under `/var/log/certbot-renewal`, and transient webroot and renewal flag under `/run/certbot-renewal`. The client cache can be recreated without losing certificate state. No acme.sh installer, shell profile changes or separate cron job is used. Custom writable paths require appropriate systemd sandbox access and Nginx changes if overriding WEB_ROOT.

The client checks whether issuance is due. Exit status 2 means renewal was skipped; other failures stop deployment. Certificates are exported with acme.sh's `--install-cert` interface instead of reading its internal storage. A persistent pending marker ensures a failed export or deployment is retried on the next successful run, even when renewal is skipped. The marker is cleared only after deployment and both service restarts succeed. Unchanged certificates normally cause no deployment or restarts.

## Migration from Certbot

Back up existing state and deployed certificates, stop the service, then rerun `install.sh` and start the service. The installer replaces the old updater. Existing Certbot account data, certificates and cached virtual environments are retained; they are not imported. The first acme.sh run creates its own account and requests a new certificate, so CA issuance limits apply. Existing deployed certificates remain in use until issuance and deployment succeed.

Remove an old `CONFIG_PATH` override, or set it to a separate empty directory for acme.sh. `CERT_NAME`, `CERTBOT_VENV` and `WORK_DIR` are no longer used. Stop any independently configured Certbot timers to avoid duplicate renewals.

## Validation and removal

```sh
bash -n certbot-renew.sh certbot-deploy.sh update-acme.sh install.sh uninstall.sh
sudo systemd-analyze verify /etc/systemd/system/certbot-renew.service /etc/systemd/system/certbot-renew.timer
sudo ./uninstall.sh
```

Uninstall stops the timer and service and removes installed scripts and units. Configuration, cached clients, certificates, account data, logs and deployed files are retained.

Client download failure prevents renewal. Downloads use HTTPS from the [official acme.sh repository](https://github.com/acmesh-official/acme.sh), tracking its master branch. UPnP cleanup is best effort, with a 600-second router lease. Deployment checks resolved staging paths and nonempty files, without race-proof reads, cryptographic verification or rollback. Nginx configuration is tested after copies and before restarting services. Monitor renewal failures and certificate expiry independently.
