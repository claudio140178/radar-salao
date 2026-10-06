// Contador anônimo de visitas e cliques no WhatsApp do site do Studio Morgana Silveira.
// Recebe sendBeacon (text/plain) para não exigir preflight CORS. Não guarda IP nem dados pessoais.
import { createClient } from "npm:@supabase/supabase-js@2";

// schema fixo em public: o schema padrao da Data API deste projeto nao e public
const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { db: { schema: "public" } });
const allowed = (Deno.env.get("MORGANA_ALLOWED_ORIGINS") ?? "*").split(",").map((s) => s.trim());
const EVENTOS = new Set(["visita", "whatsapp", "formulario"]);
const clean = (v: unknown, n: number) => (typeof v === "string" ? v.replace(/[^\w\-\/#áéíóúãõç ]/gi, "").slice(0, n) : null);

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  const ok = allowed.includes("*") || (origin !== null && allowed.includes(origin));
  const h = { "Access-Control-Allow-Origin": ok ? (origin ?? "*") : "null", "Access-Control-Allow-Methods": "POST, OPTIONS", "Access-Control-Allow-Headers": "content-type", "Vary": "Origin" };
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: h });
  if (req.method !== "POST") return new Response(null, { status: 405, headers: h });
  if (!ok) return new Response(null, { status: 403, headers: h });
  try {
    const b = JSON.parse((await req.text()).slice(0, 500));
    if (!EVENTOS.has(b.evento)) return new Response(null, { status: 422, headers: h });
    const { error } = await sb.from("morgana_cliques").insert({ evento: b.evento, origem: clean(b.origem, 40), pagina: clean(b.pagina, 120) });
    if (error) console.error(error);
  } catch { return new Response(null, { status: 400, headers: h }); }
  return new Response(null, { status: 204, headers: h });
});
