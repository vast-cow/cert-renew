# Cert Renew

acme.sh and UPnP run under systemd DynamicUser. The dynamic user bootstraps acme.sh in systemd's cache directory once, then runs the cached client's `--upgrade` option before each renewal. Upstream checks for updates and downloads the package when needed. Root deploys certificates to Nginx and StrongSwan afterward. The persistent timer runs twice daily with up to an hour of random delay.

The systemd units are `cert-renew.service` and `cert-renew.timer`. Existing `certbot-renewal` directory paths are retained to preserve configuration and certificate state. No Certbot or Python environment is used.

## Setup

Requires Linux with systemd, Bash, POSIX sh, curl, tar, gzip, OpenSSL, coreutils, iproute2, jq, miniupnpc, Nginx and StrongSwan (`strongswan-starter`). Public DNS must resolve to your router, which must support UPnP and forward public TCP port 80 to this host. The mapping must be dedicated to this process: cleanup deletes it.

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
cp cert.env.example cert.env
# Edit cert.env for your domain, email and destination paths.
sudo ./install.sh
sudo systemctl start cert-renew.service
sudo journalctl -u cert-renew.service -n 100 --no-pager
systemctl list-timers cert-renew.timer
```

The installer enables the timer immediately; a missed schedule can trigger a prompt run. Prepare networking and Nginx first. Existing installed configuration is preserved on reinstall. Edit `/etc/certbot-renewal/cert.env` to change it. `DOMAINLIST` supports one DNS name. acme.sh uses Let's Encrypt explicitly and requests RSA 4096-bit keys. Using this automation implies acceptance of the CA's subscriber agreement.

Configure Nginx TLS to use `/etc/nginx/pki/certs/fullchain.pem` and `/etc/nginx/pki/certs/privkey.pem`, and StrongSwan to use the deployed files under `/etc/ipsec.d`, adjusting for configured destination overrides. Scripts, configuration and deployment destinations must remain root-owned and unwritable by the renewal user.

Systemd manages the client at `$CACHE_DIRECTORY/acme.sh/acme.sh`, private account and certificate state at `$STATE_DIRECTORY/acme`, deployment staging at `$STATE_DIRECTORY/acme-deploy`, logs under `/var/log/certbot-renewal`, and transient webroot and renewal flag under `/run/certbot-renewal`. The client cache can be recreated without losing certificate state. The upstream upgrade installs the client and bundled hooks in the cache, with cron and shell profile setup disabled. Custom writable paths require appropriate systemd sandbox access and Nginx changes if overriding WEB_ROOT.

The client checks whether issuance is due. Exit status 2 means renewal was skipped; other failures stop deployment. Certificates are exported with acme.sh's `--install-cert` interface instead of reading its internal storage. A persistent pending marker ensures a failed export or deployment is retried on the next successful run, even when renewal is skipped. The marker is cleared only after deployment and both service restarts succeed. Unchanged certificates normally cause no deployment or restarts.

## Migration from the previous unit names

Before reinstalling, disable and stop the old units:

```sh
sudo systemctl disable --now certbot-renew.timer
sudo systemctl stop certbot-renew.service
sudo rm -f /etc/systemd/system/certbot-renew.service /etc/systemd/system/certbot-renew.timer
```

Then rerun `install.sh`. It installs and enables `cert-renew.timer` and copies an existing `/etc/certbot-renewal/certbot.env` to `cert.env` if the new file is absent. State and cache directories retain their existing paths. Rename any local `certbot.env` to `cert.env` for future installs, and update monitoring or commands that use the old unit names.

## Migration from Certbot

Back up existing state and deployed certificates, stop the service, then rerun `install.sh` and start the service. The installer replaces the old updater. Existing Certbot account data, certificates and cached virtual environments are retained; they are not imported. The first acme.sh run creates its own account and requests a new certificate, so CA issuance limits apply. Existing deployed certificates remain in use until issuance and deployment succeed.

Remove an old `CONFIG_PATH` override, or set it to a separate empty directory for acme.sh. `CERT_NAME`, `CERTBOT_VENV` and `WORK_DIR` are no longer used. Stop any independently configured Certbot timers to avoid duplicate renewals.

## Validation and removal

```sh
bash -n cert-renew.sh cert-deploy.sh update-acme.sh install.sh uninstall.sh
sudo systemd-analyze verify /etc/systemd/system/cert-renew.service /etc/systemd/system/cert-renew.timer
sudo ./uninstall.sh
```

Uninstall stops the timer and service and removes installed scripts and units. Configuration, cached clients, certificates, account data, logs and deployed files are retained.

Client bootstrap or upgrade failure prevents renewal. Downloads use HTTPS from the [official acme.sh repository](https://github.com/acmesh-official/acme.sh), tracking its master branch. UPnP cleanup is best effort, with a 600-second router lease. Deployment checks resolved staging paths and nonempty files, without race-proof reads, cryptographic verification or rollback. Nginx configuration is tested after copies and before restarting services. Monitor renewal failures and certificate expiry independently.
