// supabase/functions/complete-bp-mission/index.ts
// Completa una misión del Battle Pass: valida progreso, otorga XP,
// avanza de tier si corresponde.
//
// Deploy: supabase functions deploy complete-bp-mission --project-ref <ref>

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface CompleteMissionRequest {
  mission_id: string
}

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const authHeader = req.headers.get('Authorization')
  const { data: { user } } = await supabase.auth.getUser(
    authHeader?.replace('Bearer ', ''),
  )
  if (!user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }

  const { mission_id }: CompleteMissionRequest = await req.json()
  if (!mission_id) {
    return new Response(JSON.stringify({ error: 'mission_id es requerido' }), { status: 400 })
  }

  // 1. Obtener misión de battle_pass_missions
  const { data: mission, error: missionError } = await supabase
    .from('battle_pass_missions')
    .select('*')
    .eq('id', mission_id)
    .single()

  if (missionError || !mission) {
    return new Response(JSON.stringify({ error: 'Misión no encontrada' }), { status: 404 })
  }

  // 2. Obtener progreso del usuario para esta misión
  const { data: progress, error: progressError } = await supabase
    .from('user_missions_progress')
    .select('*')
    .eq('user_id', user.id)
    .eq('mission_id', mission_id)
    .maybeSingle()

  if (progressError) throw progressError

  if (!progress) {
    return new Response(JSON.stringify({
      error: 'No tienes progreso registrado para esta misión',
    }), { status: 400 })
  }

  // 3. Validar que haya alcanzado el target y no esté ya completada
  if (progress.is_completed) {
    return new Response(JSON.stringify({
      error: 'Esta misión ya fue completada anteriormente',
    }), { status: 400 })
  }

  if (progress.progress < mission.target) {
    return new Response(JSON.stringify({
      error: `Progreso insuficiente: ${progress.progress}/${mission.target}`,
    }), { status: 400 })
  }

  // 4. Marcar misión como completada
  const xpAwarded = mission.xp_reward || 50

  const { error: updateError } = await supabase
    .from('user_missions_progress')
    .update({
      is_completed: true,
      completed_at: new Date().toISOString(),
    })
    .eq('id', progress.id)

  if (updateError) throw updateError

  // 5. Sumar XP a battle_pass_progress.xp_in_season
  const { data: bpProgress } = await supabase
    .from('battle_pass_progress')
    .select('*')
    .eq('user_id', user.id)
    .eq('battle_pass_id', mission.battle_pass_id)
    .maybeSingle()

  if (bpProgress) {
    const { error: bpUpdateError } = await supabase
      .from('battle_pass_progress')
      .update({
        xp_in_season: (bpProgress.xp_in_season || 0) + xpAwarded,
      })
      .eq('id', bpProgress.id)

    if (bpUpdateError) throw bpUpdateError
  }

  // 6. Insertar log en season_pass_xp_log
  const { error: logError } = await supabase
    .from('season_pass_xp_log')
    .insert({
      user_id: user.id,
      battle_pass_id: mission.battle_pass_id,
      mission_id: mission.id,
      xp: xpAwarded,
      source: 'mission_complete',
    })

  if (logError) throw logError

  // 7. Llamar advance_battle_pass_tier
  let tierAdvanced = false
  const { data: tierResult, error: tierError } = await supabase.rpc(
    'advance_battle_pass_tier',
    {
      p_user_id: user.id,
      p_battle_pass_id: mission.battle_pass_id,
    },
  )

  if (tierError) {
    console.error('Error advancing tier:', tierError.message)
  } else {
    tierAdvanced = tierResult?.tier_advanced ?? false
  }

  return new Response(JSON.stringify({
    success: true,
    xp_awarded: xpAwarded,
    tier_advanced: tierAdvanced,
  }), {
    headers: { 'Content-Type': 'application/json' },
    status: 200,
  })
})
