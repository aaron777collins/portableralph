#!/bin/bash
#
# PortableRalph Installer
# https://github.com/aaron777collins/portableralph
#
# Usage:
#   Interactive:  curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash
#   Headless:     curl -fsSL ... | bash -s -- --headless --slack-webhook "https://..."
#
# Options:
#   --headless                    Non-interactive mode
#   --install-dir DIR             Install location (default: ~/ralph)
#   --slack-webhook URL           Slack webhook URL
#   --discord-webhook URL         Discord webhook URL
#   --telegram-token TOKEN        Telegram bot token
#   --telegram-chat ID            Telegram chat ID
#   --custom-script PATH          Custom notification script path
#   --skip-notifications          Skip notification setup
#   --skip-shell-config           Don't modify shell config
#   --help                        Show this help
#

set -euo pipefail

# ============================================
# CONFIGURATION
# ============================================

VERSION="1.4.0"
REPO_URL="https://github.com/aaron777collins/portableralph.git"
DEFAULT_INSTALL_DIR="$HOME/ralph"

# Colors (disabled in headless mode or non-tty)
setup_colors() {
    if [[ -t 1 ]] && [[ "${HEADLESS:-false}" != "true" ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        MAGENTA='\033[0;35m'
        BOLD='\033[1m'
        DIM='\033[2m'
        NC='\033[0m'
    else
        RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' BOLD='' DIM='' NC=''
    fi
}

# ============================================
# ARGUMENT PARSING
# ============================================

HEADLESS=false
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
SLACK_WEBHOOK=""
DISCORD_WEBHOOK=""
TELEGRAM_TOKEN=""
TELEGRAM_CHAT=""
CUSTOM_SCRIPT=""
SKIP_NOTIFICATIONS=false
SKIP_SHELL_CONFIG=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --headless)
                HEADLESS=true
                shift
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --slack-webhook)
                SLACK_WEBHOOK="$2"
                shift 2
                ;;
            --discord-webhook)
                DISCORD_WEBHOOK="$2"
                shift 2
                ;;
            --telegram-token)
                TELEGRAM_TOKEN="$2"
                shift 2
                ;;
            --telegram-chat)
                TELEGRAM_CHAT="$2"
                shift 2
                ;;
            --custom-script)
                CUSTOM_SCRIPT="$2"
                shift 2
                ;;
            --skip-notifications)
                SKIP_NOTIFICATIONS=true
                shift
                ;;
            --skip-shell-config)
                SKIP_SHELL_CONFIG=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
PortableRalph Installer

Usage:
  ./install.sh [options]

Options:
  --headless                Non-interactive mode (for scripts/CI)
  --install-dir DIR         Install location (default: ~/ralph)
  --slack-webhook URL       Slack webhook URL
  --discord-webhook URL     Discord webhook URL
  --telegram-token TOKEN    Telegram bot token
  --telegram-chat ID        Telegram chat ID
  --custom-script PATH      Custom notification script
  --skip-notifications      Skip notification setup
  --skip-shell-config       Don't modify ~/.bashrc or ~/.zshrc
  --help                    Show this help

Examples:
  # Interactive install
  ./install.sh

  # Headless with Slack
  ./install.sh --headless --slack-webhook "https://hooks.slack.com/..."

  # Custom install location
  ./install.sh --install-dir /opt/ralph

  # Headless, skip everything optional
  ./install.sh --headless --skip-notifications --skip-shell-config
EOF
}

# ============================================
# UTILITIES
# ============================================

log() {
    echo -e "${GREEN}▸${NC} $1"
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✖${NC} $1" >&2
}

success() {
    echo -e "${GREEN}✔${NC} $1"
}

prompt() {
    local prompt_text="$1"
    local default="${2:-}"
    local result

    if [[ "$HEADLESS" == "true" ]]; then
        echo "$default"
        return
    fi

    if [[ -n "$default" ]]; then
        echo -en "${CYAN}?${NC} ${prompt_text} ${DIM}[$default]${NC}: "
        read -r result
        echo "${result:-$default}"
    else
        echo -en "${CYAN}?${NC} ${prompt_text}: "
        read -r result
        echo "$result"
    fi
}

prompt_yn() {
    local prompt_text="$1"
    local default="${2:-y}"

    if [[ "$HEADLESS" == "true" ]]; then
        [[ "$default" =~ ^[Yy] ]] && return 0 || return 1
    fi

    local yn_hint
    if [[ "$default" =~ ^[Yy] ]]; then
        yn_hint="Y/n"
    else
        yn_hint="y/N"
    fi

    echo -en "${CYAN}?${NC} ${prompt_text} ${DIM}[$yn_hint]${NC}: "
    read -r answer
    answer="${answer:-$default}"

    [[ "$answer" =~ ^[Yy] ]]
}

spinner() {
    local pid=$1
    local message="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    if [[ "$HEADLESS" == "true" ]] || [[ ! -t 1 ]]; then
        wait "$pid"
        return $?
    fi

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${BLUE}%s${NC} %s" "${spin:i++%10:1}" "$message"
        sleep 0.1
    done

    wait "$pid"
    local exit_code=$?

    printf "\r"
    return $exit_code
}

# ============================================
# CHECKS
# ============================================

check_dependencies() {
    local missing=()

    if ! command -v git &>/dev/null; then
        missing+=("git")
    fi

    if ! command -v curl &>/dev/null; then
        missing+=("curl")
    fi

    if ! command -v claude &>/dev/null; then
        warn "Claude CLI not found. Install from: https://docs.anthropic.com/en/docs/claude-code"
        warn "Ralph requires Claude CLI to run."
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing[*]}"
        error "Please install them and try again."
        exit 1
    fi
}

check_existing_install() {
    if [[ -d "$INSTALL_DIR" ]]; then
        if [[ -f "$INSTALL_DIR/ralph.sh" ]]; then
            warn "Existing installation found at $INSTALL_DIR"
            if prompt_yn "Update existing installation?"; then
                log "Updating existing installation..."
                return 0
            else
                error "Installation cancelled."
                exit 1
            fi
        fi
    fi
}

# ============================================
# INSTALLATION
# ============================================

print_banner() {
    if [[ "$HEADLESS" == "true" ]]; then
        echo "PortableRalph Installer v$VERSION"
        return
    fi

    echo ""
    echo -e "${MAGENTA}"
    cat << 'EOF'
    ____             __        __    __     ____        __      __
   / __ \____  _____/ /_____ _/ /_  / /__  / __ \____ _/ /___  / /_
  / /_/ / __ \/ ___/ __/ __ `/ __ \/ / _ \/ /_/ / __ `/ / __ \/ __ \
 / ____/ /_/ / /  / /_/ /_/ / /_/ / /  __/ _, _/ /_/ / / /_/ / / / /
/_/    \____/_/   \__/\__,_/_.___/_/\___/_/ |_|\__,_/_/ .___/_/ /_/
                                                     /_/
EOF
    echo -e "${NC}"
    echo -e "${DIM}An autonomous AI development loop that works in any repo${NC}"
    echo -e "${DIM}v$VERSION${NC}"
    echo ""
}

install_ralph() {
    log "Installing PortableRalph to ${CYAN}$INSTALL_DIR${NC}"

    if [[ -d "$INSTALL_DIR/.git" ]]; then
        # Update existing
        (cd "$INSTALL_DIR" && git pull --quiet origin master) &
        spinner $! "Updating from git..."
        success "Updated to latest version"
    else
        # Fresh install
        rm -rf "$INSTALL_DIR" 2>/dev/null || true
        git clone --quiet "$REPO_URL" "$INSTALL_DIR" &
        spinner $! "Cloning repository..."
        success "Cloned repository"
    fi

    # Make scripts executable
    chmod +x "$INSTALL_DIR"/*.sh
    success "Made scripts executable"
}

# ============================================
# SHELL CONFIGURATION
# ============================================

configure_shell() {
    if [[ "$SKIP_SHELL_CONFIG" == "true" ]]; then
        info "Skipping shell configuration (--skip-shell-config)"
        return
    fi

    log "Configuring shell..."

    local shell_config=""
    local shell_name=""

    # Detect shell
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        shell_config="$HOME/.zshrc"
        shell_name="zsh"
    elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == *"bash"* ]]; then
        shell_config="$HOME/.bashrc"
        shell_name="bash"
    else
        warn "Unknown shell. Please manually add ralph to your PATH."
        return
    fi

    # Check if already configured
    if grep -q "source.*ralph.env" "$shell_config" 2>/dev/null; then
        info "Shell already configured"
        return
    fi

    # Add configuration
    if [[ "$HEADLESS" == "true" ]] || prompt_yn "Add Ralph to your $shell_name config?"; then
        cat >> "$shell_config" << EOF

# PortableRalph
[[ -f ~/.ralph.env ]] && source ~/.ralph.env
alias ralph='$INSTALL_DIR/ralph.sh'
EOF
        success "Added to $shell_config"
        info "Run ${CYAN}source $shell_config${NC} or restart your terminal"
    fi
}

# ============================================
# NOTIFICATIONS
# ============================================

setup_notifications() {
    if [[ "$SKIP_NOTIFICATIONS" == "true" ]]; then
        info "Skipping notification setup (--skip-notifications)"
        return
    fi

    # Check if any credentials provided via args
    if [[ -n "$SLACK_WEBHOOK" ]] || [[ -n "$DISCORD_WEBHOOK" ]] || \
       [[ -n "$TELEGRAM_TOKEN" ]] || [[ -n "$CUSTOM_SCRIPT" ]]; then
        write_notification_config
        return
    fi

    # Interactive setup
    if [[ "$HEADLESS" == "true" ]]; then
        info "No notification credentials provided. Skipping setup."
        return
    fi

    echo ""
    log "Notification Setup"
    echo ""
    echo "Ralph can notify you on Slack, Discord, Telegram, or custom integrations."
    echo ""

    if ! prompt_yn "Would you like to set up notifications?"; then
        info "Skipping notification setup. Run ${CYAN}~/ralph/setup-notifications.sh${NC} later."
        return
    fi

    echo ""
    echo "Which platform(s) would you like to configure?"
    echo ""
    echo -e "  ${CYAN}1${NC}) Slack"
    echo -e "  ${CYAN}2${NC}) Discord"
    echo -e "  ${CYAN}3${NC}) Telegram"
    echo -e "  ${CYAN}4${NC}) Custom script"
    echo -e "  ${CYAN}5${NC}) Skip for now"
    echo ""

    local choice
    read -rp "$(echo -e "${CYAN}?${NC} Enter choice (1-5): ")" choice

    case "$choice" in
        1)
            setup_slack_interactive
            ;;
        2)
            setup_discord_interactive
            ;;
        3)
            setup_telegram_interactive
            ;;
        4)
            setup_custom_interactive
            ;;
        *)
            info "Skipping notification setup."
            return
            ;;
    esac

    write_notification_config
}

setup_slack_interactive() {
    echo ""
    echo -e "${BOLD}Slack Setup${NC}"
    echo ""
    echo "To get a webhook URL:"
    echo -e "  1. Go to ${CYAN}https://api.slack.com/apps${NC}"
    echo "  2. Create New App → From scratch"
    echo "  3. Enable Incoming Webhooks"
    echo "  4. Add webhook to workspace"
    echo "  5. Copy the URL"
    echo ""
    SLACK_WEBHOOK=$(prompt "Paste your Slack webhook URL")
}

setup_discord_interactive() {
    echo ""
    echo -e "${BOLD}Discord Setup${NC}"
    echo ""
    echo "To get a webhook URL:"
    echo "  1. Right-click channel → Edit Channel"
    echo "  2. Integrations → Webhooks → New Webhook"
    echo "  3. Copy Webhook URL"
    echo ""
    DISCORD_WEBHOOK=$(prompt "Paste your Discord webhook URL")
}

setup_telegram_interactive() {
    echo ""
    echo -e "${BOLD}Telegram Setup${NC}"
    echo ""
    echo "Step 1: Create a bot"
    echo -e "  1. Message ${CYAN}@BotFather${NC} on Telegram"
    echo "  2. Send /newbot and follow prompts"
    echo "  3. Copy the bot token"
    echo ""
    TELEGRAM_TOKEN=$(prompt "Paste your bot token")

    if [[ -n "$TELEGRAM_TOKEN" ]]; then
        echo ""
        echo "Step 2: Get your chat ID"
        echo "  1. Start a chat with your bot"
        echo "  2. Send any message"
        echo -e "  3. Visit: ${CYAN}https://api.telegram.org/bot$TELEGRAM_TOKEN/getUpdates${NC}"
        echo "  4. Find your chat ID in the response"
        echo ""
        TELEGRAM_CHAT=$(prompt "Paste your chat ID")
    fi
}

setup_custom_interactive() {
    echo ""
    echo -e "${BOLD}Custom Script Setup${NC}"
    echo ""
    echo "Your script receives the notification message as \$1"
    echo ""
    CUSTOM_SCRIPT=$(prompt "Path to your notification script")
}

write_notification_config() {
    local config_file="$HOME/.ralph.env"

    log "Writing notification configuration..."

    cat > "$config_file" << EOF
# PortableRalph Notification Configuration
# Generated by installer on $(date)

EOF

    if [[ -n "$SLACK_WEBHOOK" ]]; then
        echo "export RALPH_SLACK_WEBHOOK_URL=\"$SLACK_WEBHOOK\"" >> "$config_file"
    fi

    if [[ -n "$DISCORD_WEBHOOK" ]]; then
        echo "export RALPH_DISCORD_WEBHOOK_URL=\"$DISCORD_WEBHOOK\"" >> "$config_file"
    fi

    if [[ -n "$TELEGRAM_TOKEN" ]]; then
        echo "export RALPH_TELEGRAM_BOT_TOKEN=\"$TELEGRAM_TOKEN\"" >> "$config_file"
        echo "export RALPH_TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT\"" >> "$config_file"
    fi

    if [[ -n "$CUSTOM_SCRIPT" ]]; then
        echo "export RALPH_CUSTOM_NOTIFY_SCRIPT=\"$CUSTOM_SCRIPT\"" >> "$config_file"
    fi

    chmod 600 "$config_file"
    success "Configuration saved to $config_file"

    # Source it for current session
    source "$config_file" 2>/dev/null || true
}

# ============================================
# VERIFICATION
# ============================================

verify_installation() {
    log "Verifying installation..."

    local errors=0

    if [[ ! -x "$INSTALL_DIR/ralph.sh" ]]; then
        error "ralph.sh not found or not executable"
        ((errors++))
    fi

    if [[ ! -x "$INSTALL_DIR/notify.sh" ]]; then
        error "notify.sh not found or not executable"
        ((errors++))
    fi

    if [[ ! -f "$INSTALL_DIR/PROMPT_build.md" ]]; then
        error "PROMPT_build.md not found"
        ((errors++))
    fi

    if [[ $errors -gt 0 ]]; then
        error "Installation verification failed with $errors error(s)"
        exit 1
    fi

    success "Installation verified"
}

test_notifications() {
    if [[ "$SKIP_NOTIFICATIONS" == "true" ]]; then
        return
    fi

    # Check if any notification is configured
    if [[ -z "${RALPH_SLACK_WEBHOOK_URL:-}" ]] && \
       [[ -z "${RALPH_DISCORD_WEBHOOK_URL:-}" ]] && \
       [[ -z "${RALPH_TELEGRAM_BOT_TOKEN:-}" ]] && \
       [[ -z "${RALPH_CUSTOM_NOTIFY_SCRIPT:-}" ]]; then
        return
    fi

    if [[ "$HEADLESS" == "true" ]] || prompt_yn "Send a test notification?"; then
        log "Sending test notification..."
        if "$INSTALL_DIR/notify.sh" "🎉 PortableRalph installed successfully!"; then
            success "Test notification sent"
        else
            warn "Test notification may have failed"
        fi
    fi
}

# ============================================
# COMPLETION
# ============================================

print_success() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Quick Start:${NC}"
    echo ""
    echo -e "    ${CYAN}# Reload your shell${NC}"
    echo -e "    source ~/.bashrc  ${DIM}# or ~/.zshrc${NC}"
    echo ""
    echo -e "    ${CYAN}# Run Ralph on a plan file${NC}"
    echo -e "    ralph ./my-plan.md"
    echo ""
    echo -e "    ${CYAN}# Or use the full path${NC}"
    echo -e "    $INSTALL_DIR/ralph.sh ./my-plan.md"
    echo ""
    echo -e "  ${BOLD}Documentation:${NC}"
    echo -e "    ${CYAN}https://aaron777collins.github.io/portableralph/${NC}"
    echo ""
    echo -e "  ${BOLD}Need help?${NC}"
    echo -e "    ralph --help"
    echo ""
}

# ============================================
# MAIN
# ============================================

main() {
    parse_args "$@"
    setup_colors

    print_banner

    log "Starting installation..."
    echo ""

    check_dependencies
    check_existing_install
    install_ralph
    configure_shell
    setup_notifications
    verify_installation
    test_notifications

    print_success
}

main "$@"
