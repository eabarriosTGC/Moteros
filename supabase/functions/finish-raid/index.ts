// supabase/functions/finish-raid/index.ts
// Finaliza un raid: calcula XP por modo, streaks, bonus, anti-cheat.
// Solo el host puede ejecutar.
//
// Deploy: supabase functions deploy finish-raid --project-ref <ref>

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const authHeader = req.headers.get('Authorization')
  const { data: { user } } = await supabase.auth.getUser(authHeader?.replace('Bearer ', ''))
  if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

  const { raid_id } = await req.json()

  // 1. Verificar que soy host
  const { data: raid } = await supabase
    .from('raids').select('*, host_id, mode, status, is_night_raid')
    .eq('id', raid_id).single()

  if (!raid) return new Response(JSON.stringify({ error: 'Raid no encontrado' }), { status: 404 })
  if (raid.host_id !== user.id) return new Response(JSON.stringify({ error: 'Solo el host puede finalizar' }), { status: 403 })
  if (raid.status !== 'active') return new Response(JSON.stringify({ error: 'Raid no está activo' }), { status: 400 })

  // 2. XP base por modo
  const xpTable: Record<string, number> = {
    free_ride: 10, rally: 25, ruta_gotica: 15,
    convoy: 15, sobrevivencia: 40, guerra_clanes: 20,
  }
  const baseXp = xpTable[raid.mode] || 10

  // 3. Obtener total de checkpoints para bonus
  const { count: totalCheckpoints } = await supabase
    .from('raid_checkpoints')
    .select('*', { count: 'exact', head: true })
    .eq('raid_id', raid_id)

  // 4. Obtener participantes
  const { data: participants } = await supabase
    .from('raid_participants')
    .select('*, user_xp!inner(current_streak, last_raid_date)')
    .eq('raid_id', raid_id)

  let totalXpDistributed = 0
  let participantsCompleted = 0
  const participantResults: Array<{ user_id: string; xp_earned: number; position?: number }> = []
  const rallyTimes: Array<{ user_id: string; time_seconds: number }> = []

  for (const p of participants || []) {
    if (!p.is_completed) continue

    let xp = baseXp
    const streak = p.user_xp?.current_streak || 0
    const lastDate = p.user_xp?.last_raid_date

    // Bonus: todos los checkpoints
    if (totalCheckpoints && p.checkpoints_taken >= totalCheckpoints) {
      xp += 50
    }

    // Bonus: primer raid del día
    if (!lastDate || lastDate < new Date().toISOString().slice(0, 10)) {
      xp += 20
    }

    // Multiplicador de racha
    if (streak >= 7) xp *= 3
    else if (streak >= 3) xp *= 2

    // Bonus nocturno (+15%)
    if (raid.is_night_raid) xp = Math.round(xp * 1.15)

    // Rally: guardar tiempo para clasificación
    if (raid.mode === 'rally') {
      rallyTimes.push({ user_id: p.user_id, time_seconds: p.time_seconds })
    }

    // Anti-cheat: si está flagged, retener XP
    if (p.is_flagged) {
      xp = 0
    }

    // Otorgar XP
    if (xp > 0) {
      await supabase.rpc('award_xp', { p_user_id: p.user_id, p_xp: xp })
      await supabase.from('raid_participants')
        .update({ xp_earned: xp })
        .eq('id', p.id)
    }

    // Actualizar km_traveled en user_xp
    if (p.km_traveled > 0) {
      await supabase.rpc('update_km_traveled', {
        p_user_id: p.user_id,
        p_km: p.km_traveled,
      })
    }

    totalXpDistributed += xp
    participantsCompleted++
    participantResults.push({ user_id: p.user_id, xp_earned: xp })
  }

  // 5. Rally: asignar posiciones por precisión ETA
  if (raid.mode === 'rally' && rallyTimes.length > 0 && raid.adjusted_eta) {
    const targetSeconds = Math.abs(
      new Date(raid.adjusted_eta).getTime() - new Date(raid.scheduled_at).getTime(),
    ) / 1000

    rallyTimes.sort((a, b) =>
      Math.abs(a.time_seconds - targetSeconds) - Math.abs(b.time_seconds - targetSeconds)
    )

    for (let i = 0; i < rallyTimes.length; i++) {
      await supabase.from('raid_participants')
        .update({ finished_position: i + 1 })
        .eq('raid_id', raid_id)
        .eq('user_id', rallyTimes[i].user_id)

      // Ganador recibe +50 XP extra
      if (i === 0) {
        await supabase.rpc('award_xp', { p_user_id: rallyTimes[i].user_id, p_xp: 50 })
      }
    }
  }

  // 6. Marcar raid como completado
  await supabase.from('raids').update({
    status: 'completed',
    updated_at: new Date().toISOString(),
  }).eq('id', raid_id)

  // 7. Generar snapshot de leaderboard
  await generateLeaderboardSnapshot(supabase, 'general')

  return new Response(JSON.stringify({
    completed: true,
    xp_distributed: totalXpDistributed,
    participants_completed: participantsCompleted,
  }), { status: 200 })
})

async function generateLeaderboardSnapshot(supabase: any, category: string) {
  const { data: rankings } = await supabase
    .from('user_xp')
    .select('user_id, total_xp')
    .gt('total_xp', 0)
    .order('total_xp', { ascending: false })
    .limit(100)

  if (!rankings) return

  const today = new Date().toISOString().slice(0, 10)
  const rows = rankings.map((r: any, i: number) => ({
    category,
    rank: i + 1,
    user_id: r.user_id,
    metric_value: r.total_xp,
    snapshot_date: today,
  }))

  for (const row of rows) {
    await supabase.from('leaderboard_snapshots').upsert(row, {
      onConflict: 'category,rank,snapshot_date',
    })
  }
}
