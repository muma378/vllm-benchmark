#!/bin/bash

# VLLM Monitoring Control Script
# Manages GPU and RDMA monitoring processes
# Usage: 
#   Start: ./monitor_vllm.sh start [output_dir] [prefix]
#   Stop:  ./monitor_vllm.sh stop

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${2:-/benchmark_results}"
PREFIX="${3:-}"
PID_FILE="/tmp/vllm_monitor.pids"

# Monitoring configurations
GPU_SAMPLING_INTERVAL="${GPU_SAMPLING_INTERVAL:-1}"
RDMA_SAMPLING_INTERVAL="${RDMA_SAMPLING_INTERVAL:-1}"

start_monitoring() {
    # Check if monitoring is already running
    if [ -f "$PID_FILE" ]; then
        echo "Warning: Monitoring appears to be already running."
        echo "PID file exists at: $PID_FILE"
        echo ""
        echo "Checking process status..."
        
        local has_running=0
        while IFS= read -r pid; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo "  PID $pid: RUNNING"
                has_running=1
            else
                echo "  PID $pid: NOT RUNNING (stale)"
            fi
        done < "$PID_FILE"
        
        if [ $has_running -eq 0 ]; then
            echo ""
            echo "All processes are stopped. Cleaning up stale PID file..."
            rm -f "$PID_FILE"
            echo "Proceeding with startup..."
            echo ""
        else
            echo ""
            echo "Please stop existing monitors first:"
            echo "  $0 stop"
            echo ""
            echo "Or force cleanup with:"
            echo "  pkill -f 'rdma_monitor.py' && pkill -f 'gpu_monitor.sh' && rm -f $PID_FILE"
            exit 1
        fi
    fi

    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    echo "Starting monitoring..."
    echo "Output directory: $OUTPUT_DIR"
    if [ -n "$PREFIX" ]; then
        echo "Filename prefix: $PREFIX"
    fi
    echo "---"

    # Start GPU monitor
    echo "Starting GPU monitor..."
    if [ -n "$PREFIX" ]; then
        GPU_LOG="$OUTPUT_DIR/${PREFIX}_gpu_usage.csv"
        RDMA_LOG="$OUTPUT_DIR/${PREFIX}_rdma_usage.csv"
    else
        GPU_LOG="$OUTPUT_DIR/gpu_usage.csv"
        RDMA_LOG="$OUTPUT_DIR/rdma_usage.csv"
    fi
    
    bash "$SCRIPT_DIR/gpu_monitor.sh" "$GPU_LOG" "$GPU_SAMPLING_INTERVAL" > /dev/null 2>&1 &
    GPU_PID=$!
    echo "  GPU monitor PID: $GPU_PID"
    echo "  GPU CSV log: $GPU_LOG"

    # Start RDMA monitor
    echo "Starting RDMA monitor..."
    python3 "$SCRIPT_DIR/rdma_monitor.py" \
        --interval "$RDMA_SAMPLING_INTERVAL" \
        --log-csv "$RDMA_LOG" \
        --daemon \
        > /dev/null 2>&1 &
    RDMA_PID=$!
    echo "  RDMA monitor PID: $RDMA_PID"
    echo "  RDMA CSV log: $RDMA_LOG"

    # Save PIDs for later cleanup
    echo "$GPU_PID" > "$PID_FILE"
    echo "$RDMA_PID" >> "$PID_FILE"

    echo "---"
    echo "Monitoring started successfully!"
    echo "To stop monitoring, run: $0 stop"
    echo ""
    echo "Monitoring processes:"
    echo "  GPU:  PID $GPU_PID"
    echo "  RDMA: PID $RDMA_PID"
    echo ""
    echo "Output files:"
    echo "  GPU CSV:  $GPU_LOG"
    echo "  RDMA CSV: $RDMA_LOG"
}

stop_monitoring() {
    echo "Stopping monitoring..."

    if [ ! -f "$PID_FILE" ]; then
        echo "No PID file found at $PID_FILE"
        echo "Attempting to stop any running monitoring processes..."
        
        # Fallback: try to kill by process name
        pkill -f "gpu_monitor.sh"
        pkill -f "rdma_monitor.py"
        
        echo "Done."
        return 0
    fi

    # Read PIDs and stop processes
    local stopped_count=0
    local failed_count=0
    
    while IFS= read -r pid; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "Stopping process $pid..."
            if kill -TERM "$pid" 2>/dev/null; then
                # Wait for graceful shutdown (max 5 seconds)
                local wait_count=0
                while kill -0 "$pid" 2>/dev/null && [ $wait_count -lt 50 ]; do
                    sleep 0.1
                    wait_count=$((wait_count + 1))
                done
                
                # Force kill if still running
                if kill -0 "$pid" 2>/dev/null; then
                    echo "  Process $pid did not stop gracefully, forcing..."
                    kill -KILL "$pid" 2>/dev/null
                fi
                
                echo "  Process $pid stopped."
                stopped_count=$((stopped_count + 1))
            else
                echo "  Failed to stop process $pid"
                failed_count=$((failed_count + 1))
            fi
        else
            echo "  Process $pid not running (already stopped or invalid PID)"
        fi
    done < "$PID_FILE"

    # Remove PID file
    rm -f "$PID_FILE"

    echo "---"
    echo "Monitoring stopped."
    echo "  Processes stopped: $stopped_count"
    if [ $failed_count -gt 0 ]; then
        echo "  Failed to stop: $failed_count"
    fi
}

show_status() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Monitoring is NOT running (no PID file found)"
        return 1
    fi

    echo "Monitoring status:"
    echo "PID file: $PID_FILE"
    echo ""
    
    local running_count=0
    local stopped_count=0
    
    while IFS= read -r pid; do
        if [ -n "$pid" ]; then
            if kill -0 "$pid" 2>/dev/null; then
                echo "  PID $pid: RUNNING"
                running_count=$((running_count + 1))
            else
                echo "  PID $pid: STOPPED"
                stopped_count=$((stopped_count + 1))
            fi
        fi
    done < "$PID_FILE"
    
    echo ""
    echo "Summary: $running_count running, $stopped_count stopped"
    
    if [ $running_count -eq 0 ]; then
        echo "Warning: No monitoring processes are running. Consider cleaning up with 'stop' command."
        return 1
    fi
}

# Main command handler
case "${1:-}" in
    start)
        start_monitoring
        ;;
    stop)
        stop_monitoring
        ;;
    status)
        show_status
        ;;
    restart)
        stop_monitoring
        sleep 2
        start_monitoring
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart} [output_dir] [prefix]"
        echo ""
        echo "Commands:"
        echo "  start [output_dir] [prefix]  - Start GPU and RDMA monitoring"
        echo "  stop                         - Stop all monitoring processes"
        echo "  status                       - Check monitoring status"
        echo "  restart [output_dir] [prefix]- Restart monitoring"
        echo ""
        echo "Arguments:"
        echo "  output_dir  - Directory for output CSV files (default: /benchmark_results)"
        echo "  prefix      - Prefix for CSV filenames (optional)"
        echo "                If provided: {prefix}_gpu_usage.csv, {prefix}_rdma_usage.csv"
        echo "                If omitted:  gpu_usage.csv, rdma_usage.csv"
        echo ""
        echo "Environment variables:"
        echo "  GPU_SAMPLING_INTERVAL   - GPU sampling interval in seconds (default: 1)"
        echo "  RDMA_SAMPLING_INTERVAL  - RDMA sampling interval in seconds (default: 1)"
        echo ""
        echo "Examples:"
        echo "  $0 start /my/results"
        echo "  $0 start /my/results test1"
        echo "  GPU_SAMPLING_INTERVAL=2 $0 start /my/results experiment_a"
        echo "  $0 stop"
        exit 1
        ;;
esac


