# KV Cache Offloading Benchmark

| 编号| 测试方式     |  测试场景  |     备注     | 方向  |
| --- | ----------- | ----- | -------------------- | ---------- |
| [0821](./benchmark_result_0821/)  |   prefill only    |  CPU<br>400Gbps Disk w/ or w/o arcc<br>800Gbps Disk w/ or w/o arcc<br>400Gbps GDS w/ arcc       |      测试Disk时同时开启了CPU offloading     | N/A |
| [0822](./benchmark_result_0822/)  |   prefill+decode  |  NO KVCache<br>CPU<br>400Gbps Disk w/ arcc<br>800Gbps Disk w/ arcc<br>400Gbps GDS w/ arcc      |      测试Disk时同时开启了CPU offloading    | N/A |
| [0901-pd](./benchmark_result_0901_pd/)  |   prefill+decode  |  400Gbps Disk w/o arcc<br>800Gbps Disk w/o arcc<br>400Gbps GDS w/o arcc<br>800Gbps GDS w/o arcc      |      测试Disk时同时开启了CPU offloading    | N/A |
| [0901-prefill](./benchmark_result_0901_prefill/)  |   prefill only  |  400Gbps Disk w/o arcc<br>800Gbps Disk w/o arcc<br>400Gbps GDS w/o arcc<br>800Gbps GDS w/o arcc      |      测试Disk时同时开启了CPU offloading    | N/A |
| [0908](./benchmark_result_0908/) |   prefill only  |  800Gbps Disk w/o arcc<br>400Gbps GDS w/o arcc<br>800Gbps GDS w/o arcc      |     关闭CPU offloading，定长input len变长prompt num，迭代100轮     | N/A |
| [0910](./benchmark_result_0910/)  |   prefill only  |  400Gbps Disk w/o arcc<br>800Gbps Disk w/o arcc<br>400Gbps GDS w/o arcc<br>800Gbps GDS w/o arcc   |     关闭CPU offloading，迭代10轮      | 东西向 |
| [0912](./benchmark_result_0912<br>)  |   prefill only  |  800Gbps Disk w/ or w/o arcc<br>800Gbps GDS w/ or w/o arcc      |     关闭CPU offloading，迭代10轮，只测了100k input len   | 南北向 |
| [0914](./benchmark_result_0914/)  |   prefill only  |  800Gbps Disk w/ arcc<br>800Gbps GDS w/ arcc      |     关闭CPU offloading，迭代10轮，只测了100k input len | 东西向 |

> 1. 测试Disk时同时开启了CPU offloading时设置内存为100G;
> 2. 定长input len变长prompt num时是为了追求KV Cache size按照50G/100G/150G/200G/250G变化;
> 3. 前几次测试默认都是南北向，但是由于没有监控无法100%确认；


----
目录都是用日期命名，但是可以通过上述文件夹描述来区分内容
一些命名规则：
比如“400Gbps Disk w/ arcc”，
- “400Gbps”表示400G的网络连接外部存储，
- “Disk” 通过LocalDisk的方式而不是gDS的方式连接该存储（类似这里的LMCACHE_LOCAL_DISK就表示这个LocalDisk模式。 反之，就是的LMCACHE_GDS_PATH所表示的GDS模式）
- "w/ arcc" 是网络交换机的一个功能开关

你自行去tree这个 ， 看看各种文件目录结构
比如ds-0821-disk-400g_mean_ttft_ms.png
这些png是plot绘图的对比线。 ds表示deepseek， mean_ttft表示关注vllm benchmark结果中的mean_TTFT的指标。
比如benchmark_result_0821/ds-0821-cpu.json

## 对比数据抽取与脚本使用

场景一：介质对比（HBM / CPU / Local Disk / GDS）
- 说明：跨所有 `benchmark_result_*` 目录扫描 `ds-*.json`，统一提取为一个 CSV；支持 Prefill TTFT 折线图绘制（需安装 `matplotlib`）。
- 生成 CSV（扫描所有批次）：
  - `python3 tools/compare_offloading.py -o media_compare.csv`
- 绘制 Prefill TTFT 介质对比图（可选）：
  - `python3 tools/compare_offloading.py -o media_compare.csv --plot --plot-out plots/media_prefill_ttft.png`
- 绘制 Prefill 吞吐(throughput) 介质对比图（可选）：
  - `python3 tools/compare_offloading.py -o media_compare.csv --plot-throughput --plot-throughput-out plots/media_prefill_throughput.png`
- 仅扫描指定目录（示例）：
  - `python3 tools/compare_offloading.py -o media_compare.csv --include-dirs benchmark_result_0910 benchmark_result_0912`

场景二：网络对比（GDS 的带宽与拓扑差异）
- 说明：在介质抽取基础上，筛选 GDS 记录并按 `bandwidth` 与 `direction`（东西向/南北向）进行对比。支持输出网络维度 CSV 与 Prefill TTFT 折线图。
- 生成网络维度 CSV（仅 GDS）：
  - `python3 tools/compare_offloading.py --network-out network_compare.csv`
- 绘制 GDS 网络维度的 Prefill TTFT 对比图（可选）：
  - `python3 tools/compare_offloading.py -o network_compare.csv  --plot-network --plot-network-out plots/network_prefill_ttft.png`

说明：
- CSV 字段包含：`folder,file,phase,iteration,input_len,kvcache,modality,bandwidth,arcc,direction,mean_ttft_ms,std_ttft_ms,mean_itl_ms,total_token_throughput`。
- 若未安装 `matplotlib` 或 `numpy`，绘图会自动跳过并提示；仅生成 CSV。

### 散点与帕累托前沿绘制（推荐）

使用独立脚本 `tools/plot_pareto.py` 绘制所有点的散点图，并叠加帕累托前沿，便于同时观察 TTFT 与吞吐的最优折衷。

- 媒体对比（Prefill，横轴从0开始，不使用对数坐标）：
  - 生成图与前沿：
    - `python3 tools/plot_pareto.py media_compare.csv --x mean_ttft_ms --y total_token_throughput --phase prefill --pareto --frontier-csv plots/media_pareto_prefill_frontier.csv --out plots/media_pareto_prefill.png --xmax 10000 --connect-by input_len --connect-lw 1.5 --connect-alpha 0.6`

- 网络对比（仅 GDS，Prefill）：
  - `python3 tools/plot_pareto.py network_compare.csv --x mean_ttft_ms --y total_token_throughput --phase prefill --filter-modality GDS --pareto --out plots/network_pareto_prefill.png --xmax 50000`

说明：
- 该脚本支持按 `phase/modality/bandwidth/direction/arcc` 过滤；坐标轴默认从0开始，可通过 `--xmax/--xmin` 控制横轴范围；不推荐使用对数坐标。

本仓库提供了一个通用脚本用于统一抽取并聚合各批次的介质对比数据：`tools/compare_offloading.py`。

脚本功能概览：
- 扫描仓库根目录下所有 `benchmark_result_*` 目录中的 `ds-*.json`，统一抽取生成一个 CSV（默认 `media_compare.csv` 写入仓库根）。
- 缺字段稳健处理：从文件名或命名约定自动推断 `kvcache`、`bandwidth`、`phase`、`arcc`。
- 介质映射：`none→HBM`、`cpu/cpu-cpu→CPU`、`disk*→Local Disk`、`gds*→GDS`。
- 可选绘制 Prefill 场景下的 TTFT 介质对比图（需要安装 `matplotlib`）。

输出字段（CSV）：
- `folder,file,phase,iteration,input_len,kvcache,modality,bandwidth,arcc,mean_ttft_ms,std_ttft_ms,mean_itl_ms,total_token_throughput`

基础使用建议：
- 生成 CSV（扫描所有批次）：
  - `python3 tools/compare_offloading.py -o media_compare.csv`
- 同时绘制 Prefill TTFT 介质对比图：
  - `python3 tools/compare_offloading.py -o media_compare.csv --plot --plot-out plots/media_prefill_ttft.png`
- 仅扫描指定目录：
  - `python3 tools/compare_offloading.py -o media_compare.csv --include-dirs benchmark_result_0910 benchmark_result_0912`

环境说明：
- 脚本不依赖 pandas/numpy（使用纯 Python 写 CSV）。
- 绘图使用 `matplotlib`（未安装则跳过绘图并提示）。