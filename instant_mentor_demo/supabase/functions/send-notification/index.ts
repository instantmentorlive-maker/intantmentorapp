import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { userId, title, message, type = 'info', data, actionUrl, fcmTokens } = await req.json()

    if (!userId || !title || !message) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: userId, title, message' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Store notification in database
    const { data: notification, error: notificationError } = await supabase
      .from('notifications')
      .insert({
        user_id: userId,
        title: title,
        message: message,
        type: type,
        action_url: actionUrl,
        data: data,
        is_read: false
      })
      .select()
      .single()

    if (notificationError) {
      throw new Error(`Failed to store notification: ${notificationError.message}`)
    }

    // Send push notification via FCM if tokens provided
    if (fcmTokens && fcmTokens.length > 0) {
      const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')
      
      if (fcmServerKey) {
        const fcmPayload = {
          registration_ids: fcmTokens,
          notification: {
            title: title,
            body: message,
            icon: 'ic_notification',
            sound: 'default',
            click_action: actionUrl || 'FLUTTER_NOTIFICATION_CLICK'
          },
          data: {
            type: type,
            userId: userId,
            notificationId: notification.id,
            ...data
          }
        }

        const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
          method: 'POST',
          headers: {
            'Authorization': `key=${fcmServerKey}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(fcmPayload)
        })

        if (!fcmResponse.ok) {
          const errorText = await fcmResponse.text()
          console.error('FCM sending failed:', errorText)
        } else {
          const fcmResult = await fcmResponse.json()
          console.log('FCM sent successfully:', fcmResult)
        }
      }
    }

    // Send real-time notification via Supabase realtime
    const { error: realtimeError } = await supabase
      .channel(`user_${userId}`)
      .send({
        type: 'broadcast',
        event: 'notification',
        payload: {
          id: notification.id,
          title: title,
          message: message,
          type: type,
          data: data,
          actionUrl: actionUrl,
          createdAt: notification.created_at
        }
      })

    if (realtimeError) {
      console.error('Failed to send realtime notification:', realtimeError)
    }

    return new Response(
      JSON.stringify({
        success: true,
        notificationId: notification.id,
        message: 'Notification sent successfully'
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Notification sending error:', error)
    
    return new Response(
      JSON.stringify({ 
        error: 'Failed to send notification', 
        details: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
