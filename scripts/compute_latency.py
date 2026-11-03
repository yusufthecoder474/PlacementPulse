#!/usr/bin/env python3
"""Compute reminder-scheduling latency statistics from recorded data.

Input CSV columns (required): scheduled_at, executed_at.
Timestamps must be ISO 8601 (a trailing "Z" is accepted). Each row's
latency is executed_at - scheduled_at, in seconds.

This script invents nothing: it only summarises rows you recorded.
If the file is empty or a timestamp cannot be parsed, it fails loudly
instead of producing a plausible-looking number.

Usage:
    python3 scripts/compute_latency.py path/to/latency.csv
"""

import csv
import sys
from datetime import datetime


def parse_timestamp(value: str) -> datetime:
    value = value.strip()
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    return datetime.fromisoformat(value)


def percentile(sorted_values, pct: float) -> float:
    if not sorted_values:
        raise ValueError("no values")
    if len(sorted_values) == 1:
        return sorted_values[0]
    rank = (pct / 100) * (len(sorted_values) - 1)
    low = int(rank)
    high = min(low + 1, len(sorted_values) - 1)
    fraction = rank - low
    return sorted_values[low] * (1 - fraction) + sorted_values[high] * fraction


def main(argv) -> int:
    if len(argv) != 2:
        print("usage: compute_latency.py <csv-file>", file=sys.stderr)
        return 2
    latencies = []
    with open(argv[1], newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None or "scheduled_at" not in reader.fieldnames \
                or "executed_at" not in reader.fieldnames:
            print("error: CSV must have scheduled_at and executed_at columns",
                  file=sys.stderr)
            return 2
        for row in reader:
            if not row["scheduled_at"] or not row["executed_at"]:
                continue
            latencies.append(
                (parse_timestamp(row["executed_at"])
                 - parse_timestamp(row["scheduled_at"])).total_seconds()
            )
    if not latencies:
        print("error: no usable rows in CSV", file=sys.stderr)
        return 2
    latencies.sort()
    print(f"n: {len(latencies)}")
    print(f"min_s: {latencies[0]:.3f}")
    print(f"p50_s: {percentile(latencies, 50):.3f}")
    print(f"p95_s: {percentile(latencies, 95):.3f}")
    print(f"max_s: {latencies[-1]:.3f}")
    print(f"mean_s: {sum(latencies) / len(latencies):.3f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
