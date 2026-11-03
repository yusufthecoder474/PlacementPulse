# Limitations

Honest limits of this implementation, as it stands. Each item says
what would be needed to remove it.

## Not verified / not done

- **Production deployment: not done.** No hosting account or
  credentials were available, so no production URL exists and none is
  claimed. Deployment configuration is limited to Docker Compose
  (unrun, see below) and environment-variable documentation.
- **Docker Compose: not run.** The Docker daemon is unavailable in
  the build environment, so `docker-compose.yml` is untested
  configuration. The api/worker services mount `./backend` into a
  Ruby 3.2 image and run `bundle install` at container start; verify
  on a machine with Docker before relying on it.
- **GitHub push and CI run: not done.** No GitHub login or connection
  was available. The repository is local only, and
  `.github/workflows/ci.yml` was validated by YAML parsing only, not
  by a GitHub Actions run.
- **Real SMTP inbox delivery: not executed.** Development uses file
  delivery (`backend/tmp/mails/`) and tests use `:test` delivery. A
  real SMTP provider, verified sender domain, and a delivered test
  email to a real inbox are still needed.
- **Playwright end-to-end test: not run.** The Chromium download
  failed repeatedly in this environment (see
  `docs/testing-report.md`). The spec exists and the same workflow was
  verified over HTTP, but the browser test itself has not passed
  anywhere yet. Run it where a browser can be downloaded.
- **Screenshots: not captured.** Same blocker as the Playwright run.
  The README therefore has no screenshots.

## Design limitations

- **Eligible-only filter loads before paginating.** Eligibility is
  computed in Ruby, so the filter loads published notices before
  pagination. Fine at portfolio scale; a large deployment would need
  eligibility persisted or computed in SQL.
- **Exactly-once email is not guaranteed.** The unique
  `(user, notice, kind)` index guarantees one reminder row, not one
  email. A worker crash after sending but before writing `sent_at`
  can cause a duplicate on retry. See the root README.
- **No public coordinator signup, by design.** Coordinator accounts
  are created directly in the database or by seeds. That is a
  security choice, not an oversight, but it means onboarding a real
  placement cell needs a documented admin step.
- **Plain-text/simple-HTML mail, English only.** No templating
  system, no localisation, no attachment handling.
- **Parser is deterministic and therefore brittle by design.** It
  handles the formats its rules cover and flags the rest as uncertain
  instead of guessing. Unusual notice formats will produce more
  uncertainties, which is the safe failure mode, but it means a
  coordinator must still review. No real-notice accuracy figure exists
  yet (see M2 in `docs/measurement-plan.md`).

## Evidence limitations

- **No peer-reviewed placement-portal evaluation meeting the bar was
  found** during Part 1 research. The reminder evidence used is from
  healthcare appointments and prospective-memory experiments; it
  motivates the design but does not prove a placement effect.
- **All test data is synthetic.** Seeded users, the seeded notice,
  and every test fixture are invented. Nothing in this repository may
  be quoted as real student behaviour, real parser accuracy, or real
  impact.
- **No survey, pilot, or timing study has been run.** M1 and M6
  require consenting participants and authorised real notices, neither
  of which exists yet.

## Scope deliberately excluded

No LLM/AI extraction, chatbots, WhatsApp, SMS, push notifications,
OAuth, payments, analytics dashboards, microservices, or file uploads.
Adding any of these is a new decision, not a missing piece of this
build.
