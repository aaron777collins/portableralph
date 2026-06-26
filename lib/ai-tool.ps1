# ai-tool.ps1 - AI CLI tool abstraction layer for Ralph (PowerShell)
# Provides a single seam for selecting and invoking the underlying AI coding
# CLI (Claude Code, OpenAI Codex, OpenCode, or a custom command) so the rest
# of Ralph does not need to know which tool is configured.
#
# Functions:
#   - Get-AiTool              Resolve the configured tool name
#   - Test-AiToolAvailable    Verify the tool binary is installed
#   - Get-AiToolDisplayName   Human-friendly name for the banner
#   - Invoke-AiTool           Execute the tool with a prompt
#   - Get-AiToolApiHost       API host for network reachability checks
#   - Get-DefaultModel        Default model for the configured tool
#
# Configuration (environment variables):
#   RALPH_AI_TOOL     One of: claude, codex, opencode, custom (default: claude)
#   RALPH_AI_COMMAND  Command to run when RALPH_AI_TOOL=custom (prompt via stdin)
#
# Usage:
#   . "$RALPH_DIR\lib\ai-tool.ps1"

# Source guard - dot-sourcing this file more than once is a no-op
if ($script:AiToolLoaded) { return }
$script:AiToolLoaded = $true

$ErrorActionPreference = "Stop"

# Tools whose binary name matches their configured name
$script:AiToolBinaries = @{
    claude   = "claude"
    codex    = "codex"
    opencode = "opencode"
}

$script:AiToolDisplayNames = @{
    claude   = "Claude Code"
    codex    = "OpenAI Codex"
    opencode = "OpenCode"
    custom   = "Custom AI Tool"
}

$script:AiToolApiHosts = @{
    claude   = "api.anthropic.com"
    codex    = "api.openai.com"
    opencode = ""
    custom   = ""
}

$script:AiToolDefaultModels = @{
    claude   = "sonnet"
    codex    = "gpt-4.1"
    opencode = "default"
}

<#
.SYNOPSIS
    Returns the configured AI tool name.
.OUTPUTS
    String - one of: claude, codex, opencode, custom
#>
function Get-AiTool {
    $tool = $env:RALPH_AI_TOOL
    if (-not $tool) {
        return "claude"
    }

    $tool = $tool.ToLower().Trim()
    $valid = @("claude", "codex", "opencode", "custom")
    if ($valid -notcontains $tool) {
        if (Get-Command Write-RalphError -ErrorAction SilentlyContinue) {
            Write-RalphError "Unknown RALPH_AI_TOOL '$tool', falling back to 'claude'. Valid values: $($valid -join ', ')"
        } else {
            Write-Warning "Unknown RALPH_AI_TOOL '$tool', falling back to 'claude'. Valid values: $($valid -join ', ')"
        }
        return "claude"
    }
    return $tool
}

<#
.SYNOPSIS
    Returns a human-friendly display name for the configured AI tool.
.OUTPUTS
    String
#>
function Get-AiToolDisplayName {
    $tool = Get-AiTool
    $name = $script:AiToolDisplayNames[$tool]
    if (-not $name) {
        return $tool
    }
    return $name
}

<#
.SYNOPSIS
    Returns the API host used for network reachability checks.
.OUTPUTS
    String - hostname, or empty string when no host applies
#>
function Get-AiToolApiHost {
    $tool = Get-AiTool
    return $script:AiToolApiHosts[$tool]
}

<#
.SYNOPSIS
    Returns the default model name for the configured AI tool.
.OUTPUTS
    String
#>
function Get-DefaultModel {
    $tool = Get-AiTool
    # Custom tools manage their own model selection
    if ($tool -eq "custom") {
        return ""
    }
    return $script:AiToolDefaultModels[$tool]
}

<#
.SYNOPSIS
    Checks that the configured AI tool binary is available on PATH.
.OUTPUTS
    Boolean - $true if available, $false otherwise
#>
function Test-AiToolAvailable {
    $tool = Get-AiTool

    if ($tool -eq "custom") {
        if (-not $env:RALPH_AI_COMMAND) {
            Write-Host "Error: RALPH_AI_TOOL is 'custom' but RALPH_AI_COMMAND is not set." -ForegroundColor Red
            Write-Host "Set RALPH_AI_COMMAND to the command Ralph should run (the prompt is piped via stdin)." -ForegroundColor Yellow
            return $false
        }

        # The custom command may include arguments; check only the executable
        $exe = ($env:RALPH_AI_COMMAND.Trim() -split '\s+')[0]
        if (Get-Command $exe -ErrorAction SilentlyContinue) {
            return $true
        }

        Write-Host "Error: Custom AI command '$exe' not found on PATH." -ForegroundColor Red
        Write-Host "Check the RALPH_AI_COMMAND setting in your configuration." -ForegroundColor Yellow
        return $false
    }

    $binary = $script:AiToolBinaries[$tool]
    if (Get-Command $binary -ErrorAction SilentlyContinue) {
        return $true
    }

    $displayName = Get-AiToolDisplayName
    Write-Host "Error: $displayName CLI ('$binary') not found on PATH." -ForegroundColor Red
    switch ($tool) {
        "claude" {
            Write-Host "Install it from: https://docs.anthropic.com/en/docs/claude-code" -ForegroundColor Yellow
        }
        "codex" {
            Write-Host "Install it from: https://github.com/openai/codex" -ForegroundColor Yellow
        }
        "opencode" {
            Write-Host "Install it from: https://github.com/opencode-ai/opencode" -ForegroundColor Yellow
        }
    }
    Write-Host "Or set RALPH_AI_TOOL to a different tool (claude, codex, opencode, custom)." -ForegroundColor Yellow
    return $false
}

<#
.SYNOPSIS
    Executes the configured AI tool with the given prompt.
.PARAMETER Prompt
    The prompt text to send to the AI tool.
.PARAMETER Model
    The model to use. Defaults to the tool's default model.
.PARAMETER StreamOutput
    When $true, lets the tool stream verbose output to the console.
#>
function Invoke-AiTool {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,

        [string]$Model = "",

        [bool]$StreamOutput = $true
    )

    $tool = Get-AiTool

    if (-not $Model) {
        $Model = Get-DefaultModel
    }

    try {
        switch ($tool) {
            "claude" {
                if ($StreamOutput) {
                    $Prompt | claude -p --dangerously-skip-permissions --model $Model --verbose
                } else {
                    $Prompt | claude -p --dangerously-skip-permissions --model $Model
                }
            }
            "codex" {
                # Codex takes the prompt as a positional argument, not via stdin
                codex --approval-mode full-auto --model $Model --quiet $Prompt
            }
            "opencode" {
                $Prompt | opencode --non-interactive --model $Model
            }
            "custom" {
                if (-not $env:RALPH_AI_COMMAND) {
                    throw "RALPH_AI_TOOL is 'custom' but RALPH_AI_COMMAND is not set."
                }
                # Split the command so any embedded arguments are honored
                $parts = $env:RALPH_AI_COMMAND.Trim() -split '\s+'
                $exe = $parts[0]
                $cmdArgs = @($parts | Select-Object -Skip 1)
                $Prompt | & $exe @cmdArgs
            }
        }
    } catch {
        $displayName = Get-AiToolDisplayName
        if (Get-Command Write-RalphError -ErrorAction SilentlyContinue) {
            Write-RalphError "$displayName exited with error: $($_.Exception.Message)"
        } else {
            Write-Host "$displayName exited with error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
