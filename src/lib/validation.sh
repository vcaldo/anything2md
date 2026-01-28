#!/usr/bin/env bash
# validation.sh - Input validation functions for anything2md
# shellcheck disable=SC1091  # Don't follow source (colors.sh, constants.sh may not be in static analysis path)

# NOTE: Dependencies (constants.sh, output.sh) are loaded by initialize.sh before this library

# validate_file_exists: Check if file exists and is readable
# Args: $1 - file path
# Returns: EXIT_SUCCESS (0) if exists, EXIT_FILE_NOT_FOUND (2) otherwise
validate_file_exists() {
  local file_path="$1"

  if [[ -z "$file_path" ]]; then
    log_error "File path is empty"
    return "${EXIT_FILE_NOT_FOUND:-2}"
  fi

  if [[ ! -f "$file_path" ]]; then
    log_error "File not found: $file_path"
    return "${EXIT_FILE_NOT_FOUND:-2}"
  fi

  if [[ ! -r "$file_path" ]]; then
    log_error "File is not readable: $file_path"
    return "${EXIT_FILE_NOT_FOUND:-2}"
  fi

  return "${EXIT_SUCCESS:-0}"
}

# validate_directory_exists: Check if directory exists and is accessible
# Args: $1 - directory path
# Returns: EXIT_SUCCESS (0) if exists, EXIT_DIR_NOT_FOUND (6) otherwise
validate_directory_exists() {
  local dir_path="$1"

  if [[ -z "$dir_path" ]]; then
    log_error "Directory path is empty"
    return "${EXIT_DIR_NOT_FOUND:-6}"
  fi

  if [[ ! -d "$dir_path" ]]; then
    log_error "Directory not found: $dir_path"
    return "${EXIT_DIR_NOT_FOUND:-6}"
  fi

  if [[ ! -r "$dir_path" ]]; then
    log_error "Directory is not readable: $dir_path"
    return "${EXIT_DIR_NOT_FOUND:-6}"
  fi

  return "${EXIT_SUCCESS:-0}"
}

# validate_file_extension: Check if file has supported extension
# Args: $1 - file path
# Returns: EXIT_SUCCESS (0) if supported, EXIT_UNSUPPORTED_TYPE (3) otherwise
validate_file_extension() {
  local file_path="$1"
  local extension

  extension=$(get_file_extension "$file_path")

  if [[ -z "$extension" ]]; then
    log_error "File has no extension: $file_path"
    return "${EXIT_UNSUPPORTED_TYPE:-3}"
  fi

  # Convert extension to lowercase for comparison
  extension="${extension,,}"

  # Check if extension is in SUPPORTED_EXTENSIONS array
  for supported_ext in "${SUPPORTED_EXTENSIONS[@]}"; do
    if [[ "$extension" == "$supported_ext" ]]; then
      return "${EXIT_SUCCESS:-0}"
    fi
  done

  log_error "Unsupported file type: .$extension (supported: ${SUPPORTED_EXTENSIONS[*]})"
  return "${EXIT_UNSUPPORTED_TYPE:-3}"
}

# validate_output_format: Check if output format is valid
# Args: $1 - format (markdown|json|html|chunks)
# Returns: EXIT_SUCCESS (0) if valid, EXIT_INVALID_ARGS (1) otherwise
validate_output_format() {
  local format="$1"

  if [[ -z "$format" ]]; then
    log_error "Output format is empty"
    return "${EXIT_INVALID_ARGS:-1}"
  fi

  # Convert to lowercase for comparison
  format="${format,,}"

  case "$format" in
    markdown|json|html|chunks)
      return "${EXIT_SUCCESS:-0}"
      ;;
    *)
      log_error "Invalid output format: $format (valid: markdown, json, html, chunks)"
      return "${EXIT_INVALID_ARGS:-1}"
      ;;
  esac
}

# validate_page_range: Validate page range format (e.g., "0-10,15,20-25")
# Args: $1 - page range string
# Returns: EXIT_SUCCESS (0) if valid, EXIT_INVALID_ARGS (1) otherwise
validate_page_range() {
  local range="$1"

  if [[ -z "$range" ]]; then
    log_error "Page range is empty"
    return "${EXIT_INVALID_ARGS:-1}"
  fi

  # Valid page range format: numbers separated by commas, with optional ranges (X-Y)
  # Examples: "1", "1-5", "1,3,5", "1-5,10,15-20"
  if [[ ! "$range" =~ ^[0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*$ ]]; then
    log_error "Invalid page range format: $range (expected format: '0-10,15,20-25')"
    return "${EXIT_INVALID_ARGS:-1}"
  fi

  # Validate that ranges are logical (start <= end)
  local IFS=','
  for part in $range; do
    if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      local start="${BASH_REMATCH[1]}"
      local end="${BASH_REMATCH[2]}"
      if [[ "$start" -gt "$end" ]]; then
        log_error "Invalid page range: $start-$end (start must be <= end)"
        return "${EXIT_INVALID_ARGS:-1}"
      fi
    fi
  done

  return "${EXIT_SUCCESS:-0}"
}

# is_hidden_file: Check if file is hidden (starts with .)
# Args: $1 - file path
# Returns: EXIT_SUCCESS (0) if hidden, 1 otherwise
is_hidden_file() {
  local file_path="$1"
  local basename

  basename=$(basename "$file_path")

  if [[ "$basename" =~ ^\. ]]; then
    return 0
  fi

  return 1
}

# get_file_extension: Extract file extension (case-insensitive)
# Args: $1 - file path
# Returns: Extension without dot (e.g., "pdf" not ".pdf"), or empty if no extension
get_file_extension() {
  local file_path="$1"
  local basename
  local extension

  basename=$(basename "$file_path")

  # Extract extension after last dot
  if [[ "$basename" =~ \.([^.]+)$ ]]; then
    extension="${BASH_REMATCH[1]}"
    # Convert to lowercase
    echo "${extension,,}"
  else
    # No extension found
    echo ""
  fi
}
