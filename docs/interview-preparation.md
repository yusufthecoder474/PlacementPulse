# Interview preparation

All answers below are grounded in the code actually in this
repository. Where a number appears, it is a verified count from
`docs/testing-report.md`; anything unmeasured is marked `[MEASURE]`.

## 30-second pitch

PlacementPulse turns long campus placement emails into structured,
reviewed opportunities: a coordinator pastes a notice, a deterministic
parser extracts its fields, the coordinator reviews and publishes it,
students see whether they are eligible and why, and Sidekiq sends
deadline reminders 24 hours and 2 hours before registration closes.

## 60-second pitch

Placement coordinators send placement opportunities as long emails,
and students waste time working out whether each one applies to them
— and sometimes miss the deadline. PlacementPulse fixes the boring,
error-prone middle: a coordinator pastes the notice, a rule-based
parser (no LLM) extracts company, branches, CGPA, percentages, arrears
rules, CTC, and deadlines, and flags anything uncertain instead of
guessing. The coordinator corrects and publishes it. Students then see
a deadline-sorted list with an explained eligibility decision for
each drive, mark themselves registered, and get timed reminders. The
hard parts are the ones worth talking about: human review before
publication, inclusive threshold boundaries, and idempotent reminders
so retries cannot create duplicate reminder rows.

## 2-minute technical walkthrough

The backend is a Rails 7.1.6 API-only app on PostgreSQL 16, with
Sidekiq 8.1.7 on Redis 7 for background work and a React 19 +
TypeScript + Vite + Tailwind 4 frontend. Auth is email and password
with bcrypt, and login returns an opaque token whose SHA256 digest is
stored in a `sessions` row with a 24-hour expiry — logout deletes the
row, which is how revocation works, and there is deliberately no
public signup, so coordinator accounts cannot be self-created.
Notices are parsed by a pure Ruby service using regexes, keyword
matching, and branch synonyms; every field carries a value and an
uncertainty status, and publication is blocked while a required field
is missing and unconfirmed, because a missing requirement must never
be read as "no restriction". Eligibility is a separate pure service
used by the dashboard, the eligibility endpoint, and job targeting, so
all three agree; boundaries are inclusive, so CGPA 7.5 meets a 7.5
minimum, and every failure carries a human-readable reason.
Publishing enqueues one notification job per eligible student and
schedules 24-hour and 2-hour reminders; each delivery job re-checks
registration, publication status, and deadline at run time, and a
unique database index on (user, notice, kind) guarantees one reminder
row — which is a database guarantee, not exactly-once email, because a
crash between sending and recording `sent_at` could still duplicate
an email on retry. The test evidence is 83 RSpec examples and 6 Vitest
tests, all passing on re-run, plus a Playwright workflow spec that is
written but blocked in this environment by a failed browser download.

## 15 interview questions and answers

### 1. Why Rails for this project?

Rails gives routing, ActiveRecord, migrations, Action Mailer, and
Active Job in one framework with strong conventions, so a small team
(or one person) can build a complete API, background jobs, and mail
without assembling and versioning five separate libraries. The target
role asks for Rails, and the project's shape — CRUD plus rules plus
jobs — fits Rails' strengths. If the system were mostly real-time
sockets or heavy stream processing, a different stack would be a
better argument.

### 2. How does Rails MVC map to this API-only app?

There is no view layer in the HTML sense. Routes
(`config/routes.rb`) map HTTP verbs and paths to controller actions;
controllers (`app/controllers/api/`) authenticate, authorize, call a
service, and render JSON; models (`app/models/`) own validations and
associations; serializers (`app/serializers/`) shape the JSON. The
parser and eligibility logic live in `app/services/` precisely so
they are not controller code and can be unit-tested in isolation.

### 3. How is the REST API designed?

Conventional resource routes under `/api`: sessions (create/destroy),
`me`, profile (update), notices (index/show/create/update) with
member actions `publish` and `eligibility`, and nested registration
(create/destroy). Errors share one shape, `{ error: { message } }`,
with appropriate statuses: 401 for bad credentials (one generic
message for unknown email and wrong password alike, so the API does
not leak which emails exist), 403 for wrong-role access, 404 for
drafts requested by students, and 422 for publish blocked by
uncertainties. Listing supports `page`/`per_page` (capped at 50) and
`eligible_only`.

### 4. What does the PostgreSQL schema look like, and why?

Five tables: `users`, `sessions`, `notices`, `registrations`,
`reminders`. The student profile lives on `users` (branch, CGPA,
percentages, arrears) because a separate profile table would add a
join for no benefit. `notices` holds the 13 parsed fields plus
`source_text`, a jsonb `uncertainties` list, an
`unrestricted_fields` array, and a `status`. `sessions` exists only
because revocable tokens need server-side state. See
`docs/architecture.md` for the full column and index list.

### 5. Which indexes and constraints matter, and why?

Unique indexes: `LOWER(users.email)` (case-insensitive email
uniqueness that application validation alone cannot guarantee under
concurrency), `(registrations.user_id, notice_id)` (one registration
row per student per notice), `(reminders.user_id, notice_id, kind)`
(one reminder row per kind — the duplicate guard), and
`sessions.token_digest`. Check constraints: role, notice status,
arrears rule, reminder kind, and CGPA/percentage ranges. Query
indexes: `notices.status`, `notices.registration_deadline` (the
dashboard sorts by deadline), `notices.company`, and
`reminders.scheduled_at`/`sent_at`. Model specs deliberately bypass
validations to prove the database constraints themselves fire.

### 6. How does authentication work, and how is it secure?

`has_secure_password` stores only a bcrypt `password_digest`; no
plaintext password ever exists in the database. Login returns a
random token once, and only its SHA256 digest is stored in
`sessions`, with `expires_at` 24 hours out. Every authenticated
request sends `Authorization: Bearer <token>`; the controller looks
up the digest and rejects expired rows. Logout deletes the row. That
is the whole revocation story, and it is why a session table exists:
stateless JWTs cannot be revoked per-token without equivalent
server-side state.

### 7. How is authorization enforced?

By role, in controllers, on the server — never only in the React UI.
Students get 403 from the eligibility endpoint when called as a
coordinator, 404 for draft notices, and their `status` filter
parameter is ignored on listing (students always see published only).
Profile updates are scoped to the current user, so one student cannot
edit another's profile, and `role`/`email` cannot be changed through
the profile endpoint (strong parameters). The coordinator navigation
button is hidden for students, but that is presentation; the API is
the enforcement point.

### 8. How does the parser work, and what happens when it is unsure?

`NoticeParser` is pure Ruby: regexes for labelled values (CGPA,
percentages, CTC, stipend, dates), keyword matching for arrears
("no standing arrears" → `no_standing_arrears`), branch synonyms
(CSE/CS/Computer Science and Engineering → CSE), and normalization
(deadlines read as Asia/Kolkata; a bare date means 23:59 that day).
Each field returns a value plus uncertainties. Ambiguity is recorded,
not resolved silently: multiple deadlines, unknown branch
abbreviations, different percentages per course, and unclear arrears
wording all become uncertainties. Publication is blocked until the
coordinator fills the field or lists it in `unrestricted_fields`.

### 9. Why no LLM for parsing?

Three reasons, in order: determinism (the same notice always parses
the same way, and a failure can be traced to a specific rule);
auditability (a coordinator can see exactly why a field was flagged);
and scope (the brief forbids it, and a student project cannot
responsibly depend on an external model for eligibility decisions).
The cost is brittleness on unusual formats — which is why the
uncertainty mechanism, not a guesser, is the safety net.

### 10. How does the eligibility engine work?

`EligibilityChecker` takes a student profile and a notice and returns
`eligible`, `not_eligible`, or `needs_clarification`, with one reason
per failed or uncertain criterion (for example, "CGPA 7.2 is below
the minimum 7.5"). It checks branch membership, CGPA, Class X, Class
XII, and standing arrears. Thresholds are inclusive: exactly meeting
a minimum passes. Missing profile data or an unconfirmed requirement
yields `needs_clarification`, never a silent pass or fail.
Unpublished notices are not eligible for anyone. The same service
drives the dashboard, the eligibility endpoint, and notification
targeting.

### 11. How does Sidekiq fit in, and what runs when?

`PublishNotificationsJob` runs on publish: it creates one
`publication` reminder per eligible student and schedules 24-hour and
2-hour reminders through `ReminderScheduler`. `ReminderDeliveryJob`
runs at each scheduled time and re-checks, in order: already sent?
registered? notice still published? deadline not yet passed? Any "yes"
to the wrong question means skip silently. Failures record
`failed_at` and `error_message` and re-raise, so Sidekiq retries with
backoff. Sidekiq concurrency is 5 in `config/sidekiq.yml`.

### 12. How do you prevent duplicate reminders and duplicate emails?

Duplicate reminder **rows** are prevented by the unique
`(user, notice, kind)` index plus `find_or_create` semantics in the
scheduler: duplicate publishes, repeated job runs, and concurrent
workers all converge on one row (and the suite includes a
unique-constraint race spec). Duplicate **emails** are reduced but not
eliminated: once `sent_at` is recorded, a re-run skips, but if a
worker crashes after the mailer sends and before `sent_at` is written,
a retry can send twice. Claiming exactly-once email delivery would be
false, and this codebase does not claim it.

### 13. What happens when email delivery fails?

The delivery job records the failure on the reminder row
(`failed_at`, `error_message`) and re-raises the exception, so
Sidekiq's retry mechanism (with backoff) retries it instead of
dropping it silently. The row keeps the failure visible for debugging
rather than deleting the reminder or marking it sent. In development,
mail goes to files (`backend/tmp/mails/`); real inbox delivery has
not been executed and needs a real SMTP provider.

### 14. How is state managed in the React app?

Deliberately simply: `useState` in components, no global store, no
state library. `App.tsx` holds the current user and the active view
(dashboard/profile/coordinator); pages fetch through `src/api.ts`,
which attaches the stored token and throws a single `ApiError` shape
for consistent error display. The dashboard sorts by deadline on the
client so the order holds even if the server order changes, and each
notice card owns its eligibility display (`EligibilityStatus`) and
registration button (`RegistrationButton`), which update the card's
local state after a successful API call. Loading, empty, and error
states are explicit in every page; forms use labelled inputs.

### 15. How do you test, run CI, deploy, and debug this?

Backend: RSpec (83 examples, 0 failures on re-run) covering requests,
models, parser, eligibility, and jobs. Frontend: Vitest (6 tests) for
the two most decision-critical components, plus a Playwright workflow
spec (written; browser download blocked in this environment — see
`docs/testing-report.md`). CI (`.github/workflows/ci.yml`) runs
backend RSpec against Postgres 16 and Redis services, frontend Vitest
plus `tsc` build, and a Playwright job that migrates/seeds, starts the
backend, and runs the workflow spec; it is YAML-validated but not yet
executed on GitHub. Deployment is Docker Compose configuration (unrun
— daemon unavailable) plus environment variables; production needs a
host with Rails, Postgres, Redis, a Sidekiq worker, and SMTP. For
debugging, the order is: reproduce over HTTP with curl, read the Rails
log, check the reminder row's `failed_at`/`error_message` for job
problems, and check `backend/tmp/mails/` for what was actually sent
in development.
