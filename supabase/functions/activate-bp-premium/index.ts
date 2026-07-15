// supabase/functions/activate-bp-premium/index.ts
// Activa el premium de un Battle Pass: cobra 500 coins,
// marca has_premium = true en battle_pass_progress.
//
// Deploy: supabase functions deploy activate-bp-premium --project-ref <ref>

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface ActivatePremiumRequest {
  battle_pass_id: string
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

  const { battle_pass_id }: ActivatePremiumRequest = await req.json()
  if (!battle_pass_id) {
    return new Response(JSON.stringify({ error: 'battle_pass_id es requerido' }), { status: 400 })
  }

  // 1. Verificar que battle_pass está activo
  const { data: bp, error: bpError } = await supabase
    .from('battle_passes')
    .select('*')
    .eq('id', battle_pass_id)
    .single()

  if (bpError || !bp) {
    return new Response(JSON.stringify({ error: 'Battle Pass no encontrado' }), { status: 404 })
  }

  if (!bp.is_active) {
    return new Response(JSON.stringify({ error: 'Este Battle Pass no está activo' }), { status: 400 })
  }

  // 2. Costo: 500 coins via spend_coins
  const { data: spendResult, error: spendError } = await supabase.rpc('spend_coins', {
    p_user_id: user.id,
    p_amount: 500,
  })

  if (spendError || !spendResult?.success) {
    return new Response(JSON.stringify({
      error: spendResult?.error || 'No tienes suficientes coins (cuestan 500)',
    }), { status: 400 })
  }

  // 3. Actualizar o insertar battle_pass_progress.has_premium = true
  const { data: existingProgress } = await supabase
    .from('battle_pass_progress')
    .select('*')
    .eq('user_id', user.id)
    .eq('battle_pass_id', battle_pass_id)
    .maybeSingle()

  if (existingProgress) {
    const { error: updateError } = await supabase
      .from('battle_pass_progress')
      .update({ has_premium: true })
      .eq('id', existingProgress.id)

    if (updateError) throw updateError
  } else {
    const { error: insertError } = await supabase
      .from('battle_pass_progress')
      .insert({
        user_id: user.id,
        battle_pass_id: battle_pass_id,
        has_premium: true,
        xp_in_season: 0,
        current_tier: 1,
      })

    if (insertError) throw insertError
  }

  return new Response(JSON.stringify({
    success: true,
    has_premium: true,
  }), {
    headers: { 'Content-Type': 'application/json' },
    status: 200,
  })
})
