import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { to, subject, html, text, cc, bcc } = await req.json()

    // Validate required fields
    if (!to || !subject || !html) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: to, subject, html' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Email service configuration
    const emailServiceUrl = Deno.env.get('EMAIL_SERVICE_URL') || 'https://api.sendgrid.v3'
    const emailApiKey = Deno.env.get('EMAIL_API_KEY') || Deno.env.get('SENDGRID_API_KEY')

    if (!emailApiKey) {
      throw new Error('Email service API key not configured')
    }

    // Prepare email payload for SendGrid
    const emailPayload = {
      personalizations: [
        {
          to: [{ email: to }],
          subject: subject,
          ...(cc && { cc: cc.map((email: string) => ({ email })) }),
          ...(bcc && { bcc: bcc.map((email: string) => ({ email })) })
        }
      ],
      from: {
        email: Deno.env.get('FROM_EMAIL') || 'noreply@instantmentor.app',
        name: Deno.env.get('FROM_NAME') || 'InstantMentor'
      },
      content: [
        {
          type: 'text/html',
          value: html
        },
        ...(text ? [{ type: 'text/plain', value: text }] : [])
      ]
    }

    // Send email via SendGrid
    const emailResponse = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${emailApiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(emailPayload)
    })

    if (!emailResponse.ok) {
      const errorText = await emailResponse.text()
      throw new Error(`SendGrid API error: ${emailResponse.status} - ${errorText}`)
    }

    // Log email activity in database
    const { error: logError } = await supabase
      .from('email_logs')
      .insert({
        recipient: to,
        subject: subject,
        status: 'sent',
        provider: 'sendgrid',
        sent_at: new Date().toISOString()
      })

    if (logError) {
      console.error('Failed to log email activity:', logError)
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Email sent successfully',
        messageId: emailResponse.headers.get('x-message-id')
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Email sending error:', error)
    
    return new Response(
      JSON.stringify({ 
        error: 'Failed to send email', 
        details: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
