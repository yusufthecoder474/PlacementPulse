# PlacementPulse architecture

## System in one paragraph

A Rails API-only backend owns the data, the parser, the eligibility
rules, and the background jobs. A React single-page app is the only
client. PostgreSQL is the source of truth; Redis holds only the Sidekiq
queue. Email goes out through Action Mailer. There are no other
services, no LLM, no external extraction service, and no analytics
pipeline. That is the whole system, deliberately.

## Components

| Component | Technology (actual versions) | Job |
| --- | --- | --- |
| API | Rails 7.1.6, API-only, Ruby 3.2.3, Puma 8.0.2 | REST endpoints, auth, validation, serialization |
| Database | PostgreSQL 16 | Users, sessions, notices, registrations, reminders |
| Queue | Sidekiq 8.1.7 on Redis 7 | Publication notifications, 24h/2h reminders |
| Mail | Action Mailer | Notice and reminder emails (file delivery in development) |
| Frontend | React 19, TypeScript 5.9, Vite 7, Tailwind 4 | Login, dashboard, profile, coordinator review |
| Tests | RSpec 7.1.1, FactoryBot 6.5.1, Vitest 3.2, Playwright 1.64 | Backend, frontend, end-to-end |

## Request flow

```text
Browser (React, :5173)
  │  fetch, Authorization: Bearer <token>
  ▼
Rails API (:3000) ── routes in config/routes.rb
  │  controllers: Api::Sessions / Me / Profiles / Notices / Registrations
  │  services: NoticeParser, EligibilityChecker, ReminderScheduler
  ▼
PostgreSQL 16 ── users, sessions, notices, registrations, reminders
  │
  └── on publish: PublishNotificationsJob ──► Sidekiq / Redis
        └── ReminderDeliveryJob (24h, 2h) ──► Action Mailer
```

## Why the pieces are where they are

- **Parser and eligibility are service objects, not controller code.**
  `NoticeParser` is pure Ruby (regex, keywords, normalization) and
  `EligibilityChecker` is pure Ruby (one rule per criterion, each with
  a reason). Both are unit-tested without HTTP, and the same
  eligibility service is used by the dashboard listing, the
  eligibility endpoint, and job targeting, so the three cannot disagree.
  In Express terms, this is the same as moving logic out of a route
  handler into a plain module — Rails just makes the convention
  explicit with `app/services/`.
- **Auth is a database session, not JWT.** Login returns a random
  token once; only its SHA256 digest is stored, with a 24-hour expiry.
  Logout deletes the row, which is revocation. There is no signup
  endpoint: coordinator accounts are created directly in the database
  (or by seeds), so coordinator registration is not publicly
  accessible. Passwords are bcrypt hashes in `password_digest` only.
- **The queue is not the guarantee; the database is.** Sidekiq
  delivers at least once and retries. The unique index on
  `(reminders.user_id, notice_id, kind)` guarantees at most one
  reminder row per student, notice, and kind, and a delivery job that
  re-runs after `sent_at` is recorded skips. See the exactly-once
  caveat in the root README: a crash between sending mail and writing
  `sent_at` can still produce a duplicate email on retry. No part of
  this system claims otherwise.
- **Deadlines are Kolkata time.** `config.time_zone` is Asia/Kolkata;
  timestamps are stored in UTC. A deadline with no timezone is read as
  Kolkata time, and a date with no time is treated as 23:59 Kolkata
  time (see `backend/app/services/notice_parser.rb`).

## Data model

Five tables, all with foreign keys:

- `users` — email (unique on `LOWER(email)`), `password_digest`,
  role (`student`/`coordinator`, check constraint), branch, CGPA
  (0–10 check), Class X/XII percentages (0–100 checks), standing
  arrears. The student profile lives on the user row; there is no
  separate profile table.
- `sessions` — user reference, `token_digest` (unique), `expires_at`.
  This is the one table beyond the four domain models, and it exists
  only because revocable tokens require server-side state.
- `notices` — the 13 parsed fields, `source_text` (coordinators only
  in API responses), `uncertainties` (jsonb), `unrestricted_fields`
  (array), `status` (`draft`/`published`, check constraint),
  `publisher` reference. Indexed on `status`, `registration_deadline`,
  and `company`.
- `registrations` — unique on `(user_id, notice_id)`; re-posting
  returns the same row, deleting when nothing exists returns
  `not_registered`. Both are idempotent by design.
- `reminders` — unique on `(user_id, notice_id, kind)` where kind is
  `publication`, `reminder_24h`, or `reminder_2h`; carries
  `scheduled_at`, `sent_at`, `failed_at`, and `error_message`.

## Coordinator workflow

Paste notice → `POST /api/notices/parse` → review extracted fields and
flagged uncertainties → correct values → `POST /api/notices` (always
created as draft; `status` cannot be smuggled in) → `POST
/api/notices/:id/publish`. Publication is blocked (422 with the
uncertainties) while a required field is missing and not confirmed as
unrestricted. A missing requirement is never silently treated as
unrestricted.

## Student workflow

Sign in → dashboard lists published notices sorted by deadline →
eligible-only filter → eligibility status with reasons per notice →
open the registration link (external site) → "I Registered" records a
registration, which also suppresses that student's pending reminders
for the notice at job execution time.

## Known scaling limitation

The eligible-only filter computes eligibility in Ruby and therefore
loads published notices before paginating. That is acceptable at
portfolio scale and is documented as a limitation; at large scale it
would need eligibility persisted in SQL or precomputed per student.
