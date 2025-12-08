#!/bin/bash

# GPU monitoring script
# This script runs continuously until interrupted
# Usage: ./gpu_monitor.sh <output_file> [sampling_interval]

OUTPUT_FILE="${1:-/benchmark_results/gpu_usage.log}"
SAMPLING_INTERVAL="${2:-1}"

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Check if nvidia-smi is available
if ! command -v nvidia-smi &> /dev/null; then
    echo "Error: nvidia-smi not found. Please ensure NVIDIA drivers are installed." >&2
    exit 1
fi

echo "GPU monitoring started at $(date)" >&2
echo "Output file: $OUTPUT_FILE" >&2
echo "Sampling interval: ${SAMPLING_INTERVAL}s" >&2

# Cleanup handler
cleanup() {
    echo "" >&2
    echo "GPU monitoring stopped at $(date)" >&2
    exit 0
}

# Trap signals for graceful shutdown
trap cleanup SIGINT SIGTERM

# Start GPU monitoring (will run until interrupted)
nvidia-smi \
  --query-gpu=timestamp,index,name,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw \
  --format=csv -l "$SAMPLING_INTERVAL" \
  > "$OUTPUT_FILE" 2>&1

cleanup


