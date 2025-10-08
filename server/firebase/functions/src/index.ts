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

// Env
const STRIPE_SECRET = process.env.STRIPE_SECRET || '';
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || '';
const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || '';
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || '';
const RAZORPAY_WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET || '';
const SUPABASE_URL = process.env.SUPABASE_URL || '';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

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
    const order = await razorpay.orders.create({ amount, currency: currency || 'INR', receipt: `topup_${uid}_${Date.now()}` });
    return { gateway: 'razorpay', orderId: order.id };
  } else {
    throw new functions.https.HttpsError('invalid-argument', 'Unsupported gateway');
  }
});

export const handleStripeWebhook = functions.https.onRequest(async (req: Request, res: Response) => {
  if (!stripe) return res.status(500).send('Stripe not configured');
  const sig = req.headers['stripe-signature'] as string | undefined;
  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(await getRawBody(req), sig || '', STRIPE_WEBHOOK_SECRET);
  } catch (err: any) {
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (!supabase) return res.status(500).send('Supabase not configured');

  if (event.type === 'payment_intent.succeeded') {
    const pi = event.data.object as Stripe.PaymentIntent;
    const uid = (pi.metadata && pi.metadata.uid) || undefined;
    const idem = (pi.metadata && pi.metadata.idem) || undefined;
    if (!uid) return res.status(200).send('Missing uid');
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

export const handleRazorpayWebhook = functions.https.onRequest(async (req: Request, res: Response) => {
  if (!razorpay) return res.status(500).send('Razorpay not configured');
  // Verify signature
  const signature = req.headers['x-razorpay-signature'] as string | undefined;
  const body = await getRawBody(req);
  const crypto = await import('crypto');
  const expected = crypto.createHmac('sha256', RAZORPAY_WEBHOOK_SECRET).update(body).digest('hex');
  if (expected !== signature) return res.status(400).send('Invalid signature');

  const event = JSON.parse(body.toString());
  if (!supabase) return res.status(500).send('Supabase not configured');
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
  if (error) throw new functions.https.HttpsError('internal', error.message);
  return { status: 'pending', id: row.id };
});

export const handlePayoutWebhook = functions.https.onRequest(async (req: Request, res: Response) => {
  // Implement signature verification per gateway route you expose
  if (!supabase) return res.status(500).send('Supabase not configured');
  // Example skeleton (you may separate by path /stripe-payouts, /razorpay-payouts):
  const body = req.body;
  const status = body.status as string | undefined;
  const payoutId = body.payoutId as string | undefined;
  const requestId = body.requestId as string | undefined; // our payout_requests.id
  if (!requestId) return res.sendStatus(200);
  if (status === 'paid') {
    await supabase.from('payout_requests').update({ status: 'paid', payout_id: payoutId, completed_at: new Date().toISOString() }).eq('id', requestId);
    // Append ledger payout mentor_available -> external_gateway via a dedicated RPC if desired
  } else if (status === 'failed') {
    await supabase.from('payout_requests').update({ status: 'failed', payout_id: payoutId, failure_reason: body.failure_reason }).eq('id', requestId);
    // Reverse any soft-lock to mentor_available if applied earlier
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

// Helpers
async function getRawBody(req: Request): Promise<Buffer> {
  // Firebase Functions may not provide raw body by default in TS; this is a minimal helper
  // If using functions.https.onRequest, ensure you disable bodyParser for raw verification, or use raw middleware.
  return Buffer.isBuffer(req.body) ? req.body : Buffer.from(JSON.stringify(req.body));
}
