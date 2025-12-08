# NVidia + SuperCloud + DaoCloud 11 月实验

## 项目概述

本项目记录了 2025 年 11 月期间，基于 NVidia H20 GPU、SuperCloud 存储和 DaoCloud 环境进行的 vLLM 推理性能基准测试实验。实验主要聚焦于 KV Cache 卸载（offloading）策略的性能优化，包括单机和双机分布式场景下的不同配置对比。

## 目录结构

```bash
nv-11/
├── benchmark_results/                    # 基准测试结果数据
│   ├── ex-database-039-disablesaveonly/  # lmcache save_only_first_rank=false 配置下的对比实验
│   ├── ex-database-chunk/                # 不同 lmcache chunk + GDS + SuperCloud 存储的 KV cache offload 对比
│   ├── ex-database-static/               # 固定最优 lmcache + GDS 配置下的对比实验
│   └── pd-ex-databse/                    # Prefill-Decode 分离架构的双机实验数据
├── pd-patch/                             # Prefill-Decode 分离架构相关补丁
│   ├── 039post2/
│   │   ├── gds_backends-v1.py            # GDS PD 分离补丁
│   │   └── weka_gds_backend_v4.py        # PD 分离下 Weka 补丁
│   └── patch.md                          # 补丁镜像构建操作指南
└── tools/                                # 实验工具脚本
    ├── auto_benchmark.sh                 # 单机测试脚本：自动化运行 vLLM 推理、bench 测试、GPU 和 RDMA 监控
    ├── disagg_proxy_demo.py              # PD 分离架构 Proxy 脚本
    ├── gpu_monitor.sh                    # GPU 监控脚本
    ├── monitor_vllm.sh                   # 双机环境下独立监控 GPU 和 RDMA
    ├── pd_benchmark.sh                   # 双机 PD 分离测试脚本
    ├── rdma_monitor.py                   # RDMA 监控脚本
    └── run.sh                            # 单机 vLLM bench 依赖脚本
```

## H20 单机 DeepSeek 实验

### 实验分组说明

- **ex-database-039-disablesaveonly**: 在 `lmcache save_only_first_rank=false` 配置下，测试不同参数组合的性能表现
- **ex-database-chunk**: 对比不同 lmcache chunk 大小、GDS 配置和 SuperCloud 存储方案对 KV cache offload 性能的影响
- **ex-database-static**: 在确定的最优 lmcache + GDS 配置基础上，进行不同目的的性能对比实验（如带宽限制、ARCC 开关等）

### 测试结果文件说明

每个实验目录下包含以下文件：

```
benchmark_results/ex-database-static/gds-eastwest-1_6t-ISL1-r2/
├── 20251122-171557_vllm.log    # vLLM 运行日志
├── benchmark_result.json        # 基准测试推理性能数据（JSON 格式）
├── gpu_usage.log               # 测试过程中的 GPU 使用率记录
├── rdma_monitor.log            # RDMA 网络监控日志
├── rdma.csv                    # RDMA 每秒统计数据（CSV 格式）
└── runtime.config              # 基准测试命令参数和 vLLM 运行配置
```

### 命名规范

**ex-database-static** 目录下的实验命名遵循以下规范：

#### ISL（Input Sequence Length）配置
- `ISL1-r2`: 输出 token 数为 1，重复 2 轮测试
- `ISL10-r3`: 输出 token 数为 10，重复 3 轮测试

#### 存储类型前缀
- `gds-`: 使用 GDS（GPU Direct Storage）和 SuperCloud 存储
- `nogds-`: 不使用 GDS
- `cpu-`: CPU 存储方案
- `no-kvcache-`: 不使用 KV cache

#### 网络带宽配置
- `eastwest-[带宽]`: 东西向带宽限制
  - `1_6t` = 1.6Tbps
  - `3_2t` = 3.2Tbps
  - `400g` = 400Gbps
  - `800g` = 800Gbps
- `northsouth-[带宽]`: 南北向带宽限制（同上带宽规格）

#### 其他配置标识
- `-noarcc`: 关闭 ARCC（Accelerated Remote Cache Coherence）
- `-weka`: 使用 Weka 存储后端
- `-iothread32`: IO 线程数设置为 32

#### 命名示例

`gds-eastwest-1_6t-ISL1-r2-noarcc` 表示：
- 使用 GDS + SuperCloud 存储
- 东西向带宽限制为 1.6Tbps
- 输出 token 数为 1，重复 2 轮测试
- 关闭 ARCC 功能

## H20 + R6KD 双机 Qwen 实验

### 实验架构说明

本部分实验采用 Prefill-Decode（PD）分离架构，将模型推理的 Prefill 和 Decode 阶段分布到不同的 GPU 节点上执行，以优化资源利用和性能。

### 实验分组说明

**pd-ex-databse** 目录包含双机实验数据：

- **pd-16-***: 16 实例下的 PD 一体实验（单机场景）
- **pd-8p8d-***: 8 Prefill + 8 Decode 配置实验（双机分布式场景）
  - `-r6kdprefill`: R6KD GPU 负责 Prefill 阶段
  - `-r6kddecode`: R6KD GPU 负责 Decode 阶段
  - `-noarcc`: 关闭 ARCC 功能
  - `-wekagds`: 使用 Weka + GDS 存储后端

### 测试结果文件说明

双机实验目录结构示例：

```bash
benchmark_results/pd-ex-databse/pd-8p8d-gds-r6kdprefill/
├── 20251201-022931-bench.log    # vLLM bench server 日志
├── 20251201-030049-bench.log    # vLLM bench server 日志
├── benchmark_result.json         # 基准测试推理性能数据
├── h20/                          # H20 GPU 节点监控数据
│   ├── gpu_usage.csv             # GPU 使用率记录
│   └── rdma_usage.csv            # RDMA 网络使用统计
├── r6kd/                         # R6KD GPU 节点监控数据
│   ├── gpu_usage.csv             # GPU 使用率记录
│   └── rdma_usage.csv            # RDMA 网络使用统计
└── readme.md                     # 实验运行信息和配置说明
```



## 工具使用说明

### 单机实验工具

- **auto_benchmark.sh**: 单机自动化测试脚本
  - 自动启动 vLLM 推理服务
  - 运行 vLLM bench 性能测试
  - 并行监控 GPU 使用率和 RDMA 网络流量
  - 收集并整理测试结果

- **gpu_monitor.sh**: GPU 监控脚本
  - 实时记录 GPU 使用率、显存占用等指标

- **rdma_monitor.py**: RDMA 监控脚本
  - 监控 RDMA 网络流量和性能指标
  - 生成 CSV 格式的统计数据

### 双机实验工具

- **pd_benchmark.sh**: 双机 PD 分离测试脚本
  - 协调双机环境下的 Prefill 和 Decode 节点
  - 执行分布式推理性能测试

- **monitor_vllm.sh**: 双机独立监控脚本
  - 分别在 H20 和 R6KD 节点上监控 GPU 和 RDMA
  - 生成分离的监控数据文件

- **disagg_proxy_demo.py**: PD 分离架构 Proxy 脚本
  - 实现 Prefill 和 Decode 阶段的请求路由和协调

### 补丁说明

PD 分离架构需要特定的补丁支持，详见 `pd-patch/patch.md` 了解如何构建补丁镜像。

## 实验报告

📊 [11 月超云/Nvidia/H20/R6kD 测试报告（公开）](https://daocloud.feishu.cn/docx/EEX9d6gCOo2BeDxWzN7cSwnJnec?from=from_copylink)



