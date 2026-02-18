#!/usr/bin/env bash
# =============================================================================
# Health Check — Comprehensive Bifrost health assessment
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
load_env

usage() {
    echo "Usage: $(basename "$0") [quick|full|json]"
    echo ""
    echo "  quick   Quick HTTP health check (default)"
    echo "  full    Full health check (HTTP + providers + disk)"
    echo "  json    Output health status as JSON"
}

quick_check() {
    local url
    url="$(get_bifrost_url)/v1/health"
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

    if [ "$status" = "200" ]; then
        ok "Bifrost is healthy (HTTP ${status})"
        return 0
    else
        err "Bifrost is unhealthy (HTTP ${status})"
        return 1
    fi
}

full_check() {
    section "Bifrost Health Check"
    local score=0
    local total=0

    # 1. HTTP endpoint
    total=$((total + 1))
    log "Checking HTTP endpoint..."
    if quick_check; then
        score=$((score + 1))
    fi

    # 2. Container status
    total=$((total + 1))
    log "Checking container status..."
    check_docker
    CONTAINER=$(get_container)
    if docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
        ok "Container running: ${CONTAINER}"
        score=$((score + 1))
    else
        err "Container not running"
    fi

    # 3. Provider connectivity
    total=$((total + 1))
    log "Checking provider config..."
    if [ -f "${PROJECT_ROOT}/config/config.json" ]; then
        local provider_count
        provider_count=$(python3 -c "import json; print(len(json.load(open('${PROJECT_ROOT}/config/config.json')).get('providers', {})))" 2>/dev/null || echo "0")
        if [ "$provider_count" -gt 0 ]; then
            ok "Providers configured: ${provider_count}"
            score=$((score + 1))
        else
            warn "No providers configured"
        fi
    else
        err "config.json not found"
    fi

    # 4. Disk space
    total=$((total + 1))
    log "Checking disk space..."
    local disk_pct
    disk_pct=$(df -h / | awk 'NR==2 {gsub(/%/,""); print $5}')
    if [ "$disk_pct" -lt 90 ]; then
        ok "Disk usage: ${disk_pct}%"
        score=$((score + 1))
    else
        warn "Disk usage high: ${disk_pct}%"
    fi

    # Summary
    echo ""
    hr
    local pct=$((score * 100 / total))
    if [ "$pct" -ge 75 ]; then
        ok "Health Score: ${score}/${total} (${pct}%)"
    elif [ "$pct" -ge 50 ]; then
        warn "Health Score: ${score}/${total} (${pct}%)"
    else
        err "Health Score: ${score}/${total} (${pct}%)"
    fi
}

json_check() {
    local http_status
    http_status=$(curl -s -o /dev/null -w "%{http_code}" "$(get_bifrost_url)/v1/health" 2>/dev/null || echo "000")
    local container_running="false"
    check_docker 2>/dev/null
    CONTAINER=$(get_container 2>/dev/null)
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "$CONTAINER"; then
        container_running="true"
    fi

    cat <<EOF
{
  "service": "bifrost",
  "http_status": ${http_status},
  "container_running": ${container_running},
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

case "${1:-quick}" in
    quick)   quick_check ;;
    full)    full_check ;;
    json)    json_check ;;
    help|--help|-h)
        usage
        ;;
    *)
        err "Unknown option: $1"
        usage
        exit 1
        ;;
esac
