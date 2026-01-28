#!/usr/bin/env bash
# before.sh - Pre-flight checks run before every command
# This file is sourced by the main anything2md script before executing any command

# Check Docker is installed and running (fail if not available)
# Cache result to avoid repeated checks in the same session
if [[ -z "${_DOCKER_CHECKED}" ]]; then
  log_debug "Checking Docker installation and status..."

  # Check if Docker is installed
  if ! check_docker_installed; then
    log_error "Docker is not installed. Please install Docker to use anything2md."
    log_error "Visit: https://docs.docker.com/get-docker/"
    exit "${EXIT_CONTAINER_ERROR}"
  fi

  # Check if Docker daemon is running
  if ! check_docker_running; then
    log_error "Docker daemon is not running. Please start Docker."
    exit "${EXIT_CONTAINER_ERROR}"
  fi

  # Mark Docker as checked for this session
  _DOCKER_CHECKED="1"
  log_debug "Docker is installed and running"
fi

# Verify marker image exists (warn if not, don't fail)
# This allows users to run 'config pull' to download the image
if ! check_image_exists; then
  log_warning "Marker Docker image not found locally."
  log_warning "Run 'anything2md config pull' to download the image, or it will be pulled automatically on first use."
fi

# Set GPU availability flag for later use
# Cache result to avoid repeated GPU detection calls
if [[ -z "${_GPU_AVAILABLE}" ]]; then
  log_debug "Detecting GPU availability..."

  if can_use_gpu; then
    _GPU_AVAILABLE="1"
    log_debug "GPU support detected and available"

    # Log GPU info in debug mode
    # shellcheck disable=SC2154  # args array is provided by bashly
    if [[ "${DEBUG}" == "1" ]] || [[ "${args[--debug]}" == "1" ]]; then
      gpu_info=$(get_gpu_info)
      log_debug "GPU Info: ${gpu_info}"
    fi
  else
    _GPU_AVAILABLE="0"
    log_debug "No GPU support detected - will use CPU mode"
  fi
fi

# Log environment debug info if debug mode enabled
# shellcheck disable=SC2154  # args array is provided by bashly
if [[ "${DEBUG}" == "1" ]] || [[ "${args[--debug]}" == "1" ]]; then
  log_debug "Environment:"
  log_debug "  - Docker: installed and running"
  log_debug "  - GPU Available: ${_GPU_AVAILABLE}"
  log_debug "  - Marker Image: $(check_image_exists && echo "present" || echo "not found")"
  log_debug "  - Working Directory: $(pwd)"
fi
