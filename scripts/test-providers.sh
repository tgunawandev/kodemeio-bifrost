#!/usr/bin/env bash
# =============================================================================
# Test Providers — Send test requests to each configured provider
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
load_env

usage() {
    echo "Usage: $(basename "$0") [provider] [options]"
    echo ""
    echo "  Without arguments: test all configured providers"
    echo "  With provider:     test specific provider"
    echo ""
    echo "Providers: openai, anthropic, google"
    echo ""
    echo "Options:"
    echo "  --quick    Quick test (shorter prompt)"
    echo "  --verbose  Show full response"
}

VERBOSE=""
QUICK=""

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v) VERBOSE=1; shift ;;
        --quick|-q)   QUICK=1; shift ;;
        --help|-h)    usage; exit 0 ;;
        *)            break ;;
    esac
done

PROVIDER="${1:-all}"

test_model() {
    local model="$1"
    local provider_name="$2"
    local prompt="${3:-Say hello in one word.}"

    log "Testing ${provider_name} (${model})..."

    local start_time
    start_time=$(date +%s%N)

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$(get_bifrost_url)/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"${model}\",
            \"messages\": [{\"role\": \"user\", \"content\": \"${prompt}\"}],
            \"max_tokens\": 10
        }" 2>/dev/null)

    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    local end_time
    end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))

    if [ "$http_code" = "200" ]; then
        ok "${provider_name} (${model}): OK (${duration_ms}ms)"
        if [ -n "$VERBOSE" ]; then
            echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
        fi
    else
        err "${provider_name} (${model}): FAILED (HTTP ${http_code}, ${duration_ms}ms)"
        if [ -n "$VERBOSE" ]; then
            echo "$body"
        fi
    fi
}

test_openai() {
    local model="${1:-gpt-4o-mini}"
    test_model "$model" "OpenAI"
}

test_anthropic() {
    local model="${1:-claude-haiku-4-5-20251001}"
    test_model "$model" "Anthropic"
}

test_google() {
    local model="${1:-gemini-2.0-flash}"
    test_model "$model" "Google"
}

section "Provider Connection Tests"
echo ""

case "$PROVIDER" in
    openai)    test_openai ;;
    anthropic) test_anthropic ;;
    google)    test_google ;;
    all)
        test_openai
        test_anthropic
        test_google
        ;;
    *)
        err "Unknown provider: $PROVIDER"
        usage
        exit 1
        ;;
esac

echo ""
hr
ok "Provider tests complete"
