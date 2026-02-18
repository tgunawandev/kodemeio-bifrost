# kodemeio-bifrost

Production Docker deployment for Bifrost AI Gateway (ai.kodeme.io).
Deployed to Dokploy with Traefik reverse proxy (HTTPS).

## Architecture

```
                     dokploy-network (external)
                           |
                Traefik (HTTPS + Let's Encrypt)
                           |
                     bifrost:8080
                 (maximhq/bifrost:latest)
                           |
              ┌────────────┼────────────┐
              │            │            │
           OpenAI     Anthropic     Google
         (gpt-4o)   (claude-*)   (gemini-*)
```

- **bifrost**: Bifrost AI Gateway on port 8080 (Traefik routes HTTPS to ai.kodeme.io)
- Routes requests to 15+ LLM providers via unified OpenAI-compatible API
- Automatic failover, load balancing, and semantic caching

## Project Structure

```
docker-compose.prod.yml          # Production compose (Dokploy entry point)
docker-compose.yml               # Development compose
.env.prod                        # Production secrets (gitignored)
.env.example                     # Environment template
config/
  config.json                    # Bifrost provider configuration
scripts/
  bifrost.sh                     # Main CLI entry point (dispatches all commands)
  lib/common.sh                  # Shared utilities (colors, logging, S3, notifications)
  health.sh                      # Health check (quick, full, json)
  providers.sh                   # Provider management (list, show, status)
  keys.sh                        # Virtual key management (list, create, delete, rotate)
  logs.sh                        # Log viewer with filtering
  backup.sh                      # Config backup to S3
  restore.sh                     # Config restore from S3
  monitor.sh                     # Monitoring dashboard (summary, watch, json)
  test-providers.sh              # Test provider connections
.github/workflows/
  build-push.yml                 # CI: validate compose, config, lint scripts
```

## Networks

- `dokploy-network` (external) — Traefik routing, shared across Dokploy services
- `bifrost-internal` (bridge) — Internal network (for future sidecars)

## Volumes

- `bifrost-data` — Bifrost data directory (config.db, logs.db)
- `./config/config.json` — Provider configuration (bind mount, read-only)

## CLI Reference

All management commands go through `./scripts/bifrost.sh`:

```bash
# Service commands
bifrost.sh status               # Gateway status, health, version
bifrost.sh start                # Start the gateway
bifrost.sh stop                 # Stop the gateway
bifrost.sh restart              # Restart the gateway
bifrost.sh update               # Pull latest image and restart
bifrost.sh version              # Show Bifrost version
bifrost.sh shell                # Open shell in container

# Provider management
bifrost.sh providers            # List configured providers
bifrost.sh providers status     # Check API key status
bifrost.sh test                 # Test all provider connections
bifrost.sh test openai          # Test specific provider

# Key management
bifrost.sh keys                 # List virtual keys
bifrost.sh keys create <name>   # Create virtual key
bifrost.sh keys delete <id>     # Delete virtual key
bifrost.sh keys rotate <id>     # Rotate virtual key

# Monitoring
bifrost.sh health               # Quick health check
bifrost.sh health full          # Full health assessment
bifrost.sh logs --follow        # Tail logs
bifrost.sh logs --errors        # Show only errors
bifrost.sh monitor              # Status summary
bifrost.sh monitor watch        # Live dashboard
bifrost.sh metrics              # Prometheus metrics

# Backup/restore
bifrost.sh backup               # Backup config to S3
bifrost.sh backup --list        # List S3 backups
bifrost.sh restore              # List available backups
bifrost.sh restore <file>       # Restore from backup
```

## Deployment

```bash
# Start all services
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d

# View logs
docker compose -f docker-compose.prod.yml --env-file .env.prod logs -f

# Check health
./scripts/bifrost.sh health

# Test providers
./scripts/bifrost.sh test
```

## Traefik Routing

| Router | Rule | Port | Notes |
|--------|------|------|-------|
| `kodemeio-bifrost` | `Host(\`ai.kodeme.io\`)` | 8080 | AI Gateway API |

## Environment Variables

| Section | Variables | Notes |
|---------|-----------|-------|
| Bifrost | `APP_PORT`, `APP_HOST`, `LOG_LEVEL`, `LOG_STYLE` | Core config |
| OpenAI | `OPENAI_API_KEY` | GPT-4o, GPT-4.1, o3-mini |
| Anthropic | `ANTHROPIC_API_KEY` | Claude Sonnet/Opus/Haiku |
| Google | `GOOGLE_API_KEY` | Gemini 2.0/2.5 |
| AWS | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` | Bedrock |
| Resources | `CPU_LIMIT`, `MEMORY_LIMIT` | Configurable limits |
| S3 Backup | `S3_ENDPOINT`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_BUCKET` | Config backup |
| Notifications | `TELEGRAM_BOT_TOKEN`, `MATTERMOST_WEBHOOK_URL` | Alerts |

## Resource Allocation

| Service | CPU Limit | Memory Limit | CPU Reserved | Memory Reserved |
|---------|-----------|-------------|-------------|-----------------|
| bifrost | 1.0 | 1G | 0.25 | 256M |

## Monitoring Labels

```yaml
- "logging=promtail"
- "app=bifrost"
- "app.tenant=kodemeio"
- "app.component=gateway"
- "app.service=bifrost-gateway"
```

Loki queries:
```logql
{app="bifrost"} |= "ERROR"
{app="bifrost", app_component="gateway"} | json
```

## Provider Configuration

Edit `config/config.json` to add/modify providers. Format:

```json
{
  "providers": {
    "<provider-name>": {
      "keys": [{
        "name": "<key-name>",
        "value": "env.<ENV_VAR>",
        "models": ["model-1", "model-2"],
        "weight": 1.0
      }]
    }
  }
}
```

## API Usage

Bifrost exposes an OpenAI-compatible API:

```bash
curl https://ai.kodeme.io/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## Server Info

- **Domain**: ai.kodeme.io (via Traefik)
- **Image**: maximhq/bifrost:latest (upstream, no custom Dockerfile)
- **Port**: 8080 (internal)
- **Backup**: Hetzner Object Storage (S3-compatible)
- **Notifications**: Telegram + Mattermost

## Rules for Claude

- Always use `docker compose -f docker-compose.prod.yml --env-file .env.prod` for compose commands
- No custom Dockerfile — uses upstream `maximhq/bifrost` image
- Config is via `config/config.json` (bind mount) + environment variables
- `bifrost.sh` is the single CLI entry point — dispatches to individual scripts
- Provider API keys are in `.env.prod`, never hardcode them
- The `.env.prod` is gitignored; `.env.example` is the template
- Service name in compose: `bifrost`
- Container name pattern: `kodemeio-bifrost-bifrost-1`
