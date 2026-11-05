# Nginx Operations and TLS Hardening

This document explains the Nginx configuration used by the Ansible playbook, the health endpoint, and the security rationale behind the configuration.

## Overview

The nginx configuration is responsible for:

- serving HTTPS for the configured domain
- redirecting HTTP traffic to HTTPS
- exposing a lightweight `/healthz` endpoint
- applying hardened TLS settings to reduce exposure to common attacks

## Main configuration behavior

The playbook creates a custom nginx configuration at `/etc/nginx/conf.d/reverse-proxy.conf`.

### HTTPS server block

The HTTPS server block:

- listens on port `443` for IPv4 and IPv6
- uses the Let’s Encrypt certificate files from `/etc/letsencrypt/live/<domain>/`
- serves a JSON health endpoint at `/healthz`, checking Joplin Server's `/api/ping`
- returns `404` for all other paths

### HTTP redirect

The HTTP server block redirects all requests to HTTPS using a `301` permanent redirect.

## TLS hardening details

The configuration now enforces stronger TLS defaults:

- `ssl_protocols TLSv1.2 TLSv1.3`
  - disables older, less secure protocols
- `ssl_prefer_server_ciphers on`
  - ensures the server chooses the most secure acceptable cipher
- `ssl_ciphers ...`
  - restricts the server to modern strong cipher suites
- `ssl_ecdh_curve X25519:prime256v1:secp384r1`
  - enables modern elliptic curves for key exchange
- `ssl_session_cache shared:SSL:10m;`
  - improves performance while keeping session reuse controlled
- `ssl_session_timeout 1d;`
  - limits how long TLS sessions remain valid
- `ssl_session_tickets off;`
  - avoids ticket-based session resumption, which can be less predictable in some environments

## Security headers

The configuration adds headers to improve browser-side protection:

- `Strict-Transport-Security`
  - instructs browsers to always use HTTPS for the domain
- `X-Frame-Options: DENY`
  - reduces clickjacking risk
- `X-Content-Type-Options: nosniff`
  - helps prevent MIME-type sniffing issues
- `Referrer-Policy: no-referrer`
  - reduces leakage of referrer information

## Health endpoint

The unauthenticated `/healthz` route returns only the Joplin service status, without VM details or upstream error information. A healthy response is HTTP `200`:

```json
{"status":"ok","services":{"joplin":"ok"}}
```

If Joplin does not respond successfully, the route returns HTTP `503`:

```json
{"status":"degraded","services":{"joplin":"unavailable"}}
```

The endpoint uses `Cache-Control: no-store`. A local health handler checks each configured app at most once every 60 seconds, on demand. The first request after that interval performs the checks and atomically updates the JSON response file; concurrent and subsequent requests serve the latest file without probing the apps again. The last-check time is based on the response file's modification time, so restarting the handler does not itself trigger another probe. If an app is unavailable, the endpoint returns HTTP `503` and reports that app as unavailable. Check URLs are configured by `healthz_services` in `provision-nginx.yml`; each URL should return HTTP `200` when that app is healthy. Checks send the configured `domain_name` as the HTTP `Host` header so Joplin accepts requests addressed to its configured domain. Add one entry per app. The checks do not expose detailed diagnostics or check the VM's overall health.

## `/healthz` operator runbook

### How it works

Nginx proxies `/healthz` to the health handler listening only on `127.0.0.1:18081`. The handler serves the cached JSON file at `/var/lib/nginx/healthz.json`. The first request after the 60-second cache interval checks each configured service, updates the file atomically, and responds from the new result. A lock ensures concurrent requests do not start duplicate checks. The cache timestamp comes from the file's modification time and survives handler restarts.

The Joplin probe is a GET to `http://127.0.0.1:22300/api/ping` with `Host: <configured domain_name>`. Each check has a 2-second timeout. The response is `200` only when all configured checks pass; any unavailable service yields `503`. The file is a cache, not a live health indicator between checks, so a status can be up to about 60 seconds old.

### Quick check

Replace `your-domain` with the configured public domain:

```bash
curl -i https://your-domain/healthz
sudo cat /var/lib/nginx/healthz.json
sudo stat /var/lib/nginx/healthz.json
```

Check the health handler service and recent messages:

```bash
sudo systemctl status cloud-forge-healthz.service --no-pager
sudo journalctl -u cloud-forge-healthz.service -n 50 --no-pager
```

### Troubleshooting

#### `/healthz` returns `503` and a service is `unavailable`

Test Joplin directly from the VM, using the configured domain in the `Host` header:

```bash
curl -i -H 'Host: your-domain' http://127.0.0.1:22300/api/ping
```

Expected result: HTTP `200` and Joplin's JSON ping response. A `404` saying `Invalid origin` usually means the `Host` header does not match Joplin's configured domain. A connection refusal or timeout indicates Joplin is not reachable at that address and port.

For Joplin container state and logs:

```bash
cd /opt/stacks/joplin
sudo docker compose ps
sudo docker compose logs --tail=100 app
sudo docker compose logs --tail=100 db
```

Resolve any container or database problem, then repeat the direct `curl` test. The health cache may take up to 60 seconds to refresh.

#### Force a fresh check now

Restarting the handler alone preserves the cache age. To deliberately discard the cached result, remove only the health response file, restart the handler, then request `/healthz` to trigger a new check:

```bash
sudo rm /var/lib/nginx/healthz.json
sudo systemctl restart cloud-forge-healthz.service
curl -i https://your-domain/healthz
sudo cat /var/lib/nginx/healthz.json
```

The handler recreates the file on that request. If the file is not recreated, check the handler's journal and verify it can write to `/var/lib/nginx`:

```bash
sudo namei -l /var/lib/nginx/healthz.json
```

#### The handler is inactive or cannot bind its local port

```bash
sudo systemctl status cloud-forge-healthz.service --no-pager
sudo journalctl -u cloud-forge-healthz.service -n 100 --no-pager
sudo ss -ltnp | grep ':18081'
```

The handler should listen on `127.0.0.1:18081`. If another process already owns that port, identify and resolve the conflict, then restart the handler. Do not expose port `18081` publicly; only Nginx should reach it locally.

#### Nginx returns `502` or the public endpoint cannot be reached

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
sudo journalctl -u nginx -n 100 --no-pager
curl -i http://127.0.0.1:18081/healthz
```

If the local handler responds but the public endpoint does not, check the Nginx configuration, TLS certificate, DNS, and Azure network rules for ports `80` and `443`. If the local handler is unreachable, check that `cloud-forge-healthz.service` is running and listening on the expected port.

#### The response looks stale

Check the response file's modification time with `stat`. A successful or failed check is cached for 60 seconds, and normal requests during that interval do not probe services. Wait for the interval to expire, or use the force-refresh steps above.

### Adding a service check

Add a unique `name` and a loopback-reachable `url` under `healthz_services` in `provision-nginx.yml`. The URL must return HTTP `200` when the service is healthy. The shared `Host` header is set to `domain_name`; if an app requires a different host, the health handler will need a per-service Host setting. Re-run the provisioning playbook and use the force-refresh steps to validate the new check.

## Important operational notes

### Certificate management

The playbook uses Certbot to request or install certificates for the configured domain. A successful deployment depends on:

- the domain resolving correctly to the VM
- inbound TCP/80 and TCP/443 being reachable
- the email address being valid for certificate issuance

### Renewal

Let’s Encrypt certificates expire regularly, so certificate renewal should be automated with the Certbot renewal timer.

### Firewall exposure

The server should only expose the ports required for public access:

- `80/tcp` for the HTTP redirect
- `443/tcp` for HTTPS

SSH should be restricted to trusted source addresses.

## Suggested next hardening steps

If you want to go further, consider:

- restricting `/healthz` to localhost or a monitoring subnet
- enabling HTTP/2
- adding OCSP stapling if your certificate provider and environment support it
- monitoring TLS configuration with tools such as SSL Labs
- keeping the Debian host, nginx, and Certbot packages fully updated
