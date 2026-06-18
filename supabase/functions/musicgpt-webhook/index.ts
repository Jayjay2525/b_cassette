import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const payload = await req.json()

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
