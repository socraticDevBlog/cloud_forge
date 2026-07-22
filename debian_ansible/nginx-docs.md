# Nginx TLS Hardening Guide

This document explains the nginx configuration used by the Ansible playbook in this repository and the security rationale behind the choices.

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
- serves a minimal JSON health endpoint at `/healthz`
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

The `/healthz` route returns JSON:

```json
{"healthy":true}
```

This endpoint is intentionally lightweight and should be used only for monitoring or health checks.

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
