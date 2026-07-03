# Caddy Template

A Docker-based [Caddy](https://caddyserver.com/) web server template with Cloudflare DNS and Layer 4 proxy extensions pre-built.

## What's Included

- **Caddy 2.11.2** with [caddy-dns/cloudflare](https://github.com/caddy-dns/cloudflare) and [caddy-l4](https://github.com/mholt/caddy-l4) modules
- Docker Compose setup with persistent data/config volumes
- A dedicated `caddy_network` bridge network for connecting other services
- Static file serving on port 80 with a default status page

## Project Structure

```
├── .env.sample         # Sample env vars injected into the Caddy container
├── compose.yaml        # Docker Compose service definition
├── dockerfile          # Multi-stage build: xcaddy builder → runtime image
├── config/
│   └── Caddyfile       # Caddy configuration (serves /srv on :80)
├── static/
│   └── index.html      # Default "Service Active" status page
└── tests/
    └── integration_test.sh
```

## Quick Start

```bash
docker compose up -d
curl http://localhost
```

If you need environment variables in your Caddy configs, create `.env` from the sample first:

```bash
cp .env.sample .env
```

To rebuild after changes:

```bash
docker compose up -d --build
```

## Configuration

Edit `config/Caddyfile` to customise routing, TLS, reverse proxying, etc. The file is bind-mounted, so you can reload without rebuilding:

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

## Environment Variables In Caddy Configs

The `caddy` service optionally loads environment variables from the repo-level `.env` file and makes them available to every Caddyfile fragment imported from `config/caddy-configs/*/index.caddyfile`.

Use Caddy's env placeholder syntax inside any loaded config:

```caddyfile
:443 {
    tls {
        dns cloudflare {$CLOUDFLARE_API_TOKEN}
    }
}
```

If your config needs environment variables, create `.env` from the sample file and add the values you need:

```bash
cp .env.sample .env
```

If you change `.env`, recreate the container so Caddy starts with the updated environment:

```bash
docker compose up -d --force-recreate caddy
```

## Adding more configs
- Create a folder inside `config/caddy-configs/folder`
- You must have `index.caddyfile` that may have your configs, also support importing other .caddyfile within the root of the folder your created.

## Connecting Other Services

Other Compose services can join the pre-existing network:

```yaml
services:
  app:
    image: my-app
    networks:
      - caddy_network

networks:
  caddy_network:
    external: true
```

## Teardown

```bash
docker compose down            # stop and remove containers
docker compose down -v         # also remove volumes
```
