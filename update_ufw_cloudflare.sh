#!/bin/bash
# Script for adding CF subnets to ufw (port 443)
# If necessary add to cron

CF_IPV4_URL="https://www.cloudflare.com/ips-v4"
CF_IPV6_URL="https://www.cloudflare.com/ips-v6"

LOG_FILE="/var/log/ufw_cloudflare_update.log"

log_message() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

if [[ $EUID -ne 0 ]]; then
   log_message "This script must be run as root." 
   exit 1
fi

log_message "Fetching Cloudflare IP ranges..."

CF_IPV4=$(curl -s "$CF_IPV4_URL")
CF_IPV6=$(curl -s "$CF_IPV6_URL")

if [[ -z "$CF_IPV4" || -z "$CF_IPV6" ]]; then
    log_message "Failed to retrieve Cloudflare IP ranges."
    exit 1
fi

log_message "Removing old Cloudflare UFW rules..."

rule_numbers=$(ufw status numbered | grep 'Cloudflare' | awk '{print $1}' | tr -d '[]')

for rule_number in $(echo "$rule_numbers" | tac); do
    if [ -n "$rule_number" ]; then
        log_message "Deleting rule number $rule_number"
        ufw --force delete "$rule_number"
    else
        log_message "No valid rule number found."
    fi
done

log_message "Adding new Cloudflare UFW rules..."

add_ufw_rules() {
    local ips="$1"
    local protocol="$2"

    while IFS= read -r ip; do
        log_message "Allowing $protocol traffic from $ip on port 443 (Cloudflare)"
        ufw allow from "$ip" to any port 443 proto tcp comment 'Cloudflare'
    done <<< "$ips"
}

add_ufw_rules "$CF_IPV4" "IPv4"

add_ufw_rules "$CF_IPV6" "IPv6"

log_message "Reloading UFW..."
ufw reload

log_message "UFW Cloudflare rules update completed."

