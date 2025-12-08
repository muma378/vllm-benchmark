#!/bin/bash

################################################################################
# PD Benchmark Script
# 
# This script runs Prefill/Decode benchmarks with different modes:
# - Separate mode: Run prefill-only and decode-only tests separately
# - Combined mode: Run PD combined tests (requires model in PD mode)
# - All mode: Run both separate and combined tests
#
# Each input length will have a unique seed for reproducibility
################################################################################

set -e

# ============================================================================
# Configuration
# ============================================================================

# Default values
MODEL="${MODEL:-/models/Qwen3-30B-A3B-Instruct-2507-FP8}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-Qwen3-30B-A3B-Instruct-2507-FP8}"
BASE_URL="${BASE_URL:-http://localhost:30800}"
OUTPUT_BASE_DIR="${OUTPUT_BASE_DIR:-/benchmark_results}"
CASE_NAME="${CASE_NAME:-pd-separate-test}"

# Test parameters
NUM_PROMPTS="${NUM_PROMPTS:-20}"
REQUEST_RATE="${REQUEST_RATE:-16}"
DECODE_OUTPUT_LEN="${DECODE_OUTPUT_LEN:-10}"

# Test type: separate, combined, or all
# - separate: Run prefill-only and decode-only tests separately
# - combined: Run PD combined test (requires model redeployment for PD mode)
# - all: Run both separate and combined tests
TEST_TYPE="${TEST_TYPE:-separate}"

# Input length array - can be overridden by environment variable
# Example: INPUT_LENS="100 1000 10000 50000 100000"
if [ -z "$INPUT_LENS" ]; then
    INPUT_LENS=(100 1000 10000 20000 50000)
else
    # Convert space-separated string to array
    read -ra INPUT_LENS <<< "$INPUT_LENS"
fi

# Base seed for generating unique seeds
BASE_SEED="${BASE_SEED:-22}"

# Warmup settings
WARMUP="${WARMUP:-true}"
WARMUP_SEED=2
WARMUP_PROMPTS=5
WARMUP_INPUT_LEN=100

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
    exit 1
}

# Generate unique seed for each input length
# Formula: BASE_SEED + input_len
generate_seed() {
    local input_len=$1
    echo $((BASE_SEED + input_len))
}

# ============================================================================
# Main Functions
# ============================================================================

print_config() {
    log "=========================================="
    log "PD Benchmark Configuration"
    log "=========================================="
    log "Model: $MODEL"
    log "Served Model Name: $SERVED_MODEL_NAME"
    log "Base URL: $BASE_URL"
    log "Output Directory: $OUTPUT_DIR"
    log "Case Name: $CASE_NAME"
    log "------------------------------------------"
    log "Test Type: $TEST_TYPE"
    log "Test Parameters:"
    log "  Number of Prompts: $NUM_PROMPTS"
    log "  Request Rate: $REQUEST_RATE"
    log "  Decode Output Length: $DECODE_OUTPUT_LEN"
    log "  Input Lengths: ${INPUT_LENS[*]}"
    log "  Base Seed: $BASE_SEED"
    log "------------------------------------------"
    log "Warmup: $WARMUP"
    if [ "$WARMUP" = "true" ]; then
        log "  Warmup Prompts: $WARMUP_PROMPTS"
        log "  Warmup Input Length: $WARMUP_INPUT_LEN"
        log "  Warmup Seed: $WARMUP_SEED"
    fi
    log "=========================================="
}

run_warmup() {
    if [ "$WARMUP" != "true" ]; then
        log "Skipping warmup..."
        return
    fi
    
    log "=========================================="
    log "Running warmup..."
    log "=========================================="
    
    /opt/venv/bin/vllm bench serve \
        --model "$MODEL" \
        --served-model-name "$SERVED_MODEL_NAME" \
        --dataset-name random \
        --base-url "$BASE_URL" \
        --seed $WARMUP_SEED \
        --num-prompts $WARMUP_PROMPTS \
        --max-concurrency 1 \
        --random-input-len $WARMUP_INPUT_LEN \
        --random-output-len 1 \
        --metadata "type=warmup"
    
    log "Warmup completed"
    sleep 1
}

run_prefill_only() {
    local input_len=$1
    local seed=$2
    
    log "=========================================="
    log "Running Prefill-Only Test"
    log "Input Length: $input_len, Seed: $seed"
    log "=========================================="
    
    /opt/venv/bin/vllm bench serve \
        --model "$MODEL" \
        --served-model-name "$SERVED_MODEL_NAME" \
        --dataset-name random \
        --seed "$seed" \
        --num-prompts "$NUM_PROMPTS" \
        --request-rate "$REQUEST_RATE" \
        --random-input-len "$input_len" \
        --random-output-len 1 \
        --base-url "$BASE_URL" \
        --save-result \
        --save-detailed \
        --append-result \
        --result-filename "${OUTPUT_DIR}/benchmark_result.json" \
        --metadata "type=prefill-only,input_len=$input_len"
    
    log "Prefill-Only test completed for input_len=$input_len"
    sleep 2
}

run_decode_only() {
    local input_len=$1
    local seed=$2
    
    log "=========================================="
    log "Running Decode-Only Test"
    log "Input Length: $input_len, Seed: $seed"
    log "=========================================="
    
    /opt/venv/bin/vllm bench serve \
        --model "$MODEL" \
        --served-model-name "$SERVED_MODEL_NAME" \
        --dataset-name random \
        --seed "$seed" \
        --num-prompts "$NUM_PROMPTS" \
        --request-rate "$REQUEST_RATE" \
        --random-input-len "$input_len" \
        --random-output-len "$DECODE_OUTPUT_LEN" \
        --base-url "$BASE_URL" \
        --save-result \
        --save-detailed \
        --append-result \
        --result-filename "${OUTPUT_DIR}/benchmark_result.json" \
        --metadata "type=decode-only,input_len=$input_len,output_len=$DECODE_OUTPUT_LEN"
    
    log "Decode-Only test completed for input_len=$input_len"
    sleep 2
}

run_pd_combined() {
    local input_len=$1
    local seed=$2
    
    log "=========================================="
    log "Running PD Combined Test"
    log "Input Length: $input_len, Seed: $seed"
    log "=========================================="
    log "NOTE: Make sure the model is deployed in PD mode!"
    
    /opt/venv/bin/vllm bench serve \
        --model "$MODEL" \
        --served-model-name "$SERVED_MODEL_NAME" \
        --dataset-name random \
        --seed "$seed" \
        --num-prompts "$NUM_PROMPTS" \
        --request-rate "$REQUEST_RATE" \
        --random-input-len "$input_len" \
        --random-output-len "$DECODE_OUTPUT_LEN" \
        --base-url "$BASE_URL" \
        --save-result \
        --save-detailed \
        --append-result \
        --result-filename "${OUTPUT_DIR}/benchmark_result.json" \
        --metadata "type=pd,input_len=$input_len,output_len=$DECODE_OUTPUT_LEN"
    
    log "PD Combined test completed for input_len=$input_len"
    sleep 2
}

run_separate_tests() {
    log "=========================================="
    log "Starting PD Separate Tests"
    log "=========================================="
    
    for input_len in "${INPUT_LENS[@]}"; do
        # Generate unique seed for this input length
        local seed=$(generate_seed "$input_len")
        
        log "------------------------------------------"
        log "Testing with input_len=$input_len, seed=$seed"
        log "------------------------------------------"
        
        # Run prefill-only test
        run_prefill_only "$input_len" "$seed"
        
        # Run decode-only test
        run_decode_only "$input_len" "$seed"
        
        log "Completed separate tests for input_len=$input_len"
        log ""
    done
    
    log "=========================================="
    log "All PD Separate Tests Completed"
    log "=========================================="
}

run_combined_tests() {
    log "=========================================="
    log "Starting PD Combined Tests"
    log "=========================================="
    log "IMPORTANT: Ensure the model is deployed in PD mode!"
    log "=========================================="
    
    for input_len in "${INPUT_LENS[@]}"; do
        # Generate unique seed for this input length
        local seed=$(generate_seed "$input_len")
        
        log "------------------------------------------"
        log "Testing with input_len=$input_len, seed=$seed"
        log "------------------------------------------"
        
        # Run PD combined test
        run_pd_combined "$input_len" "$seed"
        
        log "Completed combined test for input_len=$input_len"
        log ""
    done
    
    log "=========================================="
    log "All PD Combined Tests Completed"
    log "=========================================="
}

run_all_tests() {
    # Validate test type
    case "$TEST_TYPE" in
        separate)
            run_separate_tests
            ;;
        combined|pd)
            run_combined_tests
            ;;
        all)
            log "=========================================="
            log "Running ALL Tests (Separate + Combined)"
            log "=========================================="
            log ""
            
            run_separate_tests
            
            log ""
            log "=========================================="
            log "Switching to PD Combined Tests"
            log "=========================================="
            log "IMPORTANT: You may need to redeploy the model in PD mode now!"
            log "Press Ctrl+C to abort, or wait 10 seconds to continue..."
            sleep 10
            
            run_combined_tests
            ;;
        *)
            error "Invalid test type: $TEST_TYPE. Must be one of: separate, combined, all"
            ;;
    esac
}

show_results() {
    log "=========================================="
    log "Test Results Summary"
    log "=========================================="
    log "Results saved to: ${OUTPUT_DIR}/benchmark_result.json"
    
    if [ -f "${OUTPUT_DIR}/benchmark_result.json" ]; then
        log "Result file size: $(du -h "${OUTPUT_DIR}/benchmark_result.json" | cut -f1)"
        log "Total test cases: $(grep -c '"metadata"' "${OUTPUT_DIR}/benchmark_result.json" || echo "0")"
    else
        log "Warning: Result file not found"
    fi
    
    log "=========================================="
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

PD Benchmark Script - Runs Prefill/Decode separate or combined tests

Options:
    -h, --help              Show this help message
    -c, --case NAME         Set case name (default: pd-separate-test)
    -t, --test-type TYPE    Test type: separate, combined, or all (default: separate)
                            - separate: Run prefill-only and decode-only separately
                            - combined: Run PD combined test (requires PD mode deployment)
                            - all: Run both separate and combined tests
    -i, --input-lens LENS   Space-separated input lengths (default: "100 1000 5000 10000")
    -p, --prompts NUM       Number of prompts (default: 2)
    -r, --rate NUM          Request rate (default: 16)
    -d, --decode-len NUM    Decode output length (default: 10)
    -s, --base-seed NUM     Base seed for generating unique seeds (default: 1000)
    --no-warmup             Skip warmup phase
    --output-dir DIR        Output directory (default: /benchmark_results)

Environment Variables:
    MODEL                   Model path (default: /models/Qwen3-30B-A3B-Instruct-2507-FP8)
    SERVED_MODEL_NAME       Served model name (default: Qwen3-30B-A3B-Instruct-2507-FP8)
    BASE_URL                Base URL for vllm server (default: http://localhost:30800)
    TEST_TYPE               Test type: separate, combined, or all

Examples:
    # Run separate tests (default)
    $0

    # Run PD combined test (model must be in PD mode)
    $0 --test-type combined

    # Run all tests (separate + combined)
    $0 --test-type all

    # Run with custom input lengths and parameters
    $0 -t combined -i "1000 5000 10000" -p 5 -r 32 -d 20

    # Run with custom case name
    $0 -c pd-gds-OSL1 -t combined

    # Run with environment variables
    MODEL=/models/MyModel BASE_URL=http://localhost:8000 TEST_TYPE=combined $0

EOF
}

# ============================================================================
# Parse Arguments
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -c|--case)
                CASE_NAME="$2"
                shift 2
                ;;
            -t|--test-type)
                TEST_TYPE="$2"
                shift 2
                ;;
            -i|--input-lens)
                INPUT_LENS_STR="$2"
                read -ra INPUT_LENS <<< "$INPUT_LENS_STR"
                shift 2
                ;;
            -p|--prompts)
                NUM_PROMPTS="$2"
                shift 2
                ;;
            -r|--rate)
                REQUEST_RATE="$2"
                shift 2
                ;;
            -d|--decode-len)
                DECODE_OUTPUT_LEN="$2"
                shift 2
                ;;
            -s|--base-seed)
                BASE_SEED="$2"
                shift 2
                ;;
            --no-warmup)
                WARMUP="false"
                shift
                ;;
            --output-dir)
                OUTPUT_BASE_DIR="$2"
                shift 2
                ;;
            *)
                error "Unknown option: $1. Use -h for help."
                ;;
        esac
    done
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Validate test type
    if [[ ! "$TEST_TYPE" =~ ^(separate|combined|pd|all)$ ]]; then
        error "Invalid test type: $TEST_TYPE. Must be one of: separate, combined, all"
    fi
    
    # Setup output directory
    OUTPUT_DIR="${OUTPUT_BASE_DIR}/${CASE_NAME}"
    mkdir -p "$OUTPUT_DIR"
    
    # Setup log file with timestamp
    LOG_TIME=$(date +'%Y%m%d-%H%M%S')
    LOG_FILE="${OUTPUT_DIR}/${LOG_TIME}-bench.log"
    
    # Redirect all output to both console and log file
    exec > >(tee -a "$LOG_FILE")
    exec 2>&1
    
    log "Log file: $LOG_FILE"
    
    # Print configuration
    print_config
    
    # Record start time
    START_TIME=$(date +%s)
    
    # Run warmup
    run_warmup
    
    # Run tests based on test type
    run_all_tests
    
    # Calculate duration
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # Show results
    show_results
    
    log "Total execution time: ${DURATION} seconds"
    log "Test completed successfully!"
}

# Run main function
main "$@"


