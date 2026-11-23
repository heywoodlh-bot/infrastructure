#!/usr/bin/env bash
# Keep heralding's log files from filling the /logs volume.
#
# Any file over MAX_LOG_BYTES is cut down to its newest KEEP_LOG_BYTES, on whole lines
# (CSV headers are preserved). Files are rewritten in place, never replaced, because
# heralding keeps them open for appending and would otherwise write to a deleted inode.
#
# Usage: prune-logs.sh            prune once
#        prune-logs.sh --loop     prune, then repeat every PRUNE_INTERVAL seconds

LOG_DIR="${LOG_DIR:-/logs}"
MAX_LOG_BYTES="${MAX_LOG_BYTES:-209715200}"   # 200MiB per file
KEEP_LOG_BYTES="${KEEP_LOG_BYTES:-104857600}" # 100MiB per file after pruning
PRUNE_INTERVAL="${PRUNE_INTERVAL:-600}"

prune_file() {
    local file="$1" has_header="$2" size tmp
    [ -f "${file}" ] || return 0
    size=$(stat -c %s "${file}")
    [ "${size}" -gt "${MAX_LOG_BYTES}" ] || return 0

    # Stage on the rootfs: the volume may be completely full.
    tmp=$(mktemp)
    {
        [ "${has_header}" = "csv" ] && head -n 1 "${file}"
        # The first line of the tail is almost always partial, so drop it.
        tail -c "${KEEP_LOG_BYTES}" "${file}" | tail -n +2
    } > "${tmp}"

    # Rewriting through the existing inode needs no extra space as the data only shrinks.
    cat "${tmp}" > "${file}"
    rm -f "${tmp}"
    echo "prune-logs: trimmed ${file} from ${size} to $(stat -c %s "${file}") bytes"
}

prune_all() {
    prune_file "${LOG_DIR}/log_session.json" json
    prune_file "${LOG_DIR}/log_session.csv" csv
    prune_file "${LOG_DIR}/log_auth.csv" csv
    prune_file "${LOG_DIR}/heralding.log" text
}

prune_all
if [ "$1" = "--loop" ]; then
    while sleep "${PRUNE_INTERVAL}"; do
        prune_all
    done
fi
