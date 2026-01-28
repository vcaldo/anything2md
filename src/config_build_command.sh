#!/usr/bin/env bash
# shellcheck disable=SC2154
# Disable shellcheck for 'args' array (provided by bashly)

# config_build_command.sh - Build custom marker Docker image
# This command builds the custom marker image with WeasyPrint dependencies

# Parse arguments
force_rebuild="${args[--force]}"

log_info "Building custom marker Docker image: $CUSTOM_MARKER_IMAGE"
echo ""

# Check if Docker is installed and running
if ! check_docker_installed; then
  log_error "Docker is not installed. Please install Docker first."
  exit "$EXIT_CONTAINER_ERROR"
fi

if ! check_docker_running; then
  log_error "Docker daemon is not running. Please start Docker."
  exit "$EXIT_CONTAINER_ERROR"
fi

# Get Dockerfile path
dockerfile_path="$(get_dockerfile_path)"

if [[ ! -f "$dockerfile_path" ]]; then
  log_error "Dockerfile not found at: $dockerfile_path"
  log_error "Please ensure the project is properly installed."
  exit "$EXIT_FILE_NOT_FOUND"
fi

log_info "Using Dockerfile: $dockerfile_path"

# Check if upstream image exists
if ! check_image_exists "$MARKER_IMAGE"; then
  log_info "Upstream image not found. It will be pulled during build..."
fi

echo ""

# Build the image
if [[ "$force_rebuild" == "1" ]]; then
  log_info "Force rebuild enabled (--no-cache)"
  echo ""
fi

if build_custom_image "$force_rebuild"; then
  echo ""
  log_success "Custom marker image built successfully!"

  # Show image info
  if check_image_exists "$CUSTOM_MARKER_IMAGE"; then
    image_size=$(docker image inspect "$CUSTOM_MARKER_IMAGE" --format='{{.Size}}' 2>/dev/null)
    if [[ -n "$image_size" ]]; then
      size_gb=$(awk "BEGIN {printf \"%.2f\", $image_size/1024/1024/1024}")
      log_info "Image size: ${size_gb} GB"
    fi

    echo ""
    log_info "Image ready with WeasyPrint support for PPTX conversion"
    log_success "You can now convert PPTX files: anything2md convert file.pptx"
  fi

  exit "$EXIT_SUCCESS"
else
  echo ""
  log_error "Failed to build custom marker image"
  log_error "Please check:"
  log_error "  - Docker is running correctly"
  log_error "  - You have sufficient disk space"
  log_error "  - Network connectivity (for pulling base image)"
  exit "$EXIT_CONTAINER_ERROR"
fi
