# PMO Platform Roadmap

Draft, derived from the seed datasets in `seed/`. Review and adjust before building.

## Seed-derived data model (starting point)

| Table | Source | Key fields |
|---|---|---|
| `kpi_registry` | KPI_Registry | name, engagement_type, target, warning_threshold, critical_threshold, is_higher_better, display_order |
| `deliverable_templates` | Deliverable_Templates | name, phase, owner_role, required, template_required |
| `severity_profiles` | CRITICAL _Severity_Profiles | profile, failed_weight, out_of_date_weight, retry_weight, staleness_per_day, paused_adjustment, pinned_adjustment |
| `client_environments` | Client_Environment_Templates | client_name, region, upgrade_mode, severity_profile, client_criticality, alerts_enabled |
| `solution_registry` | New-PMOPackageName.ps1 / provisioning script | solution_name, version (major.minor[.patch]), status (Draft/Approved/Deprecated) |

Planned additions: `engagements`, `engagement_deliverables`, `kpi_measurements`, `profiles` (with role), `audit_log`.

## Phase 1: Foundation (good remote-session candidate)

1. Scaffold Next.js + Tailwind static export, Cloudflare Pages config (mirror wlyons-portal).
2. Supabase client helper and auth (email/password), role model (e.g. system_admin, pm, viewer).
3. Migrations 0001+: reference tables above with RLS; seed loader from `seed/`.
4. App shell, navigation, protected routes.

*Local step:* Wade creates the Supabase project, adds env vars, applies migrations.

## Phase 2: Core data screens

Engagements, deliverables tracking by phase and owner role, client environment list with severity scoring.

## Phase 3: KPI dashboards

Measurements against targets/thresholds (respecting `is_higher_better`), warning/critical status, trend views.

## Phase 4: Alerts and integrations

Alerts for environments with `alerts_enabled`, severity scoring using profile weights, optional SharePoint sync via server-side functions.

## Phase 5: Polish

Audit log, exports, accessibility, docs.
