// Edge Function: create_route_with_motoposadas
// Creates a route with auto-included nearby motoposadas
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

interface CreateRouteRequest {
  title: string;
  description?: string;
  waypoints: Array<{ lat: number; lng: number; name?: string; stop_type?: string; duration_min?: number }>;
  difficulty?: string;
  isPublic?: boolean;
  tags?: string[];
  coverImageUrl?: string;
}

serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization')?.replace('Bearer ', '');
    if (!authHeader) return new Response('Unauthorized', { status: 401 });

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: `Bearer ${authHeader}` } } }
    );

    const { data: { user } } = await supabase.auth.getUser(authHeader);
    if (!user) return new Response('Unauthorized', { status: 401 });

    // Rate limit: max 5 routes/day per user
    const today = new Date().toISOString().split('T')[0];
    const { count: todayCount } = await supabase
      .from('routes')
      .select('*', { count: 'exact', head: true })
      .eq('created_by', user.id)
      .gte('created_at', today);

    if (todayCount && todayCount >= 5) {
      return new Response(JSON.stringify({ error: 'Límite diario de rutas alcanzado (5/día)' }), { status: 429 });
    }

    const data: CreateRouteRequest = await req.json();
    if (!data.title || !data.waypoints || data.waypoints.length === 0) {
      return new Response(JSON.stringify({ error: 'Título y waypoints requeridos' }), { status: 400 });
    }

    if (data.waypoints.length > 20) {
      return new Response(JSON.stringify({ error: 'Máximo 20 waypoints' }), { status: 400 });
    }

    // Calculate total KM using Haversine between consecutive waypoints
    let totalKm = 0;
    for (let i = 1; i < data.waypoints.length; i++) {
      const { data: dist } = await supabase.rpc('haversine_distance', {
        lat1: data.waypoints[i - 1].lat,
        lng1: data.waypoints[i - 1].lng,
        lat2: data.waypoints[i].lat,
        lng2: data.waypoints[i].lng,
      });
      totalKm += (dist as number || 0) / 1000;
    }

    // Create route with waypoints
    const waypointsJson = data.waypoints.map((wp, i) => ({
      lat: wp.lat,
      lng: wp.lng,
      name: wp.name || `Punto ${i + 1}`,
      stop_type: wp.stop_type || 'paso',
      duration_min: wp.duration_min || 0,
    }));

    const { data: route, error: routeError } = await supabase
      .from('routes')
      .insert({
        created_by: user.id,
        title: data.title,
        description: data.description || '',
        waypoints: waypointsJson,
        total_km: Math.round(totalKm * 100) / 100,
        est_duration_min: Math.round(totalKm / 0.8), // ~48 km/h avg
        difficulty: data.difficulty || 'medio',
        is_public: data.isPublic ?? true,
        tags: data.tags || [],
        cover_image_url: data.coverImageUrl,
      })
      .select()
      .single();

    if (routeError) throw routeError;

    // Create route segments
    const segments = [];
    for (let i = 1; i < data.waypoints.length; i++) {
      const { data: segDist } = await supabase.rpc('haversine_distance', {
        lat1: data.waypoints[i - 1].lat,
        lng1: data.waypoints[i - 1].lng,
        lat2: data.waypoints[i].lat,
        lng2: data.waypoints[i].lng,
      });
      segments.push({
        route_id: route.id,
        segment_order: i - 1,
        from_waypoint_index: i - 1,
        to_waypoint_index: i,
        segment_km: Math.round(((segDist as number || 0) / 1000) * 100) / 100,
        est_duration_min: Math.round(((segDist as number || 0) / 1000) / 0.8),
        polyline: [],
        road_type: 'desconocida',
      });
    }

    if (segments.length > 0) {
      const { error: segError } = await supabase.from('route_segments').insert(segments);
      if (segError) throw segError;
    }

    return new Response(JSON.stringify({ success: true, route }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 });
  }
});
