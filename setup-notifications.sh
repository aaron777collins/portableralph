#!/bin/bash
# setup-notifications.sh - Interactive setup wizard for Ralph notifications
# Supports: Slack, Discord, Telegram, and Custom scripts
#
# Usage: ralph notify setup (or ~/ralph/setup-notifications.sh)
#
# This wizard will:
# 1. Ask which platforms you want to configure
# 2. Guide you through getting the credentials for each
# 3. Save configuration to ~/.ralph.env
# 4. Test the notifications

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$HOME/.ralph.env"

# Load constants
if [ -f "$RALPH_DIR/lib/constants.sh" ]; then
    source "$RALPH_DIR/lib/constants.sh"
fi

# Source shared validation library
source "${RALPH_DIR}/lib/validation.sh"

# All validation functions are now loaded from lib/validation.sh:
# - validate_webhook_url() / validate_url()
# - validate_email()
# - validate_file_path() / validate_path()
# - json_escape()
# - mask_token()
# - validate_numeric()

# Sanitize string input to prevent injection attacks
# Removes dangerous characters while preserving useful input
sanitize_string_input() {
    local input="$1"

    # Remove null bytes
    input="${input//$'\0'/}"

    # Remove control characters except tab and newline
    input="$(printf '%s' "$input" | tr -d '\000-\010\013\014\016-\037')"

    printf '%s' "$input"
}

# Validate Telegram token format
validate_telegram_token() {
    local token="$1"

    if [ -z "$token" ]; then
        return 0  # Empty is okay (user skipping)
    fi

    # Telegram bot tokens format: NNNNNNNNNN:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    # Where N is digits and X is alphanumeric
    if [[ ! "$token" =~ ^[0-9]{8,10}:[A-Za-z0-9_-]{35}$ ]]; then
        echo -e "${RED}Error: Invalid Telegram bot token format${NC}" >&2
        echo -e "${YELLOW}Expected format: 123456789:ABCdefGHI...${NC}" >&2
        return 1
    fi

    return 0
}

# Validate Telegram chat ID format
validate_telegram_chat_id() {
    local chat_id="$1"

    if [ -z "$chat_id" ]; then
        return 0  # Empty is okay
    fi

    # Chat IDs are integers (positive for users, negative for groups)
    if [[ ! "$chat_id" =~ ^-?[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid Telegram chat ID format${NC}" >&2
        echo -e "${YELLOW}Chat IDs must be numeric (e.g., 123456789 or -987654321 for groups)${NC}" >&2
        return 1
    fi

    return 0
}

# ============================================
# SECURITY: CREDENTIAL ENCRYPTION
# ============================================

# Encrypt sensitive value using openssl (if available)
encrypt_value() {
    local value="$1"

    # If openssl not available, store as plain text with warning
    if ! command -v openssl &>/dev/null; then
        echo "$value"
        return 0
    fi

    # Use cryptographically secure key derivation matching decrypt-env.sh
    # Uses PBKDF2 with high iteration count and machine-specific salt
    local machine_id
    machine_id=$(cat /etc/machine-id 2>/dev/null || echo 'default')

    # Create a cryptographically strong key material from multiple sources
    local key_material="${HOSTNAME:-localhost}:${USER:-unknown}:${machine_id}"

    # Use SHA256 to hash the key material for additional entropy
    local key_hash
    key_hash=$(echo -n "$key_material" | openssl dgst -sha256 -binary | base64)

    # Encrypt using PBKDF2 with 100000 iterations for strong key derivation
    local encrypted
    encrypted=$(echo -n "$value" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -pass "pass:$key_hash" -base64 2>/dev/null)

    if [ $? -eq 0 ]; then
        echo "ENC:$encrypted"
    else
        echo "$value"  # Fallback to plain text
    fi
}

# Check if encryption is available
encryption_available() {
    command -v openssl &>/dev/null && [ -f /etc/machine-id ]
}

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Ralph Notifications Setup Wizard${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "This wizard will help you configure notifications for Ralph."
echo -e "Your settings will be saved to: ${CYAN}$CONFIG_FILE${NC}"
echo ""

# Load existing config if present
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Existing configuration found.${NC}"
    read -p "Do you want to reconfigure? (y/N): " RECONFIGURE < /dev/tty
    if [[ ! "$RECONFIGURE" =~ ^[Yy]$ ]]; then
        echo "Keeping existing configuration."
        echo ""
        echo "To test notifications, run:"
        echo -e "  ${CYAN}ralph notify test${NC}"
        exit 0
    fi
    echo ""
fi

# Initialize config
SLACK_URL=""
DISCORD_URL=""
TELEGRAM_TOKEN=""
TELEGRAM_CHAT=""
EMAIL_TO=""
EMAIL_FROM=""
EMAIL_METHOD=""
SMTP_HOST=""
SMTP_PORT=""
SMTP_USER=""
SMTP_PASS=""
SENDGRID_KEY=""
AWS_REGION=""
AWS_KEY=""
AWS_SECRET=""
CUSTOM_SCRIPT=""

# ============================================
# PLATFORM SELECTION
# ============================================
echo -e "${BOLD}Which platforms do you want to configure?${NC}"
echo ""
echo "  1) Slack"
echo "  2) Discord"
echo "  3) Telegram"
echo "  4) Email (SMTP, SendGrid, or AWS SES)"
echo "  5) Custom script (for proprietary integrations)"
echo "  6) All standard platforms (1-4)"
echo "  7) Cancel"
echo ""
read -p "Enter your choice (1-7): " PLATFORM_CHOICE < /dev/tty

case "$PLATFORM_CHOICE" in
    1) SETUP_SLACK=true; SETUP_DISCORD=false; SETUP_TELEGRAM=false; SETUP_EMAIL=false; SETUP_CUSTOM=false ;;
    2) SETUP_SLACK=false; SETUP_DISCORD=true; SETUP_TELEGRAM=false; SETUP_EMAIL=false; SETUP_CUSTOM=false ;;
    3) SETUP_SLACK=false; SETUP_DISCORD=false; SETUP_TELEGRAM=true; SETUP_EMAIL=false; SETUP_CUSTOM=false ;;
    4) SETUP_SLACK=false; SETUP_DISCORD=false; SETUP_TELEGRAM=false; SETUP_EMAIL=true; SETUP_CUSTOM=false ;;
    5) SETUP_SLACK=false; SETUP_DISCORD=false; SETUP_TELEGRAM=false; SETUP_EMAIL=false; SETUP_CUSTOM=true ;;
    6) SETUP_SLACK=true; SETUP_DISCORD=true; SETUP_TELEGRAM=true; SETUP_EMAIL=true; SETUP_CUSTOM=false ;;
    7) echo "Setup cancelled."; exit 0 ;;
    *) echo -e "${RED}Invalid choice. Exiting.${NC}"; exit 1 ;;
esac

# ============================================
# SLACK SETUP
# ============================================
if [ "$SETUP_SLACK" = true ]; then
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Slack Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "To get a Slack webhook URL:"
    echo ""
    echo -e "  1. Go to: ${CYAN}https://api.slack.com/apps${NC}"
    echo "  2. Click 'Create New App' > 'From scratch'"
    echo "  3. Name it 'Ralph' and select your workspace"
    echo "  4. Go to 'Incoming Webhooks' in the sidebar"
    echo "  5. Toggle 'Activate Incoming Webhooks' ON"
    echo "  6. Click 'Add New Webhook to Workspace'"
    echo "  7. Select the channel and click 'Allow'"
    echo "  8. Copy the webhook URL"
    echo ""
    read -p "Paste your Slack webhook URL (or press Enter to skip): " SLACK_URL < /dev/tty
    SLACK_URL=$(sanitize_string_input "$SLACK_URL")

    if [ -n "$SLACK_URL" ]; then
        if validate_webhook_url "$SLACK_URL" "Slack"; then
            echo -e "${GREEN}Slack webhook configured.${NC}"
        else
            echo -e "${YELLOW}Invalid Slack webhook URL. Skipping Slack.${NC}"
            SLACK_URL=""
        fi
    else
        echo -e "${YELLOW}Slack skipped.${NC}"
    fi
fi

# ============================================
# DISCORD SETUP
# ============================================
if [ "$SETUP_DISCORD" = true ]; then
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Discord Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "To get a Discord webhook URL:"
    echo ""
    echo "  1. Open your Discord server"
    echo "  2. Right-click the channel > 'Edit Channel'"
    echo "  3. Go to 'Integrations' > 'Webhooks'"
    echo "  4. Click 'New Webhook'"
    echo "  5. Name it 'Ralph' and click 'Copy Webhook URL'"
    echo ""
    read -p "Paste your Discord webhook URL (or press Enter to skip): " DISCORD_URL < /dev/tty
    DISCORD_URL=$(sanitize_string_input "$DISCORD_URL")

    if [ -n "$DISCORD_URL" ]; then
        if validate_webhook_url "$DISCORD_URL" "Discord"; then
            echo -e "${GREEN}Discord webhook configured.${NC}"
        else
            echo -e "${YELLOW}Invalid Discord webhook URL. Skipping Discord.${NC}"
            DISCORD_URL=""
        fi
    else
        echo -e "${YELLOW}Discord skipped.${NC}"
    fi
fi

# ============================================
# TELEGRAM SETUP
# ============================================
if [ "$SETUP_TELEGRAM" = true ]; then
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Telegram Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "To set up Telegram notifications:"
    echo ""
    echo -e "  ${BOLD}Step 1: Create a bot${NC}"
    echo "  1. Open Telegram and search for @BotFather"
    echo "  2. Send /newbot and follow the prompts"
    echo "  3. Copy the bot token (looks like: 123456789:ABCdefGHI...)"
    echo ""
    read -p "Paste your bot token (or press Enter to skip): " TELEGRAM_TOKEN < /dev/tty
    TELEGRAM_TOKEN=$(sanitize_string_input "$TELEGRAM_TOKEN")

    if [ -n "$TELEGRAM_TOKEN" ]; then
        # Validate token format
        if ! validate_telegram_token "$TELEGRAM_TOKEN"; then
            echo -e "${YELLOW}Telegram skipped (invalid token format).${NC}"
            TELEGRAM_TOKEN=""
        else
            echo ""
            echo -e "  ${BOLD}Step 2: Get your chat ID${NC}"
            echo "  1. Start a chat with your new bot (search for it and click Start)"
            echo "  2. Send any message to the bot"
            echo "  3. Visit this URL in your browser:"
            # Safely display URL without executing any embedded commands
            printf '     %bhttps://api.telegram.org/bot%s/getUpdates%b\n' "${CYAN}" "${TELEGRAM_TOKEN}" "${NC}"
            echo "  4. Look for \"chat\":{\"id\":YOUR_CHAT_ID}"
            echo ""
            echo "  For group chats: Add the bot to the group, send a message,"
            echo "  then check getUpdates. Group IDs are negative numbers."
            echo ""
            read -p "Paste your chat ID: " TELEGRAM_CHAT < /dev/tty
            TELEGRAM_CHAT=$(sanitize_string_input "$TELEGRAM_CHAT")

            if [ -n "$TELEGRAM_CHAT" ]; then
                # Validate chat ID format
                if validate_telegram_chat_id "$TELEGRAM_CHAT"; then
                    echo -e "${GREEN}Telegram configured.${NC}"
                else
                    echo -e "${YELLOW}Telegram skipped (invalid chat ID).${NC}"
                    TELEGRAM_TOKEN=""
                    TELEGRAM_CHAT=""
                fi
            else
                echo -e "${YELLOW}Telegram skipped (no chat ID).${NC}"
                TELEGRAM_TOKEN=""
            fi
        fi
    else
        echo -e "${YELLOW}Telegram skipped.${NC}"
    fi
fi

# ============================================
# EMAIL SETUP
# ============================================
if [ "$SETUP_EMAIL" = true ]; then
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Email Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Email notifications support three delivery methods:"
    echo "  1) SMTP (traditional mail server)"
    echo "  2) SendGrid API (cloud email service)"
    echo "  3) AWS SES (Amazon Simple Email Service)"
    echo ""

    # Get basic email info
    read -p "Recipient email address (To): " EMAIL_TO < /dev/tty
    EMAIL_TO=$(sanitize_string_input "$EMAIL_TO")

    if [ -z "$EMAIL_TO" ]; then
        echo -e "${YELLOW}Email skipped (no recipient).${NC}"
    elif ! validate_email "$EMAIL_TO" "Recipient email"; then
        echo -e "${YELLOW}Email skipped (invalid recipient email).${NC}"
        EMAIL_TO=""
    else
        read -p "Sender email address (From): " EMAIL_FROM < /dev/tty
        EMAIL_FROM=$(sanitize_string_input "$EMAIL_FROM")

        if [ -z "$EMAIL_FROM" ]; then
            echo -e "${YELLOW}Email skipped (no sender).${NC}"
            EMAIL_TO=""
        elif ! validate_email "$EMAIL_FROM" "Sender email"; then
            echo -e "${YELLOW}Email skipped (invalid sender email).${NC}"
            EMAIL_TO=""
            EMAIL_FROM=""
        else
            echo ""
            echo "Choose email delivery method:"
            echo "  1) SMTP (Gmail, Outlook, etc.)"
            echo "  2) SendGrid API"
            echo "  3) AWS SES"
            echo ""
            read -p "Enter your choice (1-3): " EMAIL_METHOD_CHOICE < /dev/tty

            case "$EMAIL_METHOD_CHOICE" in
                1)
                    # SMTP Setup
                    echo ""
                    echo -e "${BOLD}SMTP Configuration${NC}"
                    echo ""
                    echo "Common SMTP servers:"
                    echo "  Gmail: smtp.gmail.com (port 587)"
                    echo "  Outlook: smtp-mail.outlook.com (port 587)"
                    echo "  Yahoo: smtp.mail.yahoo.com (port 587)"
                    echo ""
                    read -p "SMTP host: " SMTP_HOST < /dev/tty
                    SMTP_HOST=$(sanitize_string_input "$SMTP_HOST")
                    read -p "SMTP port (default 587): " SMTP_PORT < /dev/tty
                    SMTP_PORT=$(sanitize_string_input "$SMTP_PORT")
                    SMTP_PORT="${SMTP_PORT:-587}"
                    # Validate port is numeric
                    if [[ ! "$SMTP_PORT" =~ ^[0-9]+$ ]] || [ "$SMTP_PORT" -lt 1 ] || [ "$SMTP_PORT" -gt 65535 ]; then
                        echo -e "${RED}Invalid port number. Using default 587.${NC}"
                        SMTP_PORT="587"
                    fi
                    read -p "SMTP username: " SMTP_USER < /dev/tty
                    SMTP_USER=$(sanitize_string_input "$SMTP_USER")
                    read -sp "SMTP password: " SMTP_PASS < /dev/tty
                    SMTP_PASS=$(sanitize_string_input "$SMTP_PASS")
                    echo ""

                    if [ -n "$SMTP_HOST" ] && [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASS" ]; then
                        EMAIL_METHOD="smtp"
                        echo -e "${GREEN}SMTP configured.${NC}"
                    else
                        echo -e "${YELLOW}Email skipped (incomplete SMTP configuration).${NC}"
                        EMAIL_TO=""
                        EMAIL_FROM=""
                    fi
                    ;;
                2)
                    # SendGrid Setup
                    echo ""
                    echo -e "${BOLD}SendGrid API Configuration${NC}"
                    echo ""
                    echo "To get a SendGrid API key:"
                    echo "  1. Sign up at https://sendgrid.com"
                    echo "  2. Go to Settings > API Keys"
                    echo "  3. Create a new API key with 'Mail Send' permission"
                    echo "  4. Copy the API key (starts with 'SG.')"
                    echo ""
                    read -sp "SendGrid API key: " SENDGRID_KEY < /dev/tty
                    SENDGRID_KEY=$(sanitize_string_input "$SENDGRID_KEY")
                    echo ""

                    if [ -n "$SENDGRID_KEY" ]; then
                        EMAIL_METHOD="sendgrid"
                        echo -e "${GREEN}SendGrid configured.${NC}"
                    else
                        echo -e "${YELLOW}Email skipped (no API key).${NC}"
                        EMAIL_TO=""
                        EMAIL_FROM=""
                    fi
                    ;;
                3)
                    # AWS SES Setup
                    echo ""
                    echo -e "${BOLD}AWS SES Configuration${NC}"
                    echo ""
                    echo "Prerequisites:"
                    echo "  1. AWS CLI installed (apt install awscli)"
                    echo "  2. SES verified sender email address"
                    echo "  3. IAM user with SES permissions"
                    echo ""
                    read -p "AWS region (e.g., us-east-1): " AWS_REGION < /dev/tty
                    AWS_REGION=$(sanitize_string_input "$AWS_REGION")
                    read -p "AWS Access Key ID: " AWS_KEY < /dev/tty
                    AWS_KEY=$(sanitize_string_input "$AWS_KEY")
                    read -sp "AWS Secret Access Key: " AWS_SECRET < /dev/tty
                    AWS_SECRET=$(sanitize_string_input "$AWS_SECRET")
                    echo ""

                    if [ -n "$AWS_REGION" ] && [ -n "$AWS_KEY" ] && [ -n "$AWS_SECRET" ]; then
                        EMAIL_METHOD="ses"
                        echo -e "${GREEN}AWS SES configured.${NC}"
                    else
                        echo -e "${YELLOW}Email skipped (incomplete AWS configuration).${NC}"
                        EMAIL_TO=""
                        EMAIL_FROM=""
                    fi
                    ;;
                *)
                    echo -e "${YELLOW}Invalid choice. Email skipped.${NC}"
                    EMAIL_TO=""
                    EMAIL_FROM=""
                    ;;
            esac
        fi
    fi
fi

# ============================================
# CUSTOM SCRIPT SETUP
# ============================================
if [ "$SETUP_CUSTOM" = true ]; then
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Custom Script Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Custom scripts let you integrate with proprietary systems."
    echo "Your script receives the notification message as \$1."
    echo ""
    echo -e "${BOLD}How it works:${NC}"
    echo "  1. Create a script that accepts a message argument"
    echo "  2. Your script handles delivery (API call, database insert, etc.)"
    echo "  3. Ralph calls your script for each notification"
    echo ""
    echo -e "${BOLD}Example script (my-notify.sh):${NC}"
    echo -e "  ${CYAN}#!/bin/bash"
    echo -e "  MESSAGE=\"\$1\""
    echo -e "  curl -X POST -d \"text=\$MESSAGE\" https://your.api/notify${NC}"
    echo ""
    echo -e "${BOLD}Use cases:${NC}"
    echo "  - Database-to-Slack bridge (insert into DB, service posts to Slack)"
    echo "  - Internal company notification API"
    echo "  - SMS or email gateway"
    echo "  - Custom webhook format"
    echo ""
    read -p "Path to your notification script (or press Enter to skip): " CUSTOM_SCRIPT < /dev/tty

    if [ -n "$CUSTOM_SCRIPT" ]; then
        # Validate path before processing
        if ! validate_file_path "$CUSTOM_SCRIPT" "Script path"; then
            echo -e "${YELLOW}Custom script skipped (invalid path).${NC}"
            CUSTOM_SCRIPT=""
        else
            # Expand ~ to home directory (safe after validation)
            CUSTOM_SCRIPT="${CUSTOM_SCRIPT/#\~/$HOME}"

            # Convert to absolute path if relative (for security)
            if [[ ! "$CUSTOM_SCRIPT" =~ ^/ ]]; then
                CUSTOM_SCRIPT="$(cd "$(dirname "$CUSTOM_SCRIPT")" 2>/dev/null && pwd)/$(basename "$CUSTOM_SCRIPT")" || CUSTOM_SCRIPT=""
            fi

            if [ -z "$CUSTOM_SCRIPT" ]; then
                echo -e "${YELLOW}Custom script skipped (invalid path).${NC}"
            elif [ -x "$CUSTOM_SCRIPT" ]; then
                echo -e "${GREEN}Custom script configured: $CUSTOM_SCRIPT${NC}"
            elif [ -f "$CUSTOM_SCRIPT" ]; then
                echo -e "${YELLOW}Warning: Script exists but is not executable.${NC}"
                read -p "Make it executable? (Y/n): " MAKE_EXEC < /dev/tty
                if [[ ! "$MAKE_EXEC" =~ ^[Nn]$ ]]; then
                    chmod +x "$CUSTOM_SCRIPT" 2>/dev/null || {
                        echo -e "${RED}Failed to make script executable. Check permissions.${NC}"
                        CUSTOM_SCRIPT=""
                    }
                    if [ -n "$CUSTOM_SCRIPT" ]; then
                        echo -e "${GREEN}Made executable. Custom script configured.${NC}"
                    fi
                else
                    echo -e "${YELLOW}Custom script skipped (not executable).${NC}"
                    CUSTOM_SCRIPT=""
                fi
            else
                echo -e "${YELLOW}Warning: Script not found at $CUSTOM_SCRIPT${NC}"
                echo "Make sure the script exists before running Ralph."
            fi
        fi
    else
        echo -e "${YELLOW}Custom script skipped.${NC}"
    fi
fi

# ============================================
# SAVE CONFIGURATION
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Saving Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if anything was configured
if [ -z "$SLACK_URL" ] && [ -z "$DISCORD_URL" ] && [ -z "$TELEGRAM_TOKEN" ] && [ -z "$EMAIL_TO" ] && [ -z "$CUSTOM_SCRIPT" ]; then
    echo -e "${YELLOW}No platforms were configured.${NC}"
    echo "Run this wizard again when you're ready."
    exit 0
fi

# Write config file with encrypted sensitive values
cat > "$CONFIG_FILE" << EOF
# Ralph Notification Configuration
# Generated by setup-notifications.sh on $(date)
# Source this file in your shell: source ~/.ralph.env
#
# NOTE: Sensitive values (webhook URLs, tokens) are encrypted using AES-256-CBC
# They are automatically decrypted when loaded. Encryption is machine-specific.

EOF

# Display encryption status
if encryption_available; then
    echo -e "${GREEN}Using AES-256 encryption for sensitive values${NC}"
    echo "# Encryption: ENABLED (openssl AES-256-CBC with PBKDF2)" >> "$CONFIG_FILE"
else
    echo -e "${YELLOW}Warning: openssl not available, credentials will be stored in plain text${NC}"
    echo -e "${YELLOW}Install openssl for enhanced security: apt-get install openssl${NC}"
    echo "# Encryption: DISABLED (install openssl for encryption)" >> "$CONFIG_FILE"
fi
echo "" >> "$CONFIG_FILE"

if [ -n "$SLACK_URL" ]; then
    echo "# Slack" >> "$CONFIG_FILE"
    encrypted_slack=$(encrypt_value "$SLACK_URL")
    echo "export RALPH_SLACK_WEBHOOK_URL=\"$encrypted_slack\"" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
fi

if [ -n "$DISCORD_URL" ]; then
    echo "# Discord" >> "$CONFIG_FILE"
    encrypted_discord=$(encrypt_value "$DISCORD_URL")
    echo "export RALPH_DISCORD_WEBHOOK_URL=\"$encrypted_discord\"" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
fi

if [ -n "$TELEGRAM_TOKEN" ]; then
    echo "# Telegram" >> "$CONFIG_FILE"
    encrypted_token=$(encrypt_value "$TELEGRAM_TOKEN")
    encrypted_chat=$(encrypt_value "$TELEGRAM_CHAT")
    echo "export RALPH_TELEGRAM_BOT_TOKEN=\"$encrypted_token\"" >> "$CONFIG_FILE"
    echo "export RALPH_TELEGRAM_CHAT_ID=\"$encrypted_chat\"" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
fi

if [ -n "$EMAIL_TO" ]; then
    echo "# Email" >> "$CONFIG_FILE"
    echo "export RALPH_EMAIL_TO=\"$EMAIL_TO\"" >> "$CONFIG_FILE"
    echo "export RALPH_EMAIL_FROM=\"$EMAIL_FROM\"" >> "$CONFIG_FILE"

    if [ "$EMAIL_METHOD" = "smtp" ]; then
        encrypted_pass
        encrypted_pass=$(encrypt_value "$SMTP_PASS")
        echo "export RALPH_SMTP_HOST=\"$SMTP_HOST\"" >> "$CONFIG_FILE"
        echo "export RALPH_SMTP_PORT=\"$SMTP_PORT\"" >> "$CONFIG_FILE"
        echo "export RALPH_SMTP_USER=\"$SMTP_USER\"" >> "$CONFIG_FILE"
        echo "export RALPH_SMTP_PASSWORD=\"$encrypted_pass\"" >> "$CONFIG_FILE"
        echo "export RALPH_SMTP_TLS=\"true\"" >> "$CONFIG_FILE"
    elif [ "$EMAIL_METHOD" = "sendgrid" ]; then
        encrypted_key
        encrypted_key=$(encrypt_value "$SENDGRID_KEY")
        echo "export RALPH_SENDGRID_API_KEY=\"$encrypted_key\"" >> "$CONFIG_FILE"
    elif [ "$EMAIL_METHOD" = "ses" ]; then
        encrypted_secret
        encrypted_secret=$(encrypt_value "$AWS_SECRET")
        echo "export RALPH_AWS_SES_REGION=\"$AWS_REGION\"" >> "$CONFIG_FILE"
        echo "export RALPH_AWS_ACCESS_KEY_ID=\"$AWS_KEY\"" >> "$CONFIG_FILE"
        echo "export RALPH_AWS_SECRET_KEY=\"$encrypted_secret\"" >> "$CONFIG_FILE"
    fi

    # Email options
    echo "export RALPH_EMAIL_HTML=\"true\"" >> "$CONFIG_FILE"
    batch_delay="${EMAIL_BATCH_DELAY_DEFAULT:-300}"
    batch_max="${EMAIL_BATCH_MAX_DEFAULT:-10}"
    echo "export RALPH_EMAIL_BATCH_DELAY=\"$batch_delay\"  # $(($batch_delay / 60)) minutes" >> "$CONFIG_FILE"
    echo "export RALPH_EMAIL_BATCH_MAX=\"$batch_max\"" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
fi

if [ -n "$CUSTOM_SCRIPT" ]; then
    echo "# Custom Script" >> "$CONFIG_FILE"
    echo "export RALPH_CUSTOM_NOTIFY_SCRIPT=\"$CUSTOM_SCRIPT\"" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
fi

chmod 600 "$CONFIG_FILE"
echo -e "${GREEN}Configuration saved to: $CONFIG_FILE${NC}"
echo -e "${GREEN}File permissions set to 600 (owner read/write only)${NC}"

# ============================================
# SOURCE AND TEST
# ============================================
echo ""
echo -e "${BOLD}Loading configuration...${NC}"
source "$CONFIG_FILE"

echo ""
read -p "Do you want to send a test notification? (Y/n): " TEST_NOW < /dev/tty
if [[ ! "$TEST_NOW" =~ ^[Nn]$ ]]; then
    echo ""
    "$RALPH_DIR/notify.sh" --test
fi

# ============================================
# FINAL INSTRUCTIONS
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "To enable notifications in new terminal sessions, add this to your"
echo "shell profile (~/.bashrc or ~/.zshrc):"
echo ""
echo -e "  ${CYAN}source ~/.ralph.env${NC}"
echo ""
echo "Or run this command now:"
echo ""
echo -e "  ${CYAN}echo 'source ~/.ralph.env' >> ~/.bashrc${NC}"
echo ""
echo "Test notifications anytime with:"
echo ""
echo -e "  ${CYAN}ralph notify test${NC}"
echo ""
