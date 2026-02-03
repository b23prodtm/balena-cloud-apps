#!/usr/bin/env bash
# Portable logging library with systemd autodetect
# Backward‑compatible with original init_functions.sh

# ---------------------------------------------------------------------------
# LOG LEVELS
# ---------------------------------------------------------------------------

LOG_LEVEL="${LOG_LEVEL:-info}"

# Map log levels to numeric values
__log_level_num() {
    case "$1" in
        debug) echo 0 ;;
        info)  echo 1 ;;
        warn)  echo 2 ;;
        error) echo 3 ;;
        *)     echo 1 ;; # default to info
    esac
}

CURRENT_LEVEL_NUM="$(__log_level_num "$LOG_LEVEL")"

# ---------------------------------------------------------------------------
# SYSTEMD DETECTION
# ---------------------------------------------------------------------------

if command -v systemd-cat >/dev/null 2>&1; then
    __USE_SYSTEMD=1
else
    __USE_SYSTEMD=0
fi

# ---------------------------------------------------------------------------
# CORE LOGGER
# ---------------------------------------------------------------------------

__log() {
    local level="$1"; shift
    local msg="$*"

    local level_num="$(__log_level_num "$level")"

    # Skip messages below current log level
    if [ "$level_num" -lt "$CURRENT_LEVEL_NUM" ]; then
        return 0
    fi

    if [ "$__USE_SYSTEMD" -eq 1 ]; then
        # systemd logging
        systemd-cat --priority="$level" --identifier="$(basename "$0")" echo "$msg"
    else
        # portable fallback
        printf "[%s] %s: %s\n" "$(date +%H:%M:%S)" "$level" "$msg"
    fi
}

# ---------------------------------------------------------------------------
# PUBLIC API (backward compatible)
# ---------------------------------------------------------------------------

log_daemon_msg()   { __log info  "$*"; }
log_progress_msg() { __log info  "$*"; }
log_success_msg()  { __log info  "$*"; }
log_failure_msg()  { __log error "$*"; }

# Debug mode
if [ "${DEBUG:-0}" = "1" ]; then
    log_debug() { __log debug "$*"; }
else
    log_debug() { :; } # no-op
fi

# ---------------------------------------------------------------------------
# LOG FILE SUPPORT (optional)
# ---------------------------------------------------------------------------

new_log() {
    local script_name
    script_name="$(basename "$0")"

    LOG="/tmp/log/${script_name}/$(date +%Y%m%d_%H%M%S).log"
    mkdir -p "$(dirname "$LOG")"

    touch "$LOG" || {
        __log error "Failed to create log file: $LOG"
        return 1
    }

    __log info "Logging to $LOG"
}
