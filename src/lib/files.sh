#!/usr/bin/env bash
# files.sh - File management and path utilities for anything2md
# Provides functions for output path calculation, directory management, file listing, and filtering

# NOTE: Dependencies (constants.sh, output.sh, validation.sh) are loaded by initialize.sh before this library

# get_output_filename - Determine output file path based on input file and options
# Args:
#   $1 - input_file (path to input file)
#   $2 - output_format (markdown|json|html|chunks, default: markdown)
#   $3 - output_dir (optional, defaults to input file directory)
# Returns:
#   Prints the full output file path
# Example:
#   get_output_filename "/path/to/file.pdf" "markdown" "/output"
#   -> /output/file.md
get_output_filename() {
  local input_file="$1"
  local output_format="${2:-markdown}"
  local output_dir="$3"

  # Get the base filename without extension
  local basename
  basename="$(basename "$input_file")"
  local filename_no_ext="${basename%.*}"

  # Determine file extension based on format
  local ext
  case "$output_format" in
    markdown) ext="md" ;;
    json) ext="json" ;;
    html) ext="html" ;;
    chunks) ext="json" ;;  # chunks format also uses .json
    *) ext="md" ;;  # default to markdown
  esac

  # Determine output directory
  local out_dir
  if [[ -n "$output_dir" ]]; then
    out_dir="$output_dir"
  else
    out_dir="$(dirname "$input_file")"
  fi

  # Return full output path
  echo "${out_dir}/${filename_no_ext}.${ext}"
}

# get_output_directory - Resolve output directory (handles relative paths)
# Args:
#   $1 - output_dir (can be relative or absolute)
# Returns:
#   Prints the absolute output directory path
get_output_directory() {
  local output_dir="$1"

  # If empty, return current directory
  if [[ -z "$output_dir" ]]; then
    pwd
    return 0
  fi

  # Convert to absolute path
  if [[ "$output_dir" = /* ]]; then
    # Already absolute
    echo "$output_dir"
  else
    # Relative path - make absolute
    echo "$(pwd)/${output_dir}"
  fi
}

# ensure_output_directory - Create output directory if it doesn't exist
# Args:
#   $1 - directory path to create
# Returns:
#   0 on success, EXIT_DIR_NOT_FOUND (6) if creation fails
ensure_output_directory() {
  local dir="$1"

  if [[ -d "$dir" ]]; then
    return 0
  fi

  log_debug "Creating output directory: $dir"

  if mkdir -p "$dir" 2>/dev/null; then
    log_debug "Created directory: $dir"
    return 0
  else
    log_error "Failed to create output directory: $dir"
    return "$EXIT_DIR_NOT_FOUND"
  fi
}

# is_already_converted - Check if output file already exists for input file
# Args:
#   $1 - input_file path
#   $2 - output_format (optional, default: markdown)
#   $3 - output_dir (optional)
# Returns:
#   0 if already converted (output exists), 1 if not converted
is_already_converted() {
  local input_file="$1"
  local output_format="${2:-markdown}"
  local output_dir="$3"

  local output_file
  output_file="$(get_output_filename "$input_file" "$output_format" "$output_dir")"

  if [[ -f "$output_file" ]]; then
    return 0  # Already converted
  else
    return 1  # Not converted
  fi
}

# list_convertible_files - Find files with supported extensions in a directory
# Args:
#   $1 - directory path
#   $2 - recursive flag (0 = non-recursive, 1 = recursive)
# Returns:
#   Prints list of convertible file paths (one per line)
list_convertible_files() {
  local dir="$1"
  local recursive="${2:-0}"

  if [[ ! -d "$dir" ]]; then
    log_error "Directory not found: $dir"
    return "$EXIT_DIR_NOT_FOUND"
  fi

  local files=()

  if [[ "$recursive" -eq 1 ]]; then
    # Recursive listing
    mapfile -t files < <(list_files_recursive "$dir")
  else
    # Non-recursive listing
    while IFS= read -r -d '' file; do
      files+=("$file")
    done < <(find "$dir" -maxdepth 1 -type f -print0 2>/dev/null)
  fi

  # Filter by supported extensions
  for file in "${files[@]}"; do
    local ext
    ext="$(get_file_extension "$file")"

    # Check if extension is supported
    if [[ " ${SUPPORTED_EXTENSIONS[*]} " =~ [[:space:]]${ext}[[:space:]] ]]; then
      echo "$file"
    fi
  done
}

# list_files_recursive - Recursively traverse directory and list all files
# Args:
#   $1 - directory path
# Returns:
#   Prints list of all file paths (one per line)
list_files_recursive() {
  local dir="$1"

  # Use find for recursive traversal
  find "$dir" -type f 2>/dev/null
}

# filter_hidden_files - Remove hidden files from a list
# Args:
#   stdin - list of file paths (one per line)
# Returns:
#   Prints filtered list (non-hidden files only)
filter_hidden_files() {
  while IFS= read -r file; do
    if ! is_hidden_file "$file"; then
      echo "$file"
    fi
  done
}

# Move original file to specified directory
# Args:
#   $1 - source file path
#   $2 - destination directory
# Returns:
#   0 on success, 1 on failure
move_original_file() {
  local source_file="$1"
  local dest_dir="$2"

  if [[ ! -f "$source_file" ]]; then
    log_error "Source file not found: $source_file"
    return 1
  fi

  if [[ ! -d "$dest_dir" ]]; then
    log_debug "Creating destination directory: $dest_dir"
    if ! mkdir -p "$dest_dir" 2>/dev/null; then
      log_error "Failed to create destination directory: $dest_dir"
      return 1
    fi
  fi

  local filename
  filename="$(basename "$source_file")"
  local dest_path="${dest_dir}/${filename}"

  log_debug "Moving $source_file to $dest_path"

  if mv "$source_file" "$dest_path" 2>/dev/null; then
    log_debug "Moved file to: $dest_path"
    return 0
  else
    log_error "Failed to move file: $source_file"
    return 1
  fi
}
