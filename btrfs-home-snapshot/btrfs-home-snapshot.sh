#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Check if /home-snapshots is a mounted btrfs subvolume
if ! (mount | grep -q "/home-snapshots" && btrfs subvolume show /home-snapshots &>/dev/null); then
    echo "/home-snapshots must be a mounted btrfs subvolume."
    exit 1
fi

# Create a snapshot
timestamp=$(date '+%Y%m%d-%H%M%S.%3N')
snapshot_name="boot-${timestamp}"
btrfs subvolume snapshot -r /home /home-snapshots/${snapshot_name}

# Clean up old snapshots
snapshots_to_keep=3
current_snapshots=($(ls -1t /home-snapshots | grep "^boot-"))
delete_candidates=($(find /home-snapshots -maxdepth 1 -type d -name "boot-*" -mtime +7 | sort))

for i in "${!delete_candidates[@]}"; do
    if [ "${#current_snapshots[@]}" -gt "${snapshots_to_keep}" ]; then
        btrfs subvolume delete "${delete_candidates[$i]}"
        current_snapshots=("${current_snapshots[@]:1}")
    else
        break
    fi
done
