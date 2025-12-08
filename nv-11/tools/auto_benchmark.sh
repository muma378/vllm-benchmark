#!/bin/bash
set -x
set -e

DRY_RUN=false
ONLY_BENCHMARK_TEST=false
FORCE_REMOVE=true
KEEP_MODEL_AFTER_SINGLE=false
KEEP_MODEL_ACTIVE=false

CONTAINER_RUNTIME="docker"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE="lmcache/vllm-openai:v0.3.3-gds"
BENCHMARK_IMAGE="vllm-benchmark:latest"
CONTAINER_NAME="vllm-server-deepseek"
BENCHMARK_CONTAINER_NAME="vllm-benchmark"
BENCHMARK_ENV_VARS=()

HOST_IP="10.20.10.2"

TP_SIZE=8
CPU_CACHE=48
LMCACHE_CHUNK_SIZE=256
TESTS_CASE_RAW="no-kvcache"
GPU_MEMORY_UTILIZATION=""
EXPERIMENT_PURPOSE=""
LMCACHE_EXTRA_ARGS=()


WORK_DIR="/root/daocloud"
DISK_MODELS="/data"
MODEL_PATH="/models/DeepSeek-R1-0528"

GDS_800_CACHE_DIR="/800Gb"
GDS_400_CACHE_DIR="/400Gb"

RDMA_MONITOR_INTERVAL=1
RDMA_MONITOR_PID=""

STOP_OUTDIR="$WORK_DIR/benchmark_results"

ORIGINAL_ARGS=("$@")

usage() {
    cat <<EOF
Usage: $0 [options]
  --dry-run                        Only print commands without execution
  --vllm-image <image>             Docker image for vllm server (default: $IMAGE)
  --benchmark-image <image>        Docker image for benchmark container (default: $BENCHMARK_IMAGE)
  --container-name <name>          vllm server container name (default: $CONTAINER_NAME)
  --benchmark-container-name <name> Benchmark container name (default: $BENCHMARK_CONTAINER_NAME)
  --host-ip <ip>                   Host IP exported to container (default: $HOST_IP)
  --container-runtime <runtime>    Container runtime command (docker or nerdctl, default: $CONTAINER_RUNTIME)
  --work-dir <path>                 Work directory (default: $WORK_DIR)
  --disk-models <path>             Disk models Weight download path (default: $DISK_MODELS)
  --model-path <path>              VLLM command model path, must /models prefix (default: $MODEL_PATH)
  --tp-size <size>                 Tensor parallel size (default: $TP_SIZE)
  --gpu-memory-utilization <ratio> Set vLLM --gpu-memory-utilization (e.g. 0.85)
  --cpu-cache <size>               CPU cache size (default: $CPU_CACHE)
  --lmcache-chunk-size <size>      LMCACHE chunk size (default: $LMCACHE_CHUNK_SIZE)
  --lmcache-arg KEY=VALUE          Additional LMCACHE env-style argument (repeatable)
  --tests-case <cases>             Comma separated test cases from:
                                   gds-400g,gds-800g,disk-400g,disk-800g,cpu,no-kvcache
  --gds-400-cache-dir <path>       GDS 400GB cache directory (default: $GDS_400_CACHE_DIR)
  --gds-800-cache-dir <path>       GDS 800GB cache directory (default: $GDS_800_CACHE_DIR)
  --only-benchmark-test            Skip starting vLLM servers, only run benchmarks
  --bench-output-dir <path>        Override OUTPUT_DIR env for benchmark runs
  --bench-results-file <name>      Override BENCHMARK_RESULTS_FILE env
  --bench-output-len <len>         Override OUTPUT_LEN env
  --bench-num-prompts <num>        Override PROMPTS_NUM env
  --bench-seed <seed|random>       Override SEED env (use 'random' for per-run random seeds)
  --bench-max-concurrency <num>    Override MAX_CONCURRENCY env
  --bench-input-len-list <list>    Override INPUT_LEN_LIST env (comma separated)
  --bench-repeat <num>             Override RANDOM_REPEAT env
  --bench-retry-count <num>        Override BENCHMARK_RETRY_COUNT env (default: 3)
  --bench-retry-delay <seconds>    Override BENCHMARK_RETRY_DELAY env (default: 5)
  --experiment-purpose <text>      Description of the experiment purpose
  --bench-env KEY=VALUE            Pass through additional env vars to run.sh (repeatable)
  --force-remove <true|false>      Force remove containers on exit (default: true)
  --keep-model                     Keep vLLM container running after single test case
  -h, --help                       Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --container-runtime)
            CONTAINER_RUNTIME="$2"
            shift 2
            ;;
        --vllm-image)
            IMAGE="$2"
            shift 2
            ;;
        --benchmark-image)
            BENCHMARK_IMAGE="$2"
            shift 2
            ;;
        --container-name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        --benchmark-container-name)
            BENCHMARK_CONTAINER_NAME="$2"
            shift 2
            ;;
        --host-ip)
            HOST_IP="$2"
            shift 2
            ;;
        --work-dir)
            WORK_DIR="$2"
            shift 2
            ;;
        --disk-models)
            DISK_MODELS="$2"
            shift 2
            ;;
        --model-path)
            MODEL_PATH="$2"
            shift 2
            ;;
        --tp-size)
            TP_SIZE="$2"
            shift 2
            ;;
        --cpu-cache)
            CPU_CACHE="$2"
            shift 2
            ;;
        --lmcache-chunk-size)
            LMCACHE_CHUNK_SIZE="$2"
            shift 2
            ;;
        --tests-case)
            TESTS_CASE_RAW="$2"
            shift 2
            ;;
        --bench-output-dir)
            BENCHMARK_ENV_VARS+=("OUTPUT_DIR=$2")
            shift 2
            ;;
        --bench-results-file)
            BENCHMARK_ENV_VARS+=("BENCHMARK_RESULTS_FILE=$2")
            shift 2
            ;;
        --bench-output-len)
            BENCHMARK_ENV_VARS+=("OUTPUT_LEN=$2")
            shift 2
            ;;
        --bench-num-prompts)
            BENCHMARK_ENV_VARS+=("PROMPTS_NUM=$2")
            shift 2
            ;;
        --bench-seed)
            BENCHMARK_ENV_VARS+=("SEED=$2")
            shift 2
            ;;
        --bench-max-concurrency)
            BENCHMARK_ENV_VARS+=("MAX_CONCURRENCY=$2")
            shift 2
            ;;
        --bench-input-len-list)
            BENCHMARK_ENV_VARS+=("INPUT_LEN_LIST=$2")
            shift 2
            ;;
        --bench-repeat)
            BENCHMARK_ENV_VARS+=("RANDOM_REPEAT=$2")
            shift 2
            ;;
        --bench-retry-count)
            BENCHMARK_ENV_VARS+=("BENCHMARK_RETRY_COUNT=$2")
            shift 2
            ;;
        --bench-retry-delay)
            BENCHMARK_ENV_VARS+=("BENCHMARK_RETRY_DELAY=$2")
            shift 2
            ;;
        --experiment-purpose)
            EXPERIMENT_PURPOSE="$2"
            shift 2
            ;;
        --bench-env)
            if [[ "$2" != *=* ]]; then
                echo "Invalid --bench-env format. Expected KEY=VALUE."
                exit 1
            fi
            BENCHMARK_ENV_VARS+=("$2")
            shift 2
            ;;
        --lmcache-arg)
            if [[ "$2" != *=* ]]; then
                echo "Invalid --lmcache-arg format. Expected KEY=VALUE."
                exit 1
            fi
            LMCACHE_EXTRA_ARGS+=("$2")
            shift 2
            ;;
        --gpu-memory-utilization)
            GPU_MEMORY_UTILIZATION="$2"
            shift 2
            ;;
        --only-benchmark-test)
            ONLY_BENCHMARK_TEST=true
            shift
            ;;
        --gds-400-cache-dir)
            GDS_400_CACHE_DIR="$2"
            shift 2
            ;;
        --gds-800-cache-dir)
            GDS_800_CACHE_DIR="$2"
            shift 2
            ;;
        --force-remove)
            FORCE_REMOVE="$2"
            shift 2
            ;;
        --keep-model)
            KEEP_MODEL_AFTER_SINGLE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

FORCE_REMOVE=$(printf '%s' "$FORCE_REMOVE" | tr '[:upper:]' '[:lower:]')
if [[ "$FORCE_REMOVE" != "true" && "$FORCE_REMOVE" != "false" ]]; then
    echo "Invalid value for --force-remove: $FORCE_REMOVE"
    exit 1
fi

if ! command -v "$CONTAINER_RUNTIME" >/dev/null 2>&1; then
    echo "Container runtime '$CONTAINER_RUNTIME' not found in PATH."
    exit 1
fi

echo "Using container runtime: $CONTAINER_RUNTIME"

init_work_dir() {
    mkdir -p "$WORK_DIR/benchmark_results"
    mkdir -p "$WORK_DIR/src"
    echo "Please move benchmark scripts to $WORK_DIR/src"
}

container_exists() {
    $CONTAINER_RUNTIME ps -a --format '{{.Names}}' | grep -wq "$1"
}

remove_container() {
    local cname="$1"
    local max_retry=10
    local count=0
    local sleep_interval=1

    while container_exists "$cname"; do
        if $CONTAINER_RUNTIME rm -f "$cname"; then
            if ! container_exists "$cname"; then
                return
            fi
        else
            echo "$CONTAINER_RUNTIME rm failed for $cname, trying $CONTAINER_RUNTIME kill..."
            $CONTAINER_RUNTIME kill "$cname" >/dev/null 2>&1 || true
        fi

        count=$((count+1))
        if [ $count -ge $max_retry ]; then
            echo "Failed to remove container $cname after $max_retry attempts."
            break
        fi

        sleep "$sleep_interval"
        if [ $sleep_interval -lt 4 ]; then
            sleep_interval=$((sleep_interval * 2))
        fi
    done
}

cleanup_on_exit() {
    local exit_code="${1:-0}"
    stop_rdma_monitor
    if [[ "$FORCE_REMOVE" != "true" ]]; then
        return
    fi

    if [[ "$exit_code" -ne 0 ]]; then
        local current_step="${step:-unknown}"
        echo "[Step $current_step] Capturing final logs due to non-zero exit (status=$exit_code). Output target: $STOP_OUTDIR."
        collect_results "$STOP_OUTDIR"
    fi

    echo "Force remove enabled. Cleaning up containers..."
    remove_container "$BENCHMARK_CONTAINER_NAME"
    if [[ "$ONLY_BENCHMARK_TEST" != true ]]; then
        if [[ "$KEEP_MODEL_ACTIVE" == true ]]; then
            echo "Keep-model mode active, skipping automatic removal of $CONTAINER_NAME."
        else
            remove_container "$CONTAINER_NAME"
        fi
    fi
}

handle_signal() {
    echo "Received termination signal. Exiting..."
    exit 130
}

format_script_args() {
    if [[ ${#ORIGINAL_ARGS[@]} -eq 0 ]]; then
        printf ""
        return
    fi
    local parts=()
    local arg
    for arg in "${ORIGINAL_ARGS[@]}"; do
        parts+=("$(printf '%q' "$arg")")
    done
    printf '%s' "${parts[*]}"
}

save_runtime_config() {
    local outdir="$1"
    local idx="$2"
    local config_path="$outdir/runtime.config"
    local benchmark_env_vars=""
    local script_args
    script_args="$(format_script_args)"

    if [[ ${#BENCHMARK_ENV_VARS[@]} -gt 0 ]]; then
        benchmark_env_vars="${BENCHMARK_ENV_VARS[0]}"
        for env_var in "${BENCHMARK_ENV_VARS[@]:1}"; do
            benchmark_env_vars+=",${env_var}"
        done
    fi

    {
        printf "# -------------- benchmark defaults (from tools/run.sh)\n"
        printf "run_sh_default_output_len=%s\n" "1"
        printf "run_sh_default_prompts_num=%s\n" "50"
        printf "run_sh_default_seed=%s\n" "66"
        printf "run_sh_default_max_concurrency=%s\n" "16"
        printf "run_sh_default_input_len_list=%s\n" "100,1000,10000,50000,100000"
        printf "run_sh_default_random_repeat=%s\n" "2"
        printf "run_sh_default_benchmark_retry_count=%s\n" "3"
        printf "run_sh_default_benchmark_retry_delay=%s\n" "5"

        printf "\n# ------------- script invocation\n"
        printf "auto_benchmark_args=%s\n" "$script_args"

        printf "\n# -------------- runtime configuration\n"
        printf "timestamp=%s\n" "$(date +"%Y-%m-%dT%H:%M:%S%z")"
        printf "dry_run=%s\n" "$DRY_RUN"
        printf "only_benchmark_test=%s\n" "$ONLY_BENCHMARK_TEST"
        printf "force_remove=%s\n" "$FORCE_REMOVE"
        printf "container_runtime=%s\n" "$CONTAINER_RUNTIME"
        printf "vllm_image=%s\n" "$IMAGE"
        printf "benchmark_image=%s\n" "$BENCHMARK_IMAGE"
        printf "container_name=%s\n" "$CONTAINER_NAME"
        printf "benchmark_container_name=%s\n" "$BENCHMARK_CONTAINER_NAME"
        printf "host_ip=%s\n" "$HOST_IP"
        printf "work_dir=%s\n" "$WORK_DIR"
        printf "disk_models=%s\n" "$DISK_MODELS"
        printf "model_path=%s\n" "$MODEL_PATH"
        printf "tp_size=%s\n" "$TP_SIZE"
        printf "cpu_cache=%s\n" "$CPU_CACHE"
        printf "lmcache_chunk_size=%s\n" "$LMCACHE_CHUNK_SIZE"
        printf "gpu_memory_utilization=%s\n" "$GPU_MEMORY_UTILIZATION"
        printf "tests_case_raw=%s\n" "$TESTS_CASE_RAW"
        printf "test_case=%s\n" "${TEST_CASE_KEYS[$idx]}"
        printf "metadata=%s\n" "${METADATAS[$idx]}"
        printf "experiment_purpose=%s\n" "$EXPERIMENT_PURPOSE"

        
        printf "\n\n# ------------- benchmark environment variables\n"
        printf "benchmark_env_vars=%s\n" "$benchmark_env_vars"
        printf "output_dir=%s\n" "$outdir"

        printf "\n\n# ------------- generated commands\n"
        if [[ "$ONLY_BENCHMARK_TEST" != true ]]; then
            printf "vllm_command=%s\n" "${CMDS[$idx]}"
        fi
        printf "run_command=%s %s\n" "/daocloud/tools/run.sh" "${METADATAS[$idx]}"
        
    } > "$config_path"
}

trap 'cleanup_on_exit $?' EXIT
trap handle_signal INT TERM

start_rdma_monitor() {
    local outdir="$1"
    if [[ -z "$outdir" ]]; then
        return
    fi
    local csv_path="$outdir/rdma.csv"
    local log_path="$outdir/rdma_monitor.log"
    echo "Starting RDMA monitor. Output: $csv_path"
    python3 "$SCRIPT_DIR/rdma_monitor.py" \
        --interval "$RDMA_MONITOR_INTERVAL" \
        --log-csv "$csv_path" \
        --no-alt-screen \
        --no-ansi \
        --quiet-init \
        >"$log_path" 2>&1 &
    RDMA_MONITOR_PID=$!
}

stop_rdma_monitor() {
    if [[ -z "$RDMA_MONITOR_PID" ]]; then
        return
    fi
    if kill -0 "$RDMA_MONITOR_PID" >/dev/null 2>&1; then
        kill "$RDMA_MONITOR_PID" >/dev/null 2>&1 || true
        wait "$RDMA_MONITOR_PID" >/dev/null 2>&1 || true
    fi
    RDMA_MONITOR_PID=""
}

clean_cache() {
    echo "Cleaning up old containers..."
    if [[ "$ONLY_BENCHMARK_TEST" == true ]]; then
        remove_container "$BENCHMARK_CONTAINER_NAME"
        return 0
    fi
    remove_container "$BENCHMARK_CONTAINER_NAME"
    remove_container "$CONTAINER_NAME"

    echo "Cleaning up old results..."

    local clean_400_file=false
    local clean_400_gds=false
    local clean_800_file=false
    local clean_800_gds=false

    for idx in "${SELECTED_INDICES[@]}"; do
        case "${TEST_CASE_KEYS[$idx]}" in
            gds-400g)
                clean_400_gds=true
                ;;
            gds-800g)
                clean_800_gds=true
                ;;
            disk-400g)
                clean_400_file=true
                ;;
            disk-800g)
                clean_800_file=true
                ;;
        esac
    done

    if [[ "$clean_400_file" == true ]]; then
        rm -rf "$GDS_400_CACHE_DIR/cache/deepseek-r1-file/"
        mkdir -p "$GDS_400_CACHE_DIR/cache/deepseek-r1-file/"
    fi
    if [[ "$clean_400_gds" == true ]]; then
        rm -rf "$GDS_400_CACHE_DIR/cache/deepseek-r1-gds/"
        mkdir -p "$GDS_400_CACHE_DIR/cache/deepseek-r1-gds/"
    fi
    if [[ "$clean_800_file" == true ]]; then
        rm -rf "$GDS_800_CACHE_DIR/cache/deepseek-r1-file/"
        mkdir -p "$GDS_800_CACHE_DIR/cache/deepseek-r1-file/"
    fi
    if [[ "$clean_800_gds" == true ]]; then
        rm -rf "$GDS_800_CACHE_DIR/cache/deepseek-r1-gds/"
        mkdir -p "$GDS_800_CACHE_DIR/cache/deepseek-r1-gds/"
    fi
}
# 需要提前 init cache dir

# 挂载参数
MOUNTS=(
    -v "/run/udev:/run/udev"
    -v "$DISK_MODELS:/models"
    -v "$GDS_400_CACHE_DIR:/mnt/400gb"
    -v "$GDS_800_CACHE_DIR:/mnt/800gb"
    -v "$WORK_DIR:/daocloud"
    -v "$WORK_DIR/benchmark_results:/benchmark_results"
)

VLLM_COMMON_ARGS="/opt/venv/bin/vllm serve $MODEL_PATH --served-model-name deepseek-ai/deepseek-r1-0528 --tensor-parallel-size $TP_SIZE --no-enable-prefix-caching --disable-log-requests"
if [[ -n "$GPU_MEMORY_UTILIZATION" ]]; then
    VLLM_COMMON_ARGS+=" --gpu-memory-utilization $GPU_MEMORY_UTILIZATION"
fi
LMCACHE_COMMON_ARGS="PYTHONHASHSEED=0 LMCACHE_USE_EXPERIMENTAL=True LMCACHE_CHUNK_SIZE=$LMCACHE_CHUNK_SIZE LMCACHE_MAX_LOCAL_CPU_SIZE=$CPU_CACHE"
if [[ ${#LMCACHE_EXTRA_ARGS[@]} -gt 0 ]]; then
    for extra_arg in "${LMCACHE_EXTRA_ARGS[@]}"; do
        LMCACHE_COMMON_ARGS+=" $extra_arg"
    done
fi

# 启动命令数组
CMD5="$LMCACHE_COMMON_ARGS LMCACHE_CUFILE_BUFFER_SIZE=\"8192\" LMCACHE_LOCAL_CPU=False LMCACHE_GDS_PATH=\"/mnt/400gb/cache/deepseek-r1-gds/\" LMCACHE_EXTRA_CONFIG='{\"save_only_first_rank\":false, \"use_direct_io\":true}' $VLLM_COMMON_ARGS --kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}'"
CMD6="$LMCACHE_COMMON_ARGS LMCACHE_CUFILE_BUFFER_SIZE=\"8192\" LMCACHE_LOCAL_CPU=False LMCACHE_GDS_PATH=\"/mnt/800gb/cache/deepseek-r1-gds/\" LMCACHE_EXTRA_CONFIG='{\"save_only_first_rank\":false, \"use_direct_io\":true}' $VLLM_COMMON_ARGS --kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}'"

CMD1="$LMCACHE_COMMON_ARGS LMCACHE_LOCAL_DISK=\"file:///mnt/400gb/cache/deepseek-r1-file/\" LMCACHE_MAX_LOCAL_DISK_SIZE=5000.0 $VLLM_COMMON_ARGS --kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}'"
CMD2="$LMCACHE_COMMON_ARGS LMCACHE_LOCAL_DISK=\"file:///mnt/800gb/cache/deepseek-r1-file/\" LMCACHE_MAX_LOCAL_DISK_SIZE=5000.0 $VLLM_COMMON_ARGS --kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}'"
CMD3="$LMCACHE_COMMON_ARGS $VLLM_COMMON_ARGS --kv-transfer-config '{\"kv_connector\":\"LMCacheConnectorV1\", \"kv_role\":\"kv_both\"}'"
CMD4="$VLLM_COMMON_ARGS"

CMDS=("$CMD5" "$CMD6" "$CMD1" "$CMD2" "$CMD3" "$CMD4")
TEST_CASE_KEYS=("gds-400g" "gds-800g" "disk-400g" "disk-800g" "cpu" "no-kvcache")
METADATAS=(
    "kvcache=gds-400g chunksize=$LMCACHE_CHUNK_SIZE"
    "kvcache=gds-800g chunksize=$LMCACHE_CHUNK_SIZE"
    "kvcache=disk-400g chunksize=$LMCACHE_CHUNK_SIZE"
    "kvcache=disk-800g chunksize=$LMCACHE_CHUNK_SIZE"
    "kvcache=cpu chunksize=$LMCACHE_CHUNK_SIZE"
    "kvcache=none"
)
DATESTR=$(date +"%Y%m%d-%H%M%S")
OUTPUT_NAMES=(
    "ds-${DATESTR}-gds-400g"
    "ds-${DATESTR}-gds-800g"
    "ds-${DATESTR}-disk-400g"
    "ds-${DATESTR}-disk-800g"
    "ds-${DATESTR}-cpu"
    "ds-${DATESTR}-no-kvcache"
)

if [[ -n "$TESTS_CASE_RAW" ]]; then
    OLD_IFS="$IFS"
    IFS=','
    read -ra REQUESTED_CASES <<< "$TESTS_CASE_RAW"
    IFS="$OLD_IFS"
    SELECTED_INDICES=()
    for case in "${REQUESTED_CASES[@]}"; do
        trimmed_case=$(echo "$case" | xargs)
        found=false
        for idx in "${!TEST_CASE_KEYS[@]}"; do
            if [[ "${TEST_CASE_KEYS[$idx]}" == "$trimmed_case" ]]; then
                SELECTED_INDICES+=("$idx")
                found=true
                break
            fi
        done
        if [[ "$found" == false ]]; then
            echo "Unknown test case: $trimmed_case"
            echo "Supported cases: ${TEST_CASE_KEYS[*]}"
            exit 1
        fi
    done
else
    SELECTED_INDICES=("${!TEST_CASE_KEYS[@]}")
fi

if [[ "$KEEP_MODEL_AFTER_SINGLE" == true && ${#SELECTED_INDICES[@]} -eq 1 && "$ONLY_BENCHMARK_TEST" != true ]]; then
    KEEP_MODEL_ACTIVE=true
    echo "Keep-model mode enabled: single test case detected, vLLM container will stay running after completion."
fi

rm_flag="--rm"
# nerdctl not supported --rm -d together
if [[ "$CONTAINER_RUNTIME" == "nerdctl" ]]; then
    rm_flag=""
fi

run_benchmark() {
    local metadata="$1"
    local outdir="$2"
    local mount_outdir="$3"
    echo "Running benchmark with metadata: $metadata"
    if [[ ${#BENCHMARK_ENV_VARS[@]} -gt 0 ]]; then
        echo "Applying benchmark env overrides: ${BENCHMARK_ENV_VARS[*]}"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    local env_args=()
    for env_var in "${BENCHMARK_ENV_VARS[@]}"; do
        env_args+=(-e "$env_var")
    done

    start_rdma_monitor "$outdir"
    set +e
    $CONTAINER_RUNTIME run \
        --entrypoint /bin/bash \
        --network host \
        --gpus all \
        $rm_flag \
        "${env_args[@]}" \
        -e OUTPUT_DIR=$mount_outdir \
        --name $BENCHMARK_CONTAINER_NAME \
        "${MOUNTS[@]}" \
        $IMAGE -c "bash /daocloud/tools/run.sh $metadata"
    local status=$?
    set -e
    stop_rdma_monitor
    return $status
}

vllm_serve() {
    local cmd="$1"
    echo "Starting vllm server with command: $cmd"
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    $CONTAINER_RUNTIME run \
        --entrypoint /bin/bash \
        --network host \
        --shm-size 32g \
        --gpus all \
        $rm_flag \
        -d \
        --name $CONTAINER_NAME \
        -e VLLM_HOST_IP=$HOST_IP \
        "${MOUNTS[@]}" \
        $IMAGE -c "source /opt/venv/bin/activate && $cmd"
    wait_for_vllm
}

wait_for_vllm() {
    echo "Waiting for vllm server to be ready..."
    for i in {1..200}; do
        sleep 5
        # 检查 completions 或 metrics 接口
        if curl --noproxy localhost,127.0.0.1 -s -o /dev/null -w "%{http_code}" \
            -H "Content-Type: application/json" \
            -d '{"model": "deepseek-ai/deepseek-r1-0528", "prompt": "Hello", "max_tokens": 1}' \
            http://localhost:8000/v1/completions | grep -q "200"; then
            echo "vllm /v1/completions is up."
            return 0
        fi
        if curl --noproxy localhost,127.0.0.1 -s -o /dev/null -w "%{http_code}" http://localhost:8000/metrics | grep -q "200"; then
            echo "vllm /metrics is up."
            return 0
        fi
    done
    echo "Timeout waiting for vllm server!"
    return 1
}

# 0. benckmark_results.json
# 1. vllm.log
# 2. gpu_usage.log
# 3. metrics.json
collect_results() {
    local outdir="$1"
    mkdir -p $outdir
    $CONTAINER_RUNTIME cp $CONTAINER_NAME:/tmp/vllm.log $outdir/${DATESTR}_vllm.log
}

if [[ "$DRY_RUN" == false ]]; then
   clean_cache
fi
step=1
for idx in "${SELECTED_INDICES[@]}"; do
    echo "=============================="
    DS_OUTDIR="${OUTPUT_NAMES[$idx]}"
    OUTDIR="$WORK_DIR/benchmark_results/$DS_OUTDIR"
    mkdir -p "$OUTDIR"
    save_runtime_config "$OUTDIR" "$idx"
  
    MOUNT_BENCH_OUTDIR="/benchmark_results/$DS_OUTDIR"
    if [[ "$ONLY_BENCHMARK_TEST" == true ]]; then
        echo "[Step $step] Running benchmark only for test case ${TEST_CASE_KEYS[$idx]}..."
        run_benchmark "${METADATAS[$idx]}" "$OUTDIR" "$MOUNT_BENCH_OUTDIR"

        echo "[Step $step] Benchmark only run finished. Results saved to $OUTDIR."
        collect_results $OUTDIR
        echo "=============================="
        step=$((step+1))
        continue
    fi
    echo "[Step $step] Starting vllm server with test case ${TEST_CASE_KEYS[$idx]}..."
    # 停止并删除旧容器
    #docker rm -f $CONTAINER_NAME || true
    # 启动新容器，直接运行 vllm serve 并保存日志
    vllm_serve "${CMDS[$idx]} > /tmp/vllm.log 2>&1"
    # 压测
    run_benchmark "${METADATAS[$idx]}" "$OUTDIR" "$MOUNT_BENCH_OUTDIR"
    if [[ "$DRY_RUN" == true ]]; then
        echo "Dry run: skipping collection of results for $OUTDIR"
        continue
    fi
    # 收集结果
    echo "[Step $step] Done. Results saved to $OUTDIR."
    collect_results $OUTDIR
    # 停止容器
    if [[ "$KEEP_MODEL_ACTIVE" == true ]]; then
        echo "Keep-model mode active, leaving $CONTAINER_NAME running for further tests."
    else
        remove_container "$CONTAINER_NAME"
        sleep 10
    fi
    echo "=============================="
    step=$((step+1))
done

echo "All benchmarks finished."



