import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.21.0";

const corsHeaders = {
	"Access-Control-Allow-Origin": "*",
	"Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
	if (req.method === "OPTIONS") {
		return new Response("ok", { headers: corsHeaders });
	}

	try {
		const body = await req.json();
		const {
			sessionId,
			transactionId, // Stripe PaymentIntent ID stored as payment_transactions.transaction_id
			amount, // optional, major units (e.g., 100.00)
			currency, // optional, e.g., 'INR' | 'USD'
			reason = "requested_by_customer",
		} = body ?? {};

		if (!sessionId || !transactionId) {
			return new Response(
				JSON.stringify({ error: "Missing required fields: sessionId, transactionId" }),
				{ status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
			);
		}

		const supabaseUrl = Deno.env.get("SUPABASE_URL");
		const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
		const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
		if (!supabaseUrl || !supabaseKey) throw new Error("Supabase env not configured");
		if (!stripeKey) throw new Error("Stripe secret key not configured");

		const supabase = createClient(supabaseUrl, supabaseKey, { auth: { persistSession: false } });
		const stripe = new Stripe(stripeKey, { apiVersion: "2023-10-16" });

		// Retrieve payment intent to confirm currency/amount if needed
		const pi = await stripe.paymentIntents.retrieve(transactionId);
		const piCurrency = (pi.currency || currency || "INR").toUpperCase();
		const refundMinor = typeof amount === "number" && !Number.isNaN(amount)
			? Math.round(amount * 100)
			: (pi.amount_received || pi.amount || 0); // fall back to full amount
		if (!refundMinor || refundMinor <= 0) throw new Error("Refund amount invalid or zero");

		// Create refund (prefer payment_intent reference for idempotency)
		const refund = await stripe.refunds.create({
			payment_intent: transactionId,
			amount: refundMinor,
			reason: reason as any,
		});

		// Fetch session to identify student/mentor
		const { data: session, error: sessionErr } = await supabase
			.from("mentoring_sessions")
			.select("id, student_id, mentor_id")
			.eq("id", sessionId)
			.maybeSingle();
		if (sessionErr) throw new Error(`Session lookup failed: ${sessionErr.message}`);
		if (!session) throw new Error("Session not found");

		// Compute platform/mentor shares for reversal – use env percent or default 15%
		const feePercent = Number(Deno.env.get("STRIPE_FEE_PERCENT")) || 0.15;
		const refundPlatform = Math.round(refundMinor * feePercent);
		const refundMentor = refundMinor - refundPlatform;

		// Update domain ledger via RPC (reverse mentor/platform shares and credit student)
		// Follows wrapper signature: process_session_refund(session_id, student_id, mentor_id, refund_total, refund_mentor_share, refund_platform_share)
		const { error: rpcErr } = await (supabase as any).rpc("process_session_refund", {
			session_id: sessionId,
			student_id: session.student_id,
			mentor_id: session.mentor_id,
			refund_total: refundMinor,
			refund_mentor_share: refundMentor,
			refund_platform_share: refundPlatform,
		});
		if (rpcErr) {
			// Log alert but do not fail the HTTP response since the gateway refund succeeded
			try {
				await (supabase as any).rpc("admin_log_alert", {
					p_type: "refund_ledger_update_failed",
					p_severity: "error",
					p_message: "Stripe refund succeeded but ledger update failed",
					p_details: { sessionId, transactionId, refundId: refund.id, reason: rpcErr.message },
				});
			} catch (_) {}
		}

		// Best-effort: mark payment transaction as refunded
		await supabase
			.from("payment_transactions")
			.update({ status: "refunded" })
			.eq("transaction_id", transactionId);

		return new Response(
			JSON.stringify({ success: true, refundId: refund.id, amountMinor: refundMinor, currency: piCurrency }),
			{ status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
		);
	} catch (error: any) {
		// Optional: log admin alert
		try {
			const supabaseUrl = Deno.env.get("SUPABASE_URL");
			const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
			if (supabaseUrl && supabaseKey) {
				const supabase = createClient(supabaseUrl, supabaseKey, { auth: { persistSession: false } });
				await (supabase as any).rpc("admin_log_alert", {
					p_type: "refund_failed",
					p_severity: "error",
					p_message: "Refund processing failed",
					p_details: { reason: String(error?.message || error) },
				});
			}
		} catch (_) {}

		return new Response(
			JSON.stringify({ error: "Failed to process refund", details: String(error?.message || error) }),
			{ status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
		);
	}
});

