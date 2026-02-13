#!/usr/bin/env python3
"""
通用 KV-Cache 介质对比数据抽取与聚合脚本

用途
- 扫描仓库根目录下所有 benchmark_result_* 目录中的 ds-*.json，统一提取并聚合为一个 CSV；
- 可选绘制 Prefill 场景下的 TTFT 介质对比图（需要安装 matplotlib）。

字段与映射
- 缺失字段的稳健处理：
  - kvcache: 优先读取 JSON 中的值；缺失时从文件名推断（ds-<date>-<type>.json）。
  - bandwidth: 优先读取 JSON；缺失时从 kvcache 后缀提取（如 disk-400g、gds-800g）；CPU/none → N/A。
  - phase: 根据目录名推断（包含 prefill → prefill；包含 pd → prefill+decode；否则默认 prefill）。
  - arcc: 文件名包含 "arcc" 视为 Y；否则为 N。
- 介质映射：
  - none/空 → HBM；cpu/cpu-cpu → CPU；disk* → Local Disk；gds* → GDS；其他 → Unknown。

输出
- CSV（默认写入仓库根）：media_compare.csv，列包含：
  folder,file,phase,iteration,input_len,kvcache,modality,bandwidth,arcc,
  mean_ttft_ms,std_ttft_ms,mean_itl_ms,total_token_throughput
- 可选 PNG 图：plots/media_prefill_ttft.png（需 matplotlib）。

使用示例
- 生成 CSV（扫描所有批次）：
  python3 tools/compare_offloading.py -o media_compare.csv
- 同时绘制 Prefill TTFT 介质对比图：
  python3 tools/compare_offloading.py -o media_compare.csv --plot --plot-out plots/media_prefill_ttft.png
- 仅扫描指定目录：
  python3 tools/compare_offloading.py -o media_compare.csv --include-dirs benchmark_result_0910 benchmark_result_0912

环境说明
- 脚本不依赖 pandas/numpy（使用纯 Python 写 CSV）；
- 绘图使用 matplotlib（未安装则跳过绘图并提示）。
"""

import os
import re
import json
import argparse
import csv
from statistics import mean
from typing import Dict, List, Optional, Tuple


def load_json_lines(filepath: str) -> List[Dict]:
    rows: List[Dict] = []
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('//'):
                    continue
                try:
                    row = json.loads(line)
                    rows.append(row)
                except Exception:
                    # 跳过损坏或非JSON行
                    continue
    except Exception as e:
        print(f"Warn: failed to read {filepath}: {e}")
    return rows


def infer_kvcache_from_filename(fname: str) -> str:
    # 依据命名约定：ds-<date>-<type>.json，其中type可能是 cpu、no-kvcache、disk-400g、gds-800g 等
    base = os.path.basename(fname)
    m = re.search(r"ds-[^-]+-(.+?)\.json$", base)
    if not m:
        # 旧命名或不符合约定
        base_no_ext = os.path.splitext(base)[0]
        parts = base_no_ext.split('-')
        if len(parts) >= 3:
            return '-'.join(parts[2:])
        return ''
    return m.group(1)


def parse_bandwidth(kvcache: str, bandwidth_field: Optional[str]) -> str:
    # 优先使用JSON中的字段，其次从kvcache后缀提取（如 disk-400g / gds-800g）
    if bandwidth_field:
        return str(bandwidth_field)
    m = re.search(r"-(\d+g)\b", kvcache)
    if m:
        return m.group(1)
    # CPU/none 没有外部带宽
    if kvcache in ('cpu', 'cpu-cpu', 'none'):
        return 'N/A'
    return ''


def map_modality(kvcache: str) -> str:
    k = (kvcache or '').lower()
    if k.startswith('gds'):
        return 'GDS'
    if k.startswith('disk'):
        return 'Local Disk'
    if k in ('cpu', 'cpu-cpu'):
        return 'CPU'
    if k in ('none', ''):
        return 'HBM'
    # 兼容旧数据，如仅写了 'gds' 或 'disk'
    if k == 'gds':
        return 'GDS'
    if k == 'disk':
        return 'Local Disk'
    return 'Unknown'


def infer_phase_from_dir(dirname: str) -> str:
    d = dirname.lower()
    if 'prefill' in d:
        return 'prefill'
    if 'pd' in d:
        return 'prefill+decode'
    # 0821/0910/0912/0914 的README显示多为 prefill only
    return 'prefill'


def infer_arcc_from_filename(fname: str) -> str:
    base = os.path.basename(fname).lower()
    return 'Y' if 'arcc' in base else 'N'


def map_direction_from_folder(folder: str) -> str:
    """依据目录名粗略标注网络拓扑方向。
    - benchmark_result_0910: 东西向
    - benchmark_result_0912: 南北向
    - benchmark_result_0914: 东西向
    其余批次: N/A（未明确或不适用）
    """
    name = folder.lower()
    if 'benchmark_result_0910' in name:
        return '东西向'
    if 'benchmark_result_0912' in name:
        return '南北向'
    if 'benchmark_result_0914' in name:
        return '东西向'
    return 'N/A'


def safe_get_float(row: Dict, key: str) -> Optional[float]:
    val = row.get(key, None)
    try:
        return float(val) if val is not None and val != '' else None
    except Exception:
        return None


def safe_get_int(row: Dict, key: str) -> Optional[int]:
    val = row.get(key, None)
    try:
        return int(val) if val is not None and val != '' else None
    except Exception:
        return None


def extract_rows(dirpath: str, filepath: str) -> List[Dict]:
    rows = []
    data_lines = load_json_lines(filepath)
    # 如果JSON没有提供kvcache，依据文件名推断
    inferred_kvcache = infer_kvcache_from_filename(filepath)
    arcc = infer_arcc_from_filename(filepath)
    phase = infer_phase_from_dir(os.path.basename(dirpath))

    # 作为回退的迭代编号
    fallback_iter = 0
    for row in data_lines:
        # 跳过热身
        if str(row.get('type', '')).lower() == 'warmup':
            continue

        iteration = row.get('iteration', None)
        if iteration is None:
            fallback_iter += 1
            iteration = fallback_iter

        input_len = row.get('input_len', None)
        # 某些批次 input_lens 仅在聚合层可得；尽量转换为int
        try:
            input_len = int(str(input_len)) if input_len is not None and str(input_len).strip() != '' else None
        except Exception:
            input_len = None
        # 回填：从 input_lens 数组推断（取平均或首元素）
        if input_len is None:
            ilist = row.get('input_lens', None)
            if isinstance(ilist, list) and len(ilist) > 0:
                try:
                    input_len = int(round(sum([int(x) for x in ilist]) / len(ilist)))
                except Exception:
                    try:
                        input_len = int(ilist[0])
                    except Exception:
                        input_len = None

        kvcache = row.get('kvcache', None) or inferred_kvcache
        bandwidth = parse_bandwidth(kvcache, row.get('bandwidth', None))
        modality = map_modality(kvcache)

        extracted = {
            'folder': os.path.basename(dirpath),
            'file': os.path.basename(filepath),
            'phase': phase,
            'iteration': iteration,
            'input_len': input_len,
            'kvcache': kvcache,
            'modality': modality,
            'bandwidth': bandwidth,
            'arcc': arcc,
            'direction': map_direction_from_folder(os.path.basename(dirpath)),
            'mean_ttft_ms': safe_get_float(row, 'mean_ttft_ms'),
            'std_ttft_ms': safe_get_float(row, 'std_ttft_ms'),
            'mean_itl_ms': safe_get_float(row, 'mean_itl_ms'),
            'total_token_throughput': safe_get_float(row, 'total_token_throughput'),
        }
        rows.append(extracted)
    return rows


def scan_benchmark_dirs(root: str, targets: Optional[List[str]] = None) -> List[Tuple[str, str]]:
    pairs: List[Tuple[str, str]] = []
    for name in sorted(os.listdir(root)):
        if not name.startswith('benchmark_result_'):
            continue
        dirpath = os.path.join(root, name)
        if not os.path.isdir(dirpath):
            continue
        if targets and name not in targets:
            continue
        for fname in os.listdir(dirpath):
            if not fname.endswith('.json'):
                continue
            # 仅收集 ds-*.json
            if not fname.startswith('ds-'):
                continue
            pairs.append((dirpath, os.path.join(dirpath, fname)))
    return pairs


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description='通用KV-Cache介质对比数据抽取与聚合')
    p.add_argument('-o', '--out', default='compare.csv', help='输出CSV路径（相对于仓库根）')
    p.add_argument('--include-dirs', nargs='*', default=None, help='限定扫描的benchmark目录名称，如 benchmark_result_0910')
    p.add_argument('--plot', action='store_true', help='是否在输出CSV的同时绘制prefill TTFT对比图')
    p.add_argument('--plot-out', default='plots/media_prefill_ttft.png', help='对比图输出路径')
    # 吞吐对比（介质）
    p.add_argument('--plot-throughput', action='store_true', help='是否绘制prefill 吞吐(throughput)的介质对比图')
    p.add_argument('--plot-throughput-out', default='plots/media_prefill_throughput.png', help='吞吐对比图输出路径')
    # 网络对比
    p.add_argument('--network-out', default=None, help='输出网络维度CSV路径（相对于仓库根），仅包含GDS记录')
    p.add_argument('--plot-network', action='store_true', help='绘制GDS网络维度的prefill TTFT对比图')
    p.add_argument('--plot-network-out', default='plots/network_prefill_ttft.png', help='网络对比图输出路径')
    return p


def plot_prefill_ttft(rows: List[Dict], out_path: str) -> None:
    try:
        import matplotlib.pyplot as plt
    except Exception as e:
        print(f"Warn: matplotlib not available, skip plotting: {e}")
        return

    dff = [r for r in rows if r.get('phase') == 'prefill' and r.get('mean_ttft_ms') is not None and r.get('input_len') is not None]
    if len(dff) == 0:
        print('Warn: no prefill rows with TTFT to plot.')
        return

    # 按介质分组绘制 input_len 对 TTFT 折线图
    modalities = ['HBM', 'CPU', 'Local Disk', 'GDS']
    plt.figure(figsize=(10, 6))
    # 聚合： (modality, input_len) -> mean ttft
    grouped: Dict[Tuple[str, int], List[float]] = {}
    for r in dff:
        key = (r['modality'], int(r['input_len']))
        grouped.setdefault(key, []).append(float(r['mean_ttft_ms']))

    # 准备每个介质的曲线数据
    for m in modalities:
        pts = [(il, mean(grouped[(m, il)])) for (mod, il) in grouped.keys() if mod == m]
        if not pts:
            continue
        pts.sort(key=lambda x: x[0])
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        plt.plot(xs, ys, marker='o', label=m)
    plt.xlabel('Input Length (tokens)')
    plt.ylabel('Mean TTFT (ms)')
    plt.title('Prefill TTFT by KV-Cache Modality')
    plt.grid(True, linestyle='--', alpha=0.3)
    plt.legend()
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    plt.tight_layout()
    plt.savefig(out_path)
    plt.close()
    print(f'Plot saved to {out_path}')


def plot_network_prefill_ttft(rows: List[Dict], out_path: str) -> None:
    """绘制GDS网络维度的prefill TTFT对比图。
    折线按 label 分组：label = f"{bandwidth}-{direction}-arcc{arcc}"。
    """
    try:
        import matplotlib.pyplot as plt
    except Exception as e:
        print(f"Warn: matplotlib not available, skip plotting: {e}")
        return

    dff = [r for r in rows
           if r.get('phase') == 'prefill'
           and r.get('modality') == 'GDS'
           and r.get('mean_ttft_ms') is not None
           and r.get('input_len') is not None]
    if len(dff) == 0:
        print('Warn: no GDS prefill rows with TTFT to plot.')
        return

    grouped: Dict[str, Dict[int, List[float]]] = {}
    for r in dff:
        bw = r.get('bandwidth', '') or 'unknown'
        d = (r.get('direction', '') or '').strip()
        # 将中文方向统一为英文，避免图例中文乱码
        if d == '东西向':
            d_norm = 'EW'
        elif d == '南北向':
            d_norm = 'NS'
        elif d:
            d_norm = d
        else:
            d_norm = 'NA'
        label = f"{bw}-{d_norm}-arcc{r.get('arcc','N')}"
        il = int(r['input_len'])
        grouped.setdefault(label, {}).setdefault(il, []).append(float(r['mean_ttft_ms']))

    plt.figure(figsize=(10, 6))
    for label, mp in grouped.items():
        pts = sorted((il, mean(vals)) for il, vals in mp.items())
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        plt.plot(xs, ys, marker='o', label=label)
    plt.xlabel('Input Length (tokens)')
    plt.ylabel('Mean TTFT (ms)')
    plt.title('Prefill TTFT by GDS Network (bandwidth, direction, ARCC)')
    plt.grid(True, linestyle='--', alpha=0.3)
    plt.legend(fontsize=8)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    plt.tight_layout()
    plt.savefig(out_path)
    plt.close()
    print(f'Plot saved to {out_path}')


def plot_prefill_throughput_by_modality(rows: List[Dict], out_path: str) -> None:
    """绘制不同介质(HBM/CPU/Local Disk/GDS)的 Prefill 吞吐(throughput)对比图，X为 input_len，Y为 total_token_throughput。
    对相同 (modality, input_len) 取平均后绘制折线。
    """
    try:
        import matplotlib.pyplot as plt
    except Exception as e:
        print(f"Warn: matplotlib not available, skip plotting: {e}")
        return

    dff = [r for r in rows if r.get('phase') == 'prefill' and r.get('total_token_throughput') is not None and r.get('input_len') is not None]
    if len(dff) == 0:
        print('Warn: no prefill rows with throughput to plot.')
        return

    modalities = ['HBM', 'CPU', 'Local Disk', 'GDS']
    plt.figure(figsize=(10, 6))
    grouped: Dict[Tuple[str, int], List[float]] = {}
    for r in dff:
        key = (r['modality'], int(r['input_len']))
        grouped.setdefault(key, []).append(float(r['total_token_throughput']))

    for m in modalities:
        pts = [(il, mean(grouped[(m, il)])) for (mod, il) in grouped.keys() if mod == m]
        if not pts:
            continue
        pts.sort(key=lambda x: x[0])
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        plt.plot(xs, ys, marker='s', label=m)
    plt.xlabel('Input Length (tokens)')
    plt.ylabel('Total Token Throughput')
    plt.title('Prefill Throughput by KV-Cache Modality')
    plt.grid(True, linestyle='--', alpha=0.3)
    plt.legend()
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    plt.tight_layout()
    plt.savefig(out_path)
    plt.close()
    print(f'Plot saved to {out_path}')


def main():
    parser = build_parser()
    args = parser.parse_args()

    repo_root = os.path.dirname(os.path.dirname(__file__))
    scan_pairs = scan_benchmark_dirs(repo_root, targets=args.include_dirs)
    all_rows: List[Dict] = []
    for dirpath, filepath in scan_pairs:
        all_rows.extend(extract_rows(dirpath, filepath))

    # 若无数据
    if len(all_rows) == 0:
        print('No data extracted.')
        return
    # 输出CSV（纯Python）
    out_csv_path = os.path.join(repo_root, args.out)
    os.makedirs(os.path.dirname(out_csv_path) or '.', exist_ok=True)
    fieldnames = [
        'folder','file','phase','iteration','input_len','kvcache','modality','bandwidth','arcc','direction',
        'mean_ttft_ms','std_ttft_ms','mean_itl_ms','total_token_throughput'
    ]
    with open(out_csv_path, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for r in all_rows:
            writer.writerow(r)
    print(f'Saved CSV to {out_csv_path}')

    # 可选绘图（prefill TTFT）
    if args.plot:
        plot_out = os.path.join(repo_root, args.plot_out)
        plot_prefill_ttft(all_rows, plot_out)

    # 可选绘图（prefill 吞吐）
    if args.plot_throughput:
        plot_throughput_out = os.path.join(repo_root, args.plot_throughput_out)
        plot_prefill_throughput_by_modality(all_rows, plot_throughput_out)

    # 网络维度CSV输出（GDS）
    if args.network_out:
        net_csv_path = os.path.join(repo_root, args.network_out)
        os.makedirs(os.path.dirname(net_csv_path) or '.', exist_ok=True)
        fieldnames = [
            'folder','file','phase','iteration','input_len','kvcache','modality','bandwidth','arcc','direction',
            'mean_ttft_ms','std_ttft_ms','mean_itl_ms','total_token_throughput'
        ]
        gds_rows = [r for r in all_rows if r.get('modality') == 'GDS']
        with open(net_csv_path, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for r in gds_rows:
                writer.writerow(r)
        print(f'Saved GDS network CSV to {net_csv_path}')

    # 网络维度绘图
    if args.plot_network:
        plot_out2 = os.path.join(repo_root, args.plot_network_out)
        plot_network_prefill_ttft(all_rows, plot_out2)


if __name__ == '__main__':
    main()
