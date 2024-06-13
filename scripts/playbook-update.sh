#!/bin/bash -x

log() {
    logger -t "$(basename $0)" "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Script is being run by user: $(whoami), HOME is set to: $HOME"

log_cmd() {
    local cmd="$1"
    log "Running $cmd"
    eval "$cmd" 2>&1 | tee >(logger -t "$(basename "$0")")
}

check_wg_gw() {
    if ping -c 1 10.13.7.100 > /dev/null; then
        log "Ping to 10.13.7.100 successful. No need to restart WireGuard."
        return 0
    else
        log "Ping to 10.13.7.100 failed. Restarting WireGuard."
        return 1
    fi
}

run() {
   if ! check_wg_gw; then
        log_cmd "/usr/bin/sudo /usr/bin/wg-quick down wg0"
        log_cmd "/usr/bin/sudo /usr/bin/wg-quick up wg0"
        sleep 10
        run
   else
        log_cmd "$HOME/.local/bin/ansible-playbook $HOME/ansible-playbooks/update.yml"
   fi
}

# Retry mechanism with exponential backoff
MAX_RETRIES=5
RETRY_COUNT=0
DELAY=1

# Loop until all commands are executed successfully
while true; do
    if run; then
        log "All commands executed successfully."
        break
    else
        log "An error occurred. Re-executing the script..."

	RETRY_COUNT=$((RETRY_COUNT+1))
        log "Waiting for $DELAY seconds before retrying..."
        sleep $DELAY
        DELAY=$((DELAY * 2))  # Exponential backoff
    fi
done

log_cmd "/usr/bin/sudo /usr/bin/wg-quick down wg0"

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log "Script failed after $MAX_RETRIES attempts."
fi
