#!/usr/bin/env bash
# =============================================================================
# Bifrost CLI — Main entry point for all management operations
# =============================================================================
# Unified dispatcher for Bifrost AI Gateway management.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    echo -e "${BOLD}Bifrost AI Gateway — Management CLI${RESET}"
    echo ""
    echo -e "Usage: ${BOLD}$(basename "$0")${RESET} <command> [options]"
    echo ""
    echo -e "${BOLD}Service Commands:${RESET}"
    echo "  status          Show gateway status (health, uptime, version)"
    echo "  start           Start the gateway"
    echo "  stop            Stop the gateway"
    echo "  restart         Restart the gateway"
    echo "  update          Pull latest image and restart"
    echo "  version         Show Bifrost version"
    echo "  shell           Open interactive shell in container"
    echo ""
    echo -e "${BOLD}Provider & Key Management:${RESET}"
    echo "  providers       List configured providers and their status"
    echo "  test            Test all provider connections"
    echo "  keys            Manage virtual keys (list, create, delete, rotate)"
    echo ""
    echo -e "${BOLD}Monitoring & Logs:${RESET}"
    echo "  health          Quick health check"
    echo "  logs            View gateway logs (--follow, --tail N)"
    echo "  monitor         Live monitoring dashboard"
    echo "  metrics         Show Prometheus metrics summary"
    echo ""
    echo -e "${BOLD}Configuration:${RESET}"
    echo "  config          View/export current configuration"
    echo "  cache           Cache management (stats, clear)"
    echo ""
    echo -e "${BOLD}Backup & Restore:${RESET}"
    echo "  backup          Backup config to S3"
    echo "  restore         Restore config from S3 backup"
    echo ""
    echo -e "${BOLD}Examples:${RESET}"
    echo "  $(basename "$0") status"
    echo "  $(basename "$0") health"
    echo "  $(basename "$0") providers"
    echo "  $(basename "$0") test"
    echo "  $(basename "$0") logs --follow"
    echo "  $(basename "$0") backup"
}

case "${1:-}" in
    status)
        shift
        load_env
        check_docker
        section "Bifrost AI Gateway Status"

        CONTAINER=$(get_container)
        if docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
            ok "Container: ${CONTAINER} (running)"
            echo ""
            docker ps --filter "name=${CONTAINER}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
            echo ""

            # Health check
            HEALTH=$(bifrost_api GET /v1/health 2>/dev/null || echo '{"status":"unreachable"}')
            echo -e "${BOLD}Health:${RESET} ${HEALTH}"

            # Version
            VERSION=$(docker exec "$CONTAINER" /bin/sh -c 'cat /app/version 2>/dev/null || echo unknown' 2>/dev/null)
            echo -e "${BOLD}Version:${RESET} ${VERSION}"
        else
            err "Container ${CONTAINER} is not running"
            echo ""
            log "Start with: $(basename "$0") start"
        fi
        ;;

    start)
        shift
        load_env
        check_docker
        log "Starting Bifrost AI Gateway..."
        ${DC} up -d
        ok "Bifrost started"
        ;;

    stop)
        shift
        load_env
        check_docker
        if confirm "Stop Bifrost AI Gateway?"; then
            log "Stopping..."
            ${DC} down
            ok "Bifrost stopped"
        fi
        ;;

    restart)
        shift
        load_env
        check_docker
        log "Restarting Bifrost AI Gateway..."
        ${DC} restart
        ok "Bifrost restarted"
        ;;

    update)
        shift
        load_env
        check_docker
        log "Pulling latest Bifrost image..."
        ${DC} pull
        log "Recreating container..."
        ${DC} up -d
        ok "Bifrost updated"
        notify "🔄 Bifrost AI Gateway updated on ${DOMAIN:-ai.kodeme.io}"
        ;;

    version)
        shift
        load_env
        check_docker
        CONTAINER=$(get_container)
        docker exec "$CONTAINER" /bin/sh -c 'cat /app/version 2>/dev/null || echo unknown'
        ;;

    shell)
        shift
        load_env
        check_docker
        CONTAINER=$(get_container)
        log "Opening shell in ${CONTAINER}..."
        docker exec -it "$CONTAINER" /bin/sh
        ;;

    health)
        shift
        exec bash "${SCRIPT_DIR}/health.sh" "$@"
        ;;

    providers)
        shift
        exec bash "${SCRIPT_DIR}/providers.sh" "$@"
        ;;

    test)
        shift
        exec bash "${SCRIPT_DIR}/test-providers.sh" "$@"
        ;;

    keys)
        shift
        exec bash "${SCRIPT_DIR}/keys.sh" "$@"
        ;;

    logs)
        shift
        exec bash "${SCRIPT_DIR}/logs.sh" "$@"
        ;;

    monitor)
        shift
        exec bash "${SCRIPT_DIR}/monitor.sh" "$@"
        ;;

    metrics)
        shift
        load_env
        section "Prometheus Metrics"
        bifrost_api GET /metrics 2>/dev/null || err "Metrics endpoint not available"
        ;;

    config)
        shift
        load_env
        section "Bifrost Configuration"
        if [ -f "${PROJECT_ROOT}/config/config.json" ]; then
            cat "${PROJECT_ROOT}/config/config.json"
        else
            err "config.json not found"
        fi
        ;;

    cache)
        shift
        load_env
        case "${1:-stats}" in
            stats)
                log "Cache statistics:"
                bifrost_api GET /v1/cache/stats 2>/dev/null || warn "Cache stats not available"
                ;;
            clear)
                if confirm "Clear Bifrost cache?"; then
                    bifrost_api DELETE /v1/cache 2>/dev/null || warn "Cache clear not available"
                    ok "Cache cleared"
                fi
                ;;
            *)
                echo "Usage: $(basename "$0") cache [stats|clear]"
                ;;
        esac
        ;;

    backup)
        shift
        exec bash "${SCRIPT_DIR}/backup.sh" "$@"
        ;;

    restore)
        shift
        exec bash "${SCRIPT_DIR}/restore.sh" "$@"
        ;;

    help|--help|-h|"")
        usage
        ;;

    *)
        err "Unknown command: $1"
        echo ""
        usage
        exit 1
        ;;
esac
