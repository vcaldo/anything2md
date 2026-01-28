#!/usr/bin/env bash
# shellcheck disable=SC2154
# Disable shellcheck for 'args' array (provided by bashly)

# config_pull_command.sh - Pull marker Docker image
# This command downloads the marker image with optional tag specification

# Parse arguments
tag="${args[--tag]:-latest}"

log_info "Pulling marker Docker image: ${MARKER_IMAGE%:*}:${tag}"

# Check if Docker is installed and running (should already be checked by before.sh)
if ! check_docker_installed; then
  log_error "Docker is not installed. Please install Docker first."
  exit "$EXIT_CONTAINER_ERROR"
fi

if ! check_docker_running; then
  log_error "Docker daemon is not running. Please start Docker."
  exit "$EXIT_CONTAINER_ERROR"
fi

# Build full image name with tag
image_with_tag="${MARKER_IMAGE%:*}:${tag}"

log_info "Starting download of ${image_with_tag}..."
log_info "This may take several minutes depending on your network speed."
echo ""

# Pull the image with progress output
# Use docker pull directly to show progress to user
if docker pull "$image_with_tag"; then
  echo ""
  log_success "Successfully pulled ${image_with_tag}"

  # Verify the image was pulled correctly
  if docker image inspect "$image_with_tag" &>/dev/null; then
    # Get image size
    image_size=$(docker image inspect "$image_with_tag" --format='{{.Size}}' 2>/dev/null)
    if [[ -n "$image_size" ]]; then
      # Convert bytes to GB
      size_gb=$(awk "BEGIN {printf \"%.2f\", $image_size/1024/1024/1024}")
      log_info "Image size: ${size_gb} GB"
    fi

    # Get creation date
    created=$(docker image inspect "$image_with_tag" --format='{{.Created}}' 2>/dev/null | cut -d'T' -f1)
    if [[ -n "$created" ]]; then
      log_info "Image created: ${created}"
    fi

    echo ""
    log_success "Marker image is ready to use!"
    log_info "You can now run: anything2md convert <file>"

    exit "$EXIT_SUCCESS"
  else
    log_error "Image pull reported success but verification failed."
    log_error "Please try again or check your Docker installation."
    exit "$EXIT_CONTAINER_ERROR"
  fi
else
  echo ""
  log_error "Failed to pull ${image_with_tag}"
  log_error "Please check:"
  log_error "  - Your internet connection"
  log_error "  - Docker is running correctly"
  log_error "  - The tag '${tag}' exists for this image"
  log_info "Available tags: https://hub.docker.com/r/xiaoyao9184/marker/tags"
  exit "$EXIT_CONTAINER_ERROR"
fi
