// Instant Mentor - Cloud Functions (TypeScript) – Stubs
// Node 18+, ESM modules

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import type { Request, Response } from 'express';
import Razorpay from 'razorpay';
import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';
// import Stripe from 'stripe';
// const stripe = new Stripe(process.env.STRIPE_SECRET!, { apiVersion: '2024-06-20' });

admin.initializeApp();
const db = admin.firestore();

// Env: support both process.env and Firebase functions:config()
function cfg(path: string): string | undefined {
  try {
    const c: any = functions.config?.() || {};
    // path like 'stripe.secret'
    const parts = path.split('.');
    let cur: any = c;
    for (const p of parts) { if (!cur) return undefined; cur = cur[p]; }
    return typeof cur === 'string' ? cur : undefined;
  } catch { return undefined; }
}
const STRIPE_SECRET = process.env.STRIPE_SECRET || cfg('stripe.secret') || '';
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || cfg('stripe.webhook_secret') || '';
const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || cfg('razorpay.key_id') || '';
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || cfg('razorpay.key_secret') || '';
const RAZORPAY_WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET || cfg('razorpay.webhook_secret') || '';
const SUPABASE_URL = process.env.SUPABASE_URL || cfg('supabase.url') || '';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || cfg('supabase.service_role_key') || '';

// Clients
const stripe = STRIPE_SECRET ? new Stripe(STRIPE_SECRET, { apiVersion: '2024-06-20' }) : undefined;
const razorpay = (RAZORPAY_KEY_ID && RAZORPAY_KEY_SECRET) ? new Razorpay({ key_id: RAZORPAY_KEY_ID, key_secret: RAZORPAY_KEY_SECRET }) : undefined;
const supabase = (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY) ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } }) : undefined;

// Util: idempotency guard
async function ensureIdempotency(key: string) {
  if (!key) return;
  const ref = db.collection('idempotencyKeys').doc(key);
  await db.runTransaction(async (tx: FirebaseFirestore.Transaction) => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      throw new functions.https.HttpsError('already-exists', 'Duplicate request');
    }
    tx.set(ref, { createdAt: admin.firestore.FieldValue.serverTimestamp() });
  });
}

export const createTopupIntent = functions.https.onCall(async (data: any, context: functions.https.CallableContext) => {
  const { amount, currency, idempotencyKey, gateway } = data ?? {};
  const uid = context.auth?.uid; if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  if (!amount || amount <= 0) throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
  await ensureIdempotency(`topup:${uid}:${idempotencyKey}`);
  if (gateway === 'stripe') {
    if (!stripe) throw new functions.https.HttpsError('failed-precondition', 'Stripe not configured');
    const intent = await stripe.paymentIntents.create({
      amount,
      currency: currency || 'inr',
      metadata: { uid, idem: idempotencyKey || '' }
    }, { idempotencyKey });
    return { gateway: 'stripe', clientSecret: intent.client_secret };
  } else if (gateway === 'razorpay') {
    if (!razorpay) throw new functions.https.HttpsError('failed-precondition', 'Razorpay not configured');
    const order: any = await razorpay.orders.create({
      amount,
      currency: (currency || 'INR').toUpperCase(),
      receipt: `topup_${uid}_${Date.now()}`,
      notes: { uid, idem: idempotencyKey || '' },
    });
    return { gateway: 'razorpay', orderId: order.id };
  } else {
    throw new functions.https.HttpsError('invalid-argument', 'Unsupported gateway');
  }
});

export const handleStripeWebhook = functions.https.onRequest(async (req: Request, res: Response): Promise<void> => {
  if (!stripe) { res.status(500).send('Stripe not configured'); return; }
  const sig = req.headers['stripe-signature'] as string | undefined;
  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(await getRawBody(req), sig || '', STRIPE_WEBHOOK_SECRET);
  } catch (err: any) {
    // Alert: Stripe webhook verification failed
    try {
      await supabase?.rpc('admin_log_alert', {
        p_type: 'webhook_verification_failed',
        p_severity: 'error',
        p_message: 'Stripe signature verification failed',
        p_details: { reason: String(err?.message || err), provider: 'stripe' }
      } as any);
    } catch {}
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  if (!supabase) { res.status(500).send('Supabase not configured'); return; }

  if (event.type === 'payment_intent.succeeded') {
    const pi = event.data.object as Stripe.PaymentIntent;
    const uid = (pi.metadata && pi.metadata.uid) || undefined;
    const idem = (pi.metadata && pi.metadata.idem) || undefined;
  if (!uid) { res.status(200).send('Missing uid'); return; }
    // Credit wallet via RPC; rely on DB idempotency
    await supabase.rpc('process_wallet_topup', {
      user_id: uid,
      amount_minor: pi.amount_received,
      transaction_data: { gatewayId: pi.id, idempotencyKey: idem }
    });
  }

  // TODO: handle charge.refunded → call process_session_refund accordingly if mapping exists

  res.sendStatus(200);
});

export const handleRazorpayWebhook = functions.https.onRequest(async (req: Request, res: Response): Promise<void> => {
  if (!razorpay) { res.status(500).send('Razorpay not configured'); return; }
  // Verify signature
  const signature = req.headers['x-razorpay-signature'] as string | undefined;
  const body = await getRawBody(req);
  const crypto = await import('crypto');
  const expected = crypto.createHmac('sha256', RAZORPAY_WEBHOOK_SECRET).update(body).digest('hex');
  if (expected !== signature) {
    try {
      await supabase?.rpc('admin_log_alert', {
        p_type: 'webhook_verification_failed',
        p_severity: 'error',
        p_message: 'Razorpay signature verification failed',
        p_details: { provider: 'razorpay' }
      } as any);
    } catch {}
    res.status(400).send('Invalid signature');
    return;
  }

  const event = JSON.parse(body.toString());
  if (!supabase) { res.status(500).send('Supabase not configured'); return; }
  if (event.event === 'payment.captured') {
    const payment = event.payload.payment.entity;
    const uid = payment.notes?.uid as string | undefined;
    const orderId = payment.order_id as string | undefined;
    const idem = payment.notes?.idem as string | undefined;
    if (uid) {
      await supabase.rpc('process_wallet_topup', {
        user_id: uid,
        amount_minor: payment.amount,
        transaction_data: { gatewayId: orderId || payment.id, idempotencyKey: idem }
      });
    }
  }
  // TODO: handle refund events
  res.sendStatus(200);
});

export const reserveFundsOnBooking = functions.https.onCall(async (data: any, context: functions.https.CallableContext) => {
  const { sessionId, idempotencyKey } = data ?? {}; const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  if (!sessionId) throw new functions.https.HttpsError('invalid-argument', 'sessionId required');
  await ensureIdempotency(`reserve:${uid}:${sessionId}:${idempotencyKey}`);
  if (!supabase) throw new functions.https.HttpsError('failed-precondition', 'Supabase not configured');
  // Expect caller to include amount and currency or derive from session
  const { amountMinor, currency } = data ?? {};
  const { error } = await supabase.rpc('process_funds_reserve', {
    user_id: uid,
    amount_minor: amountMinor,
    session_id: sessionId,
    transaction_data: { idempotencyKey }
  });
  if (error) throw new functions.https.HttpsError('internal', error.message);
  return { ok: true };
});

export const settleOnSessionComplete = functions.https.onCall(async (data: any, context: functions.https.CallableContext) => {
  const { sessionId, finalAmount, mode, idempotencyKey } = data ?? {};
  if (!sessionId || !finalAmount) throw new functions.https.HttpsError('invalid-argument', 'Missing params');
  await ensureIdempotency(`settle:${sessionId}:${idempotencyKey}`);
  if (!supabase) throw new functions.https.HttpsError('failed-precondition', 'Supabase not configured');
  const { studentId, mentorId, feePercent } = data ?? {};
  const platformFee = Math.round(finalAmount * (feePercent ?? 0.15));
  const mentorAmount = finalAmount - platformFee;
  const { error } = await supabase.rpc('process_session_completion', {
    session_id: sessionId,
    student_id: studentId,
    mentor_id: mentorId,
    total_amount: finalAmount,
    mentor_amount: mentorAmount,
    platform_fee: platformFee,
    transactions_data: null
  });
  if (error) throw new functions.https.HttpsError('internal', error.message);
  return { ok: true };
});

export const requestPayout = functions.https.onCall(async (data: any, context: functions.https.CallableContext) => {
  const { amount, currency, idempotencyKey } = data ?? {}; const mentorId = context.auth?.uid;
  if (!mentorId) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  if (!amount || amount <= 0) throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
  await ensureIdempotency(`payout:${mentorId}:${idempotencyKey}`);
  if (!supabase) throw new functions.https.HttpsError('failed-precondition', 'Supabase not configured');
  // TODO: verify KYC and balance threshold via Supabase profile/earnings
  let gateway: 'stripe' | 'razorpay' = 'stripe'; // choose based on region/profile
  if (gateway === 'stripe') {
    if (!stripe) throw new functions.https.HttpsError('failed-precondition', 'Stripe not configured');
    // Here you’d create a Stripe Transfer/Payout depending on your Connect setup
  } else {
    if (!razorpay) throw new functions.https.HttpsError('failed-precondition', 'Razorpay not configured');
    // Here you’d create a Razorpay payout to the mentor’s fund account
  }
  // Deduct mentor_available via ledger payout entry is best done upon webhook confirmation; you can also soft-lock now.
  const { data: row, error } = await supabase.from('payout_requests').insert({
    mentor_uid: mentorId,
    amount,
    currency: currency ?? 'INR',
    status: 'created',
    gateway: gateway
  }).select('*').single();
  if (error) {
    try {
      await supabase.rpc('admin_log_alert', {
        p_type: 'payout_request_failed',
        p_severity: 'error',
        p_message: 'Failed to create payout request row',
        p_details: { mentorId, amount, currency, reason: error.message }
      } as any);
    } catch {}
    throw new functions.https.HttpsError('internal', error.message);
  }
  return { status: 'pending', id: row.id };
});

export const handlePayoutWebhook = functions.https.onRequest(async (req: Request, res: Response): Promise<void> => {
  // Implement signature verification per gateway route you expose
  if (!supabase) { res.status(500).send('Supabase not configured'); return; }
  // Example skeleton (you may separate by path /stripe-payouts, /razorpay-payouts):
  const body = req.body;
  const status = body.status as string | undefined;
  const payoutId = body.payoutId as string | undefined;
  const requestId = body.requestId as string | undefined; // our payout_requests.id
  if (!requestId) { res.sendStatus(200); return; }
  if (status === 'paid') {
    await supabase.from('payout_requests').update({ status: 'paid', payout_id: payoutId, completed_at: new Date().toISOString() }).eq('id', requestId);
    // Append ledger payout mentor_available -> external_gateway via a dedicated RPC if desired
  } else if (status === 'failed') {
    await supabase.from('payout_requests').update({ status: 'failed', payout_id: payoutId, failure_reason: body.failure_reason }).eq('id', requestId);
    // Reverse any soft-lock to mentor_available if applied earlier
    try {
      await supabase.rpc('admin_log_alert', {
        p_type: 'payout_failed',
        p_severity: 'error',
        p_message: 'Gateway reported payout failure',
        p_details: { requestId, payoutId, failure_reason: body.failure_reason }
      } as any);
    } catch {}
  }
  res.sendStatus(200);
});

// Scheduled release (T+24h) – runs hourly
export const releaseMentorEarningsScheduled = functions.pubsub.schedule('every 60 minutes').onRun(async () => {
  if (!supabase) return null;
  // Here you’d query sessions captured >24h and not yet released; for demo we assume you have a list or view
  // Example: select sessions needing release and call RPC per row
  // const { data: rows } = await supabase.from('sessions_to_release_view').select('*');
  // for (const r of rows ?? []) { await supabase.rpc('process_mentor_earnings_release', { mentor_id: r.mentor_id, amount_minor: r.amount_mentor, session_id: r.session_id }); }
  return null;
});

// Periodic reconciliation job – checks invariants and logs alerts
export const reconciliationCheckScheduled = functions.pubsub.schedule('every 30 minutes').onRun(async () => {
  if (!supabase) return null;
  try {
    const res: any = await supabase.rpc('admin_get_reconciliation_stats');
    const stats = (res?.data ?? res) as Record<string, any>;
    // Basic invariants: ensure no negative totals
    const negatives = [
      stats?.wallet_total_available,
      stats?.wallet_total_locked,
      stats?.earnings_total_available,
      stats?.earnings_total_locked,
      stats?.platform_revenue_net,
    ].some((v: any) => typeof v === 'number' && v < 0);
    if (negatives) {
      await supabase.rpc('admin_log_alert', {
        p_type: 'reconciliation_mismatch',
        p_severity: 'warning',
        p_message: 'Negative balance detected in reconciliation stats',
        p_details: stats,
      } as any);
    }
    // Optional: additional cross-sum checks can go here (platform net = fees – platform refunds)
  } catch (e: any) {
    try {
      await supabase.rpc('admin_log_alert', {
        p_type: 'reconciliation_check_failed',
        p_severity: 'error',
        p_message: 'Failed to run reconciliation stats',
        p_details: { reason: String(e?.message || e) },
      } as any);
    } catch {}
  }
  return null;
});

// Helpers
async function getRawBody(req: Request): Promise<Buffer> {
  // Prefer the rawBody provided by Firebase Functions to preserve exact bytes for signature verification
  const anyReq = req as any;
  if (anyReq.rawBody) {
    return Buffer.isBuffer(anyReq.rawBody) ? anyReq.rawBody : Buffer.from(anyReq.rawBody);
  }
  // Fallback: if body parser ran, reconstruct best-effort buffer
  if (Buffer.isBuffer(req.body)) return req.body;
  if (typeof req.body === 'string') return Buffer.from(req.body);
  return Buffer.from(JSON.stringify(req.body ?? {}));
}
