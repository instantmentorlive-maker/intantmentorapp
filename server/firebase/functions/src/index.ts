// Instant Mentor - Cloud Functions (TypeScript) – Stubs
// Node 18+, ESM modules

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import type { Request, Response } from 'express';
import type { CallableContext } from 'firebase-functions/v2/https';
// import Stripe from 'stripe';
// const stripe = new Stripe(process.env.STRIPE_SECRET!, { apiVersion: '2024-06-20' });

admin.initializeApp();
const db = admin.firestore();

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

  // TODO: Create PaymentIntent/Order (Stripe/Razorpay) and return client secret/orderId
  return { clientSecret: 'replace-with-real-client-secret', gateway };
});

export const handleStripeWebhook = functions.https.onRequest(async (req: Request, res: Response) => {
  // TODO: verify signature header and construct event
  const event = req.body; // placeholder

  // On payment_intent.succeeded:
  //  - append ledger(topup)
  //  - increment wallets/{uid}.balance_available
  // Use idempotency key from metadata to guard duplicates

  res.sendStatus(200);
});

export const reserveFundsOnBooking = functions.https.onCall(async (data: any, context: functions.https.CallableContext) => {
  const { sessionId, idempotencyKey } = data ?? {}; const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  if (!sessionId) throw new functions.https.HttpsError('invalid-argument', 'sessionId required');
  await ensureIdempotency(`reserve:${uid}:${sessionId}:${idempotencyKey}`);

  // In a Firestore transaction: move wallets.available -> wallets.locked, append ledger(reserve), mark session booked
  // Placeholder structure
  await db.runTransaction(async (tx: FirebaseFirestore.Transaction) => {
    // const walletRef = db.collection('wallets').doc(uid);
    // ...
  });
  return { ok: true };
});

export const settleOnSessionComplete = functions.https.onCall(async (data: any, context: functions.https.CallableContext) => {
  const { sessionId, finalAmount, mode, idempotencyKey } = data ?? {};
  if (!sessionId || !finalAmount) throw new functions.https.HttpsError('invalid-argument', 'Missing params');
  await ensureIdempotency(`settle:${sessionId}:${idempotencyKey}`);

  // Capture (direct) or debit locked (wallet), credit mentor_locked, fee to platform, schedule release
  // Placeholder
  return { ok: true };
});

export const requestPayout = functions.https.onCall(async (data: any, context: functions.https.CallableContext) => {
  const { amount, currency, idempotencyKey } = data ?? {}; const mentorId = context.auth?.uid;
  if (!mentorId) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  if (!amount || amount <= 0) throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
  await ensureIdempotency(`payout:${mentorId}:${idempotencyKey}`);

  // Validate KYC, threshold; create payout via Stripe/Razorpay; append payout ledger; create payouts/{id}
  // Placeholder
  const payoutDoc = await db.collection('payouts').add({
    mentorId, amount, currency: currency ?? 'INR', status: 'created', createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
  return { status: 'pending', id: payoutDoc.id };
});

export const handlePayoutWebhook = functions.https.onRequest(async (req: Request, res: Response) => {
  // Update payouts/{id} status -> paid/failed; reverse on failure
  // Placeholder
  res.sendStatus(200);
});
