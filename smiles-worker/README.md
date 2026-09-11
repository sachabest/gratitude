# Smiles landing worker

The Cloudflare Worker behind `gratitude.sachabest.com`, referenced by
`SmileService.landingURL` in the Gratitude app and by
`gratitude.entitlements`' Associated Domains entry. Not part of the Xcode
project — deploy it separately, whenever convenient, independent of app
builds.

## What it does

- `/.well-known/apple-app-site-association` — lets Universal Links open
  Gratitude directly when it's already installed.
- `/s?u=<icloud.com CKShare URL>&from=<sender name>` — a branded page with
  Open Graph tags (so iMessage shows a rich "X sent you a Smile" card
  instead of a plain link) and a "Get the app" fallback for anyone who opens
  it without Gratitude installed. Never sees the smile's actual message
  text — that's fetched separately, inside the app, from CloudKit.

## Deploying

One-time manual setup, then automatic on every push:

1. `sachabest.com`'s nameservers need to point at Cloudflare (skip if
   already using Cloudflare for DNS).
2. Fill in `wrangler.toml`'s `INSTALL_LINK_URL` with the real TestFlight
   public link (App Store Connect -> TestFlight tab -> Public Link). This
   value isn't secret, so it just lives in the committed `wrangler.toml`.
3. Create a Cloudflare API token (My Profile -> API Tokens -> Create Token
   -> "Edit Cloudflare Workers" template is sufficient) and add it to this
   repo as a secret named `CLOUDFLARE_API_TOKEN` (repo Settings -> Secrets
   and variables -> Actions -> New repository secret).
4. Push to `main` with changes under `smiles-worker/` (or run the "Deploy
   Smiles Worker" workflow manually from the Actions tab) —
   `.github/workflows/deploy-smiles-worker.yml` runs `wrangler deploy` for
   you from there on. First deploy can also be done by hand with
   `npx wrangler deploy` from this directory if you want to verify locally
   before wiring up the secret.
5. Workers & Pages -> this Worker -> Settings -> Domains & Routes -> Add
   Custom Domain -> `gratitude.sachabest.com`. Cloudflare provisions DNS + TLS
   automatically. This step is one-time and isn't part of the GitHub Action
   — `wrangler deploy` updates the Worker's code, not its domain bindings.
6. **Disable Bot Fight Mode / any JS challenge for this hostname** — Apple's
   and iMessage's fetchers aren't real browsers and can't pass a challenge;
   leaving one on silently breaks both the rich preview and Universal Links.
7. Add a real 1200x630 branded image at `https://gratitude.sachabest.com/smile-card.png`
   (a design asset, not code — host via Workers Static Assets, R2, or
   Cloudflare Pages, whichever's least friction).

## Verifying independently of the app

```bash
curl -s https://gratitude.sachabest.com/.well-known/apple-app-site-association
curl -s "https://gratitude.sachabest.com/s?u=https://www.icloud.com/share/test&from=Test"
```

Both should work without ever touching Xcode or a real Smile — the Worker
doesn't call CloudKit at all.
