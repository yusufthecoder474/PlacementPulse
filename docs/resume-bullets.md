# Resume bullets (Google XYZ format)

Accomplished X, measured by Y, by doing Z. Every number below is a
count verified by re-running the suites during the integration task
(see `docs/testing-report.md`). Anything not yet measured is written
as `[MEASURE]`, never as an invented figure.

- Built a full-stack campus placement system (Rails 7.1 API, React 19
  + TypeScript, PostgreSQL 16, Sidekiq 8.1), verified by an 83-example
  RSpec suite and a 6-test Vitest suite passing on re-run with zero
  failures, by implementing deterministic notice parsing, explained
  eligibility decisions, and idempotent deadline reminders.
- Prevented duplicate reminder records under retries and concurrent
  workers, verified by database unique indexes and job specs covering
  duplicate publish, repeated delivery, and a unique-constraint race,
  by guarding every reminder with a unique (user, notice, kind) index
  and re-checking registration, publication, and deadline at delivery
  time.
- Delivered an end-to-end coordinator-to-student workflow, verified
  at the API level (parse → draft → publish → eligible → registered
  against a running backend) with a Playwright spec written for the
  same flow, by building four React screens (login, dashboard,
  profile, coordinator review) on a documented REST API.
- Improved placement outcomes by `[MEASURE]`, by `[MEASURE]` — do not
  use this bullet until M1/M6 measurements exist. No user count,
  accuracy figure, latency improvement, or missed-deadline reduction
  is claimed anywhere in this repository, because none has been
  measured yet.
