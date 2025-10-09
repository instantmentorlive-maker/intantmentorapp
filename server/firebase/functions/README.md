# Firebase Cloud Functions

Endpoints and scheduled jobs used by Instant Mentor.

## Webhooks
- handleStripeWebhook (POST): Configure Stripe to send events to this URL. Verifies signature using STRIPE_WEBHOOK_SECRET.
- handleRazorpayWebhook (POST): Configure Razorpay webhook; signature verified using RAZORPAY_WEBHOOK_SECRET.
- handlePayoutWebhook (POST): Internal route to mark payout requests paid/failed. Add signature verification in production.

## Callable functions
- createTopupIntent: Creates a top-up intent/order for wallet balance.
- reserveFundsOnBooking: Moves wallet funds to locked balance for a session.
- settleOnSessionComplete: Posts final ledger entries for a session completion (wallet mode).
- requestPayout: Creates a payout request row to be completed by gateway webhook.

## Scheduled jobs
- reconciliationCheckScheduled: Runs every 30 minutes; calls admin_get_reconciliation_stats and logs alerts on mismatch/failure.
- releaseMentorEarningsScheduled: Hourly placeholder to release due mentor earnings (24h delay pattern).

## Environment
Set these via Firebase config/secrets (do not commit real values):
- STRIPE_SECRET
- STRIPE_WEBHOOK_SECRET
- RAZORPAY_KEY_ID
- RAZORPAY_KEY_SECRET
- RAZORPAY_WEBHOOK_SECRET
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
- PLATFORM_FEE_PERCENT (optional)

## Local dev tips
- Use the emulator for basic testing: `npm run serve`
- Stripe webhook verification requires rawBody; ensure `functions.https.onRequest` uses `req.rawBody`. This repo includes a helper that prefers `req.rawBody`.
- For end-to-end tests, configure Stripe CLI to forward events to your emulator.
