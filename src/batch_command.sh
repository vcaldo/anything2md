#!/usr/bin/env bash
# batch_command.sh - Process multiple documents in a directory
# This file implements the 'anything2md batch' command

# shellcheck disable=SC2154
# args array is provided by bashly

# Parse required positional argument
input_dir="${args[input_dir]}"

# Validate input directory exists
if ! validate_directory_exists "$input_dir"; then
  exit "$EXIT_DIR_NOT_FOUND"
fi

# Convert to absolute path
input_dir=$(realpath "$input_dir")

# Parse all flags (inherit from convert + batch-specific)
output_format="${args[--format]:-${ANYTHING2MD_OUTPUT_FORMAT:-$DEFAULT_OUTPUT_FORMAT}}"
output_dir="${args[--output-dir]:-${ANYTHING2MD_OUTPUT_DIR:-}}"
vram="${args[--vram]:-${ANYTHING2MD_VRAM:-}}"
force_ocr="${args[--force-ocr]:-}"
pages="${args[--pages]:-}"
paginate="${args[--paginate]:-}"
use_llm="${args[--use-llm]:-}"
# Only set llm_service if --use-llm is enabled
if [[ -n "$use_llm" ]]; then
  llm_service="${args[--llm-service]:-${ANYTHING2MD_LLM_SERVICE:-$DEFAULT_LLM_SERVICE}}"
else
  llm_service=""
fi
api_key_override="${args[--api-key]:-}"
no_images="${args[--no-images]:-}"
debug="${args[--debug]:-}"
move_originals="${args[--move-originals]:-}"
keep_originals="${args[--keep-originals]:-}"

# Batch-specific flags
recursive="${args[--recursive]:-}"
skip_hidden="${args[--skip-hidden]:-1}"  # Default: skip hidden files
include_hidden="${args[--include-hidden]:-}"
skip_processed="${args[--skip-processed]:-1}"  # Default: skip processed files
workers="${args[--workers]:-1}"

# Chunking option
chunk_size="${args[--chunk]:-}"
if [[ -n "$chunk_size" ]] && [[ ! "$chunk_size" =~ ^[1-9][0-9]*$ ]]; then
  log_error "Chunk size must be a positive number: $chunk_size"
  exit "$EXIT_INVALID_ARGS"
fi

# Validate conflicting options
if [[ -n "$move_originals" && -n "$keep_originals" ]]; then
  log_error "Cannot use both --move-originals and --keep-originals"
  exit "$EXIT_INVALID_ARGS"
fi

# Override skip_hidden if include_hidden is set
if [[ -n "$include_hidden" ]]; then
  skip_hidden=""
fi

# Validate output format
if ! validate_output_format "$output_format"; then
  exit "$EXIT_INVALID_ARGS"
fi

# Validate page range if provided
if [[ -n "$pages" ]]; then
  if ! validate_page_range "$pages"; then
    exit "$EXIT_INVALID_ARGS"
  fi
fi

# Validate workers is a positive number
if [[ ! "$workers" =~ ^[1-9][0-9]*$ ]]; then
  log_error "Workers must be a positive number: $workers"
  exit "$EXIT_INVALID_ARGS"
fi

# Build additional marker options array
additional_options=()
[[ -n "$vram" ]] && additional_options+=("--vram" "$vram")
[[ -n "$force_ocr" ]] && additional_options+=("--force_ocr")
[[ -n "$pages" ]] && additional_options+=("--page_range" "$pages")
[[ -n "$paginate" ]] && additional_options+=("--paginate")
[[ -n "$no_images" ]] && additional_options+=("--disable_image_extraction")

# List files to process
log_info "Scanning directory: $input_dir"

if [[ -n "$recursive" ]]; then
  mapfile -t files < <(list_files_recursive "$input_dir")
else
  mapfile -t files < <(list_convertible_files "$input_dir" "")
fi

# Filter hidden files if needed
if [[ -n "$skip_hidden" ]]; then
  mapfile -t files < <(printf '%s\n' "${files[@]}" | filter_hidden_files)
fi

# Filter already processed files if needed
if [[ -n "$skip_processed" ]]; then
  unprocessed_files=()
  for file in "${files[@]}"; do
    # Calculate relative path for structure-aware skip check
    local file_relative_path=""
    if [[ -n "$output_dir" ]]; then
      file_relative_path=$(calculate_relative_path "$input_dir" "$file")
    fi

    if ! is_already_converted "$file" "$output_format" "$output_dir" "$file_relative_path"; then
      unprocessed_files+=("$file")
    else
      log_debug "Skipping already converted file: $file"
    fi
  done
  files=("${unprocessed_files[@]}")
fi

# Check if there are files to process
total_files="${#files[@]}"
if [[ "$total_files" -eq 0 ]]; then
  log_warning "No files to process in directory: $input_dir"
  exit "$EXIT_SUCCESS"
fi

log_info "Found $total_files file(s) to process"

# Initialize counters
success_count=0
failure_count=0
declare -a failed_files

# Function to process a single file (for parallel execution)
process_file() {
  local file="$1"
  local file_output_dir="$output_dir"
  local relative_path=""

  # If no output_dir specified, use input file's directory
  if [[ -z "$file_output_dir" ]]; then
    file_output_dir=$(dirname "$file")
  else
    # Calculate relative path to preserve directory structure under output_dir
    relative_path=$(calculate_relative_path "$input_dir" "$file")

    # Create subdirectories to match the relative path structure
    local relative_dir
    relative_dir="$(dirname "$relative_path")"

    if [[ "$relative_dir" != "." ]]; then
      local target_subdir="${file_output_dir}/${relative_dir}"
      if ! ensure_output_directory "$target_subdir"; then
        log_error "Failed to create output subdirectory: $target_subdir"
        return "$EXIT_DIR_NOT_FOUND"
      fi
    fi
  fi

  log_info "Processing: $(basename "$file")"

  # Call convert_single_file from conversion.sh
  # Pass relative_path as 7th parameter and chunk_size as 8th for directory structure preservation
  if convert_single_file \
    "$file" \
    "$file_output_dir" \
    "$output_format" \
    "$use_llm" \
    "$llm_service" \
    "$api_key_override" \
    "$relative_path" \
    "$chunk_size" \
    "${additional_options[@]+"${additional_options[@]}"}"; then

    # Handle move/keep originals
    if [[ -n "$move_originals" ]]; then
      if ! move_original_file "$file" "$move_originals"; then
        log_warning "Failed to move original file: $file"
      fi
    fi

    return 0
  else
    return 1
  fi
}

# Export function and variables for parallel execution
export -f process_file
export -f convert_single_file
export -f build_docker_command
export -f run_docker_command
export -f build_marker_options
export -f get_llm_env_vars
export -f handle_conversion_result
export -f log_info
export -f log_error
export -f log_success
export -f log_warning
export -f log_debug
export -f calculate_relative_path
export -f ensure_output_directory
export -f is_already_converted
export -f move_original_file
export output_format use_llm llm_service api_key_override move_originals input_dir chunk_size
export -a additional_options

# Export chunking functions for parallel workers
export -f process_pdf_in_chunks
export -f get_pdf_page_count
export -f generate_chunk_ranges
export -f create_temp_chunk_dir
export -f merge_markdown_chunks
export -f merge_chunk_images
export -f find_chunk_markdown
export -f is_pdf_file
export -f convert_single_file_direct

# Process files based on worker count
if [[ "$workers" -eq 1 ]]; then
  # Sequential processing
  for file in "${files[@]}"; do
    if process_file "$file"; then
      ((++success_count))
    else
      ((++failure_count))
      failed_files+=("$file")
    fi
  done
else
  # Parallel processing with job control
  log_info "Using $workers parallel workers"

  # Create temporary directory for job status files
  job_dir=$(mktemp -d)
  export job_dir
  trap 'rm -rf "$job_dir"' EXIT

  # Job slot semaphore
  job_count=0
  job_index=0

  for file in "${files[@]}"; do
    # Wait if we've reached max workers
    while [[ "$job_count" -ge "$workers" ]]; do
      # Wait for any job to finish
      wait -n 2>/dev/null || true
      ((job_count--)) || true
    done

    # Start background job
    (
      if process_file "$file"; then
        echo "success" > "$job_dir/$job_index.status"
      else
        echo "failure" > "$job_dir/$job_index.status"
        echo "$file" > "$job_dir/$job_index.file"
      fi
    ) &

    ((++job_count))
    ((++job_index))
  done

  # Wait for all remaining jobs to complete
  wait

  # Collect results from status files
  for status_file in "$job_dir"/*.status; do
    [[ -e "$status_file" ]] || continue
    status=$(cat "$status_file")
    if [[ "$status" == "success" ]]; then
      ((++success_count))
    else
      ((++failure_count))
      file_index=$(basename "$status_file" .status)
      if [[ -e "$job_dir/$file_index.file" ]]; then
        failed_files+=("$(cat "$job_dir/$file_index.file")")
      fi
    fi
  done
fi

# Display summary
echo ""
log_info "Batch processing complete"
print_summary "$total_files" "$success_count" "$failure_count"

# Show failed files if any
if [[ "$failure_count" -gt 0 ]]; then
  echo ""
  log_error "Failed files:"
  for failed_file in "${failed_files[@]}"; do
    echo "  - $(basename "$failed_file")"
  done
fi

# Determine exit code
if [[ "$failure_count" -eq 0 ]]; then
  exit "$EXIT_SUCCESS"
elif [[ "$success_count" -gt 0 ]]; then
  exit "$EXIT_PARTIAL_FAILURE"
else
  exit "$EXIT_CONVERSION_FAILED"
fi
