#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# Journald logging with LOG_LEVEL filtering
# ---------------------------------------------------------------------------

# If DEBUG=1, force debug logging
if [[ "${DEBUG:-0}" == "1" ]]; then
    LOG_LEVEL="debug"
else
    LOG_LEVEL="${LOG_LEVEL:-info}"
fi

__level_num() {
    case "$1" in
        debug) echo 0 ;;
        info)  echo 1 ;;
        warn)  echo 2 ;;
        error) echo 3 ;;
        *)     echo 1 ;;
    esac
}

CURRENT_LEVEL_NUM="$(__level_num "$LOG_LEVEL")"


# Journald priority mapping
__journal_prio() {
    case "$1" in
        debug) echo "debug" ;;
        info)  echo "info" ;;
        warn)  echo "warning" ;;
        error) echo "err" ;;
        *)     echo "info" ;;
    esac
}

# Generic journald logger
__log() {
    local level="$1"; shift
    local level_num="$(__level_num "$level")"

    # Skip messages below LOG_LEVEL
    if (( level_num < CURRENT_LEVEL_NUM )); then
        return
    fi

    local prio="$(__journal_prio "$level")"

    # Send to journald with metadata
    systemd-cat \
        --priority="$prio" \
        --identifier="$(basename "$0")" \
        echo "$*"
}

# ---------------------------------------------------------------------------
# Required function names (journald‑native)
# ---------------------------------------------------------------------------

log_daemon_msg() {
    __log info "$*"
}

log_progress_msg() {
    __log debug "$*"
}

log_warning_msg() {
    __log warn "$*"
}

log_failure_msg() {
    __log error "$*"
}

log_success_msg() {
    __log info "$*"
}

log_end_msg() {
    case "$1" in
        0)
            __log info "Completed successfully"
            ;;
        *)
            __log error "Completed with errors (code $1)"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Syslog fallback (rarely needed on systemd systems)
# ---------------------------------------------------------------------------

slogger() {
    if [[ -S /dev/log ]]; then
        logger "$@"
        return
    fi
    __log info "$@"
}

# ---------------------------------------------------------------------------
# Utility functions (unchanged behavior, improved logging)
# ---------------------------------------------------------------------------

log_size() {
    if [[ $# -eq 0 ]]; then
        __log error "File not found"
        return 1
    fi
    wc -l "$1" | awk '{print "num_entries="$1}'
}

LOG_MAX_ROLLOUT="${LOG_MAX_ROLLOUT:-500}"

new_log() {
    local temp="/tmp/log/$(basename "$0" .sh)"
    local folder="${1:-$temp}"
    local filename="${2:-$(date +%Y-%m-%d_%H:%M).log}"

    LOG="$(cd "$folder" && pwd)/$filename"
    mkdir -p "$(dirname "$LOG")"
    touch "$LOG"
    chmod 1777 "$LOG"

    local count
    count=$(log_size "$LOG" | cut -d= -f2)
    if (( count > LOG_MAX_ROLLOUT )); then
        mv "$LOG" "$LOG.$(date +%Y-%m-%d_%H:%M)"
        new_log "$@"
        return
    fi

    printf "%s\n" "$LOG"
}

check_log() {
    if [[ -f "$LOG" ]]; then
        __log info "Log file available at $LOG"
    fi
}
