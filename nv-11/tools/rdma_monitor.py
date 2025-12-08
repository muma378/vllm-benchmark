#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
InfiniBand Network Monitor (No Flicker + Cumulative Totals)
- In-place refresh (ANSI escapes), no 'clear' calls
- Alternate screen buffer, hide/restore cursor
- Precise dt sampling
- Columns: TX Gbps, RX Gbps, TX Total(GB/GiB), RX Total(GB/GiB)
- CLI options: interval, device filter (glob/regex/exact), port, sort, CSV logging, binary totals, once/duration, disable ANSI/alt-screen, hide TOTAL row
"""

import os
import time
import glob
import signal
import sys
import csv
from datetime import datetime
from typing import Dict, Tuple, List, Optional, Iterable
import argparse
import fnmatch
import re

CSI = "\x1b["

def ansi_supported() -> bool:
    return sys.stdout.isatty() and os.name == "posix" and os.environ.get("TERM", "dumb") != "dumb"

class TerminalUI:
    def __init__(self, force_plain: bool = False, use_alt_screen: bool = True, daemon_mode: bool = False):
        base_enabled = ansi_supported() and not force_plain
        self.enabled = base_enabled and not daemon_mode
        self.use_alt_screen = use_alt_screen and base_enabled and not daemon_mode
        self.daemon_mode = daemon_mode

    def enter(self):
        if self.use_alt_screen:
            sys.stdout.write(f"{CSI}?1049h{CSI}?25l")  # Alt screen + hide cursor
            sys.stdout.flush()

    def exit(self):
        if self.use_alt_screen:
            sys.stdout.write(f"{CSI}?25h{CSI}?1049l")  # Show cursor + leave alt screen
            sys.stdout.flush()

    def redraw_begin(self):
        if self.daemon_mode:
            return  # No output in daemon mode
        if self.enabled:
            sys.stdout.write(f"{CSI}H{CSI}J")  # Move to top-left + clear to end
        else:
            sys.stdout.write("\n")
        sys.stdout.flush()

    def flush(self):
        sys.stdout.flush()

class InfiniBandMonitor:
    def __init__(
        self,
        interval: float = 1.0,
        filters: Optional[List[str]] = None,
        match_mode: str = "glob",
        port: int = 1,
        sort_key: str = "name",
        sort_desc: bool = False,
        totals_binary: bool = False,
        log_csv_path: Optional[str] = None,
        use_total_row: bool = True,
        quiet_init: bool = False,
        force_plain: bool = False,
        use_alt_screen: bool = True,
        run_once: bool = False,
        duration_sec: Optional[float] = None,
        daemon_mode: bool = False,
    ):
        self.interval = max(0.01, float(interval))
        self.filters = filters or []
        self.match_mode = match_mode
        self.port = port
        self.sort_key = sort_key
        self.sort_desc = sort_desc
        self.totals_binary = totals_binary
        self.log_csv_path = log_csv_path
        self.use_total_row = use_total_row
        self.quiet_init = quiet_init
        self.run_once = run_once
        self.duration_sec = duration_sec
        self.daemon_mode = daemon_mode

        self.ib_base_path = "/sys/class/infiniband"
        self.devices: List[str] = []
        self.xmit_paths: Dict[str, str] = {}
        self.rcv_paths: Dict[str, str] = {}

        self.previous_xmit: Dict[str, int] = {}
        self.previous_rcv: Dict[str, int] = {}

        # Peak rates
        self.max_tx_gbps: Dict[str, float] = {}
        self.max_rx_gbps: Dict[str, float] = {}

        # Cumulative byte counters since start
        self.total_tx_bytes: Dict[str, int] = {}
        self.total_rx_bytes: Dict[str, int] = {}

        self.prev_ts: Optional[float] = None

        self.ui = TerminalUI(force_plain=force_plain, use_alt_screen=use_alt_screen, daemon_mode=daemon_mode)

        # Pre-compile regexes if needed
        self._regexes: List[re.Pattern] = []
        if self.match_mode == "regex":
            for pat in self.filters:
                try:
                    self._regexes.append(re.compile(pat))
                except re.error as e:
                    print(f"Warning: invalid regex '{pat}': {e}", file=sys.stderr)

    # ---------- Initialization & reads ----------
    def check_infiniband_support(self) -> bool:
        if not os.path.exists(self.ib_base_path):
            print(f"Error: {self.ib_base_path} does not exist\nPlease ensure InfiniBand support is enabled.")
            return False
        any_port = glob.glob(f"{self.ib_base_path}/*/ports/{self.port}/counters/port_xmit_data")
        if not any_port:
            print(f"Error: No InfiniBand devices found (or missing port {self.port} counters).")
            return False
        return True

    def _match_device(self, name: str) -> bool:
        if not self.filters:
            return True
        if self.match_mode == "exact":
            return any(name == pat for pat in self.filters)
        elif self.match_mode == "glob":
            return any(fnmatch.fnmatch(name, pat) for pat in self.filters)
        elif self.match_mode == "regex":
            return any(rx.search(name) for rx in self._regexes)
        return True

    def scan_devices(self):
        """Scan device paths once to reduce per-iteration glob jitter."""
        self.devices.clear()
        self.xmit_paths.clear()
        self.rcv_paths.clear()
        for xmit_path in glob.glob(f"{self.ib_base_path}/*/ports/{self.port}/counters/port_xmit_data"):
            dev = xmit_path.split("/")[-5]
            if not self._match_device(dev):
                continue
            rcv_path = os.path.join(self.ib_base_path, dev, "ports", str(self.port), "counters", "port_rcv_data")
            if os.path.exists(rcv_path):
                self.devices.append(dev)
                self.xmit_paths[dev] = xmit_path
                self.rcv_paths[dev] = rcv_path
        self.devices.sort()

    @staticmethod
    def _read_counter_bytes(path: str) -> int:
        # IB counters are reported in 4-byte units (32-bit words)
        try:
            with open(path, "r") as f:
                val = int(f.read().strip())
                return val * 4
        except Exception:
            return 0

    def get_current_counters(self) -> Tuple[Dict[str, int], Dict[str, int]]:
        xmit, rcv = {}, {}
        for dev in self.devices:
            xmit[dev] = self._read_counter_bytes(self.xmit_paths[dev])
            rcv[dev] = self._read_counter_bytes(self.rcv_paths[dev])
        return xmit, rcv

    def initialize(self):
        self.scan_devices()
        if not self.devices:
            print(f"Error: No usable InfiniBand device found (port {self.port}).")
            sys.exit(1)

        self.previous_xmit, self.previous_rcv = self.get_current_counters()
        for d in self.devices:
            self.max_tx_gbps[d] = 0.0
            self.max_rx_gbps[d] = 0.0
            self.total_tx_bytes[d] = 0
            self.total_rx_bytes[d] = 0
        self.prev_ts = time.monotonic()

        if not self.quiet_init:
            print(f"Found {len(self.devices)} InfiniBand device(s) on port {self.port}:")
            for d in self.devices:
                print(f"  - {d}")
            print()

        # Prepare CSV logging if requested
        if self.log_csv_path:
            self._ensure_csv_header()

    # ---------- Units & formatting ----------
    def _gbps(self, bytes_per_sec: float) -> float:
        # Decimal Gbps (1e9)
        return bytes_per_sec * 8.0 / (1000.0 ** 3)

    def _to_total_units(self, bytes_val: int) -> float:
        if self.totals_binary:
            return bytes_val / (1024.0 ** 3)  # GiB
        return bytes_val / 1_000_000_000.0   # GB

    def _total_unit_label(self) -> str:
        return "GiB" if self.totals_binary else "GB"

    def _fmt_header(self) -> str:
        now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        unit = self._total_unit_label()
        line = []
        line.append(f"Last Update: {now}\n")
        line.append(f"{'Device':<16}{'TX Gbps':>12}{'RX Gbps':>12}{f'TX Total({unit})':>16}{f'RX Total({unit})':>16}\n")
        line.append("=" * 72 + "\n")
        return "".join(line)

    def _fmt_row(self, dev: str, tx_gbps: float, rx_gbps: float, tx_total: float, rx_total: float) -> str:
        return (
            f"{dev:<16}"
            f"{tx_gbps:>12.1f}"
            f"{rx_gbps:>12.1f}"
            f"{tx_total:>16.1f}"
            f"{rx_total:>16.1f}\n"
        )

    # ---------- CSV logging ----------
    def _ensure_csv_header(self):
        exists = os.path.exists(self.log_csv_path)
        try:
            with open(self.log_csv_path, "a", newline="") as f:
                writer = csv.writer(f)
                if not exists:
                    unit = self._total_unit_label()
                    writer.writerow(["timestamp", "device", "tx_gbps", "rx_gbps", f"tx_total_{unit.lower()}", f"rx_total_{unit.lower()}"])
        except Exception as e:
            print(f"Warning: failed to init CSV '{self.log_csv_path}': {e}", file=sys.stderr)
            self.log_csv_path = None

    def _append_csv_rows(self, rows: Iterable[Tuple[str, str, float, float, float, float]]):
        if not self.log_csv_path:
            return
        try:
            with open(self.log_csv_path, "a", newline="") as f:
                writer = csv.writer(f)
                for r in rows:
                    writer.writerow(r)
        except Exception as e:
            print(f"Warning: failed to write CSV '{self.log_csv_path}': {e}", file=sys.stderr)

    # ---------- Rendering ----------
    def display(self, dt: float, curr_xmit: Dict[str, int], curr_rcv: Dict[str, int]):
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        # compute per-device metrics first, then sort
        per_dev = []
        total_tx_bytes_inc = 0
        total_rx_bytes_inc = 0
        total_tx_bytes_sum = 0
        total_rx_bytes_sum = 0

        for dev in self.devices:
            dx = curr_xmit[dev] - self.previous_xmit.get(dev, 0)
            dr = curr_rcv[dev] - self.previous_rcv.get(dev, 0)

            # Handle wrap/reset: treat current value as the increment
            if dx < 0:
                dx = curr_xmit[dev]
            if dr < 0:
                dr = curr_rcv[dev]

            # Cumulative totals since start: add the positive increments
            if dx > 0:
                self.total_tx_bytes[dev] += dx
            if dr > 0:
                self.total_rx_bytes[dev] += dr

            tx_bps = dx / max(dt, 1e-6)
            rx_bps = dr / max(dt, 1e-6)
            tx_gbps = self._gbps(tx_bps)
            rx_gbps = self._gbps(rx_bps)

            # Update peaks
            self.max_tx_gbps[dev] = max(self.max_tx_gbps[dev], tx_gbps)
            self.max_rx_gbps[dev] = max(self.max_rx_gbps[dev], rx_gbps)

            total_tx_bytes_inc += dx
            total_rx_bytes_inc += dr
            total_tx_bytes_sum += self.total_tx_bytes[dev]
            total_rx_bytes_sum += self.total_rx_bytes[dev]

            per_dev.append((
                dev,
                tx_gbps,
                rx_gbps,
                self._to_total_units(self.total_tx_bytes[dev]),
                self._to_total_units(self.total_rx_bytes[dev]),
            ))

        # sorting
        key_funcs = {
            "name": lambda r: r[0],
            "tx": lambda r: r[1],
            "rx": lambda r: r[2],
            "total_tx": lambda r: r[3],
            "total_rx": lambda r: r[4],
        }
        key_func = key_funcs.get(self.sort_key, key_funcs["name"])
        per_dev.sort(key=key_func, reverse=self.sort_desc)

        # build output
        out = [self._fmt_header()]
        for dev, tx_gbps, rx_gbps, tx_total, rx_total in per_dev:
            out.append(self._fmt_row(dev, tx_gbps, rx_gbps, tx_total, rx_total))

        csv_rows = [(timestamp, dev, f"{tx:.3f}", f"{rx:.3f}", f"{tx_t:.3f}", f"{rx_t:.3f}") for dev, tx, rx, tx_t, rx_t in per_dev]

        if self.use_total_row and len(self.devices) > 1:
            out.append("-" * 72 + "\n")
            total_tx_gbps = self._gbps(total_tx_bytes_inc / max(dt, 1e-6))
            total_rx_gbps = self._gbps(total_rx_bytes_inc / max(dt, 1e-6))
            out.append(
                self._fmt_row(
                    "TOTAL",
                    total_tx_gbps,
                    total_rx_gbps,
                    self._to_total_units(total_tx_bytes_sum),
                    self._to_total_units(total_rx_bytes_sum),
                )
            )
            csv_rows.append((timestamp, "TOTAL", f"{total_tx_gbps:.3f}", f"{total_rx_gbps:.3f}",
                             f"{self._to_total_units(total_tx_bytes_sum):.3f}",
                             f"{self._to_total_units(total_rx_bytes_sum):.3f}"))

        # In-place refresh (skip in daemon mode)
        if not self.daemon_mode:
            self.ui.redraw_begin()
            sys.stdout.write("".join(out))
            self.ui.flush()

        # CSV logging
        self._append_csv_rows(csv_rows)

    def print_max_rates(self):
        print("\nPeak Rate Summary:")
        print("=" * 42)
        print(f"{'Device':<16}{'Max TX Gbps':>14}{'Max RX Gbps':>14}")
        for dev in self.devices:
            print(f"{dev:<16}{self.max_tx_gbps[dev]:>14.1f}{self.max_rx_gbps[dev]:>14.1f}")

    # ---------- Run ----------
    def _cleanup_and_exit(self, code: int = 0):
        if not self.daemon_mode:
            self.ui.redraw_begin()
            self.print_max_rates()
            self.ui.exit()
            print("\nThanks for using the InfiniBand Monitor!")
        sys.exit(code)

    def _signal_handler(self, signum, frame):
        if not self.daemon_mode:
            print("\nInterrupted (signal: %s)" % signum)
        self._cleanup_and_exit(0)

    def run(self):
        if not self.check_infiniband_support():
            sys.exit(1)

        signal.signal(signal.SIGINT, self._signal_handler)
        try:
            signal.signal(signal.SIGTERM, self._signal_handler)
        except Exception:
            pass

        if not self.daemon_mode:
            print("InfiniBand Network Monitor")
            print("Press Ctrl+C to stop")
            print("=" * 72)

        self.initialize()
        if not self.devices:
            if not self.daemon_mode:
                print("Error: No usable InfiniBand device found.")
            sys.exit(1)
        
        if not self.daemon_mode:
            time.sleep(2)
            self.ui.enter()

        start = time.monotonic()
        try:
            while True:
                t0 = time.monotonic()
                time.sleep(self.interval)
                t1 = time.monotonic()
                dt = (t1 - (self.prev_ts or t0)) if self.prev_ts else (t1 - t0)
                self.prev_ts = t1

                curr_xmit, curr_rcv = self.get_current_counters()
                self.display(dt, curr_xmit, curr_rcv)

                # Update previous counters
                self.previous_xmit = curr_xmit
                self.previous_rcv = curr_rcv

                if self.run_once:
                    break
                if self.duration_sec is not None and (t1 - start) >= self.duration_sec:
                    break

        except KeyboardInterrupt:
            self._cleanup_and_exit(0)
        except Exception:
            self.ui.exit()
            raise

        # Normal exit path when --once or --duration is used
        self._cleanup_and_exit(0)

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="InfiniBand network monitor with in-place TUI and cumulative totals.")
    p.add_argument("-i", "--interval", type=float, default=1.0, help="Sampling interval in seconds (default: 1.0).")
    p.add_argument("-d", "--filter", action="append", default=[], help="Device filter; repeatable. "
                                                                       "Use with --match-mode (glob/regex/exact).")
    p.add_argument("--match-mode", choices=["glob", "regex", "exact"], default="glob",
                   help="Filter match mode (default: glob).")
    p.add_argument("-p", "--port", type=int, default=1, help="Port number to read counters from (default: 1).")
    p.add_argument("--sort", choices=["name", "tx", "rx", "total_tx", "total_rx"], default="name",
                   help="Sort rows by this column (default: name).")
    p.add_argument("--desc", action="store_true", help="Sort in descending order.")
    p.add_argument("--log-csv", metavar="PATH", help="Append each sample to a CSV file at PATH.")
    p.add_argument("--totals-binary", action="store_true", help="Display totals in GiB (2^30) instead of GB (10^9).")
    p.add_argument("--no-ansi", action="store_true", help="Disable ANSI control codes even in a TTY.")
    p.add_argument("--no-alt-screen", action="store_true", help="Do not use the terminal alternate screen buffer.")
    p.add_argument("--once", action="store_true", help="Take a single sample and exit.")
    p.add_argument("--duration", type=float, help="Run for N seconds and exit.")
    p.add_argument("--no-total-row", action="store_true", help="Hide the aggregated TOTAL row.")
    p.add_argument("--quiet-init", action="store_true", help="Suppress initial device list printing.")
    p.add_argument("--daemon", action="store_true", help="Daemon mode: suppress all terminal output, only log to CSV.")
    return p.parse_args()

def main():
    args = parse_args()
    monitor = InfiniBandMonitor(
        interval=args.interval,
        filters=args.filter,
        match_mode=args.match_mode,
        port=args.port,
        sort_key=args.sort,
        sort_desc=args.desc,
        totals_binary=args.totals_binary,
        log_csv_path=args.log_csv,
        use_total_row=not args.no_total_row,
        quiet_init=args.quiet_init,
        force_plain=args.no_ansi,
        use_alt_screen=not args.no_alt_screen,
        run_once=args.once,
        duration_sec=args.duration,
        daemon_mode=args.daemon,
    )
    monitor.run()

if __name__ == "__main__":
    main()

