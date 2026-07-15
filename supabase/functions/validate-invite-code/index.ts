import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async (req: Request) => {
  try {
    const authHeader = req.headers.get("Authorization")!;
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { code } = await req.json();
    if (!code || typeof code !== "string") {
      return new Response(JSON.stringify({ error: "Código requerido" }), { status: 400 });
    }

    const upper = code.toUpperCase().trim();

    // Find club by join_code
    const { data: club, error } = await supabase
      .from("clubs")
      .select("id, name, club_rank")
      .eq("join_code", upper)
      .maybeSingle();

    if (error || !club) {
      return new Response(JSON.stringify({ valid: false, error: "Código inválido" }), { status: 200 });
    }

    return new Response(JSON.stringify({
      valid: true,
      club_id: club.id,
      club_name: club.name,
      club_rank: club.club_rank,
    }), { status: 200 });

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
