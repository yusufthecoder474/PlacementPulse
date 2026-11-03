#!/usr/bin/env python3
"""Summarise field-level parser evaluation from manually labelled data.

Input CSV columns (required): field, expected, actual, status.
`status` must be one of: correct, incorrect, missing, uncertain.
A row is one field of one notice, labelled by a human against an
authorised notice. This script computes nothing from synthetic fixtures
unless you feed it synthetic rows yourself, in which case label the
output as synthetic — it is not real-world accuracy.

Usage:
    python3 scripts/parser_eval.py path/to/parser_labels.csv
"""

import csv
import sys
from collections import Counter, defaultdict

VALID = {"correct", "incorrect", "missing", "uncertain"}


def main(argv) -> int:
    if len(argv) != 2:
        print("usage: parser_eval.py <csv-file>", file=sys.stderr)
        return 2
    per_field: dict[str, Counter] = defaultdict(Counter)
    total = Counter()
    with open(argv[1], newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None or not {
            "field", "expected", "actual", "status"
        } <= set(reader.fieldnames):
            print("error: CSV must have field, expected, actual, status columns",
                  file=sys.stderr)
            return 2
        for row in reader:
            status = (row["status"] or "").strip()
            if status not in VALID:
                print(f"error: invalid status {status!r} for field "
                      f"{row['field']!r}", file=sys.stderr)
                return 2
            per_field[row["field"]][status] += 1
            total[status] += 1
    n = sum(total.values())
    if n == 0:
        print("error: no rows in CSV", file=sys.stderr)
        return 2
    print(f"total_fields_labelled: {n}")
    for status in sorted(VALID):
        print(f"overall_{status}: {total[status]} "
              f"({total[status] / n:.3f})")
    print("--- per field ---")
    for field in sorted(per_field):
        counts = per_field[field]
        field_n = sum(counts.values())
        parts = ", ".join(
            f"{s}={counts[s]} ({counts[s] / field_n:.3f})"
            for s in sorted(VALID)
        )
        print(f"{field}: n={field_n}, {parts}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
