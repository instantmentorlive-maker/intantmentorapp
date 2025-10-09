# Payments migrations and smoke tests

This folder contains the main schema (`001_enhanced_payments_schema.sql`) and an optional smoke test script (`002_payments_smoke_tests.sql`).

## Order
1. Run `001_enhanced_payments_schema.sql` once to create objects.
2. Run `002_payments_smoke_tests.sql` in the Supabase SQL Editor to exercise the main flows.

## What the smoke test does
- Creates one student and one mentor using `auth.admin.create_user` (requires SQL Editor/admin privileges)
- Initializes profiles + wallet/earnings using provided init functions
- Top-ups student wallet (1000.00 minor units example)
- Reserves a session (600.00)
- Captures and splits the session (80% mentor / 20% platform)
- Performs a partial refund (100.00 -> 80 mentor, 20 platform reversed)
- Bumps capture time 25h back and calls `release_due_mentor_earnings()` to simulate T+24h release
- Prints balances via `RAISE NOTICE` so you can see results in the query output

## Expected outputs (approx in minor units)
- After capture: student locked decreases, mentor locked increases, platform fee recorded
- After partial refund: student available increases by refund_total, mentor share reduced (locked first), platform revenue reversed
- After release_due_mentor_earnings: mentor_locked -> mentor_available for the session amount

## Cleanup
The test users are left in place so you can review data. If desired, uncomment the delete_user calls at the bottom of the DO block to remove them.

## Notes
- The schema file is idempotent (triggers/policies dropped before create) and enables `pgcrypto`.
- If you see permission errors on `auth.admin.*`, ensure you are executing from the Supabase SQL Editor with service role or enable the `pgsodium/pgcrypto` extensions as provided.
