#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Collect a timestamp
timestamp=$(date '+%Y%m%d-%H%M%S.%3N')

# Support multiple snapshots at once
create_snapshot() {
    # Check if SNAPSHOT_DEST is a mounted btrfs subvolume
    if ! (mount | grep -q "${SNAPSHOT_DEST:?}" && btrfs subvolume show ${SNAPSHOT_DEST:?} &>/dev/null); then
        echo "${SNAPSHOT_DEST:?} must be a mounted btrfs subvolume."
        exit 1
    fi

    # Create a snapshot
    snapshot_name="${SNAPSHOT_PREFIX:?}-${timestamp}"
    btrfs subvolume snapshot -r ${SNAPSHOT_SRC:?} ${SNAPSHOT_DEST:?}/${snapshot_name}

    # Clean up old snapshots
    snapshots_to_keep=3
    current_snapshots=($(ls -1t ${SNAPSHOT_DEST:?} | grep "^${SNAPSHOT_PREFIX:?}-"))
    delete_candidates=($(find "${SNAPSHOT_DEST:?}" -maxdepth 1 -type d -name "${SNAPSHOT_PREFIX:?}-*" -mtime +7 | sort))

    for i in "${!delete_candidates[@]}"; do
        if [ "${#current_snapshots[@]}" -gt "${snapshots_to_keep}" ]; then
            btrfs subvolume delete "${delete_candidates[$i]}"
            current_snapshots=("${current_snapshots[@]:1}")
        else
            break
        fi
    done
}

# Check arguments and call create_snapshot for every pair of 3 arguments
while [[ $# -ge 3 ]]; do
    SNAPSHOT_PREFIX="$1"
    SNAPSHOT_SRC="$2"
    SNAPSHOT_DEST="$3"
    create_snapshot
    shift 3
done

# If there are no more arguments, we are done
if [[ $# -gt 0 ]]; then
    echo "Done."
    exit 0
fi

# If there are arguments but less than 3, something is wrong
if [[ $# -lt 3 ]]; then
    echo >&2 "Invalid arguments. Expected: [SNAPSHOT_PREFIX SNAPSHOT_SRC SNAPSHOT_DEST]..."
fi
