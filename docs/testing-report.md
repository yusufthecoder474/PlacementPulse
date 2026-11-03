# Testing report

All counts below are from independent re-runs performed during the
integration task on 2026-11-03 in this VM. They are not copied from an
earlier builder's report: the suites were run again here, and the
counts below are what those runs printed. Anything not run is listed
as not run.

## Backend — RSpec

Command (from `backend/`):

```bash
bundle exec rails db:migrate db:seed
bundle exec rspec
```

Result: **83 examples, 0 failures** (finished in ~2 seconds).

Coverage, per the backend suite: request specs (auth success/failure,
generic 401, token expiry and logout revocation, profile ownership and
strong params, notice listing/pagination/eligible-only filter, draft
hiding, coordinator-only `source_text`, parse, create/publish rules,
deadline-change rescheduling, eligibility endpoint, registration
idempotency); model specs (validations plus database-level unique-index
and check-constraint violations, bypassing validations to prove the
index/constraint itself fires); parser specs (well-formatted notices,
missing CGPA, multiple deadlines, ISO/month-first dates, branch
synonyms and unknown abbreviations, "all branches", percentage
assignment per level, different percentages per course, arrears
variants, malformed URL, expired deadline, empty/garbage input);
eligibility specs (exact thresholds, each failure reason, missing
profile, unconfirmed vs unrestricted rules, unpublished notices); job
specs (duplicate publish, repeated delivery, registration suppression,
expired-deadline skip, unpublished skip, failure recording + re-raise,
deadline-change rescheduling, unique-constraint race).

All fixtures are labelled SYNTHETIC. Synthetic results are not
real-world parser accuracy.

## Frontend — Vitest

Command (from `frontend/`):

```bash
npm test -- --run
```

Result: **6 tests passed, 0 failed, across 2 test files**
(`EligibilityStatus.test.tsx`: 4 tests; `RegistrationButton.test.tsx`:
2 tests).

## Frontend — production build

Command (from `frontend/`):

```bash
npm run build
```

Result: **passed** — `tsc` typecheck followed by Vite build, 36 modules
transformed, output `dist/index.html` plus CSS/JS bundles.

## End-to-end — Playwright

Status: **NOT RUN (blocked)** — see below. The test exists and is
kept in the repository; it is not reported as passing.

- Test: `frontend/e2e/workflow.spec.ts` (1 test, 1 file), configured by
  `frontend/playwright.config.ts` (baseURL `http://localhost:5173`,
  Vite dev server via `webServer` with `reuseExistingServer: true`,
  backend started separately as documented).
- Verification that did run: `npx playwright test --list` printed the
  1 test, and `npx tsc --noEmit` passed, so the spec and config load
  and typecheck.
- Why it did not run: the Chromium browser download failed on every
  attempt in this environment — `npx playwright install chromium`,
  `npx playwright install --with-deps chromium` (which stalled on a
  system-package confirmation that cannot be answered in this task),
  `npx playwright install --only-shell chromium`, and the same with
  `PLAYWRIGHT_DOWNLOAD_HOST` set to the npmmirror mirror all ended in
  "Failed to download Chrome for Testing / Chrome Headless Shell
  156.0.8078.4 … Download failure, code=1". No browser binary exists
  in `~/.cache/ms-playwright`, and no system Chromium/Chrome/Firefox
  is installed. npm registry downloads work in this environment, so
  this is specific to the large browser binaries, not to Playwright
  itself.
- Partial substitute that did run: the exact workflow was exercised
  over HTTP against the running backend (Rails on :3000) with the
  same synthetic notice the spec uses ("Acme Robotics", CSE/ECE, CGPA
  7.5, Class X 75, Class XII 70, no standing arrears, CTC 12 LPA,
  deadline 2027-02-20 23:59, registration URL
  https://example.com/register). Parse returned company "Acme
  Robotics", CGPA 7.5, branches CSE/ECE, and zero uncertainties; the
  notice was created as draft (id 3), published, the seeded student
  got eligibility `eligible` with no reasons, and registration
  returned `registered`. That proves the API workflow the spec drives;
  it does not prove the React UI renders it, and it is not presented
  as a Playwright pass.

## Screenshots

**Not captured.** Screenshots require a working Playwright browser,
which is blocked as above. `docs/screenshots/` is therefore empty and
the root README contains no screenshots. No stock or fabricated image
has been used in their place.

## CI

The workflow in `.github/workflows/ci.yml` was validated by parsing it
with Python's `yaml` module: 3 jobs (`backend`, `frontend`, `e2e`),
with the `e2e` job declaring `needs: [backend, frontend]`. It has
**not** been executed on GitHub (no login/connection available), so no
CI pass is claimed.

## What was not tested here

- Real SMTP delivery to a real inbox (only file and `:test` delivery
  were exercised by earlier builders and by the test suite).
- Real-notice parser accuracy (no real notices were used anywhere).
- Any user study or pilot (no participants).
- Docker Compose (daemon unavailable; see `docs/limitations.md`).
