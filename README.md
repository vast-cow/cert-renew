# Certbot renewal

Implements [the systemd/Certbot privilege separation article](https://github.com/vast-cow/en/blob/posts/posts/20260119-Automating%20TLS%20Certificate%20Renewal%20with%20systemd%20and%20%60certbot%60%20with%20Strong%20Privilege%20Separation.md).

Certbot and UPnP run under systemd DynamicUser. Root updates the dedicated Python environment before renewal and deploys updated certificates to Nginx and StrongSwan afterward. The persistent timer runs twice daily with up to an hour of random delay.

## Setup

Requires Linux with systemd, Bash, Python 3 with venv/ensurepip, coreutils, iproute2, jq, miniupnpc, Nginx and StrongSwan (`strongswan-starter`). Optional uv takes precedence over pip. Public DNS must resolve to your router, which must support UPnP and forward public TCP port 80 to this host. The port mapping must be dedicated to this process: cleanup deletes it.

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

Replace example.com with your domain. Keep redirects outside the challenge location. The runtime webroot follows the article's code; its prose contradicts this by suggesting private state storage, which Nginx cannot traverse. Do not enable TLS configuration referencing nonexistent certificates before first issuance.

```sh
cp certbot.env.example certbot.env
# Edit certbot.env for your domain, email and destination paths.
sudo ./install.sh
sudo systemctl start certbot-renew.service
sudo journalctl -u certbot-renew.service -n 100 --no-pager
systemctl list-timers certbot-renew.timer
```

The installer enables the timer immediately; a missed schedule can trigger a prompt run. Prepare networking and Nginx first. Existing installed configuration is preserved on reinstall. Edit `/etc/certbot-renewal/certbot.env` to change it. `DOMAINLIST` supports a single domain.

Configure Nginx TLS to use `/etc/nginx/pki/certs/fullchain.pem` and `/etc/nginx/pki/certs/privkey.pem`, and StrongSwan to use the deployed files under `/etc/ipsec.d`, adjusting for configured destination overrides. Scripts, configuration, virtual environment and deployment destinations must remain root-owned and unwritable by the renewal user.

Systemd manages private persistent state under `/var/lib/certbot-renewal`, logs under `/var/log/certbot-renewal`, and transient work, webroot and renewal flag under `/run/certbot-renewal`. Avoid manually assigning these directories to a fixed user. Custom writable paths require appropriate systemd sandbox access and Nginx changes if overriding WEB_ROOT.

## Validation and removal

```sh
bash -n certbot-renew.sh certbot-deploy.sh update-certbot.sh install.sh uninstall.sh
sudo systemd-analyze verify /etc/systemd/system/certbot-renew.service /etc/systemd/system/certbot-renew.timer
sudo ./uninstall.sh
```

Uninstall stops the timer and service and removes installed scripts and units. Configuration, the virtual environment, certificates, account data, logs and deployed files are retained. Back up existing Certbot data before migration and preserve live/archive symlinks while accounting for systemd's ownership handling.

As in the article, package update failure prevents renewal, UPnP cleanup is best effort (with a 600-second router lease), and deployment checks archive paths and nonempty files without race-proof reads, cryptographic verification or rollback. Nginx configuration is tested after copies and before restarting services. Monitor renewal failures and certificate expiry independently.
