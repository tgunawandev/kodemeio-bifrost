#!/usr/bin/env bash
# =============================================================================
# Provider Management — List and manage AI providers
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
load_env

usage() {
    echo "Usage: $(basename "$0") [list|show|status]"
    echo ""
    echo "  list     List all configured providers (default)"
    echo "  show     Show detailed provider configuration"
    echo "  status   Check provider API key status"
}

list_providers() {
    section "Configured Providers"

    if [ ! -f "${PROJECT_ROOT}/config/config.json" ]; then
        err "config.json not found"
        return 1
    fi

    python3 -c "
import json, sys
try:
    with open('${PROJECT_ROOT}/config/config.json') as f:
        config = json.load(f)
    providers = config.get('providers', {})
    if not providers:
        print('No providers configured')
        sys.exit(0)
    print(f'{'Provider':<15} {'Keys':<6} {'Models':<50}')
    print('─' * 71)
    for name, prov in providers.items():
        keys = prov.get('keys', [])
        models = []
        for k in keys:
            models.extend(k.get('models', []))
        print(f'{name:<15} {len(keys):<6} {', '.join(models)[:50]}')
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || {
    # Fallback without python
    log "Providers from config.json:"
    cat "${PROJECT_ROOT}/config/config.json"
}
}

show_provider() {
    section "Provider Configuration"
    if [ -f "${PROJECT_ROOT}/config/config.json" ]; then
        python3 -m json.tool "${PROJECT_ROOT}/config/config.json" 2>/dev/null || cat "${PROJECT_ROOT}/config/config.json"
    else
        err "config.json not found"
    fi
}

check_status() {
    section "Provider API Key Status"

    local providers=("OPENAI_API_KEY" "ANTHROPIC_API_KEY" "GOOGLE_API_KEY" "AWS_ACCESS_KEY_ID")
    local names=("OpenAI" "Anthropic" "Google" "AWS Bedrock")

    for i in "${!providers[@]}"; do
        local var="${providers[$i]}"
        local name="${names[$i]}"
        local val="${!var:-}"

        if [ -z "$val" ] || [[ "$val" == *"CHANGE_ME"* ]]; then
            warn "${name}: not configured"
        else
            local masked="${val:0:8}...${val: -4}"
            ok "${name}: configured (${masked})"
        fi
    done
}

case "${1:-list}" in
    list)    list_providers ;;
    show)    show_provider ;;
    status)  check_status ;;
    help|--help|-h)
        usage
        ;;
    *)
        err "Unknown option: $1"
        usage
        exit 1
        ;;
esac
