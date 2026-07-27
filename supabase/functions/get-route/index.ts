// Edge Function: get-route
// =====================================================================
// Proxies routing requests from the Flutter app to GraphHopper.
// Features:
//   - JWT authentication (reuses Supabase Auth)
//   - Route caching in route_cache table (avoids hitting GH for same routes)
//   - Motorcycle profile by default
//   - Returns polyline + turn-by-turn instructions
//
// Environment variables needed:
//   GRAPHOPPER_URL — URL of your self-hosted GraphHopper instance
//     e.g. https://graphhopper.railway.app
// =====================================================================

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

interface RouteRequest {
  origin: { lat: number; lng: number };
  destination: { lat: number; lng: number };
  waypoints?: Array<{ lat: number; lng: number }>;
  profile?: string;
  instructions?: boolean;
}

interface RouteResponse {
  polyline: Array<[number, number]>;
  distanceKm: number;
  durationMin: number;
  ascend: number;
  descend: number;
  instructions?: Array<{
    distance: number;
    time: number;
    text: string;
    sign: number;
    interval: [number, number];
  }>;
}

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // ── Auth check ──
    const authHeader = req.headers.get('Authorization')?.replace('Bearer ', '');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: `Bearer ${authHeader}` } } },
    );

    // Verify the token by getting the user
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ── Parse request ──
    const body: RouteRequest = await req.json();

    if (!body.origin || !body.destination) {
      return new Response(JSON.stringify({ error: 'origin and destination are required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const profile = body.profile || 'motorcycle';
    const includeInstructions = body.instructions !== false;

    // Build cache key from origin/destination/waypoints/profile
    const cacheKey = [
      `${body.origin.lat.toFixed(5)},${body.origin.lng.toFixed(5)}`,
      `${body.destination.lat.toFixed(5)},${body.destination.lng.toFixed(5)}`,
      profile,
    ].join('|');

    // ── Check cache ──
    const { data: cached } = await supabase
      .from('route_cache')
      .select('result')
      .eq('cache_key', cacheKey)
      .gte('created_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
      .maybeSingle();

    if (cached) {
      return new Response(JSON.stringify(cached.result), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ── Build GraphHopper request ──
    const graphhopperUrl = Deno.env.get('GRAPHOPPER_URL');
    if (!graphhopperUrl) {
      return new Response(JSON.stringify({ error: 'GraphHopper not configured' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Build points array: [lng, lat] format for GraphHopper
    const points: Array<[number, number]> = [
      [body.origin.lng, body.origin.lat],
    ];
    if (body.waypoints) {
      for (const wp of body.waypoints) {
        points.push([wp.lng, wp.lat]);
      }
    }
    points.push([body.destination.lng, body.destination.lat]);

    const ghResponse = await fetch(`${graphhopperUrl}/route`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        points,
        profile,
        instructions: includeInstructions,
        elevation: false,
        locale: 'es',
      }),
    });

    if (!ghResponse.ok) {
      const errText = await ghResponse.text();
      console.error('GraphHopper error:', ghResponse.status, errText);
      return new Response(JSON.stringify({ error: 'Routing service error' }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const ghData = await ghResponse.json();

    if (!ghData.paths || ghData.paths.length === 0) {
      return new Response(JSON.stringify({ error: 'No route found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const path = ghData.paths[0];

    // ── Decode polyline ──
    // GraphHopper returns encoded polyline (Google Polyline format)
    const polylineStr = path.points;
    const decodedPolyline = decodePolyline(polylineStr);

    // ── Build response ──
    const result: RouteResponse = {
      polyline: decodedPolyline,
      distanceKm: Math.round(path.distance / 10) / 100, // meters → km, 2 decimals
      durationMin: Math.round(path.time / 60000 * 10) / 10, // ms → min, 1 decimal
      ascend: path.ascend || 0,
      descend: path.descend || 0,
    };

    if (includeInstructions && path.instructions) {
      result.instructions = path.instructions.map((inst: any) => ({
        distance: inst.distance,
        time: inst.time,
        text: inst.text,
        sign: inst.sign,
        interval: inst.interval,
      }));
    }

    // ── Cache result (fire-and-forget) ──
    supabase.from('route_cache').insert({
      cache_key: cacheKey,
      origin: body.origin,
      destination: body.destination,
      profile,
      result,
      created_at: new Date().toISOString(),
    }).then(() => {}).catch(() => {});

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('get-route error:', e);
    return new Response(JSON.stringify({ error: e.message || 'Internal error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});

// ── Google Polyline decoder ──
// Decodes an encoded polyline string to an array of [lat, lng] pairs.
function decodePolyline(encoded: string): Array<[number, number]> {
  const points: Array<[number, number]> = [];
  let index = 0;
  let lat = 0;
  let lng = 0;

  while (index < encoded.length) {
    let shift = 0;
    let result = 0;
    let byte: number;

    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);

    const dLat = (result & 1) ? ~(result >> 1) : (result >> 1);
    lat += dLat;

    shift = 0;
    result = 0;

    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);

    const dLng = (result & 1) ? ~(result >> 1) : (result >> 1);
    lng += dLng;

    points.push([lat * 1e-5, lng * 1e-5]);
  }

  return points;
}
