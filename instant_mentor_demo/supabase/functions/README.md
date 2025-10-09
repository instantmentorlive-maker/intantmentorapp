# Supabase Edge Functions

This folder contains Deno-based Edge Functions deployed to Supabase.

Functions included:
- process-payment: Creates a PaymentIntent and returns client_secret (Stripe), or order (Razorpay).
- process-refund: Performs a refund on the payment provider and posts ledger adjustments via `process_session_refund`.
- send-notification: Demo hook to send push notifications.
- send-email: Demo hook to send transactional email.
- generate-agora-token: Demo hook to mint Agora RTC tokens.

## Environment variables
Provide these in your project on Supabase (Settings → Functions → Secrets):
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
- STRIPE_SECRET_KEY
- PLATFORM_FEE_PERCENT (optional, default 0.15)

## Deploy
From the root of your Supabase project (or using the Supabase CLI):
- supabase functions deploy process-payment
- supabase functions deploy process-refund

## Invocation
- process-refund
  - Method: POST
  - Body: { "sessionId": "...", "transactionId": "pi_...", "amount": 100.0, "reason": "requested_by_customer" }
  - Returns: { success: true, refundId: "re_..." }
