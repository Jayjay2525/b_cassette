import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const payload = await req.json()
  console.log('[webhook] received payload:', JSON.stringify(payload))

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  if (!payload.success || payload.is_flagged) {
    await supabase
      .from('cassette_music')
      .update({ status: 'failed' })
      .eq('task_id', payload.task_id)
    return new Response('ok', { status: 200 })
  }

  if (!payload.conversion_path) {
    console.log('[webhook] conversion_path is null, ignoring. task_id:', payload.task_id)
    return new Response('ok', { status: 200 })
  }

  console.log('[webhook] audio ready, updating DB. url:', payload.conversion_path)

  const { data: row } = await supabase
    .from('cassette_music')
    .update({
      status: 'completed',
      audio_url: payload.conversion_path,
      duration: payload.conversion_duration
    })
    .eq('task_id', payload.task_id)
    .select('cassette_name, device_token')
    .single()

  if (row?.device_token) {
    console.log('[webhook] sending APNs push to', row.device_token)
    try {
      await sendApnsPush(
        row.device_token,
        row.cassette_name ?? 'Your cassette',
      )
    } catch (e) {
      console.error('[webhook] APNs push failed:', e)
    }
  } else {
    console.log('[webhook] no device_token found, skipping push')
  }

  return new Response('ok', { status: 200 })
})

async function sendApnsPush(deviceToken: string, cassetteName: string) {
  const privateKeyPem = Deno.env.get('APNS_PRIVATE_KEY')!
  const keyId = Deno.env.get('APNS_KEY_ID')!
  const teamId = Deno.env.get('APNS_TEAM_ID')!
  const bundleId = 'com.jaehoonpark.cassette.Cassette'

  const jwt = await generateApnsJwt(privateKeyPem, keyId, teamId)

  const notification = {
    aps: {
      alert: {
        title: `${cassetteName} is completed.`,
        body: 'Come check your new cassette!'
      },
      sound: 'default'
    }
  }

  // Sandbox & Production 키이므로 sandbox endpoint 사용 (개발 빌드)
  const url = `https://api.sandbox.push.apple.com/3/device/${deviceToken}`
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'authorization': `bearer ${jwt}`,
      'apns-topic': bundleId,
      'apns-push-type': 'alert',
      'content-type': 'application/json'
    },
    body: JSON.stringify(notification)
  })

  const body = await res.text()
  console.log('[APNs] status:', res.status, 'body:', body)
  if (!res.ok) throw new Error(`APNs error ${res.status}: ${body}`)
}

async function generateApnsJwt(privateKeyPem: string, keyId: string, teamId: string): Promise<string> {
  const pemContent = privateKeyPem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')

  const keyData = Uint8Array.from(atob(pemContent), c => c.charCodeAt(0))

  const key = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  )

  const encode = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')

  const header = encode({ alg: 'ES256', kid: keyId })
  const payload = encode({ iss: teamId, iat: Math.floor(Date.now() / 1000) })
  const message = `${header}.${payload}`

  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(message)
  )

  const sigBase64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')

  return `${message}.${sigBase64}`
}
