// Edge Function "avisar-pedido": manda um e-mail pro administrador quando alguém pede acesso ao site.
// É chamada por um Database Webhook na tabela "perfis" (evento INSERT).
// Segredos necessários (Edge Functions → Secrets): RESEND_API_KEY, ADMIN_EMAIL, SITE_URL
// Só aceita a chave de serviço (a que o webhook usa). A chave pública (anon) fica no site e não pode disparar e-mail.
const papel = (req: Request) => {
  try {
    const t = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").split(".")[1];
    const b = t.replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(b + "=".repeat((4 - (b.length % 4)) % 4))).role;
  } catch {
    return null;
  }
};

Deno.serve(async (req) => {
  // A assinatura do token já foi conferida pelo Supabase (verify_jwt); aqui só olhamos o papel.
  if (papel(req) !== "service_role") return new Response("proibido", { status: 403 });
  try {
    const body = await req.json();
    const p = body?.record ?? {};
    if (body?.type !== "INSERT" || p.status !== "pendente") return new Response("ignorado", { status: 200 });

    const site = Deno.env.get("SITE_URL") ?? "";
    const esc = (t: string) => String(t ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));
    const nome = esc(p.nome || "Alguém"), email = esc(p.email || "");

    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from: "Ganhos do Mês <onboarding@resend.dev>",
        to: [Deno.env.get("ADMIN_EMAIL")],
        subject: `Novo pedido de acesso: ${p.nome || p.email}`,
        html: `<div style="font-family:sans-serif;font-size:15px;line-height:1.5">
          <p><b>${nome}</b> (${email}) entrou no Ganhos do Mês e está esperando sua aprovação.</p>
          <p><a href="${site}/admin" style="display:inline-block;padding:10px 16px;background:#EFA64A;color:#1A1208;text-decoration:none;font-weight:700">Abrir usuários do site</a></p>
        </div>`,
      }),
    });
    return new Response(r.ok ? "ok" : await r.text(), { status: r.ok ? 200 : 500 });
  } catch (e) {
    return new Response(String(e), { status: 500 });
  }
});
