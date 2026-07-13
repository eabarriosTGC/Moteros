// Edge Function: verify_mileage
// Admin verifies or rejects a manual mileage entry
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

interface VerifyRequest {
  entryId: number;
  verified: boolean;
  rejectionReason?: string;
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

    // Check admin status
    const { data: adminUser } = await supabase
      .from('users')
      .select('raw_user_meta_data')
      .eq('id', user.id)
      .single();

    if (!adminUser || adminUser.raw_user_meta_data?.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Solo administradores' }), { status: 403 });
    }

    const { entryId, verified, rejectionReason }: VerifyRequest = await req.json();
    if (!entryId) {
      return new Response(JSON.stringify({ error: 'entryId requerido' }), { status: 400 });
    }

    if (verified) {
      const { error } = await supabase
        .from('mileage_manual_entries')
        .update({
          is_verified: true,
          verified_by: user.id,
          verified_at: new Date().toISOString(),
          rejection_reason: null,
        })
        .eq('id', entryId);

      if (error) throw error;
    } else {
      const { error } = await supabase
        .from('mileage_manual_entries')
        .update({
          is_verified: false,
          verified_by: user.id,
          verified_at: new Date().toISOString(),
          rejection_reason: rejectionReason || 'Rechazado por administrador',
        })
        .eq('id', entryId);

      if (error) throw error;
    }

    return new Response(JSON.stringify({ success: true, verified }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 });
  }
});
