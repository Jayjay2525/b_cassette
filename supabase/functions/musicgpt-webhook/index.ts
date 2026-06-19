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

  // audio_url이 없으면 아직 생성 중 — 무시하고 다음 콜백 기다림
  if (!payload.conversion_path) {
    console.log('[webhook] conversion_path is null, ignoring this callback. task_id:', payload.task_id)
    return new Response('ok', { status: 200 })
  }

  console.log('[webhook] audio ready, updating DB. url:', payload.conversion_path)

  await supabase
    .from('cassette_music')
    .update({
      status: 'completed',
      audio_url: payload.conversion_path,
      duration: payload.conversion_duration
    })
    .eq('task_id', payload.task_id)

  return new Response('ok', { status: 200 })
})
