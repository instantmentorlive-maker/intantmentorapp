import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14.21.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { sessionId, amount, currency = 'INR', paymentMethod } = await req.json()

    // Validate required fields
    if (!sessionId || !amount) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: sessionId, amount' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Initialize Stripe
    const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
    if (!stripeKey) {
      throw new Error('Stripe secret key not configured')
    }
    const stripe = new Stripe(stripeKey, { apiVersion: '2023-10-16' })

    // Get session details from database
    const { data: session, error: sessionError } = await supabase
      .from('mentoring_sessions')
      .select(`
        *,
        mentor_profiles!inner(
          user_id,
          hourly_rate,
          user_profiles!inner(full_name, email)
        ),
        student:auth.users!student_id(email, raw_user_meta_data)
      `)
      .eq('id', sessionId)
      .single()

    if (sessionError || !session) {
      throw new Error('Session not found')
    }

    // Create payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Convert to cents
      currency: currency.toLowerCase(),
      metadata: {
        sessionId: sessionId,
        studentId: session.student_id,
        mentorId: session.mentor_id,
        type: 'session_payment'
      },
      description: `InstantMentor Session - ${session.subject}`,
      receipt_email: session.student.email
    })

    // Create payment transaction record
    const { data: transaction, error: transactionError } = await supabase
      .from('payment_transactions')
      .insert({
        session_id: sessionId,
        payer_id: session.student_id,
        payee_id: session.mentor_profiles.user_id,
        amount: amount,
        currency: currency,
        status: 'pending',
        payment_method: paymentMethod || 'stripe',
        transaction_id: paymentIntent.id
      })
      .select()
      .single()

    if (transactionError) {
      console.error('Failed to create transaction record:', transactionError)
    }

    // Update session payment status
    await supabase
      .from('mentoring_sessions')
      .update({ 
        payment_status: 'pending',
        cost: amount
      })
      .eq('id', sessionId)

    return new Response(
      JSON.stringify({
        success: true,
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
        transactionId: transaction?.id
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Payment processing error:', error)
    
    return new Response(
      JSON.stringify({ 
        error: 'Failed to process payment', 
        details: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
