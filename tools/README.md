# 压测脚本

| 脚本名称                              | 作用                                  | 示例                                        |
| --------------------------------- | ----------------------------------- | ----------------------------------------- |
| auto_benchmark.sh                 | 启动vllm-server，运行压测脚本 run.sh         | ./auto_benchmakr.sh                       |
| cache-offloading/run.sh           | 压测脚本，使用不同的参数运行 benchmark_serving.py | ./run.sh key1=val1 key2=val2              |
| rdma_monitor.py                   | rdma 网络流量监控脚本                       | python rdma_monitor.py                    |
| collect_and_plot.py               | 将压测的结果重新整理和命名，并且绘制三次迭代的折线图          | python collect_and_plot.py                |
| compare_offloading.py             | 汇总测试数据并生成CSV                        | python compare_offloading.py              |
| cache-offloading/lmcache/patch.sh | lmcache GDS bugfix patch            | ./patch.sh                                |
| plot_compare.py                   | 选取第三次迭代的数据绘制横向比较的折线图                | ./plot_compare.py mean_ttft_ms a1.json a2.json b1.json |
| plot_pareto.py                    | 从CSV绘制散点图并叠加帕累托前沿（不改动现有plot脚本）     | python3 tools/plot_pareto.py media_compare.csv --x mean_ttft_ms --y total_token_throughput --phase prefill --pareto --out plots/media_pareto_prefill.png |
| compare_offloading.py (throughput)| 绘制不同介质的 Prefill 吞吐对比折线图（按 input_len）      | python3 tools/compare_offloading.py -o media_compare.csv --plot-throughput --plot-throughput-out plots/media_prefill_throughput.png |
