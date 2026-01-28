#!/usr/bin/env bash
# shellcheck disable=SC2034
# output.sh - Logging, progress indicators, and summary formatting functions
# Uses bashly colors library for colored output

# NOTE: Dependencies (colors.sh) are loaded by initialize.sh before this library

# Logging functions with color support
# These respect NO_COLOR environment variable through bashly's colors library

log_info() {
  local message="$1"
  printf "%b[INFO]%b %s\n" "${color_blue:-}" "${color_reset:-}" "$message" >&2
}

log_success() {
  local message="$1"
  printf "%b[SUCCESS]%b %s\n" "${color_green:-}" "${color_reset:-}" "$message" >&2
}

log_warning() {
  local message="$1"
  printf "%b[WARN]%b %s\n" "${color_yellow:-}" "${color_reset:-}" "$message" >&2
}

log_error() {
  local message="$1"
  printf "%b[ERROR]%b %s\n" "${color_red:-}" "${color_reset:-}" "$message" >&2
}

log_debug() {
  local message="$1"
  # Only output when DEBUG=1 or args[--debug] is set
  if [[ "${DEBUG:-0}" == "1" ]] || [[ "${args[--debug]:-}" == "1" ]]; then
    printf "%b[DEBUG]%b %s\n" "${color_dim:-}" "${color_reset:-}" "$message" >&2
  fi
}

# Progress indicator functions
# Uses simple text-based progress indication

# Global variable to track progress state
_PROGRESS_ACTIVE=0

progress_start() {
  local message="${1:-Working...}"
  _PROGRESS_ACTIVE=1
  printf "%b%s%b " "${color_cyan:-}" "$message" "${color_reset:-}" >&2
}

progress_stop() {
  if [[ "$_PROGRESS_ACTIVE" == "1" ]]; then
    printf "\n" >&2
    _PROGRESS_ACTIVE=0
  fi
}

# Summary formatting for batch results
print_summary() {
  local total="$1"
  local success="$2"
  local failed="$3"
  local skipped="${4:-0}"

  echo ""
  echo "================================================"
  echo "Batch Processing Summary"
  echo "================================================"
  printf "Total files:     %d\n" "$total"
  printf "%bSuccessful:%b      %d\n" "${color_green:-}" "${color_reset:-}" "$success"
  if [[ "$failed" -gt 0 ]]; then
    printf "%bFailed:%b          %d\n" "${color_red:-}" "${color_reset:-}" "$failed"
  else
    printf "Failed:          %d\n" "$failed"
  fi
  if [[ "$skipped" -gt 0 ]]; then
    printf "%bSkipped:%b         %d\n" "${color_yellow:-}" "${color_reset:-}" "$skipped"
  fi
  echo "================================================"
  echo ""
}

# Print aligned table row for batch output
print_table_row() {
  local status="$1"
  local filename="$2"
  local message="${3:-}"

  # Determine color based on status
  local status_color=""
  case "$status" in
    "OK"|"SUCCESS")
      status_color="${color_green:-}"
      ;;
    "FAIL"|"ERROR")
      status_color="${color_red:-}"
      ;;
    "SKIP"|"SKIPPED")
      status_color="${color_yellow:-}"
      ;;
    "PROCESSING")
      status_color="${color_cyan:-}"
      ;;
  esac

  # Print formatted row
  printf "%b%-12s%b %-40s %s\n" \
    "$status_color" \
    "[$status]" \
    "${color_reset:-}" \
    "$filename" \
    "$message"
}

# Check if output supports colors (used internally by bashly colors)
# This function is for compatibility and testing purposes
supports_color() {
  if [[ -n "${NO_COLOR:-}" ]] || [[ "${TERM:-}" == "dumb" ]]; then
    return 1
  fi
  return 0
}
