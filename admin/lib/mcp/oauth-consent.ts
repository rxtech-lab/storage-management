const storageIconSvg = () => '<svg viewBox="0 0 72 72" xmlns="http://www.w3.org/2000/svg"><rect width="72" height="72" rx="18" fill="#80719e"/><path d="M18 26h36v30H18zm-3-10h42v10H15z" fill="#fff"/><path d="M29 34h14v5H29z" fill="#80719e"/></svg>';

export interface ConsentPageOptions {
  clientName: string;
  redirectUri: string;
  scope: string;
  requestId: string;
  csrf: string;
  action: string;
  accountName?: string | null;
  accountEmail?: string | null;
}

function escape(value: string): string {
  return value.replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}

const icon = (paths: string, className = "") => `<svg class="${className}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths}</svg>`;
const libraryIcon = icon('<rect x="7" y="5" width="13" height="16" rx="3"/><path d="M16 5V3H5a2 2 0 0 0-2 2v12h4M11 10h5M11 14h5M11 18h3"/>');
const editIcon = icon('<path d="m15 5 4 4M4 20l4-1 12-12a3 3 0 0 0-4-4L4 15l-1 6 6-1"/>');
const accountIcon = icon('<circle cx="12" cy="8" r="4"/><path d="M4 21v-2a8 8 0 0 1 16 0v2"/>');
const shieldIcon = icon('<path d="M12 3 4 6v6c0 5 8 9 8 9s8-4 8-9V6l-8-3Z"/><path d="m8 12 3 3 5-6"/>');
const linkIcon = icon('<path d="m10 13 4-4M8 16l-1 1a4 4 0 0 1-6-6l5-5a4 4 0 0 1 6 0M16 8l1-1a4 4 0 0 1 6 6l-5 5a4 4 0 0 1-6 0"/>');
const arrowIcon = icon('<path d="M5 12h14m-5-5 5 5-5 5"/>');

/** Standalone HTML keeps the sign-in flow usable without JavaScript or external assets. */
export function renderConsentPage(options: ConsentPageOptions): string {
  const { clientName, redirectUri, scope, requestId, csrf, action, accountName, accountEmail } = options;
  const permissions = scope.split(" ").map(permission => permission === "storage:read"
    ? { icon: libraryIcon, title: "Read inventory", detail: "Find and read your items and their attachments" }
    : { icon: editIcon, title: "Manage inventory", detail: "Update and move items, upload images, and move items to the recycle bin" });
  const accountLabel = accountName || accountEmail || "Your RxStorage account";
  const agentInitial = Array.from(clientName.trim())[0] || "A";
  const callback = new URL(redirectUri);
  const destination = callback.origin === "null" ? `${callback.protocol}//${callback.host}${callback.pathname}` : callback.host;
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light dark"><title>Connect to RxStorage</title>
<style>
  :root{color-scheme:light;--ink:#17213f;--muted:#667089;--surface:#fff;--soft:#f7f5fc;--line:#ebe8f4;--coral:#f57f6b;--lavender:#eee5fc}
  *{box-sizing:border-box}body{margin:0;min-height:100svh;padding:40px 20px;font:16px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:var(--ink);background:radial-gradient(ellipse at 15% 15%,#ffded4aa,transparent 50%),radial-gradient(ellipse at 90% 80%,#d7c9f599,transparent 55%),#f7f3ff;display:grid;place-items:center}
  main{width:100%;max-width:560px}.brand{display:flex;align-items:center;justify-content:center;gap:10px;margin:0 0 24px;font-size:18px;font-weight:750;letter-spacing:-.4px}.brand svg{width:32px;height:32px;display:block}
  .card{background:var(--surface);border:1px solid #ffffffa6;border-radius:30px;box-shadow:0 24px 80px #30214b12,0 4px 16px #30214b05;padding:36px}
  .connection{display:flex;align-items:center;justify-content:center;gap:20px;margin:0 0 26px}.app-mark,.agent-mark{height:72px;width:72px;display:grid;place-items:center;border:1px solid var(--line);border-radius:21px;box-shadow:0 7px 18px #17213f08}.app-mark svg{width:72px;height:72px;display:block}.agent-mark{background:var(--soft);font-size:30px;font-weight:700;color:#80719e}.connection>.link{width:23px;height:23px;color:#9b90b1}
  h1{font-size:32px;line-height:1.2;letter-spacing:-1px;text-align:center;margin:0 0 12px;font-weight:760}.intro{text-align:center;color:var(--muted);margin:0 auto 28px;max-width:420px;overflow-wrap:anywhere}.intro strong{font-weight:650;color:var(--ink)}
  .label{font-size:11px;letter-spacing:1.4px;text-transform:uppercase;font-weight:750;color:var(--muted);margin:0 0 10px}.permissions{list-style:none;padding:0;margin:0 0 24px;border:1px solid var(--line);border-radius:18px;overflow:hidden}.permission{display:flex;gap:14px;align-items:flex-start;padding:17px 18px}.permission+.permission{border-top:1px solid var(--line)}.permission-icon{flex:0 0 38px;height:38px;border-radius:11px;display:grid;place-items:center;background:#f1eaff;color:#80719e}.permission-icon svg{height:22px;width:22px}.permission-title{font-size:15px;font-weight:700;margin:0 0 2px}.permission-detail{font-size:13px;line-height:1.5;color:var(--muted);margin:0}
  .account{display:flex;gap:12px;align-items:center;margin:0 0 20px;padding:0 2px}.account-icon{width:32px;height:32px;border-radius:50%;display:grid;place-items:center;background:var(--soft);color:var(--muted);flex-shrink:0}.account-icon svg{width:17px;height:17px}.account-copy{min-width:0}.account-label{font-size:11px;color:var(--muted);margin:0}.account-name{font-size:13px;font-weight:600;margin:0;overflow-wrap:anywhere}.account-email{font-size:12px;color:var(--muted);margin:0;overflow-wrap:anywhere}
  .notice{display:flex;align-items:flex-start;gap:9px;padding:14px 15px;border-radius:14px;background:var(--soft);font-size:12px;line-height:1.6;color:var(--muted);margin-bottom:24px}.notice svg{height:17px;width:17px;flex-shrink:0;margin-top:1px;color:#8c7ba8}.notice p{margin:0}
  .actions{display:grid;grid-template-columns:1fr 1.4fr;gap:12px}button{font:inherit;font-weight:700;font-size:14px;min-height:52px;cursor:pointer;border-radius:14px;transition:background .15s,transform .15s;display:flex;align-items:center;justify-content:center;gap:8px}button svg{width:18px;height:18px}.secondary{background:var(--surface);border:1px solid var(--line);color:var(--ink)}.secondary:hover{background:var(--soft)}.primary{background:var(--coral);color:#17213f;border:1px solid transparent;box-shadow:0 4px 12px #f57f6b26}.primary:hover{background:#ff907b;transform:translateY(-1px)}button:focus-visible{outline:3px solid #b9a6e6;outline-offset:3px}
  .destination{text-align:center;margin:20px 0 0;color:var(--muted);font-size:11px;overflow-wrap:anywhere}.destination span{color:var(--ink);font-weight:550}.footnote{text-align:center;color:var(--muted);font-size:11px;margin:18px 8px 0}
  @media(max-width:480px){body{padding:24px 16px}.card{padding:26px 22px;border-radius:24px}h1{font-size:28px}.connection{margin-bottom:22px}.permission{padding:15px 14px}.actions{grid-template-columns:1fr 1.25fr;gap:10px}}
  @media(prefers-color-scheme:dark){:root{color-scheme:dark;--ink:#f4efff;--muted:#aaaec4;--surface:#171d36;--soft:#202640;--line:#30364f}body{background:radial-gradient(ellipse at 10% 0,#f57f6b12,transparent 50%),radial-gradient(ellipse at 90% 90%,#b9a6e61a,transparent 50%),#0d1225}.card{border-color:#30364f;box-shadow:0 24px 80px #0004}.agent-mark{color:#c1b1e6}.permission-icon{background:#302b49;color:#c1b1e6}.notice svg{color:#c1b1e6}}
  @media(prefers-reduced-motion:reduce){button{transition:none}.primary:hover{transform:none}}
</style></head><body><main>
  <div class="brand">${storageIconSvg()}<span>RxStorage</span></div>
  <section class="card" aria-labelledby="consent-title">
    <div class="connection" aria-hidden="true"><span class="app-mark">${storageIconSvg()}</span>${linkIcon.replace('class=""', 'class="link"')}<span class="agent-mark">${escape(agentInitial)}</span></div>
    <h1 id="consent-title">Connect to RxStorage</h1>
    <p class="intro"><strong>${escape(clientName)}</strong> would like access to your inventory.</p>
    <p class="label" id="permissions-label">This agent will be able to</p>
    <ul class="permissions" aria-labelledby="permissions-label">${permissions.map(p => `<li class="permission"><span class="permission-icon">${p.icon}</span><div><p class="permission-title">${p.title}</p><p class="permission-detail">${p.detail}</p></div></li>`).join("")}</ul>
    <div class="account"><span class="account-icon">${accountIcon}</span><div class="account-copy"><p class="account-label">Connected account</p><p class="account-name">${escape(accountLabel)}</p>${accountName && accountEmail ? `<p class="account-email">${escape(accountEmail)}</p>` : ""}</div></div>
    <div class="notice">${shieldIcon}<p>Only the permissions listed above will be shared. You can disconnect this agent from its settings.</p></div>
    <form method="post" action="${escape(action)}"><input type="hidden" name="request" value="${escape(requestId)}"><input type="hidden" name="csrf" value="${escape(csrf)}">
      <div class="actions"><button class="secondary" name="decision" value="deny">Cancel</button><button class="primary" name="decision" value="allow">Allow access ${arrowIcon}</button></div>
    </form>
    <p class="destination">Connection destination: <span>${escape(destination)}</span></p>
  </section>
  <p class="footnote">Access is granted only after you approve.</p>
</main></body></html>`;
}
