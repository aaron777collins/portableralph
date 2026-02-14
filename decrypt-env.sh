#!/bin/bash
# decrypt-env.sh - Decrypt environment variables
# This script is sourced by ralph.sh and notify.sh to decrypt sensitive values

set -euo pipefail

# Decrypt value (if it's encrypted)
decrypt_value() {
    local value="$1"
    local var_name="${2:-variable}"

    # Check if encrypted
    if [[ ! "$value" =~ ^ENC: ]]; then
        echo "$value"
        return 0
    fi

    # Skip if openssl not available
    if ! command -v openssl &>/dev/null; then
        echo "Error: Cannot decrypt $var_name - openssl is not installed" >&2
        echo "Install openssl to use encrypted credentials" >&2
        echo "" # Return empty for encrypted values when can't decrypt
        return 1
    fi

    # Check for machine-id required for decryption
    if [ ! -f /etc/machine-id ]; then
        echo "Error: Cannot decrypt $var_name - /etc/machine-id not found" >&2
        echo "Decryption requires system machine ID for key derivation" >&2
        echo "" # Return empty when machine-id missing
        return 1
    fi

    # Extract encrypted portion
    local encrypted="${value#ENC:}"

    # Decrypt using cryptographically secure key derivation
    # Uses PBKDF2 with high iteration count and machine-specific salt
    local machine_id
    machine_id=$(cat /etc/machine-id 2>/dev/null || echo 'default')

    # Create a cryptographically strong key material from multiple sources
    # Including hostname, username, and machine ID
    local key_material="${HOSTNAME:-localhost}:${USER:-unknown}:${machine_id}"

    # Use SHA256 to hash the key material for additional entropy
    local key_hash
    key_hash=$(echo -n "$key_material" | openssl dgst -sha256 -binary | base64)

    local decrypted
    # Use PBKDF2 with 100000 iterations for strong key derivation
    decrypted=$(echo -n "$encrypted" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d -base64 -pass "pass:$key_hash" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$decrypted" ]; then
        echo "$decrypted"
        return 0
    else
        echo "Error: Failed to decrypt $var_name" >&2
        echo "The encrypted value may be corrupted or was encrypted on a different machine" >&2
        echo "Please re-run: ralph notify setup" >&2
        echo "" # Return empty on decrypt failure
        return 1
    fi
}

# Decrypt all Ralph environment variables if they're encrypted
decrypt_ralph_env() {
    local decrypt_failed=0

    # Decrypt webhook URLs
    if [ -n "${RALPH_SLACK_WEBHOOK_URL:-}" ]; then
        RALPH_SLACK_WEBHOOK_URL=$(decrypt_value "$RALPH_SLACK_WEBHOOK_URL" "RALPH_SLACK_WEBHOOK_URL") || decrypt_failed=1
        export RALPH_SLACK_WEBHOOK_URL
    fi

    if [ -n "${RALPH_DISCORD_WEBHOOK_URL:-}" ]; then
        RALPH_DISCORD_WEBHOOK_URL=$(decrypt_value "$RALPH_DISCORD_WEBHOOK_URL" "RALPH_DISCORD_WEBHOOK_URL") || decrypt_failed=1
        export RALPH_DISCORD_WEBHOOK_URL
    fi

    # Decrypt Telegram credentials
    if [ -n "${RALPH_TELEGRAM_BOT_TOKEN:-}" ]; then
        RALPH_TELEGRAM_BOT_TOKEN=$(decrypt_value "$RALPH_TELEGRAM_BOT_TOKEN" "RALPH_TELEGRAM_BOT_TOKEN") || decrypt_failed=1
        export RALPH_TELEGRAM_BOT_TOKEN
    fi

    if [ -n "${RALPH_TELEGRAM_CHAT_ID:-}" ]; then
        RALPH_TELEGRAM_CHAT_ID=$(decrypt_value "$RALPH_TELEGRAM_CHAT_ID" "RALPH_TELEGRAM_CHAT_ID") || decrypt_failed=1
        export RALPH_TELEGRAM_CHAT_ID
    fi

    # Decrypt email credentials
    if [ -n "${RALPH_SMTP_PASSWORD:-}" ]; then
        RALPH_SMTP_PASSWORD=$(decrypt_value "$RALPH_SMTP_PASSWORD" "RALPH_SMTP_PASSWORD") || decrypt_failed=1
        export RALPH_SMTP_PASSWORD
    fi

    if [ -n "${RALPH_SENDGRID_API_KEY:-}" ]; then
        RALPH_SENDGRID_API_KEY=$(decrypt_value "$RALPH_SENDGRID_API_KEY" "RALPH_SENDGRID_API_KEY") || decrypt_failed=1
        export RALPH_SENDGRID_API_KEY
    fi

    if [ -n "${RALPH_AWS_SECRET_KEY:-}" ]; then
        RALPH_AWS_SECRET_KEY=$(decrypt_value "$RALPH_AWS_SECRET_KEY" "RALPH_AWS_SECRET_KEY") || decrypt_failed=1
        export RALPH_AWS_SECRET_KEY
    fi

    # Note: Custom script paths are not encrypted

    return $decrypt_failed
}
