#!/bin/bash
# Ralph - AI Tool Abstraction Layer
# Provides a uniform interface over multiple AI CLI tools (claude, codex,
# opencode, custom) so ralph.sh stays tool-agnostic.
#
# Configure via environment:
#   RALPH_AI_TOOL     - claude | codex | opencode | custom (default: claude)
#   RALPH_AI_COMMAND  - command template for the "custom" tool
#   RALPH_MODEL       - model name (per-tool default if unset)

# Source guard
if [ -n "${_AI_TOOL_LOADED:-}" ]; then return 0; fi
_AI_TOOL_LOADED=1

# Reuse colors already defined by ralph.sh / error-handling.sh (which may mark
# them readonly); only define them when still unset. Assigning unconditionally
# (e.g. RED="${RED:-...}") errors on an already-set readonly variable.
[ -n "${RED:-}" ]    || RED='\033[0;31m'
[ -n "${GREEN:-}" ]  || GREEN='\033[0;32m'
[ -n "${YELLOW:-}" ] || YELLOW='\033[1;33m'
[ -n "${BLUE:-}" ]   || BLUE='\033[0;34m'
[ -n "${NC:-}" ]     || NC='\033[0m'

detect_ai_tool() {
    local tool="${RALPH_AI_TOOL:-claude}"
    # Normalize to match the PowerShell layer (.ToLower().Trim()): strip
    # surrounding whitespace and lowercase. bash 3.2 has no ${var,,}, so use tr.
    tool="$(printf '%s' "$tool" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    if [ -z "$tool" ]; then
        tool="claude"
    fi
    case "$tool" in
        claude|codex|opencode|custom)
            printf '%s' "$tool"
            ;;
        *)
            echo -e "${YELLOW}Warning: Unknown RALPH_AI_TOOL '$tool', falling back to 'claude'${NC}" >&2
            printf '%s' "claude"
            ;;
    esac
}

get_ai_tool_display_name() {
    case "$(detect_ai_tool)" in
        claude)   printf '%s' "Claude Code" ;;
        codex)    printf '%s' "OpenAI Codex" ;;
        opencode) printf '%s' "OpenCode" ;;
        custom)   printf '%s' "Custom AI Tool" ;;
    esac
}

get_default_model() {
    case "$(detect_ai_tool)" in
        claude)   printf '%s' "sonnet" ;;
        codex)    printf '%s' "gpt-4.1" ;;
        opencode) printf '%s' "default" ;;
        custom)   printf '%s' "" ;;
    esac
}

get_ai_tool_api_host() {
    case "$(detect_ai_tool)" in
        claude) printf '%s' "api.anthropic.com" ;;
        codex)  printf '%s' "api.openai.com" ;;
        *)      printf '%s' "" ;;
    esac
}

# Resolve the binary that must exist on PATH for the configured tool.
_ai_tool_binary() {
    case "$(detect_ai_tool)" in
        claude)   printf '%s' "claude" ;;
        codex)    printf '%s' "codex" ;;
        opencode) printf '%s' "opencode" ;;
        custom)
            # First word of the command template is the binary.
            local cmd="${RALPH_AI_COMMAND:-}"
            printf '%s' "${cmd%% *}"
            ;;
    esac
}

validate_ai_tool() {
    local tool
    tool="$(detect_ai_tool)"

    if [ "$tool" = "custom" ] && [ -z "${RALPH_AI_COMMAND:-}" ]; then
        echo -e "${RED}Error: RALPH_AI_TOOL=custom requires RALPH_AI_COMMAND to be set${NC}" >&2
        echo -e "${YELLOW}Set it to your CLI command, e.g.: export RALPH_AI_COMMAND=\"my-cli --flag\"${NC}" >&2
        return 1
    fi

    local binary
    binary="$(_ai_tool_binary)"

    if [ -z "$binary" ]; then
        echo -e "${RED}Error: No command configured for AI tool '$tool'${NC}" >&2
        return 1
    fi

    if ! command -v "$binary" &>/dev/null; then
        echo -e "${RED}Error: AI tool binary '$binary' not found on PATH (RALPH_AI_TOOL=$tool)${NC}" >&2
        case "$tool" in
            claude)   echo -e "${YELLOW}Install Claude Code: https://docs.anthropic.com/en/docs/claude-code${NC}" >&2 ;;
            codex)    echo -e "${YELLOW}Install Codex CLI and ensure 'codex' is on your PATH${NC}" >&2 ;;
            opencode) echo -e "${YELLOW}Install OpenCode and ensure 'opencode' is on your PATH${NC}" >&2 ;;
            custom)   echo -e "${YELLOW}Check RALPH_AI_COMMAND points to an installed executable${NC}" >&2 ;;
        esac
        return 1
    fi

    return 0
}

# Resolve the model to use: explicit arg wins, else per-tool default.
_ai_tool_resolve_model() {
    local model="$1"
    if [ -n "$model" ]; then
        printf '%s' "$model"
    else
        get_default_model
    fi
}

# Run the configured tool with output going to the current stdout/stderr.
# Args: prompt, model, mode ("plain" or "stream-json")
# stream-json only affects claude; other tools ignore it.
_ai_tool_exec() {
    local prompt="$1"
    local model="$2"
    local mode="${3:-plain}"
    local tool
    tool="$(detect_ai_tool)"
    model="$(_ai_tool_resolve_model "$model")"

    case "$tool" in
        claude)
            if [ "$mode" = "stream-json" ]; then
                printf '%s' "$prompt" | claude -p \
                    --dangerously-skip-permissions \
                    --model "$model" \
                    --verbose \
                    --output-format stream-json
            else
                printf '%s' "$prompt" | claude -p \
                    --dangerously-skip-permissions \
                    --model "$model" \
                    --verbose
            fi
            ;;
        codex)
            # codex takes the prompt as a positional argument, not stdin.
            codex --approval-mode full-auto --model "$model" --quiet "$prompt"
            ;;
        opencode)
            # "default" is a sentinel meaning "let the tool pick" - omit --model.
            if [ -z "$model" ] || [ "$model" = "default" ]; then
                printf '%s' "$prompt" | opencode --non-interactive
            else
                printf '%s' "$prompt" | opencode --non-interactive --model "$model"
            fi
            ;;
        custom)
            # Split the template into words and exec it directly so the prompt
            # (piped via stdin) is never parsed by a shell - avoids eval and
            # injection from special characters in the prompt.
            local cmd_parts
            read -ra cmd_parts <<< "${RALPH_AI_COMMAND:-}"
            if [ "${#cmd_parts[@]}" -eq 0 ]; then
                echo -e "${RED}Error: RALPH_AI_COMMAND is empty${NC}" >&2
                return 1
            fi
            printf '%s' "$prompt" | "${cmd_parts[@]}"
            ;;
    esac
}

# Public convenience runner. Output goes to the caller's stdout/stderr.
# Args: prompt, model, stream_output ("true"/"false")
run_ai_tool() {
    local prompt="$1"
    local model="${2:-}"
    local stream_output="${3:-false}"
    local mode="plain"

    if [ "$stream_output" = "true" ] && [ "$(detect_ai_tool)" = "claude" ] && command -v jq &>/dev/null; then
        mode="stream-json"
    fi

    _ai_tool_exec "$prompt" "$model" "$mode"
}

# Streaming runner. Displays output live while capturing it.
# Args: prompt, model, output_file, error_file
run_ai_tool_streaming() {
    local prompt="$1"
    local model="$2"
    local output_file="$3"
    local error_file="$4"
    local rc=0

    if [ "$(detect_ai_tool)" = "claude" ] && command -v jq &>/dev/null; then
        # Capture raw stream-json to the output file, render text/tool events live.
        _ai_tool_exec "$prompt" "$model" "stream-json" 2>"$error_file" | \
            tee "$output_file" | \
            jq --unbuffered -r '
                select(.type == "assistant") |
                .message.content[]? |
                if .type == "text" then .text
                elif .type == "tool_use" then
                    "  \u001b[0;34m→ " + .name +
                    (if .input.file_path then ": " + .input.file_path
                     elif .input.pattern then " /" + .input.pattern + "/"
                     elif .input.command then ": " + (.input.command | .[0:80])
                     elif .input.prompt then ": " + (.input.prompt | .[0:80])
                     else "" end) + "\u001b[0m"
                else empty end
            ' || rc=$?
    else
        # Other tools (or no jq): tee plain output to terminal and file.
        _ai_tool_exec "$prompt" "$model" "plain" 2>"$error_file" | \
            tee "$output_file" || rc=$?
    fi

    return $rc
}

# Non-streaming runner. Captures output to file, then echoes it once.
# Args: prompt, model, output_file, error_file
run_ai_tool_nonstreaming() {
    local prompt="$1"
    local model="$2"
    local output_file="$3"
    local error_file="$4"
    local rc=0

    _ai_tool_exec "$prompt" "$model" "plain" 2>"$error_file" > "$output_file" || rc=$?

    if [ -f "$output_file" ]; then
        cat "$output_file"
    fi

    return $rc
}
