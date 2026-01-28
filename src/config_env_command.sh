#!/usr/bin/env bash
# config_env_command.sh - Display environment variables

# Parse flags from bashly args array
export_mode="${args[--export]:-}"
show_secrets="${args[--show-secrets]:-}"

# Define all ANYTHING2MD environment variables
# Array format: "VAR_NAME|description|default_value|is_secret"
declare -a env_vars=(
  "ANYTHING2MD_OUTPUT_FORMAT|Default output format (markdown, json, html, chunks)|markdown|0"
  "ANYTHING2MD_OUTPUT_DIR|Default output directory||0"
  "ANYTHING2MD_VRAM|GPU VRAM limit in GB||0"
  "ANYTHING2MD_LLM_SERVICE|Default LLM provider (gemini, claude, openai, ollama)|gemini|0"
  "ANYTHING2MD_GEMINI_API_KEY|Google Gemini API key||1"
  "ANYTHING2MD_ANTHROPIC_API_KEY|Anthropic Claude API key||1"
  "ANYTHING2MD_OPENAI_API_KEY|OpenAI API key||1"
  "ANYTHING2MD_OLLAMA_URL|Ollama base URL|http://localhost:11434|0"
  "ANYTHING2MD_DEBUG|Enable debug mode (0 or 1)|0|0"
)

# Function to get environment variable value
get_env_value() {
  local var_name="$1"
  local is_secret="$2"
  local value

  value="${!var_name:-}"

  if [[ -n "$value" ]]; then
    # Value is set
    if [[ "$is_secret" == "1" && -z "$show_secrets" ]]; then
      # Mask secret values unless --show-secrets is set
      echo "**********"
    else
      echo "$value"
    fi
  else
    echo "(not set)"
  fi
}

# Function to display in normal format
display_normal() {
  echo ""
  echo "Environment Variables:"
  echo "====================="
  echo ""

  for env_var in "${env_vars[@]}"; do
    IFS='|' read -r var_name description default_value is_secret <<< "$env_var"

    local current_value
    current_value=$(get_env_value "$var_name" "$is_secret")

    echo "${var_name}:"
    echo "  Description: $description"
    [[ -n "$default_value" ]] && echo "  Default: $default_value"
    echo "  Current: $current_value"
    echo ""
  done

  if [[ -z "$show_secrets" ]]; then
    echo "Note: API keys are masked. Use --show-secrets to reveal them."
    echo ""
  fi
}

# Function to display in export format
display_export() {
  for env_var in "${env_vars[@]}"; do
    IFS='|' read -r var_name description default_value is_secret <<< "$env_var"

    local current_value="${!var_name:-}"

    if [[ -n "$current_value" ]]; then
      # Variable is set - export current value
      if [[ "$is_secret" == "1" && -z "$show_secrets" ]]; then
        # Mask secret values unless --show-secrets is set
        echo "export ${var_name}=\"**********\""
      else
        echo "export ${var_name}=\"${current_value}\""
      fi
    elif [[ -n "$default_value" ]]; then
      # Variable not set but has default - export default
      echo "export ${var_name}=\"${default_value}\""
    else
      # Variable not set and no default - comment it out
      echo "# export ${var_name}=\"\""
    fi
  done

  if [[ -z "$show_secrets" ]]; then
    echo ""
    echo "# Note: API keys are masked. Use --show-secrets to reveal them."
  fi
}

# Main logic
if [[ -n "$export_mode" ]]; then
  # Export format
  display_export
else
  # Normal format
  display_normal
fi
