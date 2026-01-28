#!/usr/bin/env bash
# shellcheck disable=SC2154
# config_status_command.sh - Display comprehensive system status

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  anything2md System Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Docker Status
echo "Docker:"
if check_docker_installed; then
  docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
  if check_docker_running; then
    log_success "Docker ${docker_version} - running"
  else
    log_error "Docker ${docker_version} - daemon not running"
  fi
else
  log_error "Docker not installed"
fi
echo ""

# GPU Status
echo "GPU Acceleration:"
if detect_nvidia_gpu; then
  gpu_info=$(get_gpu_info)
  gpu_name=$(echo "$gpu_info" | grep "GPU Name:" | cut -d':' -f2- | xargs)
  vram_gb=$(get_vram_gb)

  if can_use_gpu; then
    log_success "$gpu_name (${vram_gb} GB VRAM) - enabled"
  else
    log_warning "$gpu_name detected but container toolkit not available"
  fi
else
  log_info "No NVIDIA GPU detected - CPU mode"
fi
echo ""

# Marker Image Status
echo "Marker Image:"
if check_image_exists "$MARKER_IMAGE"; then
  # Get image info
  image_size=$(docker image inspect "$MARKER_IMAGE" 2>/dev/null | grep -o '"Size": [0-9]*' | awk '{printf "%.2f GB", $2/1024/1024/1024}' | head -n1)
  image_date=$(docker image inspect "$MARKER_IMAGE" 2>/dev/null | grep -o '"Created": "[^"]*"' | head -n1 | cut -d'"' -f4 | cut -d'T' -f1)
  log_success "$MARKER_IMAGE - available (${image_size}, created ${image_date})"
else
  log_warning "$MARKER_IMAGE - not pulled (run: anything2md config pull)"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Environment Variables"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Display environment variables with defaults
echo "Output Settings:"
echo "  ANYTHING2MD_OUTPUT_FORMAT    = ${ANYTHING2MD_OUTPUT_FORMAT:-(not set, default: markdown)}"
echo "  ANYTHING2MD_OUTPUT_DIR       = ${ANYTHING2MD_OUTPUT_DIR:-(not set, uses input file directory)}"
echo ""

echo "GPU Settings:"
echo "  ANYTHING2MD_VRAM             = ${ANYTHING2MD_VRAM:-(not set, auto-detect)}"
echo ""

echo "LLM Settings:"
echo "  ANYTHING2MD_LLM_SERVICE      = ${ANYTHING2MD_LLM_SERVICE:-(not set, default: gemini)}"
if [ -n "$ANYTHING2MD_GEMINI_API_KEY" ]; then
  echo "  ANYTHING2MD_GEMINI_API_KEY   = ********** (set)"
else
  echo "  ANYTHING2MD_GEMINI_API_KEY   = (not set)"
fi
if [ -n "$ANYTHING2MD_ANTHROPIC_API_KEY" ]; then
  echo "  ANYTHING2MD_ANTHROPIC_API_KEY = ********** (set)"
else
  echo "  ANYTHING2MD_ANTHROPIC_API_KEY = (not set)"
fi
if [ -n "$ANYTHING2MD_OPENAI_API_KEY" ]; then
  echo "  ANYTHING2MD_OPENAI_API_KEY   = ********** (set)"
else
  echo "  ANYTHING2MD_OPENAI_API_KEY   = (not set)"
fi
echo "  ANYTHING2MD_OLLAMA_URL       = ${ANYTHING2MD_OLLAMA_URL:-(not set, default: http://localhost:11434)}"
echo ""

echo "Debug Settings:"
echo "  ANYTHING2MD_DEBUG            = ${ANYTHING2MD_DEBUG:-(not set, default: 0)}"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Default Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "When no environment variables are set, these defaults are used:"
echo "  Output Format:   $DEFAULT_OUTPUT_FORMAT"
echo "  LLM Service:     $DEFAULT_LLM_SERVICE"
echo "  Ollama URL:      $DEFAULT_OLLAMA_URL"
echo "  Debug Mode:      disabled"
echo ""

echo "Supported File Types:"
echo "  Documents: PDF, DOCX, XLSX, PPTX, EPUB, HTML"
echo "  Images:    PNG, JPG, JPEG, TIFF, BMP"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Summary
if check_docker_running && check_image_exists "$MARKER_IMAGE"; then
  log_success "System is ready for conversions"
  log_info "Run 'anything2md convert <file>' to convert a single file"
  log_info "Run 'anything2md batch <directory>' to batch process files"
else
  log_warning "System not fully configured"
  if ! check_docker_running; then
    log_info "Start Docker daemon to continue"
  fi
  if ! check_image_exists "$MARKER_IMAGE"; then
    log_info "Run 'anything2md config pull' to download the marker image"
  fi
fi

echo ""
