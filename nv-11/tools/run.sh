#!/bin/bash

DATESTR=$(date +"%Y%m%d-%H%M%S")
OUTPUT_DIR=${OUTPUT_DIR:-/benchmark_results}
BENCHMARK_RESULTS_FILE=${BENCHMARK_RESULTS_FILE:-benchmark_result.json}
OUTPUT_LEN=${OUTPUT_LEN:-1}  # Default output length if not set
PROMPTS_NUM=${PROMPTS_NUM:-50}  # Number of prompts to use in the benchmark
SEED=${SEED:-66}
MAX_CONCURRENCY=${MAX_CONCURRENCY:-16}
# default run random for 100, 1k, 10k, 50k, 100k 3 times each
INPUT_LEN_LIST=${INPUT_LEN_LIST:-"100,1000,10000,50000,100000"}
RANDOM_REPEAT=${RANDOM_REPEAT:-2}
# Retry configuration for benchmark failures
BENCHMARK_RETRY_COUNT=${BENCHMARK_RETRY_COUNT:-3}
BENCHMARK_RETRY_DELAY=${BENCHMARK_RETRY_DELAY:-5}


if [[ "$SEED" == "random" ]]; then
  SEED=$((RANDOM % 100))
fi

source /opt/venv/bin/activate

# 解析命令行参数，合并为 metadata_extra
metadata_extra=""
for arg in "$@"; do
    if [[ "$arg" == *=* ]]; then
        metadata_extra+=" $arg"
    fi
    # 不处理非key=value参数
    shift
    # 只保留key=value参数
    # 其他参数可按需扩展
    # ...
done

run_benchmark() {
    local retry_count=0
    local max_retries=$BENCHMARK_RETRY_COUNT
    local retry_delay=$BENCHMARK_RETRY_DELAY
    
    while [ $retry_count -lt $max_retries ]; do
        echo "Benchmark attempt $((retry_count + 1))/$max_retries..."
        
        if /opt/venv/bin/vllm bench serve \
            --model /models/DeepSeek-R1-0528 \
            --served-model-name deepseek-ai/deepseek-r1-0528 \
            --save-result \
            --save-detailed \
            --append-result \
            --result-filename "$OUTPUT_DIR/$BENCHMARK_RESULTS_FILE" \
            $@; then
            echo "Benchmark succeeded on attempt $((retry_count + 1))"
            return 0
        else
            local exit_code=$?
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                echo "Benchmark failed with exit code $exit_code. Retrying in ${retry_delay}s..."
                sleep $retry_delay
            else
                echo "Benchmark failed after $max_retries attempts with exit code $exit_code"
                return $exit_code
            fi
        fi
    done
}

run_random() {
    run_benchmark --dataset-name random \
        --seed $SEED \
        --num-prompts $PROMPTS_NUM \
        --max-concurrency $MAX_CONCURRENCY \
        $@
}

run_random_len() {
    local input_len=$1
    local iteration=${2:-1}
    run_random --random-input-len $input_len \
        --random-output-len $OUTPUT_LEN \
        --metadata "input_len=$input_len iteration=$iteration$metadata_extra"
}

warmup() {
    echo "Warming up the model..."
    run_benchmark --dataset-name random \
        --seed 2 \
        --num-prompts 5 \
        --max-concurrency 1 \
        --random-input-len 100 \
        --random-output-len 1 \
        --metadata "type=warmup"
}

repeatn() {
    local n=$1
    shift
    for i in $(seq 1 $n); do
        echo "Running command: $@ (iteration $i)"
        "$@" $i
        sleep 5  # sleep for 5 seconds between runs
    done
}

# 启动 GPU 利用率采集
nohup nvidia-smi \
  --query-gpu=timestamp,index,name,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw \
  --format=csv -l 1 \
  > "$OUTPUT_DIR/gpu_usage.log" 2>&1 &

# run random for each input length 3 times
warmup
echo "Starting benchmark runs..."
OLD_IFS="$IFS"
IFS=',' read -r -a INPUT_LENS <<< "$INPUT_LEN_LIST"
IFS="$OLD_IFS"
for raw_len in "${INPUT_LENS[@]}"; do
    len="${raw_len//[[:space:]]/}"
    if [[ -z "$len" ]]; then
        continue
    fi
    repeatn "$RANDOM_REPEAT" run_random_len "$len"
    # 可根据需要调整采样次数
    # repeatn 5 run_random_len $len
    # sleep 10
    # ...
done

# 停止 GPU 利用率采集
pkill -f "nvidia-smi --query-gpu"

