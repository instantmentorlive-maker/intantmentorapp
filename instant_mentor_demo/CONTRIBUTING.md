# Contributing to InstantMentor

Thanks for wanting to contribute! This file contains a short developer-focused section for writing and running unit/widget tests in this repository.

## Testing: env & Supabase guidance

The project uses `flutter_dotenv` and `supabase_flutter`. When writing unit or widget tests that run in the Dart VM (not on a device/emulator), follow these rules to avoid test flakes and platform-plugin errors:

- Do NOT call `SupabaseService.initialize()` or `Supabase.initialize()` from tests that run in the VM. Those initialization paths use platform plugins (for example, `shared_preferences`) and will throw `MissingPluginException` in pure VM tests.
- Always ensure dotenv is available during tests. Use the centralized test helper `test/test_helpers/dotenv_test_setup.dart`:
  - Call `ensureTestDotenvLoaded()` in your test `setUp()` to load `.env` (it seeds minimal SUPABASE keys if none are present).
  - Prefer the provided `providerOverridesForUnitTests(fakeAuthNotifier)` to inject a fake auth notifier instead of the real `authProvider`.

Example (in tests):

```dart
setUp(() async {
  await ensureTestDotenvLoaded();
  // create a FakeAuthNotifier and pass it into providerOverridesForUnitTests
});
```

Short checklist for tests:
- Seed dotenv via `ensureTestDotenvLoaded()` in `setUp()`.
- Use fakes or provider overrides for Supabase-backed providers (see `providerOverridesForUnitTests`).
- If you need to test Supabase integration that requires platform plugins, write those as integration tests that run on a device or emulator, not as VM unit tests.

## CI safety suggestion

To prevent accidental commits that initialize Supabase in the test tree, CI should fail if `SupabaseService.initialize(` or `Supabase.initialize(` appears under `test/`. A simple check is:

- grep -n "SupabaseService.initialize\(|Supabase.initialize\(" test/ && exit 1

Feel free to ask if you want me to add a ready-to-use CI script and an example job for GitHub Actions / GitLab CI.

## Pull Request checklist (recommended)
Before opening a PR, please run through this quick checklist:

- Run unit tests locally that are relevant to your change (or the full test suite if quick).
- Ensure you did not accidentally add `Supabase.initialize(` or `SupabaseService.initialize(` in any `test/` files. The CI will check this and fail the job if found.
- When adding or modifying tests, prefer the shared helpers in `test/test_helpers/`:
  - Use `ensureTestDotenvLoaded()` in `setUp()` for tests that read `dotenv.env`.
  - Prefer `providerOverridesForUnitTests(fake)` to inject a fake auth notifier in VM tests.
  - If your widget requires a fake Supabase service and SharedPreferences, use `widgetTestProviderScope()` from `test/helpers/setup_test_helper.dart`.
- Update `TEST_HELPERS.md` if you add new test helpers or change their signatures.

If you want, I can add a GitHub PR template to help enforce this checklist automatically.

---
Tiny, focused guidance helps keep tests stable. Thank you for contributing!
