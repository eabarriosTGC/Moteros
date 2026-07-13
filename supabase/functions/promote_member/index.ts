// Edge Function: promote_member
// Validates rank requirements and promotes a club member
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

interface PromoteRequest {
  clubId: number;
  memberId: string;
  targetRankId: number;
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

    const { data: { user }, error: userError } = await supabase.auth.getUser(authHeader);
    if (userError || !user) return new Response('Unauthorized', { status: 401 });

    const { clubId, memberId, targetRankId }: PromoteRequest = await req.json();
    if (!clubId || !memberId || !targetRankId) {
      return new Response(JSON.stringify({ error: 'Missing fields' }), { status: 400 });
    }

    // Prevent self-promotion
    if (memberId === user.id) {
      return new Response(JSON.stringify({ error: 'No puedes promoverte a ti mismo' }), { status: 403 });
    }

    // Check caller is presidente or oficial
    const { data: callerMembership } = await supabase
      .from('club_members')
      .select('role')
      .eq('club_id', clubId)
      .eq('user_id', user.id)
      .single();

    if (!callerMembership || !['presidente', 'oficial'].includes(callerMembership.role)) {
      return new Response(JSON.stringify({ error: 'No tienes permiso para promover' }), { status: 403 });
    }

    // Check target rank exists
    const { data: targetRank } = await supabase
      .from('club_ranks')
      .select('*')
      .eq('id', targetRankId)
      .eq('club_id', clubId)
      .single();

    if (!targetRank) {
      return new Response(JSON.stringify({ error: 'Rango no encontrado' }), { status: 404 });
    }

    // Check max slots
    if (targetRank.max_slots) {
      const { count } = await supabase
        .from('club_members')
        .select('*', { count: 'exact', head: true })
        .eq('club_id', clubId)
        .eq('rank_id', targetRankId);

      if (count && count >= targetRank.max_slots) {
        return new Response(JSON.stringify({ error: 'El rango ha alcanzado su límite de miembros' }), { status: 400 });
      }
    }

    // Check rank requirements
    const requirements = targetRank.requirements as Record<string, number>;
    if (requirements && Object.keys(requirements).length > 0) {
      const { data: memberMileage } = await supabase
        .from('user_mileage')
        .select('total_km')
        .eq('user_id', memberId)
        .maybeSingle();

      const { data: memberXp } = await supabase
        .from('user_xp')
        .select('total_xp')
        .eq('user_id', memberId)
        .maybeSingle();

      const { data: memberChallenges } = await supabase
        .from('club_challenge_progress')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', memberId)
        .eq('completed', true);

      const kmMet = !requirements.min_km || (memberMileage?.total_km ?? 0) >= requirements.min_km;
      const xpMet = !requirements.min_puntos || (memberXp?.total_xp ?? 0) >= requirements.min_puntos;
      const challengesMet = !requirements.min_challenges || (memberChallenges?.count ?? 0) >= requirements.min_challenges;

      if (!kmMet || !xpMet || !challengesMet) {
        const missing: string[] = [];
        if (!kmMet) missing.push(`min_km: ${requirements.min_km}`);
        if (!xpMet) missing.push(`min_puntos: ${requirements.min_puntos}`);
        if (!challengesMet) missing.push(`min_challenges: ${requirements.min_challenges}`);
        return new Response(JSON.stringify({ error: `Requisitos no cumplidos: ${missing.join(', ')}` }), { status: 400 });
      }
    }

    // Execute promotion
    const { error: updateError } = await supabase
      .from('club_members')
      .update({
        rank_id: targetRankId,
        role: targetRank.name,
        promoted_at: new Date().toISOString(),
        promoted_by: user.id,
      })
      .eq('club_id', clubId)
      .eq('user_id', memberId);

    if (updateError) throw updateError;

    return new Response(JSON.stringify({ success: true, promotedTo: targetRank.name }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 });
  }
});
