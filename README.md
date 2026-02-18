# kodemeio-bifrost

Centralized AI Gateway for the kodemeio ecosystem, powered by [Bifrost](https://github.com/maximhq/bifrost) (Maxim HQ).

**Domain**: `ai.kodeme.io`

## Quick Start

```bash
# 1. Copy and configure environment
cp .env.example .env.prod
# Edit .env.prod with your API keys and credentials

# 2. Deploy
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d

# 3. Check status
./scripts/bifrost.sh status

# 4. Test providers
./scripts/bifrost.sh test
```

## What is Bifrost?

Bifrost is a high-performance AI gateway that provides:

- **Unified API**: OpenAI-compatible endpoint for 15+ LLM providers
- **Automatic Failover**: Routes to backup providers on failure
- **Load Balancing**: Distributes requests across providers/keys
- **Semantic Caching**: Reduces costs with intelligent response caching
- **Virtual Keys**: Budget control and rate limiting per consumer
- **MCP Tool Integration**: Connect AI agents to external tools

## Architecture

| Service | Image | Purpose |
|---------|-------|---------|
| `bifrost` | `maximhq/bifrost:latest` | AI Gateway (OpenAI-compatible API) |

Configured providers:
- **OpenAI**: GPT-4o, GPT-4.1, GPT-4o-mini, o3-mini
- **Anthropic**: Claude Sonnet 4.6, Claude Opus 4.6, Claude Haiku 4.5
- **Google**: Gemini 2.0 Flash, Gemini 2.5 Pro

## CLI Reference

All management commands go through `./scripts/bifrost.sh`:

```bash
# Service management
./scripts/bifrost.sh status           # Gateway status
./scripts/bifrost.sh start            # Start gateway
./scripts/bifrost.sh stop             # Stop gateway
./scripts/bifrost.sh restart          # Restart gateway
./scripts/bifrost.sh update           # Pull latest + restart

# Providers
./scripts/bifrost.sh providers        # List providers
./scripts/bifrost.sh test             # Test all providers
./scripts/bifrost.sh test openai      # Test specific provider

# Monitoring
./scripts/bifrost.sh health           # Quick health check
./scripts/bifrost.sh logs --follow    # Tail logs
./scripts/bifrost.sh monitor watch    # Live dashboard

# Backup
./scripts/bifrost.sh backup           # Backup to S3
./scripts/bifrost.sh restore          # List/restore backups
```

## API Usage

Bifrost exposes an OpenAI-compatible API at `https://ai.kodeme.io`:

```bash
# Chat completion (routed to configured provider)
curl https://ai.kodeme.io/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Environment Setup

### Required API Keys

| Variable | Source | Notes |
|----------|--------|-------|
| `OPENAI_API_KEY` | [platform.openai.com](https://platform.openai.com/api-keys) | GPT models |
| `ANTHROPIC_API_KEY` | [console.anthropic.com](https://console.anthropic.com/settings/keys) | Claude models |
| `GOOGLE_API_KEY` | [aistudio.google.com](https://aistudio.google.com/apikey) | Gemini models |

### Optional

| Variable | Default | Notes |
|----------|---------|-------|
| `AWS_ACCESS_KEY_ID` | - | AWS Bedrock access |
| `AWS_SECRET_ACCESS_KEY` | - | AWS Bedrock secret |
| `S3_*` | - | Hetzner Object Storage for backup |
| `TELEGRAM_BOT_TOKEN` | - | Telegram notifications |
| `MATTERMOST_WEBHOOK_URL` | - | Mattermost notifications |

### Resource Limits

| Variable | Default | Notes |
|----------|---------|-------|
| `CPU_LIMIT` | 1 | CPU cores |
| `MEMORY_LIMIT` | 1G | Memory |
| `CPU_RESERVATION` | 0.25 | Guaranteed CPU |
| `MEMORY_RESERVATION` | 256M | Guaranteed memory |

## Provider Configuration

Providers are configured in `config/config.json`. Each provider has keys with model mappings:

```json
{
  "providers": {
    "openai": {
      "keys": [{
        "name": "openai-primary",
        "value": "env.OPENAI_API_KEY",
        "models": ["gpt-4o", "gpt-4o-mini"],
        "weight": 1.0
      }]
    }
  }
}
```

## Monitoring

- **Health**: `./scripts/bifrost.sh health`
- **Metrics**: Prometheus-compatible at `/metrics`
- **Logs**: Structured JSON logs for Grafana Loki integration
- **Labels**: `app=bifrost`, `app.tenant=kodemeio`, `app.component=gateway`
