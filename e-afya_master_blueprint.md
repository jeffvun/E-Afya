# E-AFYA — REAL-TIME CHILD MALNUTRITION MONITORING SYSTEM
## Master Blueprint (paste-ready for autonomous AI coding agents)
Version 2.0 | 2026-11-10 | Target: complete zipped system, ready to unzip & test locally

=====================================================================
PART 0 — MASTER INSTRUCTIONS TO THE AI AGENT (READ FIRST)
=====================================================================

ROLE: You are an autonomous senior full-stack engineer. Build the complete
E-Afya system end-to-end with no human intervention. Follow the phases in
order. Do not ask clarifying questions — every decision is specified below;
where a choice is genuinely free, pick the simplest proven option and record it
in DECISIONS.md.

OPERATING RULES:
1. Work phase by phase. Each phase has VERIFY steps: run the commands, capture
   output, and only proceed when green. If a verification fails, debug and fix
   within the phase (max 3 attempts), then document the workaround in
   DECISIONS.md and continue.
2. Never skip tests. The sync engine (Phase 2) is the highest-risk component —
   if its verification fails twice, still continue building later phases but
   mark the failure clearly in FINAL_REPORT.md.
3. Keep the code simple, boring, and readable. No exotic frameworks. Comment
   non-obvious sync/conflict logic.
4. i18n: NO hardcoded user-facing strings. All UI text via fr/sw language
   files from Phase 1 onward.
5. Commit logically as you go (git init in the repo root).

FINAL DELIVERABLE (the contract — this is what success means):
A single zip file named  e-afya-system.zip  containing the full monorepo:
  e-afya/
    docker-compose.yml          # one command starts everything
    README.md                   # exact run/test instructions
    DECISIONS.md                # every free choice you made
    FINAL_REPORT.md             # verification outputs per phase
    run_tests.sh                # one script: builds, migrates, seeds, tests
    app/        (Flutter mobile app — offline-first)
    api/        (FastAPI backend + Alembic migrations + seed + tests)
    web/        (Next.js coordinator dashboard + donor portal)
  After `unzip e-afya-system.zip && cd e-afya && docker compose up --build`:
   - API, Postgres, MinIO, Web start healthy.
   - `bash run_tests.sh` exits 0 (auth, scoping, sync idempotency,
     severity auto-suggestion, early-warning trigger, donor PDF).
   - Demo logins documented in README work from the web dashboard.

=====================================================================
PART 1 — PROJECT CONTEXT & PRINCIPLES
=====================================================================

Client: Eden World Foundation, South-Kivu Province, DRC. 50 health facilities
monitoring child acute malnutrition (SAM/MAM) in a conflict-affected region
with unreliable connectivity.

The five non-negotiable principles every implementation decision must serve:
1. OFFLINE-FIRST: the mobile app never blocks on the network. All reads/writes
   hit local SQLite; a background worker pushes/pulls deltas when online.
2. ONE SOURCE OF TRUTH: server PostgreSQL. Web dashboard reads it; app syncs
   to it. Never two divergent copies of a record without a conflict badge.
3. FIELD USABILITY: every screen completable in <90 seconds, one-handed, on a
   low-end Android, in French or Swahili.
4. HEALTH DATA ETHICS: guardian consent required before first visit; minimal
   PII (names + guardian phone only — no national IDs); role and facility
   scoping; full audit log; district-level aggregation only on public maps.
5. WHO STANDARDS: MUAC cut-offs — SAM <11.5cm, MAM 11.5–12.5cm, Normal >12.5cm.
   Severity auto-suggestion must match these exactly.

=====================================================================
PART 2 — TECH STACK (fixed)
=====================================================================

Mobile app    Flutter 3.x + sqflite (SQLite) — Android first, iOS-ready
Local sync    Custom delta worker: client UUIDs + sync_state + watermark
Backend       Python 3.12 + FastAPI + Alembic
Server DB     PostgreSQL 16 + PostGIS
Cache/queue   Redis (sync batching, report jobs)
Web dashboard Next.js 14 + TypeScript + Tailwind + Apache ECharts + MapLibre
Auth          JWT access (15min) + refresh (7d); PIN login on app
Storage       MinIO (S3-compatible: photos, PDF reports)
Deploy        Docker Compose (single-host, offline-tolerant)
Reports       WeasyPrint (PDF) + openpyxl (Excel), generated server-side
SMS (phase 2) Africa's Talking — out of MVP scope, stub the interface only

=====================================================================
PART 3 — DATABASE MODEL (create via Alembic; indexes included)
=====================================================================

facilities(id uuid pk, name, district, province default 'South-Kivu',
           gps_lat, gps_lng, type, last_sync_at timestamptz)

users(id uuid pk, facility_id fk->facilities, full_name, role check in
      ('nurse','coordinator','manager','viewer'), phone, pin_hash,
      is_active, created_at)
      -- nurse = scoped to own facility; coordinator/manager = province;
      -- viewer = donor read-only

children(client_uuid text pk,            -- generated on device
         facility_id fk, first_name, last_name, sex, birth_date,
         guardian_name, guardian_phone, consent_given bool not null default
         false, consent_date, village, displaced bool default false,
         created_by fk->users, server_updated_at timestamptz,
         deleted bool default false)

visits(id uuid pk, child_uuid fk, visit_date date, muac_cm numeric(4,1),
       weight_kg numeric(4,1), height_cm numeric(4,1), oedema bool,
       symptoms text[], severity check in ('SAM','MAM','normal'),
       action_taken check in ('referral','rutf','inpatient','counselling',
       'followup'), photo_url text, notes, next_visit_date,
       recorded_by fk->users, server_updated_at timestamptz)

distributions(id uuid pk, child_uuid fk, commodity check in
       ('RUTF','RUSF','fortified_flour','plumpy_sup'), quantity numeric,
       unit, distributed_at, distribution_site, given_by fk->users,
       server_updated_at timestamptz)

protocols(id uuid pk, code, title, category check in ('feeding','assessment',
       'referral','hygiene'), min_age_mo int, max_age_mo int,
       content_fr text, content_sw text, steps jsonb, is_active bool)

alerts(id uuid pk, facility_id fk null, district text, type check in
       ('surge','facility_offline','stock_low','critical_child'),
       severity check in ('info','warning','critical'), message,
       inputs jsonb,            -- threshold values used, for auditability
       status check in ('open','acknowledged','resolved') default 'open',
       acknowledged_by fk->users null, created_at timestamptz)

forecast_snapshots(id uuid pk, district, computed_at timestamptz,
       metric, value numeric, horizon_days int, model_version text)

stock_levels(facility_id fk, commodity, quantity numeric, unit,
       updated_at)               -- for stock_low alerts

audit_log(id bigserial pk, actor, action, entity, entity_id, meta jsonb,
          created_at timestamptz default now())

Indexes: visits(child_uuid, visit_date); children(facility_id);
children(guardian_phone); alerts(status, created_at);
forecast_snapshots(district, computed_at);

=====================================================================
PART 4 — MOBILE APP SPEC (Flutter; all screens work 100% offline)
=====================================================================

S1 Login: facility dropdown + username + 4-digit PIN. Session cached locally
   (re-validated on sync). fr/sw toggle on login screen.
S2 Home: KPI row (critical alerts at my facility / active cases / pending
   sync), 7-day SAM/MAM trend chart (local data), top-3 critical children
   cards, facility sync status, FAB → S3.
S3 New child / visit (THE 90-SECOND FORM): identity → weight/height/MUAC with
   live colour-scale visual (red/yellow/green) that AUTO-SUGGESTS severity
   per WHO cut-offs (editable) → symptom checkboxes (fr/sw labels) → action
   taken → guardian consent checkbox (mandatory, date-stamped) → save.
   Save writes to SQLite instantly; toast: saved offline, will sync.
S4 Patient list: search; filter chips All / SAM / MAM / Normal / Today /
   Due-for-follow-up (next_visit_date <= today).
S5 Patient detail: latest metrics, severity badge, weight-for-height,
   guardian contact, full visit + distribution history, buttons "Schedule
   follow-up" and "Alert coordinator" (creates critical_child alert on sync).
S6 Sync: pending count, progress bar, per-record states (✅⏳◯⚠), auto-sync
   on reconnect, conflict viewer (server version shown).
S7 Guidance: searchable offline protocols filtered by child age + severity,
   rendered fr/sw from local DB (this is the carer-advice feature).
S8 Distributions: log RUTF/RUSF/etc. per child (commodity, qty, site).

SYNC ENGINE (highest-risk; implement and test first within the app):
- Push: all records sync_state='pending', batches of 50, exponential backoff
  on failure. POST /sync/push returns per-record ack/conflict; conflicts →
  server wins, local row gets ⚠ badge and stores server_version json.
- Pull: GET /sync/pull?since=<watermark> scoped to caller's facility → apply.
- Watermark stored per-table; pull is resumable.
- Photos >1MB deferred when connection is metered.
- All operations idempotent — safe to retry any time.

=====================================================================
PART 5 — BACKEND API (FastAPI; all routes JWT-protected unless noted)
=====================================================================

POST /auth/login                     -> {access, refresh, user, facility}
POST /auth/refresh
POST /sync/push                      # idempotent batch upsert; returns acks
                                     # + conflicts; updates last_sync_at
GET  /sync/pull?since=               # delta, facility-scoped for nurses
POST /sync/photos                    # multipart; returns url

GET  /children?q=&severity=&due=     # scoped
POST /children                       # upsert by client_uuid
GET  /children/{uuid}                # + visits + distributions embedded
POST /children/{uuid}/visits
POST /children/{uuid}/distributions
GET  /children/{uuid}/guidance       # matching protocols (rules, offline-ok)

GET  /dashboard/province             # coordinator KPIs
GET  /alerts?status=&type=
POST /alerts/{id}/acknowledge
POST /alerts/{id}/resolve
GET  /forecast/districts             # early-warning output
PUT  /stock/{facility_id}            # upsert stock level

POST /reports/donor?period=          # enqueue job -> job_id
GET  /reports/donor/{job_id}         # status + download url (PDF+XLSX)

GET  /protocols?age=&severity=&lang=
Admin (role manager): CRUD /admin/users /admin/facilities /admin/protocols
                      PUT /admin/thresholds

Every mutating request writes audit_log. Every response that touches children
respects facility scoping for nurse tokens.

=====================================================================
PART 6 — WEB DASHBOARD (Next.js; coordinator + manager + donor-viewer)
=====================================================================

W1 Overview: live KPIs, SAM/MAM trend, alert feed (acknowledge/resolve inline).
W2 Early-warning panel: per-district status (green/yellow/red), horizon text
   ("Uvira — possible crisis, projected critical in ~2 weeks"), threshold
   config (manager only). Every alert row expandable to show its inputs.
W3 Geo map (MapLibre + PostGIS): facilities as points; hotspot circles sized
   by 7-day SAM rate; displaced-camp overlay toggle. DISTRICT LEVEL ONLY.
W4 Facility drill-down: children, visits, distributions, stock, sync health.
W5 Stock: distributed vs forecast need per facility; <2-week cover highlighted.
W6 Donor reports: period selector → request → poll job → download PDF+XLSX.
W7 Admin: users, facilities, protocols editor (fr/sw fields), thresholds,
   audit log viewer. Role-gated UI.

=====================================================================
PART 7 — EARLY-WARNING ENGINE (rules-based v1; auditable)
=====================================================================

Nightly job (also runnable on demand):
1. Per district: baseline = 28-day rolling MEAN of new SAM cases/day; current
   = 7-day rolling SUM. Trigger when current >= baseline*1.3 AND current>=5
   -> surge alert with projected horizon (linear projection, 2–3 weeks).
2. facility >= 5 new SAM in 7 days           -> surge (facility-level)
3. facility silent > 72h (no sync)          -> facility_offline
4. stock cover < 14 days at facility        -> stock_low
5. Every alert stores its exact inputs + threshold version in `inputs` jsonb.
Optional v2 (ETS/Poisson) — stub only; same output table, flag model_version.

=====================================================================
PART 8 — DONOR REPORT (auto-generated PDF + Excel)
=====================================================================

Sections: children monitored; SAM/MAM trend chart; recovery rate (children
whose latest severity improved vs first); facilities covered / 50; districts
table; alert log with per-alert DETECTION LEAD TIME ("detected 3 weeks early",
computed from forecast horizon when the event later materialised). Branded
template, period selector, one click.

=====================================================================
PART 9 — SECURITY & ETHICS (all verified in tests)
=====================================================================

TLS only; JWT + refresh; PIN re-entry for sensitive screens; SQLCipher
(encrypted SQLite) on device; server at-rest encryption; nightly DB dump
script + documented restore; shared-device wipe option on logout (default ON);
consent gate before first visit record; facility scoping enforced server-side
+ tested; PII minimal; audit log immutable (append-only table, no updates);
public maps district-aggregate only.

=====================================================================
PART 10 — BUILD PHASES WITH VERIFICATION GATES
=====================================================================

PHASE 1 FOUNDATION
 Build: monorepo; docker-compose (postgres+postgis, redis, minio, api, web);
 Alembic migrations for ALL Part-3 tables; seed (5 facilities across
 Bukavu/Uvira/Walungu; users: nurse.bukavu (PIN 1234), coordinator, manager;
 6 protocols in fr AND sw covering feeding/assessment/referral/hygiene);
 Flutter shell with i18n (fr/sw files, zero hardcoded strings) and login
 screen; git init; first commit.
 VERIFY: `docker compose up --build` healthy; `pytest api/tests/test_auth.py`
 green; seeded login returns correctly scoped JWT.

PHASE 2 SYNC CORE (riskiest — prove it before any UI work)
 Build: SQLite layer mirroring tables + sync_state + watermark; sync worker
 (connectivity listener + manual); push/pull endpoints with idempotency;
 conflict = server-wins + ⚠ badge + server_version json; photo deferral;
 sync screen S6.
 VERIFY (all automated, output captured to FINAL_REPORT.md):
  a) 100 records created offline -> sync -> 0 pending, 0 dupes server-side.
  b) sync killed at 40% -> resume -> same end state.
  c) same record edited offline + server -> server wins, conflict visible.
  d) pull?since returns only deltas.

PHASE 3 FIELD WORKFLOWS
 Build screens S1–S5, S7, S8 exactly per Part 4.
 VERIFY: scripted walkthrough — create child (consent box enforced), enter
 MUAC 10.1 -> severity auto-SAM; MUAC 11.8 -> MAM; MUAC 13.0 -> normal;
 log RUTF; find child in S4 filters; see in S5; sync; record visible via API.

PHASE 4 COORDINATOR DASHBOARD
 Build W1, W3, W4, W5, W7 per Part 6.
 VERIFY: coordinator login sees 5 facilities; acknowledge writes audit_log;
 map contains zero child-level coordinates.

PHASE 5 EARLY WARNING + DONOR REPORTS
 Build Part 7 engine + W2 panel + Part 8 report generator (WeasyPrint PDF,
 openpyxl XLSX, MinIO storage, async job).
 VERIFY: inject synthetic surge (scripted) into one district -> alert with
 horizon; donor PDF contains all Part 8 sections and correct lead-time values.

PHASE 6 HARDENING + PACKAGING
 Build: security items in Part 9; run_tests.sh (full suite); README (exact
 commands: unzip -> compose up -> bash run_tests.sh -> demo logins ->
 2-minute manual smoke path); DECISIONS.md; fr/sw string audit.
 PACKAGE: git log summarized into FINAL_REPORT.md; `zip -r e-afya-system.zip
 e-afya` (exclude build artifacts, node_modules, .dart_tool); verify the zip
 in a CLEAN directory: unzip, compose up, run_tests.sh exits 0.
 VERIFY: the clean-directory test IS the final verification. Record its
 output as the last section of FINAL_REPORT.md.

=====================================================================
PART 11 — ACCEPTANCE CRITERIA (the definition of done)
=====================================================================

1. Clean unzip -> `docker compose up --build` -> all services healthy.
2. `bash run_tests.sh` exits 0.
3. README demo walkthrough (login -> add child offline -> sync -> coordinator
   sees it -> donor PDF) completes in <10 minutes for a new user.
4. Sync proofs a–d from Phase 2 pass.
5. MUAC auto-severity matches WHO cut-offs in tests.
6. A nurse token cannot read another facility's children (automated test).
7. Every alert carries auditable inputs; donor report shows lead times.
8. fr/sw toggle changes every user-facing string.

END OF BLUEPRINT — the agent builds, verifies, packages, and reports.
