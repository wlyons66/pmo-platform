# PMO Platform

Internal PMO application for BMC Solutions / Spend Allies. Tracks engagements, deliverables, KPIs, and client environment health.

## Architecture (mirrors wlyons-portal)

- **Frontend**: Next.js (App Router), React, TypeScript, Tailwind CSS, static export (`output: "export"`)
- **Hosting**: Cloudflare Pages, auto-deploys from `main`. Server-side logic goes in Cloudflare Pages Functions / Workers.
- **Backend**: Supabase (Postgres + Auth + RLS). This app has its **own Supabase project**, separate from the portal's.
- **Repo**: github.com/wlyons66/pmo-platform (private)

## Conventions

- Apply security best practices by default: RLS on every table, no secrets in the repo, never request the service-role key in chat.
- Secrets live in environment variables (`.env.local` locally, Cloudflare/cloud-environment settings remotely). Only `NEXT_PUBLIC_*` values are safe for the client.
- Database changes are numbered SQL migrations in `supabase/migrations/`. Wade applies them in the Supabase dashboard SQL editor; do not assume they are applied until he confirms.
- Seed data originates in `seed/` (CSV/XLSX). Client names there are confidential; keep the repo private.
- Work on feature branches and open PRs; do not push directly to `main`.

## Local-only vs cloud-session work

- Cloud sessions are fine for self-contained code on a branch.
- Keep local: applying migrations, anything needing real keys, running `scripts/sharepoint/*.ps1` (needs tenant access and interactive PnP sign-in).

## Layout

- `seed/` — source seed datasets (severity profiles, client environments, deliverable templates, KPI registry)
- `scripts/sharepoint/` — SharePoint provisioning scripts from the original PMO setup. `Provision-PMO-SharePoint.ps1` defaults `-SeedDataPath` to its own folder; pass `-SeedDataPath ..\..\seed` now that seed files live in `seed/`.
- `ROADMAP.md` — phased plan
