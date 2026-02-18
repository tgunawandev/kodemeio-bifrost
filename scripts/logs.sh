#!/usr/bin/env bash
# =============================================================================
# Log Viewer — Smart log viewing with filtering
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
load_env
check_docker

usage() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  --follow, -f      Follow log output"
    echo "  --tail N, -n N    Show last N lines (default: 100)"
    echo "  --filter PATTERN  Filter logs by pattern"
    echo "  --errors          Show only error lines"
    echo "  --since TIME      Show logs since timestamp (e.g., 1h, 30m)"
}

FOLLOW=""
TAIL="100"
FILTER=""
ERRORS_ONLY=""
SINCE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --follow|-f)
            FOLLOW="--follow"
            shift
            ;;
        --tail|-n)
            TAIL="$2"
            shift 2
            ;;
        --filter)
            FILTER="$2"
            shift 2
            ;;
        --errors)
            ERRORS_ONLY="1"
            shift
            ;;
        --since)
            SINCE="--since $2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            err "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Build docker compose logs command
CMD="${DC} logs --tail ${TAIL} ${FOLLOW} ${SINCE} bifrost"

if [ -n "$ERRORS_ONLY" ]; then
    eval "${CMD}" 2>&1 | grep -iE '(error|fatal|panic|fail)' || log "No error lines found"
elif [ -n "$FILTER" ]; then
    eval "${CMD}" 2>&1 | grep -i "${FILTER}" || log "No lines matching '${FILTER}'"
else
    eval "${CMD}"
fi
