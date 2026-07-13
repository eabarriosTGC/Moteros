// Edge Function: suggest_motoposadas
// Calls suggest_motoposadas_for_route SQL function
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization')?.replace('Bearer ', '');
    if (!authHeader) return new Response('Unauthorized', { status: 401 });

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: `Bearer ${authHeader}` } } }
    );

    const url = new URL(req.url);
    const waypointsParam = url.searchParams.get('waypoints');
    const maxDistance = parseFloat(url.searchParams.get('maxDistance') || '20');

    if (!waypointsParam) {
      return new Response(JSON.stringify({ error: 'waypoints query param requerido' }), { status: 400 });
    }

    let waypoints;
    try {
      waypoints = JSON.parse(waypointsParam);
    } catch {
      return new Response(JSON.stringify({ error: 'waypoints debe ser JSON válido' }), { status: 400 });
    }

    const { data, error } = await supabase.rpc('suggest_motoposadas_for_route', {
      p_waypoints: waypoints,
      p_max_distance_km: maxDistance,
    });

    if (error) throw error;

    return new Response(JSON.stringify({ suggestions: data || [] }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 });
  }
});
