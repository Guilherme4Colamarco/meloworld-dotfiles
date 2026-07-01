#!/bin/bash
set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOUND_FILE="${DOTFILES_DIR}/assets/sounds/chime.flac"
LOG_FILE="${DOTFILES_DIR}/logs/chime.log"
MAX_WAIT=30  # seconds before giving up on PipeWire

# --- Logging ---
mkdir -p "$(dirname "${LOG_FILE}")"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}"
}

# --- Wait for PipeWire with timeout ---
start_time=${SECONDS}
while ! pw-cli info 0 &>/dev/null; do
    elapsed=$(( SECONDS - start_time ))
    if (( elapsed >= MAX_WAIT )); then
        log "ERROR: PipeWire not available after ${MAX_WAIT}s, aborting chime"
        exit 1
    fi
    sleep 0.3
done

elapsed=$(( SECONDS - start_time ))
log "PipeWire ready after ${elapsed}s"

# --- Play chime ---
sleep 0.3
if [[ ! -f "${SOUND_FILE}" ]]; then
    log "ERROR: Sound file not found: ${SOUND_FILE}"
    exit 1
fi

if pw-play "${SOUND_FILE}" 2>>"${LOG_FILE}"; then
    log "Chime played successfully"
else
    log "ERROR: pw-play failed for ${SOUND_FILE}"
    exit 1
fi
