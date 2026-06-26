#!/bin/bash
# constants.sh - Configuration constants for PortableRalph
# This file centralizes all hardcoded magic numbers used throughout the project
#
# Usage:
#   source ./lib/constants.sh
#
# Categories:
#   - Timeouts and Delays
#   - Rate Limits
#   - Retry Logic
#   - Email Configuration
#   - Monitoring Configuration
#   - Validation Limits
#   - Network Configuration

# ============================================
# TIMEOUTS AND DELAYS
# ============================================

# HTTP request timeouts (seconds)
readonly HTTP_MAX_TIME=10                    # Maximum time for HTTP request to complete
readonly HTTP_CONNECT_TIMEOUT=5              # Maximum time to establish connection
readonly HTTP_SMTP_TIMEOUT=30                # SMTP email send timeout

# Custom script execution timeout (seconds)
readonly CUSTOM_SCRIPT_TIMEOUT=30            # Timeout for custom notification scripts

# Process management timeouts (seconds)
readonly PROCESS_STOP_TIMEOUT=5              # Time to wait for graceful process shutdown
readonly PROCESS_VERIFY_DELAY=1              # Delay after starting process before verification

# Iteration delays (seconds)
readonly ITERATION_DELAY=2                   # Delay between Ralph iterations

# ============================================
# RATE LIMITS
# ============================================

# Notification rate limiting
readonly RATE_LIMIT_MAX=60                   # Maximum notifications per minute
readonly RATE_LIMIT_WINDOW=60                # Rate limit time window in seconds

# Email batch configuration
readonly EMAIL_BATCH_DELAY_DEFAULT=300       # Default delay before sending batched emails (5 minutes)
readonly EMAIL_BATCH_MAX_DEFAULT=10          # Default maximum notifications per batch
readonly EMAIL_BATCH_LOCK_RETRIES=10         # Number of lock acquisition attempts
readonly EMAIL_BATCH_LOCK_DELAY=0.1          # Delay between lock attempts (seconds)

# ============================================
# RETRY LOGIC
# ============================================

# Notification retry configuration
readonly NOTIFY_MAX_RETRIES=3                # Maximum notification retry attempts
readonly NOTIFY_RETRY_DELAY=2                # Initial retry delay (seconds, exponential backoff)

# Claude CLI retry configuration
readonly CLAUDE_MAX_RETRIES=3                # Maximum Claude CLI retry attempts
readonly CLAUDE_RETRY_DELAY=5                # Initial Claude retry delay (seconds, exponential backoff)

# Slack monitoring retry configuration
readonly SLACK_MAX_FAILURES=3                # Max consecutive Slack failures before warning

# ============================================
# MONITORING CONFIGURATION
# ============================================

# Progress monitoring intervals (seconds)
readonly MONITOR_INTERVAL_DEFAULT=300        # Default monitoring interval (5 minutes)
readonly MONITOR_INTERVAL_MIN=10             # Minimum allowed monitoring interval
readonly MONITOR_INTERVAL_MAX=86400          # Maximum allowed monitoring interval (24 hours)

# Progress change threshold
readonly MONITOR_PROGRESS_THRESHOLD=5        # Minimum progress change to trigger notification (%)

# Log rotation
readonly LOG_MAX_SIZE=10485760               # Maximum log file size before rotation (10MB)
readonly LOG_MAX_BACKUPS=5                   # Maximum number of log backups to keep

# Time display thresholds (seconds)
readonly TIME_DISPLAY_MINUTE=60              # Threshold for showing seconds vs minutes
readonly TIME_DISPLAY_HOUR=3600              # Threshold for showing minutes vs hours

# ============================================
# NOTIFICATION FREQUENCY
# ============================================

# Iteration notification frequency
readonly NOTIFY_FREQUENCY_DEFAULT=5          # Send notification every N iterations
readonly NOTIFY_FREQUENCY_MIN=1              # Minimum notification frequency
readonly NOTIFY_FREQUENCY_MAX=100            # Maximum notification frequency

# ============================================
# VALIDATION LIMITS
# ============================================

# Numeric validation defaults
readonly VALIDATION_MIN_DEFAULT=0            # Default minimum for numeric validation
readonly VALIDATION_MAX_DEFAULT=999999       # Default maximum for numeric validation

# Iteration limits
readonly MAX_ITERATIONS_DEFAULT=0            # Default max iterations (0 = unlimited)
readonly MAX_ITERATIONS_MIN=1                # Minimum max iterations when specified
readonly MAX_ITERATIONS_MAX=10000            # Maximum max iterations allowed

# Token masking
readonly TOKEN_MASK_PREFIX_LENGTH=8          # Number of characters to show in masked tokens

# Message truncation
readonly MESSAGE_TRUNCATE_LENGTH=100         # Length to truncate long messages in logs
readonly ERROR_DETAILS_TRUNCATE_LENGTH=500   # Length to truncate error details in logs

# ============================================
# NETWORK CONFIGURATION
# ============================================

# HTTP status codes
readonly HTTP_STATUS_SUCCESS_MIN=200         # Minimum successful HTTP status code
readonly HTTP_STATUS_SUCCESS_MAX=300         # Maximum successful HTTP status code (exclusive)

# ============================================
# FILE PERMISSIONS
# ============================================

# Config file permissions
readonly CONFIG_FILE_MODE=600                # Permissions for config files (owner read/write only)

# ============================================
# TELEGRAM TOKEN VALIDATION
# ============================================

# Telegram bot token format validation
readonly TELEGRAM_TOKEN_PREFIX_MIN=8         # Minimum digits in token prefix
readonly TELEGRAM_TOKEN_PREFIX_MAX=10        # Maximum digits in token prefix
readonly TELEGRAM_TOKEN_SECRET_LENGTH=35     # Length of secret part in token

# ============================================
# DISPLAY FORMATTING
# ============================================

# Spinner character count
readonly SPINNER_FRAMES=10                   # Number of frames in loading spinner

# Log tail length
readonly LOG_TAIL_LINES=10                   # Number of lines to show when tailing logs

# Update backups to keep
readonly UPDATE_MAX_BACKUPS=5                # Maximum number of update backups to keep

# ============================================
# GUARDRAILS
# ============================================

# Guardrails file line limits
readonly GUARDRAILS_SOFT_LIMIT=50            # Prompt Claude to consolidate at this many lines
readonly GUARDRAILS_WARN_LIMIT=100           # Show warning in banner at this many lines

# Export all constants for use in other scripts
export HTTP_MAX_TIME HTTP_CONNECT_TIMEOUT HTTP_SMTP_TIMEOUT
export CUSTOM_SCRIPT_TIMEOUT
export PROCESS_STOP_TIMEOUT PROCESS_VERIFY_DELAY
export ITERATION_DELAY
export RATE_LIMIT_MAX RATE_LIMIT_WINDOW
export EMAIL_BATCH_DELAY_DEFAULT EMAIL_BATCH_MAX_DEFAULT
export EMAIL_BATCH_LOCK_RETRIES EMAIL_BATCH_LOCK_DELAY
export NOTIFY_MAX_RETRIES NOTIFY_RETRY_DELAY
export CLAUDE_MAX_RETRIES CLAUDE_RETRY_DELAY
export SLACK_MAX_FAILURES
export MONITOR_INTERVAL_DEFAULT MONITOR_INTERVAL_MIN MONITOR_INTERVAL_MAX
export MONITOR_PROGRESS_THRESHOLD
export LOG_MAX_SIZE LOG_MAX_BACKUPS
export TIME_DISPLAY_MINUTE TIME_DISPLAY_HOUR
export NOTIFY_FREQUENCY_DEFAULT NOTIFY_FREQUENCY_MIN NOTIFY_FREQUENCY_MAX
export VALIDATION_MIN_DEFAULT VALIDATION_MAX_DEFAULT
export MAX_ITERATIONS_DEFAULT MAX_ITERATIONS_MIN MAX_ITERATIONS_MAX
export TOKEN_MASK_PREFIX_LENGTH
export MESSAGE_TRUNCATE_LENGTH ERROR_DETAILS_TRUNCATE_LENGTH
export HTTP_STATUS_SUCCESS_MIN HTTP_STATUS_SUCCESS_MAX
export CONFIG_FILE_MODE
export TELEGRAM_TOKEN_PREFIX_MIN TELEGRAM_TOKEN_PREFIX_MAX TELEGRAM_TOKEN_SECRET_LENGTH
export SPINNER_FRAMES LOG_TAIL_LINES
export UPDATE_MAX_BACKUPS
export GUARDRAILS_SOFT_LIMIT GUARDRAILS_WARN_LIMIT
