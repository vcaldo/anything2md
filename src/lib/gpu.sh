#!/usr/bin/env bash
# shellcheck disable=SC2034

# gpu.sh - GPU detection and information library for anything2md
# Provides functions for detecting NVIDIA GPUs and container toolkit support

# NOTE: Dependencies (constants.sh, output.sh) are loaded by initialize.sh before this library

# Mark this library as loaded
GPU_LOADED=1

# detect_nvidia_gpu - Check if nvidia-smi is available
# Returns: 0 if NVIDIA GPU detected, 1 otherwise
detect_nvidia_gpu() {
  if command -v nvidia-smi &>/dev/null; then
    # Verify nvidia-smi actually works (can query GPU)
    if nvidia-smi &>/dev/null; then
      return 0
    fi
  fi
  return 1
}

# detect_container_toolkit - Check if nvidia-container-toolkit is installed
# and Docker can see GPUs
# Returns: 0 if container toolkit detected, 1 otherwise
detect_container_toolkit() {
  # Check if docker command exists
  if ! command -v docker &>/dev/null; then
    return 1
  fi

  # Try to run a simple container with GPU access to verify toolkit works
  # Use --rm to auto-remove container after check
  # Use nvidia/cuda:12.0.0-base-ubuntu22.04 as a small test image
  if docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi &>/dev/null 2>&1; then
    return 0
  fi

  return 1
}

# can_use_gpu - Combined check for GPU support
# Checks both GPU availability and container toolkit
# Returns: 0 if GPU can be used with Docker, 1 otherwise
can_use_gpu() {
  if detect_nvidia_gpu; then
    log_debug "NVIDIA GPU detected via nvidia-smi"

    # For container usage, we also need the container toolkit
    # However, we'll do a lighter check - just verify Docker exists
    # The actual toolkit verification will happen when we try to use it
    if command -v docker &>/dev/null; then
      log_debug "Docker available, GPU passthrough possible"
      return 0
    else
      log_debug "Docker not available, cannot use GPU in containers"
      return 1
    fi
  fi

  log_debug "No NVIDIA GPU detected"
  return 1
}

# get_gpu_info - Return GPU information (name, memory, driver version)
# Outputs: JSON-like formatted string with GPU details
# Returns: 0 on success, 1 if no GPU detected
get_gpu_info() {
  if ! detect_nvidia_gpu; then
    echo "No NVIDIA GPU detected"
    return 1
  fi

  local gpu_name
  local driver_version
  local cuda_version

  # Get GPU name
  gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)

  # Get driver version
  driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)

  # Get CUDA version from nvidia-smi output
  cuda_version=$(nvidia-smi | grep -oP 'CUDA Version: \K[0-9.]+' 2>/dev/null | head -n1)

  # Output formatted info
  echo "GPU Name: ${gpu_name}"
  echo "Driver Version: ${driver_version}"
  echo "CUDA Version: ${cuda_version}"

  return 0
}

# get_vram_gb - Return total VRAM in GB
# Outputs: VRAM amount in GB (integer)
# Returns: 0 on success, 1 if no GPU detected
get_vram_gb() {
  if ! detect_nvidia_gpu; then
    echo "0"
    return 1
  fi

  local vram_mb
  local vram_gb

  # Get VRAM in MB
  vram_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -n1)

  if [[ -z "$vram_mb" ]]; then
    echo "0"
    return 1
  fi

  # Convert MB to GB (round down)
  vram_gb=$((vram_mb / 1024))

  echo "$vram_gb"
  return 0
}
