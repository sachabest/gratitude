/**
 * Cloudflare Worker behind gratitude.sachabest.com — the landing page a Smile's
 * iMessage link points at (see SmileService.landingURL in the Gratitude
 * app). Two jobs:
 *
 *  1. Serve /.well-known/apple-app-site-association so Universal Links open
 *     the app directly (AppDelegate.application(_:continue:restorationHandler:))
 *     when it's already installed.
 *  2. Serve /s?u=<icloud.com CKShare URL>&from=<sender name> with Open Graph
 *     tags, so iMessage's own link-preview fetcher renders a branded "X sent
 *     you a Smile" card instead of a plain blue link, and a visitor without
 *     the app (Universal Links only intercept when the app IS installed —
 *     everyone else actually loads this page in Safari) gets a real "Get
 *     Gratitude" install page instead of a dead end.
 *
 * Deliberately does NOT know the smile's actual message text — that stays
 * behind the app's existing CloudKit `acceptShare` fetch. Only the sender's
 * display name (already non-secret — it's the same name CloudKit's own
 * native share-invitation push already shows) goes in the URL.
 *
 * Env vars (Worker secrets/vars, not code):
 *   APPLE_APP_ID     e.g. "7M62J9KS2A.com.sachabest.gratitude"
 *   INSTALL_LINK_URL e.g. a TestFlight public link today, an App Store link later
 */
export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/.well-known/apple-app-site-association") {
      return jsonResponse({
        applinks: {
          details: [
            {
              appIDs: [env.APPLE_APP_ID],
              components: [{ "/": "/s", comment: "Smile links" }],
            },
          ],
        },
      });
    }

    if (url.pathname === "/s") {
      return handleSmileLanding(url, env);
    }

    return new Response("Not found", { status: 404 });
  },
};

function handleSmileLanding(url, env) {
  const from = escapeHtml(url.searchParams.get("from") || "Someone");
  const installLink = escapeHtml(env.INSTALL_LINK_URL || "#");
  const cardImage = `https://${url.hostname}/smile-card.png`;

  const html = `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${from} sent you a Smile</title>
<meta property="og:title" content="${from} sent you a Smile">
<meta property="og:description" content="Open Gratitude to see it.">
<meta property="og:image" content="${cardImage}">
<meta property="og:type" content="website">
</head>
<body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;text-align:center;padding:64px 24px;background:#fffaf0;color:#1c1c1e;">
  <div style="font-size:64px;line-height:1;">😊</div>
  <h1 style="font-size:28px;margin:16px 0 8px;">${from} sent you a Smile</h1>
  <p style="font-size:17px;color:#555;margin:0 0 32px;">Get Gratitude to see it.</p>
  <a href="${installLink}" style="display:inline-block;padding:14px 32px;background:#e8a628;color:#fff;border-radius:14px;text-decoration:none;font-weight:600;font-size:17px;">Get the app</a>
  <p style="font-size:13px;color:#999;margin-top:40px;">Already have the app? Come back and tap this link again once it's installed.</p>
</body>
</html>`;

  return new Response(html, {
    headers: { "content-type": "text/html; charset=utf-8" },
  });
}

function jsonResponse(body) {
  return new Response(JSON.stringify(body), {
    headers: { "content-type": "application/json" },
  });
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (c) => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
  ));
}
