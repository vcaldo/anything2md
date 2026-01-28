#!/usr/bin/env bash
# conversion.sh - Conversion orchestration functions
# This library orchestrates the complete file conversion workflow

# NOTE: Dependencies (constants.sh, output.sh, validation.sh, docker.sh, files.sh) are loaded by initialize.sh before this library

# Mark this library as loaded
# shellcheck disable=SC2034
CONVERSION_LOADED=1

# Get LLM environment variables based on service
# Args:
#   $1 - LLM service name (gemini, claude, openai, ollama)
#   $2 - Optional API key override
# Returns:
#   Echoes API key value if found, empty string otherwise
get_llm_env_vars() {
  local service="${1:-}"
  local api_key_override="${2:-}"

  # If API key explicitly provided, use it
  if [[ -n "$api_key_override" ]]; then
    echo "$api_key_override"
    return 0
  fi

  # Otherwise, look up from environment based on service
  case "$service" in
    gemini)
      echo "${ANYTHING2MD_GEMINI_API_KEY:-${GOOGLE_API_KEY:-}}"
      ;;
    claude)
      echo "${ANYTHING2MD_ANTHROPIC_API_KEY:-${ANTHROPIC_API_KEY:-}}"
      ;;
    openai)
      echo "${ANYTHING2MD_OPENAI_API_KEY:-${OPENAI_API_KEY:-}}"
      ;;
    ollama)
      echo "${ANYTHING2MD_OLLAMA_URL:-${OLLAMA_BASE_URL:-$DEFAULT_OLLAMA_URL}}"
      ;;
    *)
      log_error "Unknown LLM service: $service"
      echo ""
      ;;
  esac
}

# Build marker_single command options
# Args:
#   $1 - Input file path (inside container)
#   $2 - Output directory path (inside container)
#   $3 - Output format (markdown, json, html, chunks)
#   $4+ - Additional options (--force_ocr, --pages, --paginate, etc.)
# Returns:
#   Echoes marker_single command arguments (one per line for array usage)
build_marker_options() {
  local input_file="$1"
  local output_dir="$2"
  local output_format="${3:-markdown}"
  shift 3

  # Start building marker_single command
  echo "marker_single"
  echo "$input_file"
  echo "$output_dir"

  # Add output format
  case "$output_format" in
    markdown)
      echo "--output_format"
      echo "markdown"
      ;;
    json)
      echo "--output_format"
      echo "json"
      ;;
    html)
      echo "--output_format"
      echo "html"
      ;;
    chunks)
      echo "--output_format"
      echo "chunks"
      ;;
    *)
      log_warning "Unknown output format: $output_format, defaulting to markdown"
      echo "--output_format"
      echo "markdown"
      ;;
  esac

  # Add any additional options passed as arguments
  while [[ $# -gt 0 ]]; do
    echo "$1"
    shift
  done
}

# Handle conversion result
# Args:
#   $1 - Docker exit code
#   $2 - Input file path (for logging)
# Returns:
#   Appropriate exit code based on docker result
handle_conversion_result() {
  local docker_exit_code="$1"
  local input_file="$2"

  if [[ $docker_exit_code -eq 0 ]]; then
    log_success "Successfully converted: $input_file"
    return "$EXIT_SUCCESS"
  elif [[ $docker_exit_code -ge 125 && $docker_exit_code -le 127 ]]; then
    # Container runtime errors (125: docker run error, 126: command cannot execute, 127: command not found)
    log_error "Container error while converting: $input_file (exit code: $docker_exit_code)"
    return "$EXIT_CONTAINER_ERROR"
  else
    # Conversion/processing errors from marker
    log_error "Conversion failed: $input_file (exit code: $docker_exit_code)"
    return "$EXIT_CONVERSION_FAILED"
  fi
}

# Convert a single file
# This is the main orchestration function that coordinates the entire conversion workflow
# Args (via global variables set by command):
#   input_file - Path to input file
#   output_dir - Output directory (optional)
#   output_format - Output format (markdown, json, html, chunks)
#   vram - VRAM limit in GB (optional)
#   force_ocr - Force OCR flag (optional)
#   pages - Page range (optional)
#   paginate - Paginate flag (optional)
#   use_llm - Use LLM flag (optional)
#   llm_service - LLM service name (optional)
#   api_key - API key override (optional)
#   no_images - No images flag (optional)
#   move_originals - Directory to move originals (optional)
#   keep_originals - Keep originals flag (optional)
# Returns:
#   Exit code indicating success or failure
convert_single_file() {
  local input_file="${1:-}"
  local output_dir="${2:-}"
  local output_format="${3:-${DEFAULT_OUTPUT_FORMAT}}"
  local use_llm="${4:-}"
  local llm_service="${5:-}"
  local api_key_override="${6:-}"

  # Additional options passed as remaining arguments
  shift 6 || true
  local additional_opts=("$@")

  log_debug "Starting conversion of: $input_file"

  # Step 1: Validate input file
  if ! validate_file_exists "$input_file"; then
    return "$EXIT_FILE_NOT_FOUND"
  fi

  if ! validate_file_extension "$input_file"; then
    return "$EXIT_UNSUPPORTED_TYPE"
  fi

  # Step 2: Determine output directory
  local resolved_output_dir
  if [[ -n "$output_dir" ]]; then
    resolved_output_dir="$(get_output_directory "$output_dir")"
  else
    # Default to input file's directory
    resolved_output_dir="$(dirname "$input_file")"
  fi

  if ! ensure_output_directory "$resolved_output_dir"; then
    log_error "Failed to create output directory: $resolved_output_dir"
    return "$EXIT_DIR_NOT_FOUND"
  fi

  log_debug "Output directory: $resolved_output_dir"

  # Step 2.5: Ensure custom marker image is available
  if ! ensure_custom_image; then
    log_error "Cannot proceed without marker image"
    return "$EXIT_CONTAINER_ERROR"
  fi

  # Step 3: Get absolute paths for Docker mounts
  local abs_input_file abs_output_dir
  abs_input_file="$(realpath "$input_file")"
  abs_output_dir="$(realpath "$resolved_output_dir")"

  # Step 4: Build docker command with all parameters
  # build_docker_command expects: input_file, output_dir, output_format, llm_service, api_key, additional_options
  # Convert additional_opts array to space-separated string for build_docker_command
  local additional_opts_str=""
  if [[ ${#additional_opts[@]} -gt 0 ]]; then
    additional_opts_str="${additional_opts[*]}"
  fi

  local docker_cmd
  mapfile -t docker_cmd < <(build_docker_command "$abs_input_file" "$abs_output_dir" "$output_format" "$llm_service" "$api_key_override" "$additional_opts_str")

  log_debug "Docker command: ${docker_cmd[*]}"

  # Execute conversion
  local docker_exit_code
  if run_docker_command "${docker_cmd[@]}"; then
    docker_exit_code=$?
  else
    docker_exit_code=$?
  fi

  # Step 6: Handle conversion result
  if ! handle_conversion_result "$docker_exit_code" "$input_file"; then
    return $?
  fi

  # Step 7: Handle move/keep originals
  # Note: move_originals and keep_originals are mutually exclusive
  # If neither is set, keep the original by default
  local move_dir="${move_originals:-}"
  local keep="${keep_originals:-}"

  if [[ -n "$move_dir" && "$keep" != "1" ]]; then
    log_debug "Moving original file to: $move_dir"
    if ! move_original_file "$input_file" "$move_dir"; then
      log_warning "Failed to move original file: $input_file"
      # Don't fail the conversion if move fails
    fi
  fi

  # Step 8: Success
  local output_file
  output_file="$(get_output_filename "$input_file" "$abs_output_dir" "$output_format")"
  log_info "Output saved to: $output_file"

  return "$EXIT_SUCCESS"
}
