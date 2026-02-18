#!/usr/bin/env bash
# =============================================================================
# Shared Utilities — Colors, logging, helpers
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Logging
log()  { echo -e "${BLUE}[INFO]${RESET} $*"; }
ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Require environment variable to be set
require_env() {
    local var_name="$1"
    if [ -z "${!var_name:-}" ]; then
        err "Required environment variable ${var_name} is not set"
        return 1
    fi
}

# Confirm destructive operation
confirm() {
    local msg="${1:-Are you sure?}"
    echo -en "${YELLOW}${msg} [y/N]${RESET} "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# Project root (relative to scripts/lib/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Docker compose command
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.prod.yml"
ENV_FILE="${PROJECT_ROOT}/.env.prod"
DC="docker compose -f ${COMPOSE_FILE} --env-file ${ENV_FILE}"

# Load .env.prod if it exists
load_env() {
    if [ -f "${ENV_FILE}" ]; then
        set -a
        # shellcheck disable=SC1090
        source "${ENV_FILE}"
        set +a
    else
        err ".env.prod not found at ${ENV_FILE}"
        return 1
    fi
}

# Check if docker compose is available
check_docker() {
    if ! command -v docker &>/dev/null; then
        err "Docker is not installed or not in PATH"
        return 1
    fi
    if ! docker compose version &>/dev/null; then
        err "Docker Compose v2 is required"
        return 1
    fi
}

# Get bifrost container name
get_container() {
    local name
    name=$(docker ps --filter "name=bifrost" --format '{{.Names}}' | grep -E '(bifrost|gateway)' | head -1)
    if [ -z "$name" ]; then
        name="${COMPOSE_PROJECT_NAME:-kodemeio-bifrost}-bifrost-1"
    fi
    echo "$name"
}

# Get Bifrost base URL
get_bifrost_url() {
    echo "http://localhost:${APP_PORT:-8080}"
}

# Make API call to Bifrost
bifrost_api() {
    local method="${1:-GET}"
    local path="$2"
    shift 2
    local url
    url="$(get_bifrost_url)${path}"
    curl -s -X "$method" "$url" -H "Content-Type: application/json" "$@"
}

# Send Telegram notification
notify_telegram() {
    local message="$1"
    if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${message}" \
            -d "parse_mode=HTML" >/dev/null 2>&1
    fi
}

# Send Mattermost notification
notify_mattermost() {
    local message="$1"
    if [ -n "${MATTERMOST_WEBHOOK_URL:-}" ]; then
        curl -s -X POST "${MATTERMOST_WEBHOOK_URL}" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"${message}\"}" >/dev/null 2>&1
    fi
}

# Send notification to all configured channels
notify() {
    local message="$1"
    notify_telegram "$message"
    notify_mattermost "$message"
}

# Print a horizontal line
hr() {
    printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '─'
}

# Print a section header
section() {
    echo ""
    echo -e "${BOLD}$1${RESET}"
    hr
}
