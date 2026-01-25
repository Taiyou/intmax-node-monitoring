#!/usr/bin/env bash
#=============================================================================
# INTMAX Reward Claimer
#
# Claims accumulated rewards from multiple nodes.
# Designed to be run via cron (e.g., weekly on Sundays at 3:00 PM).
#
# Usage:
#   ./claim_rewards.sh
#
# Prerequisites:
#   - SSH key authentication to each node
#   - INTMAX CLI installed on each node
#   - spend-key file accessible on each node
#=============================================================================

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_FILE="${SCRIPT_DIR}/claim_config.env"

# Colored output
info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Check config file
if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Config file not found: $CONFIG_FILE"
    echo "Please copy the example file:"
    echo "  cp ${SCRIPT_DIR}/claim_config.env.example ${CONFIG_FILE}"
    exit 1
fi

# Load config
# shellcheck source=/dev/null
source "$CONFIG_FILE"

# Validate NODES array
if [[ ${#NODES[@]} -eq 0 ]]; then
    error "No nodes configured in $CONFIG_FILE"
    echo "Example configuration:"
    echo '  NODES=('
    echo '      "user@192.168.1.10:/home/user/intmax2/cli:/etc/intmax-builder/spend-key"'
    echo '  )'
    exit 1
fi

echo "========================================"
echo " INTMAX Reward Claimer"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo

# Process each node
for node_config in "${NODES[@]}"; do
    # Parse config: user@host:cli_dir:spend_key_file
    IFS=':' read -r ssh_target cli_dir spend_key_file <<< "$node_config"

    info "Processing: $ssh_target"

    # Get spend key
    spend_key=$(ssh "$ssh_target" "cat $spend_key_file" 2>/dev/null)
    if [[ -z "$spend_key" ]]; then
        warn "  Failed to read spend-key from $spend_key_file"
        continue
    fi

    # Get CLI binary path
    binary_path="${cli_dir}/target/release/intmax2-cli"

    # Run claim command
    info "  Executing claim..."
    if ssh "$ssh_target" "cd $cli_dir && $binary_path claim --private-key $spend_key" 2>&1; then
        ok "  Claim successful"
    else
        warn "  Claim may have failed (check logs)"
    fi

    echo
done

echo "========================================"
ok "All nodes processed"
echo "========================================"
