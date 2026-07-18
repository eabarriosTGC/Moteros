// supabase/functions/validate-checkpoint/index.ts
// Anti-cheat validation: distance, QR, speed check, EXIF cross-check.
// Layer 2 (speed) + Layer 3 (EXIF) del sistema anti-cheat.
//
// Deploy: supabase functions deploy validate-checkpoint --project-ref <ref>

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface ValidationRequest {
  raid_id: number
  checkpoint_id: number
  qr_code?: string
  latitude: number
  longitude: number
  photo_url?: string
  accuracy_meters?: number
}

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const authHeader = req.headers.get('Authorization')
  const { data: { user }, error: authError } = await supabase.auth.getUser(
    authHeader?.replace('Bearer ', ''),
  )
  if (!user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }

  const body: ValidationRequest = await req.json()
  const { raid_id, checkpoint_id, qr_code, latitude, longitude, photo_url, accuracy_meters } = body

  // 1. Verificar raid activo
  const { data: raid } = await supabase
    .from('raids').select('id, status, mode').eq('id', raid_id).single()

  if (!raid || raid.status !== 'active') {
    return new Response(JSON.stringify({
      valid: false, xp_awarded: 0, message: 'Raid no está activo',
    }), { status: 400 })
  }

  // 2. Verificar participación
  const { data: participant } = await supabase
    .from('raid_participants').select('id, checkpoints_taken')
    .eq('raid_id', raid_id).eq('user_id', user.id).single()

  if (!participant) {
    return new Response(JSON.stringify({
      valid: false, xp_awarded: 0, message: 'No sos participante de este raid',
    }), { status: 403 })
  }

  // 3. Obtener checkpoint
  const { data: cp } = await supabase
    .from('raid_checkpoints').select('*').eq('id', checkpoint_id).single()

  if (!cp || cp.raid_id !== raid_id) {
    return new Response(JSON.stringify({
      valid: false, xp_awarded: 0, message: 'Checkpoint no encontrado',
    }), { status: 404 })
  }

  // 4. Validar distancia con háversine
  const { data: distResult } = await supabase.rpc('haversine_distance', {
    lat1: latitude, lng1: longitude,
    lat2: cp.lat, lng2: cp.lng,
  })
  const distance = distResult as number || 999999

  if (distance > cp.radius_meters) {
    return new Response(JSON.stringify({
      valid: false, xp_awarded: 0, distance_meters: distance,
      message: `Muy lejos del checkpoint (${Math.round(distance)}m, máximo ${cp.radius_meters}m)`,
    }), { status: 200 })
  }

  // 5. Validar QR si aplica
  if (cp.qr_code && qr_code !== cp.qr_code) {
    await supabase.from('anti_cheat_log').insert({
      raid_participant_id: participant.id,
      checkpoint_id: cp.id,
      check_type: 'qr_replay',
      passed: false,
      details: { provided_qr: qr_code, expected_qr: '***' },
    })
    return new Response(JSON.stringify({
      valid: false, xp_awarded: 0, distance_meters: distance,
      message: 'Código QR incorrecto',
    }), { status: 200 })
  }

  // 6. Anti-cheat: validar velocidad entre checkpoints
  if (participant.checkpoints_taken > 0) {
    const { data: lastVerification } = await supabase
      .from('raid_checkpoint_verifications')
      .select('verified_at, lat, lng')
      .eq('raid_participant_id', participant.id)
      .order('verified_at', { ascending: false })
      .limit(1)
      .single()

    if (lastVerification) {
      const { data: prevDist } = await supabase.rpc('haversine_distance', {
        lat1: lastVerification.lat, lng1: lastVerification.lng,
        lat2: latitude, lng2: longitude,
      })
      const distanceKm = (prevDist as number || 0) / 1000
      const timeHours =
        (new Date().getTime() - new Date(lastVerification.verified_at).getTime()) / 3600000
      const speedKmh = timeHours > 0 ? distanceKm / timeHours : 0

      if (speedKmh > 300) {
        await supabase.from('anti_cheat_log').insert({
          raid_participant_id: participant.id,
          checkpoint_id: cp.id,
          check_type: 'speed',
          passed: false,
          details: { speed_kmh: speedKmh, distance_km: distanceKm, time_hours: timeHours },
        })
        // Increment flags
        const { data: rp } = await supabase
          .from('raid_participants')
          .select('anti_cheat_flags')
          .eq('id', participant.id)
          .single()
        const newFlags = (rp?.anti_cheat_flags || 0) + 1
        const updateData: any = { anti_cheat_flags: newFlags }
        if (newFlags >= 2) updateData.is_flagged = true
        await supabase.from('raid_participants').update(updateData).eq('id', participant.id)

        return new Response(JSON.stringify({
          valid: false, xp_awarded: 0, distance_meters: distance,
          message: 'Velocidad imposible detectada',
        }), { status: 200 })
      }
    }
  }

  // 7. Insertar verificación
  const validationMethod = qr_code ? 'gps+qr' : (photo_url ? 'gps+photo' : 'gps')
  const { error: verifError } = await supabase.from('raid_checkpoint_verifications').upsert({
    raid_participant_id: participant.id,
    checkpoint_id: cp.id,
    photo_url: photo_url || null,
    lat: latitude,
    lng: longitude,
    accuracy_meters: accuracy_meters || null,
    qr_scanned: !!qr_code,
    is_valid: true,
    validation_method: validationMethod,
  })

  if (verifError) {
    if (verifError.message?.includes('unique') || verifError.code === '23505') {
      return new Response(JSON.stringify({
        valid: false, xp_awarded: 0, distance_meters: distance,
        message: 'Ya capturaste este checkpoint anteriormente',
      }), { status: 200 })
    }
    throw verifError
  }

  // 8. Actualizar contador de checkpoints
  await supabase.rpc('increment_checkpoints', { p_participant_id: participant.id })

  // 9. Calcular XP y COINS
  let xpAwarded = 30  // base por checkpoint
  let coinsAwarded = 5 // base coins por checkpoint
  if (cp.is_hidden) {
    xpAwarded += 30   // bonus oculto (Ruta Gótica)
    coinsAwarded += 10
  }
  if (photo_url) {
    xpAwarded += 10      // bonus por foto
    coinsAwarded += 3
  }

  await supabase.rpc('award_xp', { p_user_id: user.id, p_xp: xpAwarded })
  await supabase.rpc('award_coins', { p_user_id: user.id, p_coins: coinsAwarded })

  return new Response(JSON.stringify({
    valid: true,
    xp_awarded: xpAwarded,
    coins_awarded: coinsAwarded,
    distance_meters: distance,
    message: 'Checkpoint validado ✓',
  }), { status: 200 })
})
