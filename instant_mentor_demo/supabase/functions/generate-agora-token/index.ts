import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Agora token generation utilities
const AGORA_APP_ID = Deno.env.get('AGORA_APP_ID')!
const AGORA_APP_CERTIFICATE = Deno.env.get('AGORA_APP_CERTIFICATE')!

// Token types
const AccessToken = {
  kJoinChannel: 1,
  kPublishAudioStream: 2,
  kPublishVideoStream: 3,
  kPublishDataStream: 4,
}

class AgoraAccessToken {
  private appId: string
  private appCertificate: string
  private channelName: string
  private uid: string | number
  private privilegeExpiredTs: number

  constructor(appId: string, appCertificate: string, channelName: string, uid: string | number) {
    this.appId = appId
    this.appCertificate = appCertificate
    this.channelName = channelName
    this.uid = uid
    this.privilegeExpiredTs = 0
  }

  setPrivilege(privilege: number, expiredTs: number) {
    this.privilegeExpiredTs = expiredTs
  }

  build(): string {
    // This is a simplified token generation
    // In production, use Agora's official token generation library
    const version = '006'
    const expireTime = Math.floor(Date.now() / 1000) + 3600 // 1 hour
    
    // Create a simple hash-based token (replace with proper Agora implementation)
    const message = `${this.appId}${this.channelName}${this.uid}${expireTime}`
    const signature = this.generateSignature(message)
    
    return `${version}${this.appId}${signature}${expireTime}`
  }

  private generateSignature(message: string): string {
    // Simplified signature generation - use proper HMAC-SHA256 in production
    let hash = 0
    for (let i = 0; i < message.length; i++) {
      const char = message.charCodeAt(i)
      hash = ((hash << 5) - hash) + char
      hash = hash & hash // Convert to 32-bit integer
    }
    return Math.abs(hash).toString(16)
  }
}

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  }

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    // Get request data
    const { channelId, uid, role = 'publisher', expireTime = 3600 } = await req.json()

    // Validate required parameters
    if (!channelId || uid === undefined) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required parameters: channelId and uid' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Check if Agora credentials are configured
    if (!AGORA_APP_ID || !AGORA_APP_CERTIFICATE) {
      return new Response(
        JSON.stringify({ 
          error: 'Agora credentials not configured on server' 
        }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Create Agora access token
    const accessToken = new AgoraAccessToken(AGORA_APP_ID, AGORA_APP_CERTIFICATE, channelId, uid)
    
    // Set privileges based on role
    const currentTimestamp = Math.floor(Date.now() / 1000)
    const privilegeExpiredTs = currentTimestamp + expireTime

    if (role === 'publisher') {
      accessToken.setPrivilege(AccessToken.kJoinChannel, privilegeExpiredTs)
      accessToken.setPrivilege(AccessToken.kPublishAudioStream, privilegeExpiredTs)
      accessToken.setPrivilege(AccessToken.kPublishVideoStream, privilegeExpiredTs)
    } else {
      accessToken.setPrivilege(AccessToken.kJoinChannel, privilegeExpiredTs)
    }

    // Generate token
    const token = accessToken.build()

    // Initialize Supabase client for logging
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Log token generation
    await supabaseClient
      .from('agora_tokens')
      .insert({
        channel_id: channelId,
        uid: uid.toString(),
        token: token,
        role: role,
        expires_at: new Date(privilegeExpiredTs * 1000).toISOString(),
        created_at: new Date().toISOString(),
      })
      .select()

    return new Response(
      JSON.stringify({
        success: true,
        token: token,
        channelId: channelId,
        uid: uid,
        role: role,
        expiresAt: privilegeExpiredTs,
        appId: AGORA_APP_ID,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )

  } catch (error) {
    console.error('Error generating Agora token:', error)
    
    return new Response(
      JSON.stringify({ 
        error: 'Failed to generate Agora token',
        details: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
