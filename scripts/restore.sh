#!/usr/bin/env bash
# =============================================================================
# Restore — Restore Bifrost config from S3 backup
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
load_env

usage() {
    echo "Usage: $(basename "$0") [backup-file]"
    echo ""
    echo "  Without arguments: list available backups"
    echo "  With backup-file:  restore from specified backup"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")                                    # List backups"
    echo "  $(basename "$0") bifrost-backup-20250101-120000.tar.gz  # Restore"
}

# Check required S3 vars
check_s3() {
    for var in S3_ENDPOINT S3_ACCESS_KEY S3_SECRET_KEY S3_BUCKET; do
        if [ -z "${!var:-}" ] || [[ "${!var}" == *"CHANGE_ME"* ]]; then
            err "${var} is not configured"
            return 1
        fi
    done
}

setup_s3() {
    export AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY}"
    export AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}"
    export AWS_DEFAULT_REGION="${S3_REGION:-fsn1}"
    S3_URL="--endpoint-url ${S3_ENDPOINT}"
}

list_backups() {
    check_s3
    setup_s3
    section "Available Backups"
    # shellcheck disable=SC2086
    aws s3 ls "s3://${S3_BUCKET}/" ${S3_URL} 2>/dev/null | sort -r | head -20 || warn "No backups found"
}

do_restore() {
    local backup_file="$1"
    check_s3
    setup_s3
    check_docker

    if ! confirm "Restore from ${backup_file}? This will overwrite current configuration."; then
        log "Restore cancelled"
        return 0
    fi

    local restore_dir="/tmp/bifrost-restore-$$"
    mkdir -p "${restore_dir}"

    # Download from S3
    log "Downloading ${backup_file} from S3..."
    # shellcheck disable=SC2086
    aws s3 cp "s3://${S3_BUCKET}/${backup_file}" "/tmp/${backup_file}" ${S3_URL}
    ok "Downloaded"

    # Extract
    log "Extracting..."
    tar -xzf "/tmp/${backup_file}" -C "${restore_dir}"
    ok "Extracted"

    # Find the backup directory inside the archive
    local backup_content
    backup_content=$(find "${restore_dir}" -mindepth 1 -maxdepth 1 -type d | head -1)
    if [ -z "$backup_content" ]; then
        backup_content="${restore_dir}"
    fi

    # Restore config.json
    if [ -f "${backup_content}/config.json" ]; then
        cp "${backup_content}/config.json" "${PROJECT_ROOT}/config/config.json"
        ok "Restored config.json"
    fi

    # Restore config.db to container
    CONTAINER=$(get_container)
    if docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
        if [ -f "${backup_content}/config.db" ]; then
            docker cp "${backup_content}/config.db" "${CONTAINER}:/app/data/config.db"
            ok "Restored config.db"
        fi
    else
        warn "Container not running, config.db not restored to volume"
    fi

    # Cleanup
    rm -rf "${restore_dir}" "/tmp/${backup_file}"

    log "Restarting Bifrost to apply restored config..."
    ${DC} restart bifrost
    ok "Restore complete"
    notify "🔄 Bifrost config restored from ${backup_file}"
}

case "${1:-}" in
    --help|-h|help)
        usage
        ;;
    "")
        list_backups
        ;;
    *)
        do_restore "$1"
        ;;
esac
