#!/usr/bin/env bash
# chunking.sh - PDF chunking utilities for processing large documents
# Provides functions to split PDFs into chunks, process each chunk, and merge outputs

# NOTE: Dependencies (constants.sh, output.sh, validation.sh, docker.sh, files.sh, conversion.sh)
# are loaded by initialize.sh before this library

# Guard against multiple sourcing
[[ -n "${CHUNKING_LOADED:-}" ]] && return 0
# shellcheck disable=SC2034
readonly CHUNKING_LOADED=1

# Default chunk size in pages
readonly DEFAULT_CHUNK_SIZE=50

# cleanup_temp_dir - Remove temporary directory, handling Docker-created files
# Docker runs as root, so files may be owned by root. Use Docker to clean up.
# Args:
#   $1 - Directory to remove
cleanup_temp_dir() {
  local dir="$1"

  if [[ -z "$dir" ]] || [[ ! -d "$dir" ]]; then
    return 0
  fi

  # First try normal removal
  if rm -rf "$dir" 2>/dev/null; then
    return 0
  fi

  # If that fails (permission denied), use Docker to clean up
  log_debug "Using Docker to clean up root-owned files in: $dir"
  docker run --rm -v "$dir:/cleanup" alpine rm -rf /cleanup/* 2>/dev/null || true
  rm -rf "$dir" 2>/dev/null || true
}

# is_pdf_file - Check if file is a PDF based on extension
# Args:
#   $1 - File path
# Returns:
#   0 if PDF, 1 otherwise
is_pdf_file() {
  local file="$1"
  local ext
  ext=$(get_file_extension "$file")
  [[ "$ext" == "pdf" ]]
}

# get_pdf_page_count - Get total number of pages in a PDF
# Uses pypdfium2 inside the marker Docker container
# Args:
#   $1 - PDF file path (can be relative or absolute)
# Returns:
#   Echoes page count as integer, or empty on error
get_pdf_page_count() {
  local pdf_file="$1"
  local input_dir
  local input_filename

  # Get absolute path for Docker mount
  input_dir="$(cd "$(dirname "$pdf_file")" && pwd)"
  input_filename="$(basename "$pdf_file")"

  # Get the active Docker image
  local active_image
  active_image="$(get_active_image)"

  # Run pypdfium2 inside the marker container to get page count
  # Use environment variable to pass filename safely (handles special characters)
  log_debug "Getting page count for: $input_filename in $input_dir using $active_image"
  local page_count
  page_count=$(docker run --rm \
    -v "${input_dir}:/input:ro" \
    -e "PDF_FILENAME=${input_filename}" \
    "$active_image" \
    python3 -c "
import os
import pypdfium2 as pdfium
filename = os.environ.get('PDF_FILENAME', '')
pdf = pdfium.PdfDocument('/input/' + filename)
print(len(pdf))
" 2>/dev/null)
  log_debug "Page count result: $page_count"

  if [[ -n "$page_count" ]] && [[ "$page_count" =~ ^[0-9]+$ ]]; then
    echo "$page_count"
    return 0
  fi

  log_error "Failed to get page count for: $pdf_file"
  return 1
}

# generate_chunk_ranges - Generate page ranges for chunking
# Args:
#   $1 - Total page count
#   $2 - Chunk size (default: 50)
# Returns:
#   One page range per line in format "start-end" (0-indexed)
#   E.g., for 120 pages with chunk size 50: "0-49", "50-99", "100-119"
generate_chunk_ranges() {
  local total_pages="$1"
  local chunk_size="${2:-$DEFAULT_CHUNK_SIZE}"

  local start=0
  while [[ $start -lt $total_pages ]]; do
    local end=$((start + chunk_size - 1))
    if [[ $end -ge $total_pages ]]; then
      end=$((total_pages - 1))
    fi
    echo "${start}-${end}"
    start=$((end + 1))
  done
}

# create_temp_chunk_dir - Create temporary directory for chunk outputs
# Args:
#   $1 - Base name for identification (e.g., PDF filename without extension)
# Returns:
#   Echoes path to temporary directory
create_temp_chunk_dir() {
  local base_name="$1"
  local safe_name
  # Sanitize base name for use in temp dir
  safe_name=$(echo "$base_name" | tr -cd '[:alnum:]_-')
  local temp_dir
  temp_dir=$(mktemp -d -t "anything2md_chunks_${safe_name}_XXXXXX")
  echo "$temp_dir"
}

# merge_markdown_chunks - Combine multiple markdown chunk files into one
# Args:
#   $1 - Output file path (final merged markdown)
#   $2+ - Input chunk files in order
# Returns:
#   0 on success, 1 on failure
merge_markdown_chunks() {
  local output_file="$1"
  shift
  local chunk_files=("$@")

  if [[ ${#chunk_files[@]} -eq 0 ]]; then
    log_error "No chunk files provided for merging"
    return 1
  fi

  log_debug "Merging ${#chunk_files[@]} chunks into: $output_file"

  # Clear/create output file
  : > "$output_file"

  local chunk_index=0
  for chunk_file in "${chunk_files[@]}"; do
    if [[ ! -f "$chunk_file" ]]; then
      log_error "Chunk file not found: $chunk_file"
      return 1
    fi

    # Add horizontal rule between chunks (except before first)
    if [[ $chunk_index -gt 0 ]]; then
      {
        echo ""
        echo "---"
        echo ""
      } >> "$output_file"
    fi

    # Append chunk content
    cat "$chunk_file" >> "$output_file"

    ((++chunk_index))
  done

  log_debug "Merged $chunk_index chunks successfully"
  return 0
}

# merge_chunk_images - Collect images from chunk directories into final output
# Args:
#   $1 - Final output directory
#   $2 - Base filename (without extension) for creating images subdirectory
#   $3+ - Chunk output directories in order
# Returns:
#   0 on success
merge_chunk_images() {
  local final_output_dir="$1"
  local base_name="$2"
  shift 2
  local chunk_dirs=("$@")

  # Create images subdirectory in final output (marker convention)
  local images_dir="${final_output_dir}/${base_name}"

  local image_counter=0
  local found_images=0

  for chunk_dir in "${chunk_dirs[@]}"; do
    # Find all image files in chunk directory and its subdirectories
    while IFS= read -r -d '' img_file; do
      found_images=1

      # Ensure images directory exists (create on first image)
      if [[ $image_counter -eq 0 ]]; then
        mkdir -p "$images_dir"
      fi

      local img_name
      img_name=$(basename "$img_file")
      local img_ext="${img_name##*.}"

      # Copy with sequential numbering to avoid conflicts
      local new_name="image_${image_counter}.${img_ext}"
      cp "$img_file" "${images_dir}/${new_name}"

      ((++image_counter))
    done < <(find "$chunk_dir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" \) -print0 2>/dev/null)
  done

  if [[ $found_images -eq 1 ]]; then
    log_debug "Collected $image_counter images into: $images_dir"
  fi

  return 0
}

# find_chunk_markdown - Find the markdown file in a chunk output directory
# Marker creates output with the PDF base name, so we look for any .md file
# Args:
#   $1 - Chunk output directory
# Returns:
#   Echoes path to markdown file, or empty if not found
find_chunk_markdown() {
  local chunk_dir="$1"
  local md_file

  # Find the first .md file in the chunk directory
  md_file=$(find "$chunk_dir" -maxdepth 2 -name "*.md" -type f | head -1)

  if [[ -n "$md_file" ]]; then
    echo "$md_file"
    return 0
  fi

  return 1
}

# process_pdf_in_chunks - Main orchestration function for chunked PDF processing
# Args:
#   $1 - Input PDF file (absolute path)
#   $2 - Output directory (absolute path)
#   $3 - Output format
#   $4 - Chunk size
#   $5 - use_llm flag
#   $6 - llm_service
#   $7 - api_key_override
#   $8 - relative_path
#   $9+ - additional_options
# Returns:
#   Exit code from conversion
process_pdf_in_chunks() {
  local input_file="$1"
  local output_dir="$2"
  local output_format="${3:-markdown}"
  local chunk_size="${4:-$DEFAULT_CHUNK_SIZE}"
  local use_llm="${5:-}"
  local llm_service="${6:-}"
  local api_key_override="${7:-}"
  local relative_path="${8:-}"
  shift 8 || true
  local additional_opts=("$@")

  local base_name
  base_name="$(basename "$input_file" .pdf)"
  base_name="$(basename "$base_name" .PDF)"  # Handle uppercase extension

  # Step 1: Get page count
  log_info "Analyzing PDF structure..."
  local page_count
  if ! page_count=$(get_pdf_page_count "$input_file"); then
    log_error "Could not determine page count for: $input_file"
    return "$EXIT_CONVERSION_FAILED"
  fi

  if [[ -z "$page_count" ]] || [[ "$page_count" -eq 0 ]]; then
    log_error "PDF has 0 pages or could not be read: $input_file"
    return "$EXIT_CONVERSION_FAILED"
  fi

  log_info "PDF has $page_count pages, processing in chunks of $chunk_size"

  # Step 2: Check if chunking is actually needed
  if [[ "$page_count" -le "$chunk_size" ]]; then
    log_info "PDF is small enough ($page_count pages), processing without chunking"
    # Call the regular conversion without chunk_size to avoid recursion
    convert_single_file_direct "$input_file" "$output_dir" "$output_format" \
      "$use_llm" "$llm_service" "$api_key_override" "$relative_path" \
      "${additional_opts[@]}"
    return $?
  fi

  # Step 3: Generate chunk ranges
  local chunk_ranges=()
  mapfile -t chunk_ranges < <(generate_chunk_ranges "$page_count" "$chunk_size")
  local total_chunks=${#chunk_ranges[@]}

  log_info "Splitting into $total_chunks chunks"

  # Step 4: Create temporary directory for chunk outputs
  local temp_dir
  temp_dir=$(create_temp_chunk_dir "$base_name")
  log_debug "Using temp directory: $temp_dir"

  # Step 5: Process each chunk
  local chunk_files=()
  local chunk_dirs=()
  local chunk_num=0
  local failed_chunks=0

  for range in "${chunk_ranges[@]}"; do
    ((++chunk_num))
    log_info "Processing chunk $chunk_num/$total_chunks (pages $range)"

    local chunk_output_dir="${temp_dir}/chunk_${chunk_num}"
    mkdir -p "$chunk_output_dir"

    # Build chunk-specific options (add --page_range for this chunk)
    local chunk_opts=("${additional_opts[@]}")
    chunk_opts+=("--page_range" "$range")

    # Convert this chunk using direct conversion (without chunking logic)
    if convert_single_file_direct "$input_file" "$chunk_output_dir" "$output_format" \
      "$use_llm" "$llm_service" "$api_key_override" "" \
      "${chunk_opts[@]}"; then

      # Find the generated markdown file
      local chunk_md
      if chunk_md=$(find_chunk_markdown "$chunk_output_dir"); then
        chunk_files+=("$chunk_md")
        chunk_dirs+=("$chunk_output_dir")
        log_debug "Chunk $chunk_num completed: $chunk_md"
      else
        log_error "Chunk $chunk_num: no markdown output found"
        ((++failed_chunks))
      fi
    else
      log_error "Chunk $chunk_num failed (pages $range)"
      ((++failed_chunks))
    fi
  done

  # Step 6: Check if we have any successful chunks
  if [[ ${#chunk_files[@]} -eq 0 ]]; then
    log_error "All chunks failed to convert"
    cleanup_temp_dir "$temp_dir"
    return "$EXIT_CONVERSION_FAILED"
  fi

  if [[ $failed_chunks -gt 0 ]]; then
    log_warning "$failed_chunks chunk(s) failed, continuing with ${#chunk_files[@]} successful chunk(s)"
  fi

  # Step 7: Determine final output path
  local final_output_dir
  if [[ -n "$output_dir" ]]; then
    final_output_dir="$(realpath "$output_dir")"
  else
    final_output_dir="$(dirname "$input_file")"
  fi

  # Handle relative path for directory structure preservation
  if [[ -n "$relative_path" ]]; then
    local relative_dir
    relative_dir="$(dirname "$relative_path")"
    if [[ "$relative_dir" != "." ]]; then
      final_output_dir="${final_output_dir}/${relative_dir}"
    fi
  fi

  ensure_output_directory "$final_output_dir"

  # Get final output filename
  local final_output_file
  final_output_file=$(get_output_filename "$input_file" "$output_format" "$final_output_dir" "")

  # Step 8: Merge markdown chunks
  log_info "Merging ${#chunk_files[@]} chunks..."

  if ! merge_markdown_chunks "$final_output_file" "${chunk_files[@]}"; then
    log_error "Failed to merge chunk outputs"
    cleanup_temp_dir "$temp_dir"
    return "$EXIT_CONVERSION_FAILED"
  fi

  # Step 9: Merge images if any exist
  merge_chunk_images "$final_output_dir" "$base_name" "${chunk_dirs[@]}"

  # Step 10: Cleanup temporary directory
  cleanup_temp_dir "$temp_dir"

  log_success "Chunked conversion complete: $final_output_file"

  if [[ $failed_chunks -gt 0 ]]; then
    return "$EXIT_PARTIAL_FAILURE"
  fi

  return "$EXIT_SUCCESS"
}

# convert_single_file_direct - Direct conversion without chunking logic
# This is used internally by chunking to avoid recursive chunking
# It's essentially the original convert_single_file logic
# Args: Same as convert_single_file
convert_single_file_direct() {
  local input_file="${1:-}"
  local output_dir="${2:-}"
  local output_format="${3:-${DEFAULT_OUTPUT_FORMAT}}"
  local use_llm="${4:-}"
  local llm_service="${5:-}"
  local api_key_override="${6:-}"
  local relative_path="${7:-}"

  # Additional options passed as remaining arguments
  shift 7 || true
  local additional_opts=("$@")

  log_debug "Direct conversion of: $input_file"

  # Step 1: Validate input file
  if ! validate_file_exists "$input_file"; then
    return "$EXIT_FILE_NOT_FOUND"
  fi

  if ! validate_file_extension "$input_file"; then
    return "$EXIT_UNSUPPORTED_TYPE"
  fi

  # Step 2: Determine output directory
  local resolved_output_dir
  if [[ -n "$output_dir" ]]; then
    resolved_output_dir="$(get_output_directory "$output_dir")"
  else
    resolved_output_dir="$(dirname "$input_file")"
  fi

  if ! ensure_output_directory "$resolved_output_dir"; then
    log_error "Failed to create output directory: $resolved_output_dir"
    return "$EXIT_DIR_NOT_FOUND"
  fi

  log_debug "Output directory: $resolved_output_dir"

  # Step 2.5: Ensure custom marker image is available
  if ! ensure_custom_image; then
    log_error "Cannot proceed without marker image"
    return "$EXIT_CONTAINER_ERROR"
  fi

  # Step 3: Get absolute paths for Docker mounts
  local abs_input_file abs_output_dir
  abs_input_file="$(realpath "$input_file")"
  abs_output_dir="$(realpath "$resolved_output_dir")"

  # Step 4: Build docker command with all parameters
  local additional_opts_str=""
  if [[ ${#additional_opts[@]} -gt 0 ]]; then
    additional_opts_str="${additional_opts[*]}"
  fi

  local docker_cmd
  mapfile -t docker_cmd < <(build_docker_command "$abs_input_file" "$abs_output_dir" "$output_format" "$llm_service" "$api_key_override" "$additional_opts_str")

  log_debug "Docker command: ${docker_cmd[*]}"

  # Execute conversion
  local docker_exit_code
  if run_docker_command "${docker_cmd[@]}"; then
    docker_exit_code=$?
  else
    docker_exit_code=$?
  fi

  # Step 6: Handle conversion result
  if ! handle_conversion_result "$docker_exit_code" "$input_file"; then
    return $?
  fi

  return "$EXIT_SUCCESS"
}
