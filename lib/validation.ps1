# validation.ps1 - Shared validation functions for Ralph (PowerShell)
# This library provides common validation utilities used across Ralph scripts
# to reduce code duplication and ensure consistent validation logic.
#
# Functions:
#   - Test-NumericValue       Validate numeric values with optional range checking
#   - Test-WebhookUrl         Validate webhook URLs (basic format check)
#   - Test-EmailAddress       Validate email addresses
#   - Test-FilePath           Validate file paths (basic injection protection)
#   - ConvertTo-JsonEscaped   Escape strings for JSON
#   - Hide-SensitiveToken     Mask sensitive tokens in output
#
# Usage:
#   . "$PSScriptRoot\lib\validation.ps1"
#   or
#   . "$env:RALPH_DIR\lib\validation.ps1"

<#
.SYNOPSIS
    Validates numeric values with optional range checking
.PARAMETER Value
    The value to validate
.PARAMETER Name
    Optional name of the field (for error messages)
.PARAMETER Min
    Optional minimum value (default: 0)
.PARAMETER Max
    Optional maximum value (default: 999999)
.OUTPUTS
    Boolean - $true if valid, $false if invalid
#>
function Test-NumericValue {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value,

        [string]$Name = "value",
        [int]$Min = 0,
        [int]$Max = 999999
    )

    # Check if it's a number
    $numValue = 0
    if (-not [int]::TryParse($Value, [ref]$numValue)) {
        if (Get-Command Write-RalphError -ErrorAction SilentlyContinue) {
            Write-RalphError "$Name must be a positive integer: $Value"
        }
        return $false
    }

    # Check if non-negative
    if ($numValue -lt 0) {
        if (Get-Command Write-RalphError -ErrorAction SilentlyContinue) {
            Write-RalphError "$Name must be a positive integer: $Value"
        }
        return $false
    }

    # Check range
    if ($numValue -lt $Min -or $numValue -gt $Max) {
        if (Get-Command Write-RalphError -ErrorAction SilentlyContinue) {
            Write-RalphError "$Name must be between $Min and $Max - Value: $Value"
        }
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Validates webhook URL format (basic validation only)
.PARAMETER Url
    The URL to validate
.PARAMETER Name
    Optional name of the field (for error messages, default: "webhook")
.OUTPUTS
    Boolean - $true if valid, $false if invalid
#>
function Test-WebhookUrl {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Url,

        [string]$Name = "webhook"
    )

    # Empty is okay (not configured)
    if ([string]::IsNullOrEmpty($Url)) {
        return $true
    }

    # Must start with http:// or https://
    if (-not ($Url.StartsWith("http://") -or $Url.StartsWith("https://"))) {
        if (Get-Command Write-RalphError -ErrorAction SilentlyContinue) {
            Write-RalphError "$Name URL must use HTTP or HTTPS: $Url"
        }
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Validates email address format (basic RFC 5322 compliance)
.PARAMETER Email
    The email address to validate
.PARAMETER Name
    Optional name of the field (for error messages, default: "email")
.OUTPUTS
    Boolean - $true if valid, $false if invalid
#>
function Test-EmailAddress {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Email,

        [string]$Name = "email"
    )

    # Empty is okay
    if ([string]::IsNullOrEmpty($Email)) {
        return $true
    }

    # Basic email validation regex
    if ($Email -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
        if (Get-Command Write-RalphError -ErrorAction SilentlyContinue) {
            Write-RalphError "$Name address format invalid: $Email"
        }
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Validates file path (basic injection protection only)
.PARAMETER Path
    The path to validate
.PARAMETER Name
    Optional name of the field (for error messages, default: "path")
.PARAMETER RequireExists
    Whether the path must exist (default: $false)
.OUTPUTS
    Boolean - $true if valid, $false if invalid
#>
function Test-FilePath {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Path,

        [string]$Name = "path",
        [switch]$RequireExists
    )

    # Empty is okay unless explicitly required
    if ([string]::IsNullOrEmpty($Path)) {
        return $true
    }

    # Reject null bytes (command injection vector)
    if ($Path -match "`0") {
        if (Get-Command Write-RalphError -ErrorAction SilentlyContinue) {
            Write-RalphError "$Name contains invalid characters"
        }
        return $false
    }

    # Check if file exists if required
    if ($RequireExists -and -not (Test-Path $Path)) {
        if (Get-Command Write-RalphError -ErrorAction SilentlyContinue) {
            Write-RalphError "$Name does not exist: $Path"
        }
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Escapes string for safe JSON usage
.PARAMETER Text
    The text to escape
.OUTPUTS
    String - Escaped text suitable for JSON
#>
function ConvertTo-JsonEscaped {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Text
    )

    $escaped = $Text
    # Escape backslashes first (order matters!)
    $escaped = $escaped -replace '\\', '\\'
    # Escape double quotes
    $escaped = $escaped -replace '"', '\"'
    # Escape control characters
    $escaped = $escaped -replace "`t", '\t'
    $escaped = $escaped -replace "`n", '\n'
    $escaped = $escaped -replace "`r", '\r'
    # Remove other control characters
    $escaped = $escaped -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''

    return $escaped
}

<#
.SYNOPSIS
    Masks sensitive tokens in output/logs
.PARAMETER Token
    The token to mask
.PARAMETER PrefixLength
    Number of characters to show (default: 8)
.OUTPUTS
    String - Masked token
#>
function Hide-SensitiveToken {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Token,

        [int]$PrefixLength = 8
    )

    if ([string]::IsNullOrEmpty($Token) -or $Token.Length -lt 12) {
        return "[REDACTED]"
    }

    return "$($Token.Substring(0, $PrefixLength))...[REDACTED]"
}

# Backwards compatibility aliases
Set-Alias -Name Test-WebhookURL -Value Test-WebhookUrl -ErrorAction SilentlyContinue
Set-Alias -Name Validate-NumericValue -Value Test-NumericValue -ErrorAction SilentlyContinue
Set-Alias -Name Validate-WebhookUrl -Value Test-WebhookUrl -ErrorAction SilentlyContinue
Set-Alias -Name Validate-EmailAddress -Value Test-EmailAddress -ErrorAction SilentlyContinue
Set-Alias -Name Validate-FilePath -Value Test-FilePath -ErrorAction SilentlyContinue
Set-Alias -Name Mask-Token -Value Hide-SensitiveToken -ErrorAction SilentlyContinue
