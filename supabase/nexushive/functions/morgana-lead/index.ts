// Recebe o formulário do site do Studio Morgana Silveira, grava o contato
// e avisa a Ana a cada novo pedido: por e-mail (Resend) e, se configurado, por WhatsApp (CallMeBot).
// Secrets: MORGANA_ALLOWED_ORIGINS, RESEND_API_KEY, AVISO_EMAIL, CALLMEBOT_PHONE, CALLMEBOT_APIKEY
import { createClient } from "npm:@supabase/supabase-js@2";

// schema fixo em public: o schema padrao da Data API deste projeto nao e public
const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { db: { schema: "public" } });
const allowed = (Deno.env.get("MORGANA_ALLOWED_ORIGINS") ?? "*").split(",").map((s) => s.trim());
const CMB_PHONE = (Deno.env.get("CALLMEBOT_PHONE") ?? "").replace(/\D/g, "");
const CMB_KEY = (Deno.env.get("CALLMEBOT_APIKEY") ?? "").trim();
const RESEND_KEY = (Deno.env.get("RESEND_API_KEY") ?? "").trim();
const AVISO_EMAIL = (Deno.env.get("AVISO_EMAIL") ?? "").trim();
const EMAIL_FROM = (Deno.env.get("AVISO_EMAIL_FROM") ?? "Site Morgana Silveira <onboarding@resend.dev>").trim();

function cors(origin: string | null) {
  const ok = allowed.includes("*") || (origin && allowed.includes(origin));
  return {
    "Access-Control-Allow-Origin": ok ? (origin ?? "*") : "null",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "content-type",
    "Vary": "Origin",
  };
}

function normPhone(raw: string): string | null {
  let d = (raw ?? "").replace(/\D/g, "");
  if (d.startsWith("00")) d = d.slice(2);
  if (d.length === 10 || d.length === 11) d = "55" + d;
  if (d.startsWith("55") && d.length === 12) d = d.slice(0, 4) + "9" + d.slice(4);
  if (d.length < 11 || d.length > 15) return null;
  return "+" + d;
}

const clean = (v: unknown, n = 120) => (typeof v === "string" ? v.trim().slice(0, n) : null);
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));

async function avisarEmail(assunto: string, linhas: [string, string][], wa: string) {
  if (!RESEND_KEY || !AVISO_EMAIL) { console.warn("email: RESEND_API_KEY ou AVISO_EMAIL ausente - aviso nao enviado"); return; }
  const html = `<div style="font-family:Arial,sans-serif;font-size:16px;line-height:1.5">
    <h2 style="margin:0 0 12px">Novo pedido pelo site</h2>
    ${linhas.map(([k, v]) => `<p style="margin:4px 0"><b>${esc(k)}:</b> ${esc(v)}</p>`).join("")}
    <p style="margin:20px 0"><a href="${wa}" style="background:#1F8A5B;color:#fff;padding:12px 20px;border-radius:8px;text-decoration:none;font-weight:bold">Responder no WhatsApp</a></p>
  </div>`;
  const text = linhas.map(([k, v]) => `${k}: ${v}`).join("\n") + `\n\nResponder: ${wa}`;
  try {
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST", signal: AbortSignal.timeout(10000),
      headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: EMAIL_FROM, to: [AVISO_EMAIL], subject: assunto, html, text }),
    });
    if (r.ok) console.log("email: enviado"); else console.error("email: falhou", r.status, (await r.text()).slice(0, 300));
  } catch (e) { console.error("email: erro de rede", String(e)); }
}

async function avisarWhatsApp(txt: string) {
  if (!CMB_PHONE || !CMB_KEY) return;
  const u = `https://api.callmebot.com/whatsapp.php?phone=${CMB_PHONE}&text=${encodeURIComponent(txt)}&apikey=${encodeURIComponent(CMB_KEY)}`;
  try {
    const r = await fetch(u, { signal: AbortSignal.timeout(10000) });
    const body = (await r.text()).replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").slice(0, 300);
    if (r.ok && !/error|invalid|not/i.test(body)) console.log("callmebot: enviado", r.status);
    else console.error("callmebot: falhou", r.status, body);
  } catch (e) { console.error("callmebot: erro de rede", String(e)); }
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  const h = { ...cors(origin), "Content-Type": "application/json" };
  if (req.method === "OPTIONS") return new Response(null, { headers: h });
  if (req.method !== "POST") return new Response('{"error":"method"}', { status: 405, headers: h });
  if (!allowed.includes("*") && (!origin || !allowed.includes(origin))) {
    return new Response('{"error":"origin"}', { status: 403, headers: h });
  }
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return new Response('{"error":"json"}', { status: 400, headers: h }); }
  if (b.website) return new Response('{"ok":true}', { headers: h });

  const tel = normPhone(String(b.telefone ?? ""));
  if (!tel) return new Response('{"error":"telefone"}', { status: 422, headers: h });

  const nome = clean(b.nome, 80);
  const servico = clean(b.servico);
  const periodo = clean(b.periodo, 40);
  const obs = clean(b.obs, 500);
  const consent = b.consentimento === true;
  const { error } = await sb.rpc("morgana_registrar_contato", {
    p_telefone: tel, p_nome: nome, p_origem: "site", p_canal: "site_form", p_servico: servico,
    p_conteudo: [servico, periodo, obs].filter(Boolean).join(" | "),
    p_consentimento: consent, p_consent_origem: consent ? "checkbox_site" : null,
    p_utm: typeof b.utm === "object" && b.utm ? b.utm : null,
    p_meta: { periodo, ua: req.headers.get("user-agent")?.slice(0, 200) },
  });
  if (error) {
    console.error(error);
    return new Response('{"error":"db"}', { status: 500, headers: h });
  }

  const wa = `https://wa.me/${tel.slice(1)}`;
  const linhas: [string, string][] = [
    ["Nome", nome ?? "-"], ["WhatsApp", tel], ["Serviço", servico ?? "-"], ["Período", periodo ?? "-"],
    ...(obs ? [["Obs", obs] as [string, string]] : []), ["Aceita promoções", consent ? "sim" : "não"],
  ];
  const msg = `Novo pedido pelo site 💅\n` + linhas.map(([k, v]) => `${k}: ${v}`).join("\n") + `\n${wa}`;
  await Promise.all([
    avisarEmail(`Novo pedido pelo site: ${servico ?? "serviço"} - ${nome ?? "cliente"}`, linhas, wa),
    avisarWhatsApp(msg),
  ]);

  return new Response('{"ok":true}', { headers: h });
});
