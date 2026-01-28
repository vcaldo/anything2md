#!/usr/bin/env bash
# constants.sh - Global constants for anything2md CLI
# shellcheck disable=SC2034  # Constants are used by sourcing scripts

# Guard against multiple sourcing
[[ -n "${CONSTANTS_LOADED:-}" ]] && return 0
readonly CONSTANTS_LOADED=1

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=1
readonly EXIT_FILE_NOT_FOUND=2
readonly EXIT_UNSUPPORTED_TYPE=3
readonly EXIT_CONTAINER_ERROR=4
readonly EXIT_CONVERSION_FAILED=5
readonly EXIT_DIR_NOT_FOUND=6
readonly EXIT_PARTIAL_FAILURE=7

# Supported file extensions (lowercase)
readonly SUPPORTED_EXTENSIONS=(
  "pdf"
  "docx"
  "xlsx"
  "pptx"
  "epub"
  "html"
  "png"
  "jpg"
  "jpeg"
  "tiff"
  "bmp"
)

# LLM service mapping to marker Python class names
declare -A LLM_SERVICE_MAPPING
LLM_SERVICE_MAPPING["gemini"]="marker.services.gemini.GoogleGeminiService"
LLM_SERVICE_MAPPING["claude"]="marker.services.claude.ClaudeService"
LLM_SERVICE_MAPPING["openai"]="marker.services.openai.OpenAIService"
LLM_SERVICE_MAPPING["ollama"]="marker.services.ollama.OllamaService"

# Docker image
readonly MARKER_IMAGE="xiaoyao9184/marker:latest"

# Custom image with WeasyPrint dependencies for PPTX support
readonly CUSTOM_MARKER_IMAGE="anything2md-marker:latest"

# Dockerfile location relative to project root
readonly DOCKERFILE_PATH="docker/Dockerfile"

# Default environment variable values
readonly DEFAULT_OUTPUT_FORMAT="markdown"
readonly DEFAULT_LLM_SERVICE="gemini"
readonly DEFAULT_OLLAMA_URL="http://localhost:11434"
