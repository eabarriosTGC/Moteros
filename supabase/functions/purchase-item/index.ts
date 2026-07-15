// supabase/functions/purchase-item/index.ts
// Compra un item de la tienda con coins del usuario.
// Verifica si es battle_pass_only y si el usuario tiene BP premium.
//
// Deploy: supabase functions deploy purchase-item --project-ref <ref>

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface PurchaseRequest {
  item_id: string
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

  const { item_id }: PurchaseRequest = await req.json()
  if (!item_id) {
    return new Response(JSON.stringify({ error: 'item_id es requerido' }), { status: 400 })
  }

  // 1. Obtener item de shop_items
  const { data: item, error: itemError } = await supabase
    .from('shop_items')
    .select('*')
    .eq('id', item_id)
    .single()

  if (itemError || !item) {
    return new Response(JSON.stringify({ error: 'Item no encontrado' }), { status: 404 })
  }

  if (!item.is_active) {
    return new Response(JSON.stringify({ error: 'Item no disponible' }), { status: 400 })
  }

  // 2. Si es battle_pass_only, verificar BP premium activo
  if (item.battle_pass_only) {
    const { data: bpProgress } = await supabase
      .from('battle_pass_progress')
      .select('has_premium')
      .eq('user_id', user.id)
      .maybeSingle()

    if (!bpProgress || !bpProgress.has_premium) {
      return new Response(JSON.stringify({
        error: 'Este item requiere Battle Pass premium activo',
      }), { status: 403 })
    }
  }

  // 3. Verificar y gastar coins
  const { data: spendResult, error: spendError } = await supabase.rpc('spend_coins', {
    p_user_id: user.id,
    p_amount: item.coins_cost,
  })

  if (spendError || !spendResult?.success) {
    return new Response(JSON.stringify({
      error: spendResult?.error || 'No tienes suficientes coins',
    }), { status: 400 })
  }

  // 4. Insertar en user_purchases
  const { error: purchaseError } = await supabase
    .from('user_purchases')
    .insert({
      user_id: user.id,
      item_id: item.id,
    })

  if (purchaseError) {
    throw purchaseError
  }

  return new Response(JSON.stringify({
    success: true,
    item: {
      id: item.id,
      name: item.name,
      description: item.description,
      item_type: item.item_type,
      image_url: item.image_url,
    },
    coins_remaining: spendResult.coins_remaining,
  }), {
    headers: { 'Content-Type': 'application/json' },
    status: 200,
  })
})
