#!/usr/bin/env bash
# config_check_command.sh
# Verify system dependencies and display their status

# Check Docker installation and version
log_info "Checking system dependencies..."
echo ""

# 1. Check Docker installed
if check_docker_installed; then
  docker_version=$(docker --version 2>/dev/null | head -n1)
  log_success "Docker installed: $docker_version"
else
  log_error "Docker not installed"
  echo ""
  log_error "Minimum requirements NOT met. Please install Docker to use anything2md."
  exit "$EXIT_CONTAINER_ERROR"
fi

# 2. Check Docker daemon running
if check_docker_running; then
  log_success "Docker daemon running"
else
  log_error "Docker daemon not running"
  echo ""
  log_error "Minimum requirements NOT met. Please start Docker daemon."
  exit "$EXIT_CONTAINER_ERROR"
fi

# 3. Check NVIDIA GPU (optional)
if detect_nvidia_gpu; then
  gpu_info=$(get_gpu_info)
  vram=$(get_vram_gb)
  log_success "NVIDIA GPU detected: $gpu_info (${vram}GB VRAM)"

  # Check nvidia-container-toolkit (optional but recommended with GPU)
  if detect_container_toolkit; then
    log_success "NVIDIA Container Toolkit detected (GPU passthrough enabled)"
  else
    log_warning "NVIDIA Container Toolkit not detected (GPU will not be used)"
    echo "  Install with: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
  fi
else
  log_warning "NVIDIA GPU not detected (will use CPU mode)"
  echo "  This is optional - CPU mode will work but may be slower"
fi

# 4. Check marker image pulled
echo ""
if check_image_exists "$MARKER_IMAGE"; then
  # Get image size and creation date
  image_info=$(docker images --format "{{.Size}} (created {{.CreatedSince}})" "$MARKER_IMAGE" 2>/dev/null | head -n1)
  log_success "Marker image available: $MARKER_IMAGE ($image_info)"
else
  log_error "Marker image not found: $MARKER_IMAGE"
  echo "  Run: anything2md config pull"
  echo ""
  log_error "Minimum requirements NOT met. Please pull the marker image."
  exit "$EXIT_CONTAINER_ERROR"
fi

# Summary
echo ""
echo "========================================"
if check_image_exists "$MARKER_IMAGE"; then
  log_success "All minimum requirements met!"
  echo ""
  echo "Ready to convert documents:"
  echo "  anything2md convert <file>"
  echo "  anything2md batch <directory>"
  echo ""
  if ! detect_nvidia_gpu || ! detect_container_toolkit; then
    echo "Note: GPU acceleration not available (CPU mode will be used)"
  else
    echo "GPU acceleration: ENABLED"
  fi
else
  log_error "Some requirements are missing. See errors above."
fi
echo "========================================"
