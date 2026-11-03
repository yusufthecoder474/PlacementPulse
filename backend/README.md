# PlacementPulse — Backend (Rails API)

Campus placement notice management: coordinators paste a notice, a
deterministic parser extracts its fields, a coordinator reviews and
publishes it, students see explained eligibility decisions, and Sidekiq
delivers publication notifications plus 24-hour and 2-hour registration
deadline reminders.

This README covers the backend only (`backend/`). It describes only what
is implemented here; the frontend lives in `../frontend/` and is owned
separately.

## Stack and actual versions

Verified from `Gemfile.lock` in this repository (not guessed):

- Ruby 3.2.3
- Rails 7.1.6, API-only mode
- PostgreSQL 16 (pg gem 1.7.0)
- Sidekiq 8.1.7 with Redis 7 (redis gem 6.0.0)
- Puma 8.0.2, bcrypt 3.1.22, rack-cors 3.0.0
- RSpec 7.1.1 (`rspec-rails`), FactoryBot 6.5.1
- json pinned to the 2.x line (2.21.2): ActiveSupport 7.1 passes a
  `quirks_mode` option to `JSON.generate` that json 3.x removed, which
  broke migrations that serialize a jsonb default. See `Gemfile`.

No Devise, no JWT, no LLM, no external extraction service.

## Quick start

Services needed: PostgreSQL and Redis.

```bash
# Ubuntu example (services are already running in the build VM):
pg_ctlcluster 16 main start
redis-server --daemonize yes

# PostgreSQL must have a role matching the OS user running Rails, e.g.:
su postgres -c "psql -c \"CREATE ROLE root LOGIN SUPERUSER;\""

cd backend
bundle install
bundle exec rails db:create db:migrate db:seed
```

Demo accounts created by `db:seed` (SYNTHETIC demo data only — invented
users and an invented notice, not real students or a real company):

- Coordinator: `coordinator@example.com` / `password1234`
- Student: `student@example.com` / `password1234`

Run the API and the worker in separate terminals:

```bash
bundle exec rails server -p 3000
bundle exec sidekiq -C config/sidekiq.yml
```

Health check: `GET /up` returns 200 when the app boots.

## Environment variables

Copy `.env.example` to `.env` for local use and fill in real values.
Never commit a real `.env`, password, or master key.

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | Full Postgres URL; overrides `config/database.yml` when set. Production uses this only. |
| `REDIS_URL` | Redis URL for Sidekiq (default `redis://localhost:6379/0`). |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_DOMAIN` | SMTP delivery. Development uses file delivery to `tmp/mails/` when `SMTP_ADDRESS` is unset; test uses `:test` delivery. |
| `MAILER_FROM` | From address for notice emails. |
| `FRONTEND_ORIGIN` | Browser origin allowed by CORS (default `http://localhost:5173`). |
| `RAILS_MASTER_KEY` | Note only — generate with `bin/rails credentials:edit`; keep the real key out of the repo. |

## Timezone

`config.time_zone` is `Asia/Kolkata`. Timestamps are stored in UTC by
Active Record. A notice deadline with no timezone is read as Kolkata
time, and a deadline date with no time is treated as 23:59 Kolkata time
(see `app/services/notice_parser.rb`).

## API summary

All responses use `{ error: { message } }` for errors. Authenticated
requests send `Authorization: Bearer <token>`.

| Method & path | Role | Notes |
| --- | --- | --- |
| `POST /api/sessions` | anyone | `{ user: { email, password } }` → `{ user, token, expires_at }`. 401 with one generic message for unknown email and wrong password alike. |
| `DELETE /api/sessions` | authenticated | Revokes the caller's session. |
| `GET /api/me` | authenticated | Current user. |
| `PATCH /api/profile` | student | Own profile only; role/email cannot be changed through it. |
| `GET /api/notices` | authenticated | Students see published only (a `status` param from a student is ignored). `eligible_only=true`, `page`, `per_page` (capped at 50), `meta` counts. |
| `GET /api/notices/:id` | authenticated | `source_text` only for coordinators; students get 404 for drafts. |
| `POST /api/notices/parse` | coordinator | `{ notice: { source_text } }` → `{ parsed, uncertainties }`. |
| `POST /api/notices` | coordinator | Always created as `draft`; `status` cannot be smuggled in. |
| `PATCH /api/notices/:id` | coordinator | Changing a published notice's deadline reschedules its unsent reminders. |
| `POST /api/notices/:id/publish` | coordinator | 422 + `uncertainties` when a required field is missing and not confirmed as unrestricted. Enqueues `PublishNotificationsJob`. |
| `GET /api/notices/:id/eligibility` | student | Coordinators get 403. |
| `POST /api/notices/:id/registration` | student | Idempotent: re-posting returns the same row, no duplicate. |
| `DELETE /api/notices/:id/registration` | student | Idempotent: returns `not_registered` even when nothing existed. |

## How the pieces fit

- **Auth** (`app/models/session.rb`, `Api::SessionsController`): email /
  password via `has_secure_password` (bcrypt, `password_digest` only).
  Login returns a random token once; only its SHA256 digest is stored,
  with a 24-hour expiry. Logout deletes the session row, which is the
  revocation mechanism. There is no signup endpoint by design:
  coordinator accounts are not publicly creatable.
- **Parser** (`app/services/notice_parser.rb`): pure Ruby, regex +
  keyword + normalisation, no LLM. Branch synonyms (CSE/CS/Computer
  Science and Engineering → CSE, etc.) live in one `BRANCH_SYNONYMS`
  constant; "all branches" expands to the full list. Missing never means
  unrestricted: a missing field becomes `null` plus an uncertainty, and
  publication is blocked until the coordinator fills it or lists it in
  `unrestricted_fields`.
- **Eligibility** (`app/services/eligibility_checker.rb`): pure service
  used by the dashboard, the eligibility endpoint, and job targeting, so
  all three agree. Boundaries are inclusive (CGPA 7.5 meets a 7.5
  minimum). Results are `eligible`, `not_eligible`, or
  `needs_clarification`, each failure/uncertainty carrying a
  human-readable reason (for example, "CGPA 7.2 is below the minimum
  7.5").
- **Jobs** (`app/jobs/`): `PublishNotificationsJob` creates one
  `publication` reminder per eligible student and schedules 24h/2h
  reminders through `ReminderScheduler`. `ReminderDeliveryJob`
  re-checks at execution time: already sent, registered, unpublished,
  or past deadline → skip silently. Failures record `failed_at` /
  `error_message` and re-raise so Sidekiq retries.
- **Database**: foreign keys everywhere; unique indexes on
  `LOWER(users.email)`, `(registrations.user_id, notice_id)`, and
  `(reminders.user_id, notice_id, kind)`; check constraints for role,
  status, arrears rule, reminder kind, and CGPA/percentage ranges (see
  `db/migrate/`). Indexes on notice `status`, `registration_deadline`,
  `company`, and reminder `scheduled_at`/`sent_at`.

## The exactly-once caveat (read this before claiming anything)

The unique `(user, notice, kind)` index guarantees there is at most one
reminder **row** per student, notice, and kind — duplicate publishes and
duplicate job runs cannot create a second row, and a delivery job that
runs twice will not re-send once `sent_at` is recorded. That is a
database-level guarantee about rows.

It is **not** a guarantee of exactly-once **email** delivery. If a worker
crashes after the mailer sends but before `sent_at` is written, a retry
can send the same email twice. No design in this codebase claims
otherwise, and no test asserts otherwise.

## Tests

```bash
bundle exec rails db:test:prepare
bundle exec rspec
```

83 examples, 0 failures (verified 2026-11-03 in this VM). Coverage:

- Request specs: auth success/failure, generic 401, token expiry and
  logout revocation, profile ownership and strong params, notice
  listing/pagination/eligible-only filter, draft hiding, `source_text`
  coordinator-only, parse, create/publish rules, deadline-change
  rescheduling, eligibility endpoint, registration idempotency.
- Model specs: validations plus database-level unique-index and
  check-constraint violations (bypassing validations to prove the
  index/constraint itself fires).
- Parser specs: well-formatted notices, missing CGPA, multiple
  deadlines, ISO/month-first dates, branch synonyms and unknown
  abbreviations, "all branches", percentage assignment per level,
  different percentages per course, arrears variants, malformed URL,
  expired deadline, empty/garbage input.
- Eligibility specs: exact thresholds, each failure reason, missing
  profile, unconfirmed vs unrestricted rules, unpublished notices.
- Job specs: duplicate publish, repeated delivery, registration
  suppression, expired-deadline skip, unpublished skip, failure
  recording + re-raise, deadline-change rescheduling, unique-constraint
  race.

All fixtures are labelled SYNTHETIC in comments. Synthetic test results
are not real-world parser accuracy and must never be presented as such.

## Sidekiq verification performed

Beyond the specs (which use the `:test` job adapter), a real Sidekiq
8.1.7 worker was run against Redis with the seeded published notice:
the publication email was delivered (file delivery, `tmp/mails/`), its
reminder row got `sent_at`, and the 24h/2h rows were scheduled for
19 Jan 2027 23:59 and 20 Jan 2027 21:59 IST against the 20 Jan 2027
23:59 deadline. The worker was then stopped; it is not left running.

## Verified vs not verified

- VERIFIED: migrations run (5/5 up), seeds run, server boots, login /
  token / 401 flow works over HTTP, full RSpec suite green, real
  Sidekiq worker processed a publish end to end (above).
- NOT VERIFIED / NOT DONE HERE: production deployment (no hosting
  account or credentials were available to this backend task), SMTP
  delivery to a real inbox (only file / `:test` delivery was exercised),
  real-notice parser accuracy (no real notices were used), and any
  user study or pilot (no participants, no survey data).

## Known limitations

- Eligibility is computed in Ruby for the eligible-only filter, so that
  filter loads published notices before paginating. Fine at portfolio
  scale; it would need a SQL/persisted-eligibility design at large
  scale.
- `NoticeMailer` sends plain text + simple HTML only, in English.
- Coordinator accounts must be created directly in the database (or
  seeds); there is deliberately no public coordinator signup.
