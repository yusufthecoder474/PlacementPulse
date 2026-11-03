# PlacementPulse frontend

React + TypeScript + Vite + Tailwind CSS v4 single-page app for
PlacementPulse. It implements exactly four screens: Login, Student
dashboard, Student profile, and Coordinator (paste, parse, review, edit,
save draft, publish).

## Run

```sh
npm install
npm run dev
```

The app is served by Vite on its default port. The API base URL is:

```sh
VITE_API_URL=http://localhost:3000 npm run dev
```

If `VITE_API_URL` is not set, the app defaults to
`http://localhost:3000`. The token returned by `POST /api/sessions` is
stored in `localStorage` under `placementpulse_token` and sent as
`Authorization: Bearer <token>`.

## Test and build

```sh
npm test -- --run
npm run build
```

## Scope notes

- No LLM, chat, SMS, OAuth, payments, or analytics features are included.
- The dashboard sorts by registration deadline ascending, with notices
  lacking a deadline last, and the eligible-only filter is passed to the
  API as `eligible_only=true`.
- Source text is only shown on the coordinator screen, from
  `GET /api/notices/:id`; it is never rendered on the student dashboard.

## Not yet verified

- Backend integration is implemented against the API contract supplied
  for this frontend (see `src/api.ts`). End-to-end behaviour against a
  live Rails backend has **not** been verified here, because no backend
  was running in this task. Do not claim a live end-to-end pass until
  that run has actually happened.
- No deployment claim is made for this frontend.
