// Edge Function: refresh_leaderboard
// Cron-triggered: daily snapshot of leaderboard data
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

serve(async (_req) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Call the refresh function
    const { error } = await supabase.rpc('refresh_leaderboard_snapshot');
    if (error) throw error;

    return new Response(JSON.stringify({ success: true, refreshedAt: new Date().toISOString() }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 });
  }
});
