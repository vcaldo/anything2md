#!/usr/bin/env bash
#
# E2E Test Script for anything2md
# Converts all test fixtures and validates outputs exist and are non-empty
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONVERSION_TESTS_DIR="$PROJECT_ROOT/conversion_tests"
CLI="$PROJECT_ROOT/anything2md"

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Supported extensions (from constants.sh)
SUPPORTED_EXTENSIONS=("pdf" "docx" "xlsx" "pptx" "epub" "html" "png" "jpg" "jpeg" "tiff" "bmp")

# Create temp directory for outputs
TMP_DIR=$(mktemp -d)
echo "Using temp directory: $TMP_DIR"

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up temp directory..."
    sudo rm -rf "$TMP_DIR" 2>/dev/null || rm -rf "$TMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Check if extension is supported
is_supported_extension() {
    local file="$1"
    local ext="${file##*.}"
    ext="${ext,,}" # lowercase

    for supported in "${SUPPORTED_EXTENSIONS[@]}"; do
        if [[ "$ext" == "$supported" ]]; then
            return 0
        fi
    done
    return 1
}

# Run a single test
run_test() {
    local input_file="$1"
    local relative_path="${input_file#$CONVERSION_TESTS_DIR/}"
    local basename_noext="${input_file##*/}"
    basename_noext="${basename_noext%.*}"
    local expected_output="$TMP_DIR/${basename_noext}/${basename_noext}.md"
    local error_file
    error_file=$(mktemp)

    # Run conversion
    if ! "$CLI" convert "$input_file" --output-dir "$TMP_DIR" 2>"$error_file"; then
        echo -e "${RED}[FAIL]${NC} $relative_path - conversion command failed"
        # Show error details indented
        if [[ -s "$error_file" ]]; then
            sed 's/^/       /' "$error_file"
        fi
        rm -f "$error_file"
        ((FAILED++)) || true
        return 1
    fi
    rm -f "$error_file"

    # Check if output file exists
    if [[ ! -f "$expected_output" ]]; then
        echo -e "${RED}[FAIL]${NC} $relative_path - output file not found"
        ((FAILED++)) || true
        return 1
    fi

    # Check if output file is non-empty
    if [[ ! -s "$expected_output" ]]; then
        echo -e "${RED}[FAIL]${NC} $relative_path - output file is empty"
        ((FAILED++)) || true
        return 1
    fi

    echo -e "${GREEN}[PASS]${NC} $relative_path"
    ((PASSED++)) || true
    return 0
}

# Main
main() {
    echo "========================================"
    echo "  anything2md E2E Tests"
    echo "========================================"
    echo ""

    # Check prerequisites
    if [[ ! -x "$CLI" ]]; then
        echo -e "${RED}Error:${NC} CLI not found or not executable: $CLI"
        exit 1
    fi

    if [[ ! -d "$CONVERSION_TESTS_DIR" ]]; then
        echo -e "${RED}Error:${NC} Test fixtures directory not found: $CONVERSION_TESTS_DIR"
        exit 1
    fi

    # Clean up any existing output directories from previous conversions
    echo "Cleaning up previous conversion outputs..."
    find "$CONVERSION_TESTS_DIR" -type d -mindepth 2 -exec sudo rm -rf {} + 2>/dev/null || true
    find "$CONVERSION_TESTS_DIR" -type f -name "*_meta.json" -delete 2>/dev/null || true
    echo ""

    echo "Running E2E tests..."
    echo ""

    # Find all test files
    while IFS= read -r -d '' file; do
        # Skip placeholder sample.txt files
        if [[ "$(basename "$file")" == "sample.txt" ]]; then
            continue
        fi

        # Skip files in subdirectories (marker output directories)
        local file_depth=$(echo "${file#$CONVERSION_TESTS_DIR/}" | tr -cd '/' | wc -c)
        if [[ $file_depth -gt 1 ]]; then
            continue
        fi

        # Skip non-supported extensions
        if ! is_supported_extension "$file"; then
            echo -e "${YELLOW}[SKIP]${NC} ${file#$CONVERSION_TESTS_DIR/} - unsupported extension"
            ((SKIPPED++)) || true
            continue
        fi

        run_test "$file" || true

    done < <(find "$CONVERSION_TESTS_DIR" -type f -print0 | sort -z)

    # Print summary
    echo ""
    echo "========================================"
    echo "  Summary"
    echo "========================================"
    local total=$((PASSED + FAILED))
    echo "Total tests: $total"
    echo -e "Passed:      ${GREEN}$PASSED${NC}"
    echo -e "Failed:      ${RED}$FAILED${NC}"
    if [[ $SKIPPED -gt 0 ]]; then
        echo -e "Skipped:     ${YELLOW}$SKIPPED${NC}"
    fi
    echo ""

    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

main "$@"
