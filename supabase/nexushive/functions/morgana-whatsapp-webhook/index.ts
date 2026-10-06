// Webhook de mensagens recebidas no WhatsApp do Studio Morgana Silveira.
// Aceita: (1) WhatsApp Cloud API oficial (Meta) e (2) payload genérico de outro provedor/OpenWA.
// Secrets: WA_VERIFY_TOKEN, WA_APP_SECRET (Meta) e MORGANA_WEBHOOK_SECRET (genérico).
import { createClient } from "npm:@supabase/supabase-js@2";

// schema fixo em public: o schema padrao da Data API deste projeto nao e public
const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { db: { schema: "public" } });
const VERIFY = Deno.env.get("WA_VERIFY_TOKEN") ?? "";
const APP_SECRET = Deno.env.get("WA_APP_SECRET") ?? "";
const GENERIC = Deno.env.get("MORGANA_WEBHOOK_SECRET") ?? "";

const OPT_OUT = /^\s*(sair|parar|stop|cancelar|descadastrar)\s*$/i;
const OPT_IN = /^\s*novidades\s*$/i;

function normPhone(raw: string): string | null {
  let d = (raw ?? "").replace(/\D/g, "");
  if (d.length === 10 || d.length === 11) d = "55" + d;
  if (d.startsWith("55") && d.length === 12) d = d.slice(0, 4) + "9" + d.slice(4);
  if (d.length < 11 || d.length > 15) return null;
  return "+" + d;
}

async function hmacOk(body: string, sig: string | null) {
  if (!APP_SECRET || !sig?.startsWith("sha256=")) return false;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(APP_SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body)));
  const hex = [...mac].map((b) => b.toString(16).padStart(2, "0")).join("");
  const exp = sig.slice(7);
  if (hex.length !== exp.length) return false;
  let r = 0; for (let i = 0; i < hex.length; i++) r |= hex.charCodeAt(i) ^ exp.charCodeAt(i);
  return r === 0;
}

async function registrar(tel: string, nome: string | null, texto: string, meta: unknown) {
  const optIn = OPT_IN.test(texto);
  await sb.rpc("morgana_registrar_contato", {
    p_telefone: tel, p_nome: nome, p_origem: "whatsapp", p_canal: "whatsapp_in",
    p_conteudo: texto, p_consentimento: optIn ? true : null,
    p_consent_origem: optIn ? "palavra_NOVIDADES" : null, p_meta: meta,
  });
  if (OPT_OUT.test(texto)) await sb.rpc("morgana_opt_out", { p_telefone: tel });
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  // Verificação do webhook da Meta
  if (req.method === "GET") {
    if (VERIFY && url.searchParams.get("hub.mode") === "subscribe" && url.searchParams.get("hub.verify_token") === VERIFY) {
      return new Response(url.searchParams.get("hub.challenge") ?? "", { status: 200 });
    }
    return new Response("forbidden", { status: 403 });
  }
  if (req.method !== "POST") return new Response("method", { status: 405 });
  const raw = await req.text();

  // (2) Genérico: header x-morgana-secret + {telefone, nome, mensagem}
  const gs = req.headers.get("x-morgana-secret");
  if (gs) {
    if (!GENERIC || gs !== GENERIC) return new Response("unauthorized", { status: 401 });
    try {
      const b = JSON.parse(raw);
      const tel = normPhone(String(b.telefone ?? b.from ?? ""));
      if (!tel) return new Response('{"error":"telefone"}', { status: 422 });
      await registrar(tel, b.nome ?? null, String(b.mensagem ?? b.body ?? "").slice(0, 2000), { provedor: "generico" });
      return new Response('{"ok":true}');
    } catch { return new Response('{"error":"json"}', { status: 400 }); }
  }

  // (1) Meta Cloud API
  if (!(await hmacOk(raw, req.headers.get("x-hub-signature-256")))) return new Response("unauthorized", { status: 401 });
  try {
    const b = JSON.parse(raw);
    for (const e of b.entry ?? []) for (const ch of e.changes ?? []) {
      const v = ch.value ?? {};
      const nomes: Record<string, string> = {};
      for (const c of v.contacts ?? []) nomes[c.wa_id] = c.profile?.name;
      for (const m of v.messages ?? []) {
        const tel = normPhone(m.from);
        if (!tel) continue;
        const texto = m.text?.body ?? m.button?.text ?? m.interactive?.button_reply?.title ?? `[${m.type}]`;
        await registrar(tel, nomes[m.from] ?? null, texto, { provedor: "meta", msg_id: m.id, tipo: m.type });
      }
    }
  } catch (err) { console.error(err); }
  return new Response("ok"); // sempre 200 para a Meta não reenviar
});
