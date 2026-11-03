# Measurement plan (M1–M6)

Status of every metric below: **NOT RUN**. The protocols, scripts, and
templates exist so measurements can be collected honestly later. No
number in this document is a result, and `[MEASURE]` in the resume
bullets means exactly that: not yet measured.

## Rules that apply to all six

1. Record the input before computing anything. A metric without its
   input file (or its sample size and method) is not a result.
2. Report the actual sample size. If the target is not reached, say so
   and do not present the target as achieved.
3. Synthetic fixtures validate correctness; they never count as
   real-world accuracy, real user behaviour, or real impact.
4. Healthcare reminder research (Gurol-Urganci et al. 2013; Robotham
   et al. 2016) supports reminders as a plausible intervention. It
   does **not** prove that placement reminders reduce missed
   registration deadlines. Any placement claim needs placement data.
5. Every comparison states its limitations in the same place as the
   number, not in a footnote nobody reads.

## M1 — Time to an eligibility decision

- **Question:** does the app's eligibility display let a student reach
  a decision faster than reading the original notice?
- **Participants:** at least 10 consenting students. Target: 10+.
- **Method:** each student evaluates 5 authorised real notices, once
  by reading the original notice and once from the app display.
  Counterbalance task order (half the students do manual first, half
  app first) so familiarity with a notice cannot favour the app.
  Time in seconds per notice, from the moment the notice/display is
  shown to the moment the student states eligible / not eligible /
  needs clarification.
- **Template:** `scripts/templates/m1_timing_template.csv`
  (`participant_id, notice_id, method, seconds, task_order, notes`).
- **Report:** sample size, median, minimum, maximum, per-method, plus
  the counterbalancing used. Result: `[MEASURE]`.

## M2 — Parser accuracy

- **Question:** how accurate is the deterministic parser on real
  notices, field by field?
- **Data:** manually labelled, authorised, sanitised real notices.
  Target: at least 30 notices. If fewer than 30 are available, report
  the actual count and do not claim a 30-notice benchmark.
- **Method:** for each notice, a human labels each of the 13 fields
  against the notice text. The parser's output is compared field by
  field and classified `correct`, `incorrect`, `missing`, or
  `uncertain`. Raw notices stay out of public repositories; only the
  labelled CSV (with private URLs, tokens, and personal details
  removed) is kept.
- **Script:** `python3 scripts/parser_eval.py data/parser_labels.csv`
  prints overall and per-field counts and rates with the actual `n`.
- **Template:** `scripts/templates/m2_parser_template.csv`.
- **Report:** per-field accuracy with the actual sample size.
  Result: `[MEASURE]`.

## M3 — Reminder scheduling latency

- **Question:** how close is actual reminder execution to the
  scheduled time?
- **Data:** for each delivered reminder, `scheduled_at` (from the
  `reminders` row) and the job's actual execution timestamp. Email
  provider acceptance time is recorded only if the provider supplies
  it; it is never assumed.
- **Script:** `python3 scripts/compute_latency.py data/latency.csv`
  prints `n`, min, p50, p95, max, and mean in seconds.
- **Report:** p50 and p95, with `n` and the environment (worker host,
  Sidekiq concurrency). Queue execution time is not inbox delivery
  time, and this metric never claims the second. Result: `[MEASURE]`.

## M4 — Synchronous vs asynchronous notification processing

- **Question:** what does Sidekiq change, and what does it not change?
- **Method:** controlled benchmark with a defined recipient count.
  Measure publish-endpoint latency for (a) synchronous mail delivery
  in the request and (b) Sidekiq enqueueing, over a stated number of
  repetitions, on stated hardware. Count the notifications created in
  each run.
- **Report:** publish endpoint latency (median and p95) per mode,
  recipient count, repetitions, environment. Never claim asynchronous
  processing shortens total email-delivery time unless delivery time
  itself was measured — enqueueing faster is not delivering faster.
  Result: `[MEASURE]`.

## M5 — Database query performance

- **Question:** do indexes and eager loading measurably help the
  dashboard?
- **Method:** fix a dataset size (number of notices and registrations)
  and an endpoint (dashboard listing). Record dashboard query count
  (from Rails logs / query instrumentation) and endpoint p95 latency
  before and after the optimisation, in the same environment, with the
  same data. State the reproducible benchmark command and the
  environment.
- **Report:** before/after query count and p95, dataset sizes,
  environment, command. The current indexes (`notices.status`,
  `notices.registration_deadline`, `notices.company`,
  `reminders.scheduled_at`/`sent_at`) are design choices, not measured
  wins, until this runs. Result: `[MEASURE]`.

## M6 — Two-week pilot

- **Question:** in a small, consented pilot, do students miss fewer
  deadlines while using the app than they reported missing before?
- **Participants:** consenting students, pilot length two weeks.
- **Method:** before the pilot, each participant self-reports missed
  deadlines over a stated prior period; during the pilot, missed
  deadlines are recorded per participant. The observation periods are
  recorded alongside the counts (see template) because they are
  usually different lengths.
- **Template:** `scripts/templates/m6_pilot_template.csv`.
- **Limitations, stated with any result:** small sample, self-report
  bias, different observation periods, no randomised control. The
  pilot is descriptive; it is not causal proof that the app prevents
  missed deadlines. Result: `[MEASURE]`.

## Scripts

See `scripts/README.md`. Both scripts were smoke-tested on small
synthetic CSVs in `/tmp` during the integration task (latency script:
n=3, p50 5.000 s, p95 11.300 s; parser script: 4 labelled fields,
2 correct / 1 missing / 1 uncertain). Those synthetic outputs are
proof the scripts run, not measurements of this system.
