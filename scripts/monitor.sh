#!/usr/bin/env bash
# =============================================================================
# Monitor — Real-time monitoring dashboard
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
load_env

usage() {
    echo "Usage: $(basename "$0") [summary|watch|json]"
    echo ""
    echo "  summary   One-time status summary (default)"
    echo "  watch     Live monitoring (refreshes every 5s)"
    echo "  json      Output metrics as JSON"
}

show_summary() {
    section "Bifrost Gateway Monitor"

    # Container stats
    check_docker
    CONTAINER=$(get_container)
    if docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
        echo -e "${BOLD}Container:${RESET}"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.PIDs}}" "$CONTAINER" 2>/dev/null
        echo ""

        # Uptime
        local started
        started=$(docker inspect --format '{{.State.StartedAt}}' "$CONTAINER" 2>/dev/null)
        if [ -n "$started" ]; then
            echo -e "${BOLD}Started:${RESET} ${started}"
        fi
    else
        err "Container not running"
        return 1
    fi

    # Health endpoint
    echo ""
    echo -e "${BOLD}Health:${RESET}"
    bifrost_api GET /v1/health 2>/dev/null || warn "Health endpoint not available"

    # Metrics summary
    echo ""
    echo -e "${BOLD}Metrics:${RESET}"
    local metrics
    metrics=$(bifrost_api GET /metrics 2>/dev/null || echo "")
    if [ -n "$metrics" ]; then
        echo "$metrics" | grep -E '^(bifrost_|http_)' | head -20 || log "No bifrost metrics found"
    else
        warn "Metrics endpoint not available"
    fi
}

watch_monitor() {
    log "Live monitoring (Ctrl+C to stop)..."
    echo ""
    while true; do
        clear
        echo -e "${BOLD}Bifrost Gateway — Live Monitor${RESET}  $(date '+%Y-%m-%d %H:%M:%S')"
        hr

        CONTAINER=$(get_container)
        if docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
            docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" "$CONTAINER" 2>/dev/null

            echo ""
            local health_status
            health_status=$(curl -s -o /dev/null -w "%{http_code}" "$(get_bifrost_url)/v1/health" 2>/dev/null || echo "000")
            if [ "$health_status" = "200" ]; then
                echo -e "Health: ${GREEN}OK${RESET} (${health_status})"
            else
                echo -e "Health: ${RED}DOWN${RESET} (${health_status})"
            fi
        else
            err "Container not running"
        fi

        sleep 5
    done
}

json_monitor() {
    check_docker
    CONTAINER=$(get_container)
    local running="false"
    local cpu="0"
    local mem="0"
    local health="000"

    if docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
        running="true"
        cpu=$(docker stats --no-stream --format '{{.CPUPerc}}' "$CONTAINER" 2>/dev/null | tr -d '%')
        mem=$(docker stats --no-stream --format '{{.MemPerc}}' "$CONTAINER" 2>/dev/null | tr -d '%')
        health=$(curl -s -o /dev/null -w "%{http_code}" "$(get_bifrost_url)/v1/health" 2>/dev/null || echo "000")
    fi

    cat <<EOF
{
  "service": "bifrost",
  "container_running": ${running},
  "cpu_percent": ${cpu:-0},
  "memory_percent": ${mem:-0},
  "health_http_status": ${health},
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

case "${1:-summary}" in
    summary)  show_summary ;;
    watch)    watch_monitor ;;
    json)     json_monitor ;;
    help|--help|-h)
        usage
        ;;
    *)
        err "Unknown option: $1"
        usage
        exit 1
        ;;
esac
