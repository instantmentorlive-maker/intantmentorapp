# Production Readiness Day‑by‑Day Schedule

This day-wise schedule translates the Production Readiness Assessment and Action Plan into concrete, daily work items. It prioritizes P0 issues first and sequences dependencies logically. 

Assumptions
- Work cadence: 5 days/week, Day 1 is the next working day. Days are numbered, not dated.
- Team: 3–5 engineers (Mobile/Flutter, Backend/Supabase, DevOps/QA). If fewer, expect proportional extension.
- Target: Reach production-ready baseline with CI/CD, monitoring, security, and core features stable.
- Environments: dev, staging, prod; feature flags used for unfinished features.

Quality Gates (weekly, usually Day X5)
- Build + analyze: 0 compile errors, ≤ 20 warnings; all tests green; coverage ≥ 70% (Phase 1), ≥ 80% (Phase 3+).
- Lint & format: dart format + analysis clean (no blocker-level issues).
- Security scans: secrets check, dependency audit, auth/RLS verified.
- Demo: end-of-week demo of completed scope.

Legend
- [M] Milestone, [QA] Testing/Hardening, [INF] Infra/DevOps, [SEC] Security, [PERF] Performance

---

## Phase 1: Critical Fixes (P0) — Days 1–12 (2–3 weeks)

Day 1 — Build unblocks and boot to home
- Owners: Mobile, QA
- Objectives: Fix compile issues, boot app on web (Edge) and Windows.
- Tasks
	- [ ] Fix missing `SecurityDashboard` reference in `lib/security_example.dart` (add a minimal widget or guard the route behind a feature flag).
	- [ ] Address null-safety in `lib/upi_wallet_demo.dart` around lines ~196/198/209 (ensure non-null types and guards for amount, UPI ID, callback).
	- [ ] Run analyzer and snapshot baseline; label issues by category (errors/warnings/deprecations) in tracker.
	- [ ] Create issues for top 50 blockers with assignees and severity.
- Acceptance criteria
	- App compiles and launches on Edge and Windows without crash on home.
	- `flutter analyze` runs; baseline recorded and linked.
- Example commands (PowerShell)
	- flutter clean; flutter pub get
	- flutter analyze
	- flutter run -d edge

Day 2 — Code hygiene and static analysis tightening
- Owners: Mobile
- Objectives: Remove dead code/imports; migrate easy deprecations; tighten lints.
- Tasks
	- [ ] Run auto-fixes: dart fix --apply; prune unused imports, dead files in `lib/**`, `test/**`.
	- [ ] Migrate deprecations batch (1/4): Navigator/Theme APIs, common widget renames.
	- [ ] Update `analysis_options.yaml`: treat missing_required_param, dead_code, unnecessary_imports as errors; format code.
- Acceptance criteria
	- Analyzer errors decrease by ≥ 100 from baseline; no new errors introduced.

- Example commands (PowerShell)
	- dart fix --apply
	- dart format .
	- flutter analyze

- How to verify
	- Confirm analyzer error count drops from baseline; lint rules apply (intentional failures are caught).

Day 3 — Auth consolidation and session hygiene
- Owners: Backend, Mobile
- Objectives: Single auth (Supabase), clear flow and DI.
- Tasks
	- [ ] Document chosen auth in `docs/` (login, refresh, logout, token storage).
	- [ ] Remove/hide mock or secondary auth behind feature flags; wire DI to one gateway.
	- [ ] Implement session persistence and refresh; ensure sign-out clears sensitive state.
- Acceptance criteria
	- Login/logout/refresh paths work locally; no double sources of truth for auth.

- Example commands (PowerShell)
	- flutter test test/unit/data/repositories/mock_auth_repository_test.dart
	- flutter run -d edge

- How to verify
	- Manual: login -> refresh token path -> logout; verify state cleared and no unexpected 401s; single auth provider in container/DI.

Day 4 — Security features scaffolding
- Owners: Backend
- Objectives: Rate limiting + MFA scaffolding + biometrics behind flags.
- Tasks
	- [ ] Implement basic rate limits for auth calls (Supabase edge/middleware) and document values.
	- [ ] Add MFA/OTP scaffolding (TOTP or email OTP) and minimal UI stubs; feature-flag it.
	- [ ] Integrate biometric auth for supported platforms (guarded by platform checks and flags).
- Acceptance criteria
	- Documented rate limits; feature-flag switches exist; builds still green across targets.

- Example commands (PowerShell)
	- flutter analyze
	- flutter run -d windows

- How to verify
	- Flags toggle UI/flows without crashes; rate-limit docs present; builds pass on web/desktop.

Day 5 [QA + M] — Auth tests and stability checkpoint
- Owners: QA, Mobile
- Objectives: Test auth, cut analyzer issues, and reach M1.
- Tasks
	- [ ] Unit tests for login, refresh, logout, token expiry.
	- [ ] Lint/format pass; reduce analyzer issues by ≥ 150 cumulative.
	- [ ] Smoke test on Windows + Android emulator.
- Acceptance criteria (M1)
	- App compiles on Windows and Android; core auth happy path works.

- Example commands (PowerShell)
	- flutter test
	- flutter analyze
	- flutter run -d windows

- How to verify
	- Tests green; login/logout works on at least two targets; analyzer issue delta meets threshold.

Day 6 — Supabase schema and RLS baseline
- Owners: Backend
- Objectives: Ensure migrations and minimal RLS in place.
- Tasks
	- [ ] Verify and apply migrations; fill any schema gaps via new scripts.
	- [ ] Implement RLS policies for user-scoped tables (chat, profiles, messages) and test with two users.
	- [ ] Add server-side validation on critical inputs (edge functions) or client guards as interim.
- Acceptance criteria
	- Migrations idempotent; RLS prevents cross-user reads/writes in tests.

- Example commands (PowerShell)
	- echo "Apply SQL under supabase_migrations/ to dev DB via Supabase Studio or psql" 
	- flutter test test/unit/core/models/user_test.dart

- How to verify
	- Two different users in app cannot access each other's rows; negative tests fail with 401/403 as expected.

Day 7 — Error handling and logging
- Owners: Mobile
- Objectives: Baseline retries, boundaries, and structured logs.
- Tasks
	- [ ] Add retry with jitter/backoff and cancellation for network calls.
	- [ ] Global error boundary for async providers; map exceptions to user-friendly messages.
	- [ ] Structured logging with PII-safe filters.
- Acceptance criteria
	- Offline/timeout scenarios show friendly messages; logs contain no PII.

- Example commands (PowerShell)
	- flutter analyze
	- flutter test

- How to verify
	- Simulate offline; confirm UI toasts/dialogs not leaking technical details; log lines redact tokens/PII.

Day 8 — UPI flow stabilization
- Owners: Mobile
- Objectives: Null-safety fixes plus validation and failures UX.
- Tasks
	- [ ] Validate amount/beneficiary/UPI ID; block invalid submissions.
	- [ ] Add explicit failure/cancel paths, idempotency key for transaction creation.
	- [ ] Draft reconciliation plan and stub worker task.
- Acceptance criteria
	- Payment screen cannot proceed with invalid inputs; failure/cancel handled without crashes.

- Example commands (PowerShell)
	- flutter analyze
	- flutter test
	- flutter run -d edge

- How to verify
	- Enter invalid UPI IDs/amounts; submit is disabled with clear validation; cancel path returns to a stable state.

Day 9 — Stripe scaffold and secret hygiene
- Owners: Mobile, DevOps
- Objectives: Flagged Stripe client scaffold; secrets to env.
- Tasks
	- [ ] Add Stripe tokenization client behind feature flag; use test keys only.
	- [ ] Move keys to `.env`/platform secrets; add `.env.example` and secret scanning.
	- [ ] Basic fraud checks (velocity/min/max/duplicate submissions).
- Acceptance criteria
	- No secrets in repo; Stripe code present but disabled by default.

- Example commands (PowerShell)
	- echo "Ensure .env and .env.example created; rotate local keys" 
	- flutter analyze

- How to verify
	- Secret scanner finds 0 issues; Stripe flows only reachable when a feature flag is enabled.

Day 10 [QA] — Payments test coverage and deprecations 2/4
- Owners: QA, Mobile
- Objectives: Tests for payment flows; reduce analyzer noise.
- Tasks
	- [ ] Unit tests for success/failure/cancel/retry paths.
	- [ ] Fix deprecations batch (2/4) and bring analyzer issues ≤ 350.
	- [ ] Exploratory test of payments + auth; log defects.
- Acceptance criteria
	- All new tests green; analyzer threshold met.

- Example commands (PowerShell)
	- flutter test
	- flutter analyze

- How to verify
	- Tests cover cancel/failure paths; analyzer issue count at or below target.

Day 11 — RLS hardening and analytics scaffolding
- Owners: Backend, Mobile
- Objectives: Lock down policies; add analytics events (no PII).
- Tasks
	- [ ] RLS least-privilege checks and row ownership rules; tests with two users.
	- [ ] Analytics events for auth and payments behind toggle; redact sensitive data.
	- [ ] Standardize error toasts/snackbars.
- Acceptance criteria
	- Unauthorized access attempts fail in tests; analytics toggle works.

- Example commands (PowerShell)
	- flutter analyze
	- flutter test

- How to verify
	- Forced unauthorized queries fail; analytics events emitted only when toggle on; payloads contain no PII.

Day 12 [QA + M] — Static analysis target and M2
- Owners: QA, Mobile
- Objectives: Hit static analysis goal and close P0.
- Tasks
	- [ ] Analyzer errors = 0; warnings ≤ 250; finish deprecations batch (3/4).
	- [ ] Final smoke across platforms; ensure logs in place.
- Acceptance criteria (M2)
	- P0 items closed; auth stable; payments non-crashing; RLS active; logging verified.

- Example commands (PowerShell)
	- flutter analyze
	- flutter test
	- flutter run -d windows
	- flutter run -d edge

- How to verify
	- Analyzer shows 0 errors; key flows smoke-tested on web and Windows; M2 checklist ticked.

---

## Phase 2: Core Functionality — Days 13–36 (4–6 weeks)

Day 13
- Realtime: add robust WS reconnection with jitter backoff; online/offline detection.
- Queue outgoing messages offline and flush on reconnect.

Day 14
- Message persistence: local store (e.g., sqflite/hive) for chat history; sync logic on login/reconnect.
- Define message schema, status (sending, sent, delivered, read).

Day 15 [QA]
- Write tests for reconnection and queue drain; simulate network flaps.
- Add message resend on transient failures.

Day 16
- Typing indicators: implement debounced send/receive; clear on idle.
- Presence: last seen, online flags; subscribe to presence channel.

Day 17
- Persist presence and typing state per conversation; privacy toggle.
- Optimize event fan-out to avoid UI thrash.

Day 18 [QA]
- Chat history pagination and lazy loading.
- Add message reactions and basic attachments placeholder (flagged).

Day 19
- Video calling: complete Agora integration baseline (join/leave, mute/unmute, camera switch).
- Permissions: request/handle camera/mic robustly across platforms.

Day 20
- Bandwidth adaptation: subscribe to network stats, adjust video profile.
- Call quality monitoring: collect QoS metrics; show indicator.

Day 21 [QA]
- Call recording design; implement server-side token flow and start/stop hooks (flagged in UI pre-prod).
- Add call error handling and retry join.

Day 22
- State management: standardize on Riverpod; remove direct setState usages in core flows.
- Break provider dependency cycles; add ProviderObserver logging.

Day 23
- Memory leak hunt: cancel subscriptions/disposers; use AutoDispose providers as default.
- Error boundaries per feature (chat, calls, payments).

Day 24 [QA]
- Integration tests: auth + chat happy path; calls basic join/leave.
- Stabilize flaky tests.

Day 25
- Expand tests: widget tests for core UI (chat list, message composer, call UI).
- Increase unit/integration tests ≥ 120 total.

Day 26
- Offline support improvements: optimistic UI for messages; reconcile on failure.
- Cache strategy for API responses with TTL and invalidation.

Day 27 [QA]
- Performance profiling pass: fix excessive rebuilds; memoize heavy widgets.
- Defer images and large assets; introduce simple image cache.

Day 28
- Routing cleanup: pick a single router (e.g., go_router) and migrate.
- Implement consistent route guards and deep link handling.

Day 29
- Back button behavior harmonization across platforms and nested navigators.
- Add navigation tests for critical flows.

Day 30 [QA + M]
- Analyzer warnings ≤ 200; deprecations batch (4/4) done.
- Milestone M3: Realtime chat stable offline/online; calls usable; state mgmt unified; tests ≥ 150.

Day 31
- Error pages and retry UX patterns standardized; add global toast/dialog service.
- Add Sentry or equivalent error tracking (feature-flagged until Phase 3 enablement).

Day 32
- Data validation at API boundaries (client): schemas and guards; sanitize user inputs.
- Consolidate DTOs and mappers with type-safety.

Day 33
- QA hardening on chat/calls; fix memory and lifecycle bugs.
- Security review: ensure no PII in logs, redact tokens.

Day 34
- Add message search and filters (local index); precompute on idle.
- Accessibility pass 1: basic semantics on chat/call controls.

Day 35–36 [QA]
- Buffer and stabilization; bug triage burn-down.
- Prepare Phase 3 backlog with precise acceptance criteria.

---

## Phase 3: Production Readiness — Days 37–68 (6–8 weeks)

Day 37
- Monitoring: enable Firebase Crashlytics; wire release filters and user consent.
- Analytics: implement non-PII analytics events; dashboards stub.

Day 38
- Performance monitoring: Flutter performance overlays in debug; add simple tracing.
- Define SLIs/SLOs (startup < 2s, message send < 300ms on good network, crash-free ≥ 99.5%).

Day 39 [INF]
- CI/CD: set up GitHub Actions (or Azure DevOps) with build, test, lint, coverage reports.
- Cache dependencies; parallelize jobs.

Day 40
- Code coverage gates: fail < 75%; upload coverage badge; artifact uploads for builds.
- Static analysis in CI: treat analyzer errors as failures.

Day 41 [SEC]
- Secrets management: remove hard-coded keys; use env per environment; commit .env.example.
- Add pre-commit hooks (format, lint, secrets scan).

Day 42
- Config management: dev/staging/prod configs; feature flags service; build variants.
- Parameterize URLs and constants; remove hard-coded values.

Day 43
- Accessibility pass 2: labels, focus order, contrast, larger text support.
- Screen reader checks; fix actionable violations.

Day 44
- Internationalization: setup `intl`; extract hard-coded strings; English baseline.
- Locale switching and fallback.

Day 45 [QA]
- Dark mode support; theme polish; verify contrast in both modes.
- Snapshot tests for critical screens.

Day 46
- Security hardening: input sanitization, URL validation, HTML/Markdown rendering safe defaults.
- Audit logging framework: key events (auth, payments, admin actions).

Day 47 [SEC]
- Data protection: at-rest encryption for sensitive local storage (tokens, cache subsets).
- TLS pinning feasibility review (mobile); apply where practical.

Day 48
- Privacy & legal: add privacy policy and ToS screens; first-run acceptance flow.
- Data deletion requests flow and stubs.

Day 49
- Consent management for analytics and Crashlytics; granular toggles; store preferences.
- Public documents linked from settings.

Day 50 [QA + M]
- Performance optimization pass 2: widget tree hotspots; image optimization; lazy lists.
- Milestone M4: CI/CD live; monitoring on; i18n baseline; accessibility baseline; configs per env.

Day 51
- Supabase migrations review: finalize production schema; write idempotent migrations.
- RLS extensive tests and audits on all user data tables.

Day 52
- Payment reconciliation worker: periodic checker for pending/failed; retry policies; alerts on mismatch.
- Stripe minimal viable payments behind feature flag; non-prod keys only.

Day 53 [QA]
- E2E test scaffolding (e.g., integration_test or Patrol): happy paths for login, chat, payment.
- Load test script for websocket server basic.

Day 54
- Error tracking deep integration: release tagging, source maps/symbols, user feedback dialog.
- Dashboard queries and alerts (thresholds on crash rate, auth failures, payment errors).

Day 55–56 [QA]
- Hardening sprint: bug burn-down, flaky tests, stabilization.
- Coverage ≥ 80%; analyzer warnings ≤ 120.

Day 57
- Caching strategy finalization: cache invalidation rules; stale-while-revalidate for lists.
- Document caching knobs per feature.

Day 58
- Documentation: developer setup, runbooks (incident, rollback), on-call basics.
- Security review checklist completed.

Day 59–60 [M]
- Release candidate build on staging; run smoke + regression.
- Milestone M5: Production readiness sign-off pending Phase 4 optional features.

Day 61–68 [Buffer]
- Reserved for spillover defects, performance regressions, and polish.

---

## Phase 4: Advanced Features — Days 69–98 (8–12 weeks; feature-flagged)

Day 69–70
- Advanced payments: SCA flows, 3DS where applicable; enhanced fraud rules.
- Refunds and partial captures; audit events.

Day 71–72
- AI recommendations: scaffold service boundaries and feature flags; metrics for success.
- Privacy review for any model inputs.

Day 73–74
- Advanced analytics dashboard: funnels, retention, usage heatmaps; export via CSV.

Day 75–76
- Admin panel (MVP): content moderation (reports, message takedown), role-based access.

Day 77–78
- Reporting system for users: flag content/users; backend workflows; notifications.

Day 79–80
- Notification system: push notifications (FCM/APNs); in-app notifications; preference center.

Day 81–84 [QA]
- System tests for advanced features; ensure feature flags off by default in prod.
- Load and soak tests for realtime and notifications.

Day 85–88
- Security pass: pentest findings remediation; rate limits on advanced endpoints.

Day 89–92
- Performance pass: bandwidth adaptation tuning; call recording storage lifecycle; CDN review for assets.

Day 93–96 [M]
- Finalize documentation, admin runbooks, and handover.
- Milestone M6: Advanced features ready under flags; gradual rollout plan.

Day 97–98 [Buffer]
- Contingency and stabilization; prepare GA release.

---

## Deliverables & Tracking
- This schedule should be tracked in your issue tracker with labels: Phase, Area (Auth/Chat/Calls/Payments/Infra), Severity (P0–P2).
- Each [M] Milestone should have an acceptance checklist and demo.
- Keep `.env.example` updated; never commit real secrets.
- Maintain `CHANGELOG.md` per release candidate.

## Notes
- If team size or scope changes, shift days proportionally and preserve milestone ordering.
- If a day’s work overruns, use the next buffer/QA day before pulling new scope forward.
