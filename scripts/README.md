# Measurement scripts

Infrastructure only. Every metric in this project is currently **NOT RUN**
unless a report in `docs/testing-report.md` or a future results file says
otherwise, with the real input file attached.

## `compute_latency.py` (M3, and the latency half of M4)

Input: a CSV with `scheduled_at` and `executed_at` columns (ISO 8601).
These are recorded values, not estimates: `scheduled_at` from the
`reminders` row, `executed_at` from the job run that delivered it.

```bash
python3 scripts/compute_latency.py data/latency.csv
```

Output: `n`, min, p50, p95, max, and mean latency in seconds. If the
file has no usable rows, the script exits with an error instead of
printing zeros. Queue execution time is not inbox delivery time: this
script measures the first, never the second.

## `parser_eval.py` (M2)

Input: a CSV with `field`, `expected`, `actual`, `status` columns, one
row per field per notice, labelled by a human against an authorised,
sanitised notice. `status` must be `correct`, `incorrect`, `missing`,
or `uncertain`.

```bash
python3 scripts/parser_eval.py data/parser_labels.csv
```

Output: overall and per-field counts and rates, with the actual `n`
printed. The target sample is at least 30 notices; if fewer are
available, report the actual sample size and do not present a
30-notice benchmark as achieved. Synthetic fixtures must be labelled
synthetic and must never be reported as real-world accuracy.

## Templates

- `templates/m1_timing_template.csv` — one row per participant, notice,
  and method (`manual` vs `app`), with the task order recorded so
  counterbalancing can be checked.
- `templates/m2_parser_template.csv` — the input format for
  `parser_eval.py`.
- `templates/m6_pilot_template.csv` — missed deadlines before and
  during the pilot, with the observation period for each, because the
  two periods are usually different lengths and the comparison is
  descriptive, not causal.

## What is not here

No survey responses, pilot results, latency measurements, or parser
accuracy numbers exist yet. Do not fill the templates with invented
rows and do not quote `[MEASURE]` placeholders as results.
