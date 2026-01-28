#!/usr/bin/env bash
# convert_command.sh - Single file conversion command
# This file implements the 'anything2md convert' command

# shellcheck disable=SC2154
# Note: args array and other bashly-provided variables are injected by bashly

# Get input file from positional argument
input_file="${args[input_file]}"

log_debug "Starting convert command for: $input_file"

# Step 1: Validate input file exists and has supported extension
validate_file_exists "$input_file" || exit $?
validate_file_extension "$input_file" || exit $?

# Step 2: Determine output format (flag > env var > default)
output_format="${args[--format]}"
if [[ -z "$output_format" ]]; then
  output_format="${ANYTHING2MD_OUTPUT_FORMAT:-$DEFAULT_OUTPUT_FORMAT}"
fi
validate_output_format "$output_format" || exit $?

log_debug "Output format: $output_format"

# Step 3: Determine output directory (flag > env var > input file location)
output_dir="${args[--output-dir]}"
if [[ -z "$output_dir" ]]; then
  output_dir="${ANYTHING2MD_OUTPUT_DIR}"
fi
if [[ -z "$output_dir" ]]; then
  # Default: same directory as input file
  output_dir="$(dirname "$input_file")"
fi

log_debug "Output directory: $output_dir"

# Step 4: Build additional marker options array
additional_options=()

# Handle --vram option
if [[ -n "${args[--vram]}" ]]; then
  additional_options+=("--vram=${args[--vram]}")
  log_debug "VRAM limit: ${args[--vram]} GB"
elif [[ -n "${ANYTHING2MD_VRAM}" ]]; then
  additional_options+=("--vram=${ANYTHING2MD_VRAM}")
  log_debug "VRAM limit (env): ${ANYTHING2MD_VRAM} GB"
fi

# Handle --force-ocr flag
if [[ "${args[--force-ocr]}" == "1" ]]; then
  additional_options+=("--force_ocr")
  log_debug "Force OCR enabled"
fi

# Handle --pages option
if [[ -n "${args[--pages]}" ]]; then
  validate_page_range "${args[--pages]}" || exit $?
  additional_options+=("--pages=${args[--pages]}")
  log_debug "Page range: ${args[--pages]}"
fi

# Handle --paginate flag
if [[ "${args[--paginate]}" == "1" ]]; then
  additional_options+=("--paginate")
  log_debug "Paginated output enabled"
fi

# Handle --no-images flag
if [[ "${args[--no-images]}" == "1" ]]; then
  additional_options+=("--disable_image_extraction")
  log_debug "Image extraction disabled"
fi

# Step 5: Handle LLM options
use_llm="${args[--use-llm]}"
llm_service=""
api_key_override=""

if [[ "$use_llm" == "1" ]]; then
  # Only set LLM service if LLM is explicitly enabled
  llm_service="${args[--llm-service]}"
  api_key_override="${args[--api-key]}"

  # Determine LLM service (flag > env var > default)
  if [[ -z "$llm_service" ]]; then
    llm_service="${ANYTHING2MD_LLM_SERVICE:-$DEFAULT_LLM_SERVICE}"
  fi

  log_debug "LLM enhancement enabled with service: $llm_service"

  # Additional options will be passed to convert_single_file
  # which will handle LLM configuration via get_llm_env_vars
fi

# Step 6: Handle --move-originals vs --keep-originals
move_originals_dir="${args[--move-originals]}"
keep_originals="${args[--keep-originals]}"

if [[ -n "$move_originals_dir" ]] && [[ "$keep_originals" == "1" ]]; then
  log_error "Cannot use both --move-originals and --keep-originals"
  exit "$EXIT_INVALID_ARGS"
fi

# Step 7: Call convert_single_file() from conversion.sh library
log_info "Converting: $(basename "$input_file")"

# Call the conversion function with all parameters
# Parameters: input_file, output_dir, output_format, use_llm, llm_service, api_key_override, relative_path, additional_options...
# Note: relative_path is empty string for single-file conversion (no directory structure preservation needed)
convert_single_file \
  "$input_file" \
  "$output_dir" \
  "$output_format" \
  "$use_llm" \
  "$llm_service" \
  "$api_key_override" \
  "" \
  "${additional_options[@]}"

conversion_exit_code=$?

# Step 8: Handle move originals if conversion succeeded and option specified
if [[ $conversion_exit_code -eq 0 ]] && [[ -n "$move_originals_dir" ]]; then
  log_debug "Moving original file to: $move_originals_dir"
  move_original_file "$input_file" "$move_originals_dir"
  move_exit_code=$?

  if [[ $move_exit_code -ne 0 ]]; then
    log_warning "Conversion succeeded but failed to move original file"
    # Don't fail the command - conversion was successful
  else
    log_success "Original file moved to: $move_originals_dir/$(basename "$input_file")"
  fi
fi

# Step 9: Display result message with output path
if [[ $conversion_exit_code -eq 0 ]]; then
  # Get output filename with corrected parameter order: input_file, output_format, output_dir, relative_path
  output_file=$(get_output_filename "$input_file" "$output_format" "$output_dir" "")
  log_success "Conversion complete: $output_file"
else
  log_error "Conversion failed with exit code: $conversion_exit_code"
fi

exit "$conversion_exit_code"
