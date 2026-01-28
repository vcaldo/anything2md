#!/usr/bin/env bash
# shellcheck disable=SC2154
# config_gpu_command.sh - Display detailed GPU information

# Check if NVIDIA GPU is available
if ! detect_nvidia_gpu; then
  log_warning "No NVIDIA GPU detected on this system."
  log_info "GPU acceleration is not available - conversions will run on CPU."
  log_info "To use GPU acceleration, ensure:"
  log_info "  1. An NVIDIA GPU is installed"
  log_info "  2. NVIDIA drivers are installed (nvidia-smi available)"
  log_info "  3. NVIDIA Container Toolkit is installed for Docker GPU access"
  exit "$EXIT_SUCCESS"
fi

# Display GPU information header
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  GPU Information"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get GPU info
gpu_info=$(get_gpu_info)

# Parse GPU info (get_gpu_info returns multi-line output)
gpu_name=$(echo "$gpu_info" | grep "GPU Name:" | cut -d':' -f2- | xargs)
driver_version=$(echo "$gpu_info" | grep "Driver Version:" | cut -d':' -f2- | xargs)
cuda_version=$(echo "$gpu_info" | grep "CUDA Version:" | cut -d':' -f2- | xargs)

# Get VRAM
vram_gb=$(get_vram_gb)

# Display GPU details
log_success "GPU Detected"
echo "  GPU Model:      $gpu_name"
echo "  Driver Version: $driver_version"
echo "  CUDA Version:   $cuda_version"
echo "  VRAM Total:     ${vram_gb} GB"
echo ""

# Check NVIDIA Container Toolkit
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Docker GPU Support"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if detect_container_toolkit; then
  log_success "NVIDIA Container Toolkit is installed and working"
  log_info "GPU acceleration is available for Docker containers"
  log_info "Conversions will automatically use GPU when available"
else
  log_warning "NVIDIA Container Toolkit is not detected or not working"
  log_info "Docker containers cannot access the GPU"
  log_info "Install toolkit from: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if GPU can be used with Docker
if can_use_gpu; then
  log_success "GPU acceleration is ENABLED for conversions"
else
  log_warning "GPU acceleration is NOT available (Docker or toolkit issue)"
fi

echo ""
