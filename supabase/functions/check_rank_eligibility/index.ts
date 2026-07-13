// Edge Function: check_rank_eligibility
// Checks if a member meets requirements for available ranks
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

interface CheckRequest {
  clubId: number;
  memberId: string;
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

    const { clubId, memberId }: CheckRequest = await req.json();
    if (!clubId || !memberId) {
      return new Response(JSON.stringify({ error: 'Missing fields' }), { status: 400 });
    }

    // Get current member info
    const { data: member } = await supabase
      .from('club_members')
      .select('*')
      .eq('club_id', clubId)
      .eq('user_id', memberId)
      .single();

    if (!member) {
      return new Response(JSON.stringify({ error: 'Miembro no encontrado' }), { status: 404 });
    }

    // Get all ranks for the club
    const { data: ranks } = await supabase
      .from('club_ranks')
      .select('*')
      .eq('club_id', clubId)
      .order('level', { ascending: false });

    if (!ranks) return new Response(JSON.stringify({ eligibleRanks: [] }), { headers: { 'Content-Type': 'application/json' } });

    // Get member stats
    const { data: mileage } = await supabase
      .from('user_mileage')
      .select('total_km')
      .eq('user_id', memberId)
      .maybeSingle();

    const { data: xp } = await supabase
      .from('user_xp')
      .select('total_xp')
      .eq('user_id', memberId)
      .maybeSingle();

    const { count: challengeCount } = await supabase
      .from('club_challenge_progress')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', memberId)
      .eq('completed', true);

    const eligibleRanks = ranks
      .filter((rank) => {
        if (rank.is_leader && member.role === 'presidente') return false; // Don't suggest presidente rank
        const reqs = rank.requirements as Record<string, number>;
        if (!reqs || Object.keys(reqs).length === 0) return true;
        const totalKm = mileage?.total_km ?? 0;
        const totalXp = xp?.total_xp ?? 0;
        const completedChallenges = challengeCount ?? 0;
        return (
          (!reqs.min_km || totalKm >= reqs.min_km) &&
          (!reqs.min_puntos || totalXp >= reqs.min_puntos) &&
          (!reqs.min_challenges || completedChallenges >= reqs.min_challenges)
        );
      })
      .map((rank) => ({
        id: rank.id,
        name: rank.name,
        level: rank.level,
        requirements: rank.requirements,
        maxSlots: rank.max_slots,
      }));

    return new Response(JSON.stringify({ eligibleRanks, currentRole: member.role }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 });
  }
});
