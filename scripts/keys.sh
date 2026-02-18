#!/usr/bin/env bash
# =============================================================================
# Virtual Key Management — Create, list, delete, rotate virtual keys
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
load_env

usage() {
    echo "Usage: $(basename "$0") <command> [options]"
    echo ""
    echo "Commands:"
    echo "  list              List all virtual keys"
    echo "  create <name>     Create a new virtual key"
    echo "  delete <key-id>   Delete a virtual key"
    echo "  rotate <key-id>   Rotate a virtual key"
    echo "  show <key-id>     Show virtual key details"
}

list_keys() {
    section "Virtual Keys"
    local response
    response=$(bifrost_api GET /v1/keys 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    else
        warn "Virtual keys endpoint not available or no keys configured"
        log "Virtual keys may require Bifrost Pro features"
    fi
}

create_key() {
    local name="${1:-}"
    if [ -z "$name" ]; then
        err "Key name is required"
        echo "Usage: $(basename "$0") create <name>"
        return 1
    fi

    log "Creating virtual key: ${name}..."
    local response
    response=$(bifrost_api POST /v1/keys -d "{\"name\": \"${name}\"}" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        ok "Virtual key created"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    else
        err "Failed to create virtual key"
    fi
}

delete_key() {
    local key_id="${1:-}"
    if [ -z "$key_id" ]; then
        err "Key ID is required"
        echo "Usage: $(basename "$0") delete <key-id>"
        return 1
    fi

    if confirm "Delete virtual key ${key_id}?"; then
        local response
        response=$(bifrost_api DELETE "/v1/keys/${key_id}" 2>/dev/null)
        if [ $? -eq 0 ]; then
            ok "Virtual key deleted: ${key_id}"
        else
            err "Failed to delete virtual key"
        fi
    fi
}

rotate_key() {
    local key_id="${1:-}"
    if [ -z "$key_id" ]; then
        err "Key ID is required"
        echo "Usage: $(basename "$0") rotate <key-id>"
        return 1
    fi

    if confirm "Rotate virtual key ${key_id}?"; then
        local response
        response=$(bifrost_api POST "/v1/keys/${key_id}/rotate" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$response" ]; then
            ok "Virtual key rotated"
            echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
        else
            err "Failed to rotate virtual key"
        fi
    fi
}

show_key() {
    local key_id="${1:-}"
    if [ -z "$key_id" ]; then
        err "Key ID is required"
        echo "Usage: $(basename "$0") show <key-id>"
        return 1
    fi

    local response
    response=$(bifrost_api GET "/v1/keys/${key_id}" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    else
        err "Key not found: ${key_id}"
    fi
}

case "${1:-}" in
    list)    list_keys ;;
    create)  shift; create_key "$@" ;;
    delete)  shift; delete_key "$@" ;;
    rotate)  shift; rotate_key "$@" ;;
    show)    shift; show_key "$@" ;;
    help|--help|-h)
        usage
        ;;
    "")
        list_keys
        ;;
    *)
        err "Unknown command: $1"
        usage
        exit 1
        ;;
esac
