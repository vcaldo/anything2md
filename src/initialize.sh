#!/usr/bin/env bash
# initialize.sh - Source all library files and set up global variables
# This file is sourced by the main anything2md script before executing commands

# Source all library files in correct order
# Note: BASH_SOURCE[0] points to the generated script (./anything2md)
# Libraries are in src/lib/ relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. bashly-provided color library
if [[ ! -v colors_loaded ]]; then
  # shellcheck source=src/lib/colors.sh
  source "${SCRIPT_DIR}/src/lib/colors.sh"
fi

# 2. Custom constants library (exit codes, extensions, LLM mapping)
# shellcheck source=src/lib/constants.sh
source "${SCRIPT_DIR}/src/lib/constants.sh"

# 3. Custom output library (logging functions)
# shellcheck source=src/lib/output.sh
source "${SCRIPT_DIR}/src/lib/output.sh"

# 4. Custom validation library (input validation)
# shellcheck source=src/lib/validation.sh
source "${SCRIPT_DIR}/src/lib/validation.sh"

# 5. Custom GPU library (GPU detection)
# shellcheck source=src/lib/gpu.sh
source "${SCRIPT_DIR}/src/lib/gpu.sh"

# 6. Custom Docker library (docker command building)
# shellcheck source=src/lib/docker.sh
source "${SCRIPT_DIR}/src/lib/docker.sh"

# 7. Custom files library (file utilities)
# shellcheck source=src/lib/files.sh
source "${SCRIPT_DIR}/src/lib/files.sh"

# 8. Custom conversion library (conversion orchestration)
# shellcheck source=src/lib/conversion.sh
source "${SCRIPT_DIR}/src/lib/conversion.sh"

# Set DEBUG mode from environment or flag
# This will be checked in individual commands via args[--debug]
# But also respect ANYTHING2MD_DEBUG environment variable
if [[ -n "${ANYTHING2MD_DEBUG}" ]] && [[ "${ANYTHING2MD_DEBUG}" != "0" ]]; then
  export DEBUG=1
else
  export DEBUG=0
fi

# Global variables for session state
declare -g _GPU_AVAILABLE=""
declare -g _DOCKER_CHECKED=""

# Cleanup function for graceful exit
cleanup() {
  local exit_code=$?

  # Stop any active progress indicators
  if [[ -n "${_PROGRESS_ACTIVE}" ]]; then
    progress_stop
  fi

  # Additional cleanup can be added here as needed
  # (e.g., temporary files, background processes)

  exit "${exit_code}"
}

# Set up trap for cleanup on exit
trap cleanup EXIT INT TERM
