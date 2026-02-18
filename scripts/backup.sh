#!/usr/bin/env bash
# =============================================================================
# Backup — Backup Bifrost config to S3
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
load_env

usage() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  --list    List available backups on S3"
    echo "  --dry-run Show what would be backed up"
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

# Configure AWS CLI for S3
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
    aws s3 ls "s3://${S3_BUCKET}/" ${S3_URL} --recursive 2>/dev/null || warn "No backups found or bucket not accessible"
}

do_backup() {
    check_s3
    setup_s3
    check_docker

    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="/tmp/bifrost-backup-${timestamp}"
    local archive="bifrost-backup-${timestamp}.tar.gz"

    log "Creating backup: ${archive}"
    mkdir -p "${backup_dir}"

    # Backup config.json
    if [ -f "${PROJECT_ROOT}/config/config.json" ]; then
        cp "${PROJECT_ROOT}/config/config.json" "${backup_dir}/"
        ok "Backed up config.json"
    fi

    # Backup config.db from volume
    CONTAINER=$(get_container)
    if docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
        docker cp "${CONTAINER}:/app/data/config.db" "${backup_dir}/config.db" 2>/dev/null && ok "Backed up config.db" || warn "config.db not found in container"
        docker cp "${CONTAINER}:/app/data/logs.db" "${backup_dir}/logs.db" 2>/dev/null && ok "Backed up logs.db" || warn "logs.db not found in container"
    else
        warn "Container not running, skipping volume backup"
    fi

    # Create archive
    tar -czf "/tmp/${archive}" -C /tmp "bifrost-backup-${timestamp}"
    ok "Archive created: /tmp/${archive}"

    # Upload to S3
    log "Uploading to S3..."
    # shellcheck disable=SC2086
    aws s3 cp "/tmp/${archive}" "s3://${S3_BUCKET}/${archive}" ${S3_URL}
    ok "Uploaded to s3://${S3_BUCKET}/${archive}"

    # Cleanup
    rm -rf "${backup_dir}" "/tmp/${archive}"

    notify "✅ Bifrost backup completed: ${archive}"
    ok "Backup complete: ${archive}"
}

case "${1:-}" in
    --list|list)
        list_backups
        ;;
    --dry-run)
        log "Would backup:"
        log "  - config/config.json"
        log "  - config.db (from container volume)"
        log "  - logs.db (from container volume)"
        log "  -> s3://${S3_BUCKET:-kodemeio-bifrost-backup}/"
        ;;
    --help|-h|help)
        usage
        ;;
    *)
        do_backup
        ;;
esac
