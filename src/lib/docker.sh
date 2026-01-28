#!/usr/bin/env bash
# shellcheck disable=SC2034

# docker.sh - Docker command construction and execution library for anything2md
# Provides functions for Docker operations and building marker conversion commands

# NOTE: Dependencies (constants.sh, output.sh, gpu.sh) are loaded by initialize.sh before this library

# Mark this library as loaded
DOCKER_LOADED=1

# check_docker_installed - Verify docker command exists
# Returns: 0 if Docker installed, 1 otherwise
check_docker_installed() {
  if command -v docker &>/dev/null; then
    log_debug "Docker command found"
    return 0
  fi
  log_error "Docker is not installed or not in PATH"
  return 1
}

# check_docker_running - Verify docker daemon is running
# Returns: 0 if Docker daemon running, 1 otherwise
check_docker_running() {
  if ! check_docker_installed; then
    return 1
  fi

  if docker info &>/dev/null; then
    log_debug "Docker daemon is running"
    return 0
  fi
  log_error "Docker daemon is not running"
  return 1
}

# check_image_exists - Check if marker image is pulled
# Arguments:
#   $1 - Image name (optional, defaults to MARKER_IMAGE constant)
# Returns: 0 if image exists locally, 1 otherwise
check_image_exists() {
  local image="${1:-$MARKER_IMAGE}"

  if ! check_docker_installed; then
    return 1
  fi

  if docker image inspect "$image" &>/dev/null; then
    log_debug "Docker image '$image' found locally"
    return 0
  fi
  log_debug "Docker image '$image' not found locally"
  return 1
}

# pull_marker_image - Pull xiaoyao9184/marker image
# Arguments:
#   $1 - Tag (optional, defaults to 'latest')
# Returns: 0 on success, EXIT_CONTAINER_ERROR on failure
pull_marker_image() {
  local tag="${1:-latest}"
  local image="xiaoyao9184/marker:${tag}"

  if ! check_docker_running; then
    return "$EXIT_CONTAINER_ERROR"
  fi

  log_info "Pulling Docker image: $image"

  if docker pull "$image"; then
    log_success "Successfully pulled $image"
    return 0
  else
    log_error "Failed to pull Docker image: $image"
    return "$EXIT_CONTAINER_ERROR"
  fi
}

# get_dockerfile_path - Get absolute path to Dockerfile
# Returns: Echoes the absolute path to the Dockerfile
get_dockerfile_path() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  echo "${script_dir}/${DOCKERFILE_PATH}"
}

# build_custom_image - Build the custom marker image with WeasyPrint deps
# Arguments:
#   $1 - Force rebuild (optional, "1" to force with --no-cache)
# Returns: 0 on success, EXIT_CONTAINER_ERROR on failure
build_custom_image() {
  local force_rebuild="${1:-0}"
  local dockerfile_path
  dockerfile_path="$(get_dockerfile_path)"

  if ! check_docker_running; then
    return "$EXIT_CONTAINER_ERROR"
  fi

  if [[ ! -f "$dockerfile_path" ]]; then
    log_error "Dockerfile not found: $dockerfile_path"
    return "$EXIT_CONTAINER_ERROR"
  fi

  log_info "Building custom marker image: $CUSTOM_MARKER_IMAGE"
  log_info "This includes WeasyPrint dependencies for PPTX support..."

  local -a build_args=("docker" "build" "-t" "$CUSTOM_MARKER_IMAGE")

  if [[ "$force_rebuild" == "1" ]]; then
    build_args+=("--no-cache")
    log_debug "Force rebuild enabled (--no-cache)"
  fi

  build_args+=("-f" "$dockerfile_path" "$(dirname "$dockerfile_path")")

  log_debug "Build command: ${build_args[*]}"

  if "${build_args[@]}"; then
    log_success "Successfully built $CUSTOM_MARKER_IMAGE"
    return 0
  else
    log_error "Failed to build custom marker image"
    return "$EXIT_CONTAINER_ERROR"
  fi
}

# ensure_custom_image - Ensure custom image exists, build if necessary
# This is the main function to call before conversions
# Returns: 0 if image is ready, EXIT_CONTAINER_ERROR on failure
ensure_custom_image() {
  if check_image_exists "$CUSTOM_MARKER_IMAGE"; then
    log_debug "Custom marker image found: $CUSTOM_MARKER_IMAGE"
    return 0
  fi

  log_info "Custom marker image not found. Building..."

  if ! build_custom_image; then
    log_error "Failed to build custom marker image"
    log_error "Try running: anything2md config build --force"
    return "$EXIT_CONTAINER_ERROR"
  fi

  return 0
}

# get_active_image - Get the image name to use for conversions
# Returns: Echoes CUSTOM_MARKER_IMAGE if it exists, otherwise MARKER_IMAGE
get_active_image() {
  if check_image_exists "$CUSTOM_MARKER_IMAGE"; then
    echo "$CUSTOM_MARKER_IMAGE"
  else
    echo "$MARKER_IMAGE"
  fi
}

# build_docker_command - Construct full docker run command
# Arguments:
#   $1 - Input file path (absolute)
#   $2 - Output directory (absolute)
#   $3 - Output format (markdown, json, html, chunks)
#   $4 - LLM service (gemini, claude, openai, ollama) or empty
#   $5 - API key or empty
#   $6 - Additional marker options (space-separated string)
# Outputs: Complete docker command as array elements (one per line)
# Returns: 0 on success, 1 on error
build_docker_command() {
  local input_file="$1"
  local output_dir="$2"
  local output_format="${3:-markdown}"
  local llm_service="${4:-}"
  local api_key="${5:-}"
  local additional_options="${6:-}"

  # Validate required arguments
  if [[ -z "$input_file" ]] || [[ -z "$output_dir" ]]; then
    log_error "build_docker_command: input_file and output_dir are required"
    return 1
  fi

  # Get parent directory of input file for mounting
  local input_dir
  input_dir="$(dirname "$input_file")"
  local input_filename
  input_filename="$(basename "$input_file")"

  # Start building command array
  local -a docker_cmd=(
    "docker"
    "run"
    "--rm"
  )

  # Add GPU support if available
  if can_use_gpu; then
    docker_cmd+=("--gpus" "all")
    log_debug "Adding GPU support to Docker command"
  else
    log_debug "Running in CPU-only mode (no GPU detected)"
  fi

  # Add volume mounts
  docker_cmd+=(
    "-v" "${input_dir}:/input:ro"
    "-v" "${output_dir}:/output"
    "-v" "${HOME}/.cache:/root/.cache"
  )

  # Add environment variables for LLM services
  if [[ -n "$llm_service" ]]; then
    case "$llm_service" in
      gemini)
        local gemini_key="${api_key:-${ANYTHING2MD_GEMINI_API_KEY:-}}"
        if [[ -n "$gemini_key" ]]; then
          docker_cmd+=("-e" "GOOGLE_API_KEY=${gemini_key}")
          log_debug "Added Gemini API key to environment"
        else
          log_warning "LLM service 'gemini' selected but no API key provided"
        fi
        ;;
      claude)
        local claude_key="${api_key:-${ANYTHING2MD_ANTHROPIC_API_KEY:-}}"
        if [[ -n "$claude_key" ]]; then
          docker_cmd+=("-e" "ANTHROPIC_API_KEY=${claude_key}")
          log_debug "Added Claude API key to environment"
        else
          log_warning "LLM service 'claude' selected but no API key provided"
        fi
        ;;
      openai)
        local openai_key="${api_key:-${ANYTHING2MD_OPENAI_API_KEY:-}}"
        if [[ -n "$openai_key" ]]; then
          docker_cmd+=("-e" "OPENAI_API_KEY=${openai_key}")
          log_debug "Added OpenAI API key to environment"
        else
          log_warning "LLM service 'openai' selected but no API key provided"
        fi
        ;;
      ollama)
        local ollama_url="${ANYTHING2MD_OLLAMA_URL:-$DEFAULT_OLLAMA_URL}"
        docker_cmd+=("-e" "OLLAMA_BASE_URL=${ollama_url}")
        log_debug "Added Ollama URL to environment: $ollama_url"
        ;;
      *)
        log_warning "Unknown LLM service: $llm_service"
        ;;
    esac
  fi

  # Add Docker image (use custom image if available)
  local active_image
  active_image="$(get_active_image)"
  docker_cmd+=("$active_image")
  log_debug "Using Docker image: $active_image"

  # Add marker_single command
  docker_cmd+=("marker_single")
  docker_cmd+=("/input/${input_filename}")
  docker_cmd+=("--output_dir" "/output")
  docker_cmd+=("--output_format" "$output_format")

  # Add LLM options if service is specified
  if [[ -n "$llm_service" ]]; then
    docker_cmd+=("--use_llm")
    local llm_class="${LLM_SERVICE_MAPPING[$llm_service]:-}"
    if [[ -n "$llm_class" ]]; then
      docker_cmd+=("--llm_service" "$llm_class")
      log_debug "Using LLM service: $llm_class"
    else
      log_warning "No LLM service mapping found for: $llm_service"
    fi
  fi

  # Add additional marker options if provided
  if [[ -n "$additional_options" ]]; then
    # shellcheck disable=SC2206
    docker_cmd+=($additional_options)
    log_debug "Added additional options: $additional_options"
  fi

  # Output command array (one element per line for easy parsing)
  printf "%s\n" "${docker_cmd[@]}"
  return 0
}

# run_docker_command - Execute docker command and handle errors
# Arguments:
#   $@ - Docker command array
# Returns: 0 on success, EXIT_CONTAINER_ERROR or EXIT_CONVERSION_FAILED on error
run_docker_command() {
  if [[ $# -eq 0 ]]; then
    log_error "run_docker_command: no command provided"
    return "$EXIT_CONTAINER_ERROR"
  fi

  log_debug "Executing Docker command: $*"

  # Execute command and capture exit code
  if "$@"; then
    log_debug "Docker command completed successfully"
    return 0
  else
    local exit_code=$?
    log_error "Docker command failed with exit code: $exit_code"

    # Differentiate between container errors and conversion failures
    if [[ $exit_code -eq 125 ]] || [[ $exit_code -eq 126 ]] || [[ $exit_code -eq 127 ]]; then
      # Docker/container runtime errors
      return "$EXIT_CONTAINER_ERROR"
    else
      # Conversion/processing errors
      return "$EXIT_CONVERSION_FAILED"
    fi
  fi
}
