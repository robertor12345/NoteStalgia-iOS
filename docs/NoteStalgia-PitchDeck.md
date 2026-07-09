# NoteStalgia™ by Oscillomind — Pitch Decks

> *"Sound that takes you back."*
> A music‑reminiscence and sensory‑calm platform for care homes — **embedded in supervisor workflows**, with **built‑in analytics** that turn every session into actionable care intelligence.

This document contains:

1. **Product & flow summary** (what the app does today + where production is headed)
2. **Deck A — NHS Grant Scheme** (innovation / evidence‑generation framing)
3. **Deck B — Care UK Board** (operational / commercial framing)

Each deck is written slide‑by‑slide so it can be pasted directly into PowerPoint, Keynote, or Google Slides.

> **Living docs:** product/engineering detail is maintained in `[IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)` (including PII strategy, **insights aggregation pipeline**, **data‑sharing API / partner integrations**, server‑side roster search, and GDPR Art. 9 controls). Update both when tenancy, auth, analytics, integrations, data‑governance, or architecture decisions change.

---

## 1. Product & flow summary

**What it is:** A person‑centred, non‑pharmacological calm and reminiscence tool for one‑to‑one and group sessions in residential and dementia care. It is designed to **slot into how supervisors already work** — sign‑in, pick a home, find the right resident, run a session, capture a quick observation — while building a **longitudinal analytics layer** that helps homes see what works, for whom, and when to intervene.

**Two surfaces, one device — plus an analytics loop:**

- **Supervisor surface** (text‑rich, workflow‑native): org‑scoped sign‑in → home picker → **curated roster** (pinned, recent, due, wing, search) → person‑centred profile → session handoff → **four‑tap post‑session feedback** → session history on the resident record.
- **Resident surface** (low‑text, accessible): floating instrument glyphs, music‑reactive orb, immersive "calm room" nature visuals — no reading required.
- **Insights surface** (production): **Home Admin / Company Admin dashboards** with trend charts, wing breakdowns, resident impact lists, and correlation views — turning session telemetry + carer observations into **treatment‑relevant intelligence** (what calms whom, which genres correlate with better mood, who hasn't had a session and may need outreach).

**Supervisor workflow integration (not a parallel system):**

NoteStalgia is built around the **existing shift rhythm** on the care floor — not a separate charting tool supervisors must remember to open.


| Workflow moment              | What supervisors do today (without NoteStalgia)      | What NoteStalgia adds                                                                                                                       |
| ---------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **Start of shift**           | Check handover, mentally note who needs attention    | Sign in → pick home → **curated roster** surfaces **pinned**, **recent**, and **due for visit** residents automatically                     |
| **Finding a resident**       | Walk the wing, ask colleagues, scan paper lists      | **Search by name / room / wing**; wing filter; compact row or card view — seconds, not minutes                                              |
| **Before a session**         | Recall preferences from memory or a care plan folder | **Person‑centred profile** (likes/dislikes, sensory prefs, era, playlists) + optional **discovery calibration** for new residents           |
| **During a session**         | Facilitate manually; outcomes invisible              | Resident‑led music + calm visuals; **automatic telemetry** (genres, tracks, duration, immersive use) — no extra taps                        |
| **After a session**          | Free‑text note if time allows; often skipped         | **Sequential 1–10 observations** (mood, alertness, emotional state, lucidity) + optional note — ~30 seconds, structured not clinical        |
| **Care planning / handover** | Fragmented notes, hard to spot trends                | **Session history + wellbeing trends** on the resident profile; **home dashboard** flags improving residents and those needing attention    |
| **Management oversight**     | Spreadsheets, ad‑hoc audits, delayed insight         | **Home Admin dashboard**: 14‑day KPIs, calm/wellbeing trend charts, wing comparison, recent sessions, positive highlights vs attention list |


**Data analytics & treatment intelligence:**

Every session feeds an **event‑first pipeline** (usage, playlist engagement, wellbeing ratings, group outcomes) into governed aggregation marts — the same data powers **floor‑level decisions**, **home‑level management**, and **researcher cohorts**.


| Analytics grain                   | Who uses it                                      | Treatment / operational value                                                                                                                                           |
| --------------------------------- | ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Per resident**                  | Supervisor (in‑app profile), Home Admin          | Longitudinal calm % and wellbeing trajectories; genre engagement; "last session X days ago" prompts outreach; inform **individual care plans** and family conversations |
| **Per wing / home**               | Home Admin dashboard (POC built; production web) | Compare wings; spot under‑served areas; session volume and reach KPIs; **allocate staff time** where impact is lowest                                                   |
| **Per home trends**               | Home Admin, Company Admin                        | 14‑day rolling charts: sessions, residents reached, average calm %, composite wellbeing — **early warning** when trends dip                                             |
| **Genre ↔ wellbeing correlation** | Supervisors, care leads, researchers             | Which music choices associate with better mood/calm scores for a resident or cohort — **refine playlists and non‑pharma interventions**                                 |
| **Estate / cohort**               | Company Admin (web), researchers                 | Cross‑home benchmarks within tenant; pseudonymized exports for evaluation — **evidence for prescribing review and NICE‑aligned adoption**                               |
| **External systems (API)**        | Home management platforms, estate BI, commissioners | **Pull session & wellbeing summaries** into Nourish / PCS / Log my Care etc. — no parallel record‑keeping                                                         |


**POC today:** the iPad app includes a **Home Admin insights dashboard** (KPI cards, trend graphs with legends, wing breakdown, resident impact highlights, attention‑needed list, recent sessions) built from session records — demonstrating the analytics loop before the production aggregation pipeline ships.

**Data sharing API & care‑home system integration (production roadmap):**

Homes already run on **care management platforms** — Nourish, Person Centred Software (mCare), Log my Care, Care Vision, CarePlanner, and similar. NoteStalgia is not designed to replace them; it **enriches the record** with structured reminiscence and calm‑session outcomes supervisors capture on the floor.

| Layer | What it does | Why it matters |
|---|---|---|
| **Governed data‑sharing API** | Tenant‑scoped, OAuth/OIDC‑authenticated **read API** (OpenAPI) exposing session summaries, wellbeing ratings, calm %, genre engagement, and trend rollups — keyed by resident external ID | Care operators and commissioners can **pull NoteStalgia outcomes into existing dashboards** without manual CSV export or duplicate charting |
| **Outbound events / webhooks** | Push notifications when a session completes, a wellbeing trend crosses a threshold, or a resident hits "needs attention" on the home dashboard | **Real‑time integration** with home management workflows — e.g. append a structured note to the resident's daily log |
| **Inbound resident sync (optional)** | Read‑only import of resident identifiers, room, wing, and care‑plan flags from the home's system of record (with DPIA + data‑processing agreement) | Supervisors **don't re‑type resident data**; NoteStalgia stays aligned with the canonical roster |
| **Pilot scope** | API **contract design** (OpenAPI in `notestalgia-contracts`), audit‑logged export endpoints, and **one exploratory partner integration** with a participating home's existing platform | Proves interoperability without delaying core pilot delivery; full multi‑vendor connector programme is **post‑pilot** |

**What flows across the API (governed, not a data dump):**

- Per‑resident: latest session date, calm %, composite wellbeing score, mood/alertness/emotional/lucidity ratings, genres played, session duration.
- Per‑home: session volume, residents reached, wing breakdown, improving vs needs‑attention flags.
- **Not exposed by default:** raw audio telemetry, free‑text notes without consent review, cross‑tenant data, or researcher pseudonymized cohorts (separate export path).

**Tenancy & access (POC today, production target):**

- **Organisation → care home → wing → resident.** Staff belong to a care‑home company (tenant); residents and sessions are scoped to homes within that company.
- **Sign‑in:** work **email + PIN** (domain‑validated per organisation). No biometrics — GDPR‑aligned, PIN‑only auth.
- **Roles:** floor **Supervisor**, **Home Admin** (one or more homes), **Company Admin** (whole estate — web dashboard audience).
- **Multi‑home staff:** supervisors assigned to several homes pick **which home they're working at today**, then see only that home's roster.
- **Curated roster at scale:** pinned residents, recent sessions, due for a visit, wing filter, **search by name / room / wing**, cards or compact rows, browse‑all — designed to stay fast from 30 to 3,000+ residents per company (server‑side search in production).

**Core flows:**


| Flow                                                             | What happens                                                                                                                                                                                                    | Why it matters                                                                                                                                                                                 |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Supervisor sign‑in → Home (if multi‑site) → Welcome → Roster** | Staff log in with work email + PIN; optional home picker; animated welcome; **home‑scoped curated roster** with pinned / recent / due sections                                                                  | Secure, tenant‑aware entry into the working day — **workflow‑native resident discovery**, not a separate admin task                                                                            |
| **Person‑centred profiles**                                      | Likes/dislikes, preferred lighting, scent, touch comfort, reminiscence themes, sound‑shaping preferences, age, favourite genre, curated playlists + **session history & wellbeing trends**                      | Care that adapts to the individual; supervisors see **what worked last time** before starting                                                                                                  |
| **New‑resident music discovery (calibration)**                   | Age input → 6 timed retro snippets ordered to the resident's *peak listening years (≈15–30)* → resident taps a simple traffic‑light smiley (pleasant / neutral / unpleasant) per clip → builds a tuned playlist | Personalises the library in minutes, even for residents who can't self‑report                                                                                                                  |
| **One‑to‑one calm session**                                      | Gentle staff→resident handoff → resident taps instrument glyphs to play → music‑reactive orb + equalizer → optional immersive nature "calm room" → settling pause                                               | Residents lead; staff support. Low agitation, high agency                                                                                                                                      |
| **Session feedback**                                             | Sequential 1–10 ratings (mood, alertness, emotional state, lucidity) + free note + automatic telemetry (genres played, track changes, immersive entries, duration)                                              | Lightweight, repeatable wellbeing signal — **structured data for analytics**, not another form to file away                                                                                    |
| **Group session**                                                | Compiles a cross‑resident playlist from top‑scoring tracks across the **current home's** roster → shared playback → group feedback (morale, alertness, lucidity, engagement)                                    | Social, communal reminiscence with measurable outcomes — **group‑level analytics** alongside one‑to‑one                                                                                        |
| **Home Admin insights (POC + production)**                       | KPI cards, 14‑day trend charts (sessions, reach, calm %, wellbeing), wing breakdown, improving vs needs‑attention residents, recent session feed                                                                | **Management visibility without manual charting** — connects floor activity to care‑plan and staffing decisions                                                                                |
| **Insights & exports (production)**                              | Event‑first telemetry → aggregation marts → in‑app supervisor view + **web admin dashboard** (Company Admin) + **pseudonymized**, DPIA‑gated researcher cohort exports + **governed data‑sharing API** for home management platforms | **Closed loop:** session → structured data → trends → better interventions; operational evidence for CQC/families; **feeds existing care‑home tech stacks** — PII and Art. 9 health data governed end‑to‑end |


**Explicitly out of scope for v1 production:** biometric / Face ID linking, IoT smart‑room orchestration (lighting, VR, TV mirroring). Sessions start via **supervisor handoff** only. **Full multi‑vendor care‑home ERP integration** is post‑pilot — the funded programme includes **API contract design** and one exploratory partner connector, not a marketplace of pre‑built adapters on day one.

**Design principles baked in:** accessibility‑first (VoiceOver labels, Reduce‑Motion support), a deliberately non‑clinical tone ("a small pause — not a report card"), era‑personalised music, sensory calm throughout, **offline‑first** on the care floor (poor Wi‑Fi).

**Data sensitivity — PII & special‑category health data:**

NoteStalgia handles **personally identifiable information (PII)** and **special‑category health data** under GDPR Art. 9. This is not optional compliance polish — it shapes architecture, pilot ethics, and budget.


| Data held                                            | Sensitivity                      | POC today                       | Production target                                                                                                                       |
| ---------------------------------------------------- | -------------------------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Resident name, room, wing                            | PII (operational identifiers)    | Mock data in memory on one iPad | Server‑side roster only; devices never hold a full home/company list; every search **authorised, tenant‑scoped, and audit‑logged**      |
| Portraits & media                                    | PII                              | Bundled demo assets             | S3 (SSE‑KMS) + signed URLs; tenant‑isolated                                                                                             |
| Care‑context notes, sensory prefs, wellbeing ratings | PII + **Art. 9 health data**     | In‑memory mock profiles         | **Field‑level encryption** (MongoDB Queryable Encryption / CSFLE); per‑resident keys enabling **crypto‑shredding** on erasure           |
| Session telemetry & outcome scores                   | Health‑adjacent operational data | Local mock history              | Event‑first capture → aggregation marts; operational dashboards vs **pseudonymized** researcher exports are **separate governed paths** |
| Staff email, role, home assignments                  | Workforce PII                    | Mock supervisor roster          | Argon2id‑hashed PINs; assignment‑derived access; immutable audit log                                                                    |


**Key PII design decisions (production):**

- **Searchable vs encrypted split:** name, room, and wing are minimally‑sensitive operational fields — queryable only within strict home/company RBAC and with full audit; care notes and clinical narrative stay **encrypted and never indexed**.
- **No full‑roster on device:** the POC's client‑side name search (`CareRosterEngine`) is a UX demo only. At pilot scale, search is a **governed server‑side API** — a DSAR‑relevant access event every time staff look up a resident.
- **Research ≠ operations:** care‑home dashboards show identifiable residents within the tenant; **researcher cohort exports** are pseudonymized, DPIA‑ and consent‑gated, k‑anonymity suppressed, with every export audit‑logged. Erased residents drop out of future rollups via crypto‑shredding.
- **Automated rights:** DSAR (access, portability, erasure), retention‑as‑code, DPIA + Record of Processing (RoPA) maintained under `docs/compliance/`.
- **No biometrics:** authentication is email + PIN only — no Face ID or resident biometric linking.

**Production architecture (from implementation plan):**

- **Cloud:** AWS, primary region **eu‑west‑2 (London)** for UK data residency; EU regions for expansion.
- **Data:** **MongoDB Atlas** (sharded, zone‑pinned per tenant), Redis cache, S3 + CloudFront for media/portraits.
- **Compute:** **Kubernetes (EKS)**, GitOps‑managed; **.NET modular monolith** backend with DDD bounded contexts.
- **Clients:** modular **iOS** app (SPM) + **web admin dashboard** for home/company analytics, trend reporting, and staff onboarding.
- **Analytics:** event‑first capture → S3 data lake → **aggregation marts** (per‑resident, per‑home, per‑wing, cohort) → dashboard APIs + researcher exports + **tenant‑scoped data‑sharing API** (webhooks, partner connectors); feeds phased **recommender** (better playlists from what actually calms each resident).
- **Scale target:** entire UK market — **~17,000 care homes** — without re‑architecture; tenant = care‑home company.

**Production note (funding relevance):** The current proof‑of‑concept streams open/CC placeholder audio and stores **mock PII and health data on‑device** with **mock tenancy** — suitable for UX demos, **not** for a real pilot without a governed backend. A funded pilot requires: **licensed music streaming API**, the **hosted backend + Atlas + EKS stack** above, **server‑side roster search with PII audit logging**, **field‑level encryption (CSFLE) and crypto‑shredding**, researcher‑grade **pseudonymized export pipeline**, and **GDPR Art. 9** controls (consent, lawful basis, DSAR automation, retention, immutable audit) — core cost lines in any grant application and ethics/DPIA workstreams for the embedded researcher.

---

## 2. Deck A — NHS Grant Scheme

*Framing: innovation adoption, non‑pharmacological intervention, **workflow‑embedded data capture**, evidence generation through **longitudinal analytics**, and scalability across the care/health interface.*

### Slide 1 — Title

**NoteStalgia™ by Oscillomind**
Sound that takes you back.
*A non‑pharmacological calm & reminiscence platform for dementia and elderly care.*
[Applicant / contact / date]

### Slide 2 — The problem

- Agitation, anxiety and distress are among the most common and hardest‑to‑manage symptoms in dementia care.
- Antipsychotics remain over‑relied upon despite known harms; reducing inappropriate prescribing is a long‑standing NHS priority.
- Non‑pharmacological interventions (music, reminiscence, sensory) are evidence‑backed but inconsistently delivered — they depend on staff time, skill, and the right materials in the moment.
- **Supervisors lack a feedback loop:** when calm sessions work, the signal rarely becomes structured data — so homes cannot see trends, compare wings, or **adjust care plans and interventions** from evidence on the floor.

### Slide 3 — Why music & reminiscence

- Music reaches people when language and memory fade; autobiographical "peak years" music is especially powerful.
- Established benefits: reduced agitation, improved mood, increased engagement and lucid moments, better staff–resident connection.
- The gap is **delivery at scale and consistency** — and **turning every session into analytics** that improve the *next* intervention, not just the current moment.

### Slide 4 — Our solution

A single iPad app that **fits the supervisor shift**, lets residents *lead* a calm music experience, and **builds a longitudinal analytics layer** — so care teams see what calms whom and can act before distress escalates.

- **Resident surface:** touch‑first instrument glyphs, music‑reactive visuals, immersive nature "calm room" — no reading required.
- **Supervisor surface (workflow‑native):** email + PIN sign‑in → home picker → **curated roster** (pinned / recent / due / wing / search) → profile with **session history** → handoff → **four‑tap post‑session observation** — embedded in the existing round, not a separate admin burden.
- **Insights surface:** **Home Admin dashboard** (POC live) + production **web analytics** — trend charts, wing breakdown, residents improving vs needing attention, genre–wellbeing patterns — **actionable intelligence for care leads**.

### Slide 5 — Built for the supervisor shift (workflow integration)

- **Start of shift:** sign in, pick your home, see who is **pinned**, **recent**, or **due for a visit** — no hunting through paper lists.
- **Find anyone fast:** search by name, room, or wing; filter by wing; switch card/row view — designed for homes with hundreds of residents.
- **Before the session:** person‑centred profile shows preferences, playlists, and **what worked last time** (calm %, mood trend, genres engaged).
- **During:** resident leads; app captures **automatic telemetry** (tracks, genres, duration, immersive use) — zero extra supervisor taps.
- **After (~30 sec):** structured 1–10 observations (mood, alertness, emotional state, lucidity) + optional note — feeds analytics without feeling like a clinical form.
- **Handover & planning:** session history on the resident record; home dashboard surfaces **who to prioritise tomorrow**.

### Slide 6 — How it personalises (the differentiator)

- **Era‑matched discovery:** clips are ordered to each resident's peak listening years; residents respond with a simple traffic‑light smiley.
- Builds a tuned, individual playlist in minutes — works even for residents who can't self‑report.
- Person‑centred profile captures sensory preferences (light, scent, touch, onset gentleness) so each session fits the individual.
- **Roster intelligence:** staff see who needs a visit, who they work with often, and can find any resident by name or room in seconds — even across large homes.
- **Analytics‑informed playlists (production):** recommender learns from **genre ↔ wellbeing correlations** — sessions that calm a resident inform the next playlist choice.

### Slide 7 — Built‑in outcome measurement & analytics

Every session captures, with minimal staff effort:

- Sequential 1–10 ratings: **mood, alertness, emotional state, lucidity** (group adds **morale & engagement**).
- Objective telemetry: genres played, track changes, immersive entries, session duration.
- Longitudinal history per resident → a **wellbeing trend line**, not a one‑off note.
- **Home Admin dashboard (POC):** 14‑day KPIs, trend charts (sessions, reach, calm %, composite wellbeing), wing comparison, **improving vs needs‑attention** resident lists, recent session feed.
- **Production:** event‑first pipeline → aggregation marts → in‑app + web dashboards + **pseudonymized** researcher exports (DPIA‑gated, ethics‑approved, k‑anonymity).
*Closed loop: session → structured data → trends → better non‑pharma interventions — with PII and Art. 9 health data handled by design.*

### Slide 7a — From data to better treatment decisions

- **Individual level:** supervisors see calm % and mood trajectories before starting a session — **adjust music, timing, and sensory approach** based on what historically worked.
- **Wing / home level:** compare session reach and average wellbeing across wings — **target staff time** where residents are under‑served or trending down.
- **Intervention tuning:** correlate genre engagement with post‑session ratings — refine playlists and calm‑room use for residents who respond to specific stimuli.
- **Early warning:** "days since last session" and declining trend flags prompt **proactive outreach** before agitation incidents rise.
- **Prescribing conversations (exploratory):** longitudinal calm and wellbeing data supports **medication review discussions** where partner sites share PRN/prescribing data — primary evidence remains in‑app wellbeing trajectories.
- **Research path:** the same pipeline powers **pseudonymized cohort exports** for independent evaluation — one data model, two governed consumers.

### Slide 7c — Platform integrations & data‑sharing API
- **The problem:** care homes already use **home management software** (Nourish, Person Centred Software, Log my Care, Care Vision, etc.) for daily records, care plans, and CQC evidence. A standalone wellbeing app that **doesn't connect** becomes another silo supervisors ignore.
- **The answer:** NoteStalgia exposes a **governed data‑sharing API** — tenant‑scoped, audit‑logged, OAuth‑authenticated — so session outcomes and wellbeing trends **flow into the systems homes already run**.
- **What partners can pull:** per‑resident session summaries (calm %, mood/alertness/emotional/lucidity ratings, genres, duration); per‑home KPIs and wing breakdowns; "needs attention" flags — **structured data**, not a bulk PII export.
- **How it integrates:** read API for dashboards and BI; **webhooks** on session complete or trend threshold; optional **inbound resident ID sync** so NoteStalgia matches the home's canonical roster (DPIA + DPA required).
- **Pilot deliverable:** OpenAPI contract published in `notestalgia-contracts`; export endpoints live; **one exploratory integration** with a participating home's existing platform — proves the model without blocking core evaluation.
- **Post‑pilot:** connector programme for major UK care‑home vendors; commissioner‑facing aggregate feeds for ICB quality dashboards.
- **Governance:** same Consent & Privacy module as operational dashboards — every API call and webhook delivery **audit‑logged**; erasure via crypto‑shredding propagates to partner caches on schedule.

### Slide 7b — Data governance & resident privacy (PII)

- The platform processes **PII** (names, rooms, portraits, staff accounts) and **special‑category health data** (wellbeing ratings, care‑context notes, session outcomes) — **GDPR Art. 9 applies throughout**.
- **POC limitation:** today's prototype keeps mock resident data in memory on a single iPad with client‑side roster search. A real pilot **cannot** ship this way — resident data must live in a **UK‑pinned, tenant‑isolated hosted store** with encryption, access control, and audit.
- **Operational safeguards:** staff see only residents in their **assigned home(s)**; roster search runs **server‑side** (devices never download a full estate roster); every search and profile access is **audit‑logged**; sensitive fields are **field‑encrypted** and not searchable.
- **Research safeguards:** evaluation datasets use **pseudonymized exports** — no resident names in researcher files; small‑cell suppression; consent and **DPIA** sign‑off before any cohort extract; crypto‑shredding removes erased residents from future aggregates.
- **Rights & retention:** automated DSAR (access, portability, erasure), retention policies as code, immutable audit trail — owned by a dedicated **Consent & Privacy** module in the production backend.
- **No biometrics:** staff authenticate with work email + PIN only; residents start sessions via supervisor handoff — no Face ID or biometric resident linking.

### Slide 8 — Evidence‑generation plan (what the grant funds)

**Partners (to be confirmed at application):**

- **Academic / evaluation lead:** [University TBC] — independent protocol, ethics submission, and publishable outcomes report.
- **Pilot sites:** [N care homes TBC] — 5–8 homes under a single care‑home operator or regional group, with a named **clinical/quality sponsor** per site.
- **NHS / ICB interface (optional):** [ICB or social‑care commissioner TBC] — alignment with local dementia/agitation reduction priorities and adoption pathway conversations.

**18‑month programme timeline (sequenced — build before live resident data):**


| Phase                      | Months | Focus                                                                                                                                                                                     | Live resident PII?                 |
| -------------------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| **A — Build & governance** | 1–6    | Streaming API + licensed audio; **AWS/EKS + Atlas** backend; identity/RBAC; **Consent & Privacy** scaffold; CSFLE; server‑side roster search; event capture; ethics + **DPIA** submission | No — staging only                  |
| **B — Pilot deployment**   | 7–9    | Home onboarding, staff training, MDM rollout; **baseline window** (workflow adoption, pre‑intervention wellbeing where available); production go‑live at participating homes              | Yes — after ethics + DPIA sign‑off |
| **C — Active evaluation**  | 10–15  | Intervention delivery at scale; primary outcome collection; dashboard/analytics utilisation; fortnightly engineering support                                                              | Yes                                |
| **D — Dissemination**      | 16–18  | Analysis, evidence pack, open‑access publication, commissioner/NHS adoption conversations                                                                                                 | Pseudonymized exports only         |


**Outcome hierarchy (what the evaluation measures):**


| Tier                                  | Outcomes                                                                                                                                                                                          | How measured                                                                                                |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Primary**                           | Wellbeing trajectory (mood, alertness, emotional state, lucidity); session adoption & resident reach; supervisor workflow adoption (observation completion, roster usage); staff time per session | App auto‑capture + structured post‑session observations — **no manual charting**                            |
| **Secondary**                         | Home‑level calm % and composite wellbeing trends; genre ↔ wellbeing patterns; wing coverage gaps; family/staff satisfaction                                                                       | Home Admin dashboard + staff/family surveys                                                                 |
| **Exploratory** *(partner‑dependent)* | PRN use, agitation incidents, antipsychotic prescribing trends                                                                                                                                    | Only where pilot sites can share data via agreed **data‑sharing agreements** — not assumed in base protocol |


*Lean 12‑month variant:* compresses Phase A to months 1–4, Phase B to months 5–6, Phase C to months 7–10, Phase D to months 11–12 — with 3–5 homes and **~160 funded developer days** at £500/day. Higher delivery risk; recommended only if ethics/DPIA can be expedited with a committed academic partner.

Grant funding would cover six essential cost lines alongside pilot deployment:


| Cost line                                      | Why it is required                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Embedded researcher**                        | Independent evaluation design, **ethics/IRB for Art. 9 health data processing**, **DPIA co‑authorship**, pseudonymized data collection & analysis, and a publishable outcomes report. Budgeted at **0.5 FTE × 18 months (£45,000)** — enough for credible independent evaluation while the app auto‑captures most outcome data under governed export controls.                                                                                                                                                                                                                                                                                                                                                                                                      |
| **Product development (Oscillomind)**          | The prototype shell, UX, tenancy/roster POC, and outcome instrument exist; closing the **production gap** still requires sustained senior engineering through month 15: licensed streaming API, **AWS/EKS backend + MongoDB Atlas**, **server‑side PII‑aware roster search & audit**, **Consent & Privacy module** (CSFLE, DSAR, retention), **insights aggregation pipeline**, offline‑first iOS sync, web admin dashboard, and pilot‑floor hotfixes. Budgeted as **~220 funded professional days over 18 months at £500/day (£110,000)** — day‑rate model appropriate for a **founder‑led delivery** (not a classic payroll FTE); reflects **~6 hours/day sustained** engineering (~0.75 FTE equivalent) using standard UK grant day conventions (220 days/year). |
| **Licensed music streaming API**               | The current prototype uses open/CC placeholder streams for demonstration. A production pilot requires a **third‑party music streaming API with fully cleared, commercial‑use licences** (e.g. era‑matched catalogues, genre browsing, on‑demand playback). This is a recurring subscription cost for the pilot period and is non‑negotiable for safe, scalable deployment in care settings.                                                                                                                                                                                                                                                                                                                                                                         |
| **Cloud services**                             | Production pilot requires **AWS (eu‑west‑2)**: EKS, **MongoDB Atlas** (UK‑pinned, Queryable Encryption for PII fields), **KMS** key vault, Redis, S3/CloudFront, monitoring, backups, WAF — **plus AI development tooling** (estimated **Anthropic Claude** subscription for the lead developer during the build). The POC runs in‑memory on device with mock PII; a multi‑site study needs reliable, **GDPR Art. 9‑aligned** cloud ops for the pilot period.                                                                                                                                                                                                                                                                                                       |
| **Tech hardware (development & test devices)** | **£10,000** dedicated hardware budget for Oscillomind engineering: Mac development machines, test iPads covering multiple iOS versions/screen sizes, peripherals, and spare units for on‑site debugging — so integration, streaming, and pilot hotfixes are validated on real devices throughout the 18‑month build.                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **Pilot operations**                           | Site onboarding, staff training, travel to pilot homes, and a part‑time pilot coordinator during active data collection. Pilot sites use existing care‑home iPads where available; development hardware is separate from resident‑facing kit.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |


Without the researcher, licensed music infrastructure, **PII‑governed cloud hosting**, development hardware, and ongoing engineering, the project cannot move from **working prototype** to **evidence‑backed, legally compliant care intervention**.

### Slide 9 — Alignment with NHS priorities

- Reducing inappropriate antipsychotic prescribing in dementia — **exploratory** outcome where partner sites share medication data; primary evidence via wellbeing and calm trajectories that support review conversations.
- Personalised, person‑centred care — informed by **per‑resident analytics**, not generic playlists.
- Prevention and quality of life over medicalisation — **early‑warning trends** before incidents escalate.
- Digital innovation that is low‑cost, low‑training, and deployable on existing hardware — **embedded in supervisor workflow**, not a parallel system.
- **Interoperability:** governed **data‑sharing API** lets wellbeing outcomes feed **existing home management platforms** — reducing silo risk for adoption at scale.
- **Learning health system:** every session improves the next intervention through structured analytics.

### Slide 10 — Why now / why us

- Working, accessibility‑first prototype already built (iPad, iOS 17+) — including **org/home tenancy, email + PIN auth, curated roster, and Home Admin insights dashboard** in the POC.
- Architecture and delivery plan documented for **UK‑wide scale (~17,000 homes)** with **PII and GDPR Art. 9 controls designed in**, not bolted on — including field‑level encryption, server‑side roster governance, and pseudonymized research exports.
- Designed *with* care‑setting constraints in mind (low text, Reduce‑Motion, VoiceOver, gentle non‑clinical tone, **offline‑first**).
- Ready for a structured pilot — the grant accelerates evidence, licensing, cloud production, and evaluation — not basic app build.

### Slide 11 — The ask & use of funds

**Recommended ask: £220,000 over 18 months** (5–8 care homes)  
**Minimum viable pilot: £162,000 over 12 months** (3–5 care homes)


| Budget line                                            | Recommended (18 mo) | Min. viable (12 mo) | %           | Detail                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------------------------------------ | ------------------- | ------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Researcher (evaluation lead)**                       | **£45,000**         | **£32,000**         | ~20% / ~20% | 0.5 FTE × 18 months (recommended) or 0.4 FTE × 12 months (lean). Protocol, **ethics/IRB for special‑category health data**, **DPIA**, site liaison, analysis of **pseudonymized** cohort data, and publishable report. App auto‑capture reduces manual data entry — evaluation effort focused on interpretation, governance, and outcomes write‑up. Assumes ~£40k/year pro‑rata salary + ~20% on‑costs.                                                                                                                                                                                                                                         |
| **Product development — Oscillomind (lead developer)** | **£110,000**        | **£80,000**         | ~50% / ~49% | **~220 funded days × £500/day** (recommended, 18 mo) or **~160 funded days × £500/day** (lean, 12 mo). Founder‑led senior engineering on a **day‑rate basis** (~6 hours/day sustained, ~0.75 FTE equivalent) — standard for innovation grants when the lead is not on payroll. Covers: licensed streaming API integration; **.NET backend + iOS modularisation + web dashboard**; **MongoDB Atlas + CSFLE**; **server‑side PII‑aware roster search & audit**; **Consent & Privacy module**; **event/aggregation pipeline**; offline sync; pilot hotfixes through month 15. **Intervention delivery infrastructure**, not a one‑off integration. |
| **Licensed music streaming API**                       | £16,000             | £12,000             | ~7%         | B2B streaming subscription for commercial/care‑setting use across pilot homes (~£650–900/month × pilot duration), plus setup/onboarding fee and usage overage buffer. Provider TBD (e.g. 7digital, Tuned Global, or equivalent B2B catalogue API with cleared public‑performance/commercial terms).                                                                                                                                                                                                                                                                                                                                             |
| **Cloud services**                                     | **£11,000**         | **£6,500**          | ~5%         | **~£9,100** AWS EKS + **MongoDB Atlas** (UK region, Queryable Encryption tier), **KMS**, Redis, S3/CloudFront, monitoring, backups (~~£500/mo × 18 mo). **~~£900** estimated **Anthropic Claude** subscription for lead developer (Pro ~£20/mo × 18 mo, plus allowance for Max‑tier months during streaming/API integration). Lean: ~£5,520 hosting + ~£480 Claude Pro (12 mo).                                                                                                                                                                                                                                                                 |
| **Tech hardware (development & test devices)**         | **£10,000**         | £6,000              | ~5%         | Developer Mac, test iPads (multiple generations/screen sizes), cables, and spare units for field debugging. Required for streaming API integration, device‑specific QA, TestFlight builds, and on‑site pilot support — not resident‑facing deployment kit (pilot homes use existing iPads).                                                                                                                                                                                                                                                                                                                                                     |
| **Pilot deployment & operations**                      | £26,000             | £18,000             | ~12% / ~11% | 5–8 home rollout (months 7–15): travel & site visits (~~£5k), staff training & onboarding materials (~~£4k), part‑time pilot coordinator during active collection (~~£10–12k), MDM/app provisioning on homes' existing devices (~~£3k).                                                                                                                                                                                                                                                                                                                                                                                                         |
| **Contingency & dissemination**                        | £12,000             | £7,500              | ~5%         | Open‑access publication, conference presentation, ethics amendments, streaming tier upgrade if usage exceeds forecast, exploratory medication‑data agreements at partner sites.                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **Total**                                              | **£220,000**        | **£162,000**        | 100%        |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |


**What development time delivers (recommended budget — aligned to phased timeline):**

*Months 1–6 — Build & governance (no live resident PII):*

- Streaming API selection, licensing sign‑off, integration; replace POC placeholder audio.
- **AWS/EKS + Atlas** staging/production; identity (email + PIN, tenant RBAC).
- **DPIA + RoPA draft**; ethics/IRB submission with academic partner.
- **Consent & Privacy** module scaffold; **CSFLE** on sensitive profile fields.
- Server‑side PII‑aware roster search + audit; offline/cache + local outbox sync.
- Event capture for sessions/wellbeing; era‑matched discovery wired to licensed catalogue.

*Months 7–9 — Pilot deployment:*

- Home onboarding, staff training, MDM provisioning on existing iPads.
- Production go‑live; **baseline observation window** before full evaluation metrics.
- Initial aggregation marts + in‑app Home Admin dashboard fed from live data.

*Months 10–15 — Active evaluation (developer on hotfix/support cadence):*

- Web dashboard + genre–wellbeing correlation views; pseudonymized researcher export path; **data‑sharing API v1 + partner connector spike**.
- Fortnightly releases; incident response; accessibility fixes from the floor.
- Primary outcome collection runs across all pilot homes.

*Months 16–18 — Dissemination (engineering winds down):*

- Security review, DPIA maintenance, cost control, handover documentation.
- Researcher-led analysis and evidence pack; no new feature scope.

**Deliverables:**

- Multi‑site pilot across 5–8 care homes with **licensed music live in app** (from month 7).
- **Hosted, tenant‑isolated backend** (UK data residency) replacing on‑device mock PII.
- **DPIA + Record of Processing (RoPA)** for pilot data flows.
- Independent evaluation led by embedded researcher + academic partner (ethics‑approved **pseudonymized** dataset).
- **Primary outcome report:** wellbeing trajectories, adoption, workflow fit, staff time.
- **Data‑sharing API v1** (OpenAPI contract + audit‑logged export endpoints) and **one exploratory home‑management platform integration**.
- **Secondary/exploratory outcomes** where partner data allows (PRN/incidents — explicitly partner‑dependent).
- Peer‑shareable evidence pack suitable for NHS/social‑care adoption conversations.

**Outcome:** an evidence‑based, **legally compliant**, scalable non‑pharmacological tool ready for wider NHS and care‑sector adoption.

> **Stretch target (£260,000):** 10 homes, researcher at 0.7–1.0 FTE, **+40 funded engineering days** (£20k) for accelerated web dashboard / CSFLE hardening, enterprise streaming tier, higher cloud tier, expanded dev/test device pool — suitable for a larger NIHR/iCB innovation grant or multi‑region study.

### Slide 12 — Vision

From "calm in the moment" to a **data‑informed, measurable** standard of person‑centred reminiscence care — where every supervisor shift builds intelligence that improves the next intervention, **and outcomes flow into the home management tools operators already trust** — across the UK's **~17,000 care homes** and beyond.

---

## 3. Deck B — Care UK Board

*Framing: operational impact, **supervisor workflow fit**, **data‑driven care intelligence**, quality ratings, staff experience, risk reduction, and commercial rollout.*

### Slide 1 — Title

**NoteStalgia™ by Oscillomind**
Sound that takes you back.
*Person‑centred calm & reminiscence — ready to pilot across Care UK homes.*
[Presenter / date]

### Slide 2 — The operational challenge

- Resident agitation and distress drive incidents, staff strain, and family concern.
- Non‑pharmacological calm techniques work — but are inconsistent and time‑hungry to deliver well.
- Quality regulators and families increasingly expect demonstrable, person‑centred wellbeing — not just compliance.
- **Supervisor workflows are already full:** any new tool must fit sign‑in → rounds → handover — not add another system to maintain.
- **Outcomes stay invisible:** without structured session data and home‑level analytics, managers cannot see which wings need support, which residents are improving, or **which interventions to scale**.
- Large estates need tools that work **per home, per wing, and company‑wide** — without leaking data between operators or exposing **resident PII** beyond authorised staff.

### Slide 3 — What NoteStalgia™ delivers

- A single iPad turns any room into a personalised calm space — **embedded in the supervisor's existing shift**.
- Residents lead the experience; staff facilitate in minutes, not hours.
- Every session quietly produces a **structured wellbeing record + automatic telemetry** — not a forgotten free‑text note.
- **Home Admin analytics (POC live):** 14‑day trend charts, wing breakdown, KPIs, improving vs needs‑attention residents — **management visibility without manual charting**.
- **Closed loop:** session data → trends → **better care plans, staffing decisions, and non‑pharma interventions**.
- **Plugs into your stack:** production **data‑sharing API** pushes session and wellbeing summaries into **existing home management platforms** (Nourish, PCS, Log my Care, etc.) — supervisors don't maintain a parallel record.
- **Built for your estate structure:** company tenancy, home‑scoped rosters, role‑based access, company admin dashboard — **resident PII and wellbeing data never cross tenant boundaries**.

### Slide 4 — Resident experience (demo)

- Touch‑first instrument glyphs — tap an icon, music plays instantly.
- Music‑reactive orb and immersive nature "calm room."
- No reading, no menus, no clinical feel — designed for dementia and low‑mobility residents.
- Sessions start via **supervisor handoff** — simple, consent‑aware, no biometrics, no resident PII on the low‑text surface beyond what staff have already authorised.

### Slide 5 — Staff experience & workflow fit (demo)

- **Work email + PIN** sign‑in → pick your home (if you cover several) → **curated roster** built for the shift: **pinned**, **recent**, **due for visit**, wing filter, **server‑side name search** (production).
- **Find residents in seconds** — not a separate admin task; search by name, room, or wing while on the floor.
- Person‑centred profiles with curated playlists, discovery calibration, and **session history + wellbeing trends** — see what worked last time before handoff.
- Post‑session feedback is **four taps and an optional note** (~30 sec) — structured observations that feed analytics, not a clinical assessment form.
- **Offline‑first:** sessions continue when Wi‑Fi drops; telemetry syncs when back online — analytics stay complete.

### Slide 5a — Analytics & care intelligence

- **Home Admin dashboard (in POC today):** rolling 14‑day view with KPI cards, trend graphs (sessions, residents reached, calm %, composite wellbeing), wing comparison, and recent session feed.
- **Resident impact lists:** surfaces **improving** residents (positive highlights) and those **needing attention** (declining trends, days since last session).
- **Treatment relevance:** supervisors and care leads see **genre engagement vs calm/mood outcomes** — refine playlists and calm‑room use per resident.
- **Wing‑level insight:** compare which areas of the home are under‑served — inform **staff allocation and activity planning**.
- **Production web dashboard:** Company Admin gets estate‑wide drill‑down, CSV/PDF export, and cross‑home benchmarks — all tenant‑scoped.
- **No manual charting:** the app captures telemetry automatically; supervisors add only lightweight structured observations.

### Slide 5b — Integrates with your existing home management tech
- Care UK already runs **Nourish, Person Centred Software, Log my Care**, or similar — daily logs, care plans, medication records, and CQC evidence live there today.
- NoteStalgia **does not ask you to rip and replace** your system of record. It captures reminiscence and calm outcomes on the iPad, then **pushes structured summaries back** via a governed API.
- **What your platform receives:** session date/time, calm %, wellbeing ratings, genres engaged, duration, optional supervisor note — appended to the **resident's existing record** (subject to integration agreement).
- **What IT gets:** OpenAPI‑documented endpoints, OAuth client credentials per tenant, webhook subscriptions, immutable audit log — **enterprise‑grade, not a bespoke CSV email**.
- **Pilot ask:** nominate one home already on a supported platform; we deliver **one live connector** during the pilot to prove end‑to‑end flow.
- **Commercial upside:** wellbeing data enriches the **care plans and quality evidence you already maintain** — stronger CQC narrative, less double‑entry for supervisors.

### Slide 6 — Operational benefits

- **Reduced agitation** → fewer incidents, calmer floors, lower antipsychotic reliance — with **trend data** to evidence improvement.
- **Staff time saved** → roster navigation, personalisation, and outcome capture are near‑automatic — **fits the existing shift**, no parallel charting system.
- **Data‑informed care planning** → longitudinal calm % and wellbeing trajectories on each resident profile; home dashboard flags who needs outreach.
- **Better family confidence** → visible, individualised engagement and **measurable progress over time**.
- **Management visibility** → wing comparison, session reach KPIs, early‑warning trends — **act before quality dips show up in inspections**.
- **Differentiated offer** → a modern, premium, **analytics‑backed** wellbeing experience across the estate.
- **Lower integration tax** → API‑first design means outcomes land in **systems staff already use** — faster adoption, less change fatigue.

### Slide 7 — Quality, compliance & data protection (PII)

- Built‑in, longitudinal wellbeing data (mood, alertness, emotional state, lucidity, engagement) — **special‑category health data under GDPR Art. 9** — captured as part of the **normal supervisor workflow**, not a separate audit exercise.
- Supports person‑centred care plans and CQC evidence of responsive, effective, caring service — with **trend charts and wing breakdowns** care leads can show inspectors and families.
- **PII by design:**
  - Resident names, rooms, portraits, and care notes are **tenant‑isolated** — one care company never sees another's data.
  - **Field‑level encryption** on sensitive profile and clinical narrative fields; **crypto‑shredding** on erasure.
  - **Server‑side roster search** with audit logging — every name lookup is traceable for governance and DSAR.
  - Staff see only residents in their **assigned home(s)**; temporary cover follows assignment windows automatically.
- **GDPR Art. 9 controls:** lawful basis + consent records, immutable audit log, automated DSAR (access/portability/erasure), retention policies, UK data residency (**AWS eu‑west‑2**).
- **POC vs production:** today's demo stores mock resident data on a single iPad; estate rollout requires the hosted, encrypted backend — budgeted in the pilot plan.
- Accessibility‑first (VoiceOver, Reduce‑Motion, low‑text).

### Slide 8 — Group sessions = activities, scaled

- Auto‑compiles a shared playlist from residents' best‑loved tracks **within the current home**.
- Turns reminiscence into a repeatable group activity with measured morale/engagement.
- Maximises impact per staff hour.

### Slide 9 — Fits your estate

- Runs on standard iPads — minimal hardware investment.
- **Multi‑home, multi‑wing** from one company tenant; staff see only what they're assigned to.
- **Supervisor workflow native:** sign‑in → roster → session → observation — the same rhythm staff already follow, with analytics accumulating automatically.
- **Web admin dashboard** (Company Admin): estate trends, wing comparison, resident drill‑down, exports, staff invites — scoped to Care UK data only; **no cross‑operator PII exposure**.
- **Data‑sharing API:** production roadmap includes **push to your home management platform** — session outcomes without duplicate data entry.
- Light‑touch training; designed for real care‑floor conditions — **adoption measured via roster search, session volume, and dashboard usage**.

### Slide 10 — Rollout plan

- **Pilot:** 3–5 homes, 8–12 weeks; success metrics agreed up front (incidents, PRN use, staff feedback, family NPS, **dashboard adoption, session reach per wing, wellbeing trend direction**). **DPIA and data‑processing agreement** signed before live resident data.
- **Scale:** phased estate rollout with a simple per‑home licence; architecture sized for **full UK market** without re‑build.
- **Support:** onboarding, content updates, **analytics training for Home Admins**, outcome dashboards, staff onboarding workflow.

### Slide 11 — Commercials

- Per‑home / per‑bed annual subscription [model TBD].
- Low capex (existing devices), predictable opex.
- ROI levers: incident reduction, agency/medication savings, occupancy via differentiation, quality‑rating uplift — **supported by home‑level analytics**, not anecdotal case studies.
- **Integration revenue / stickiness:** API connectors and estate‑wide data feeds increase switching costs for operators who embed NoteStalgia outcomes in their **existing care‑plan workflow**.

### Slide 12 — The ask

- Approve a **paid pilot** across [N] homes with agreed success metrics.
- Nominate a clinical/quality sponsor and pilot sites.
- Target decision: estate‑wide rollout on a successful pilot.

### Slide 13 — Vision

A calmer, more connected daily life for every resident — and a **data‑informed, measurable** standard of person‑centred care for Care UK, where supervisor workflows, analytics, and **your existing home management platforms** work together to improve every intervention.

---

### Appendix — proof points to gather during pilot

- Agitation / incident frequency (pre vs. during).
- PRN and antipsychotic administration trends.
- Wellbeing scores over time (per resident, per home).
- Staff time per session and staff satisfaction.
- Family feedback / NPS.
- Session frequency, genre engagement, immersive uptake.
- **Workflow adoption:** roster search usage, pinned/due‑list engagement, post‑session observation completion rate.
- **Analytics utilisation:** Home Admin dashboard logins, wing comparison reviews, attention‑list follow‑through (sessions scheduled for flagged residents).
- **Treatment signals:** genre ↔ wellbeing correlation shifts; residents moved from "needs attention" to "improving" on dashboard.
- **Data governance:** audit log review (roster searches, exports), DSAR drill, staff training completion on PII handling.

### Appendix — analytics metrics (standardised definitions)


| Metric                       | Grain                | Workflow / treatment use                                               |
| ---------------------------- | -------------------- | ---------------------------------------------------------------------- |
| Session count & reach        | Home, wing, resident | Are we serving enough residents? Which wings are under‑visited?        |
| Average calm %               | Home, wing, resident | Is the intervention reducing distress over time?                       |
| Composite wellbeing score    | Home, wing, resident | Mood + alertness + emotional + lucidity trend — care‑plan review input |
| Days since last session      | Resident             | Due‑list / outreach prioritisation                                     |
| Genre uptake & skip rate     | Resident, home       | Refine playlists; identify what calms whom                             |
| Immersive calm‑room entries  | Resident, session    | Sensory intervention effectiveness                                     |
| Improving vs needs‑attention | Resident lists       | Home Admin daily prioritisation                                        |
| Group morale & engagement    | Home, session        | Activities programme effectiveness                                     |


### Appendix — data‑sharing API & integration targets (production roadmap)


| Integration type | Examples | Data exchanged (governed) | Pilot / post‑pilot |
|---|---|---|---|
| **Care management (daily records)** | Nourish, Person Centred Software (mCare), Log my Care, Care Vision, CarePlanner | Session summary, wellbeing ratings, calm %, genres, duration → resident daily log | Pilot: **1 exploratory connector**; post‑pilot: vendor programme |
| **Estate BI / reporting** | Power BI, Looker, in‑house data warehouse | Aggregated home/wing KPIs, trend series | Pilot: CSV + API export; post‑pilot: scheduled feeds |
| **Commissioner / ICB dashboards** | Regional quality boards | Pseudonymized or aggregated cohort metrics (DPIA‑gated) | Post‑pilot |
| **Inbound roster sync** | Same care‑management vendors | External resident ID, room, wing, active flag (read‑only) | Post‑pilot (optional; reduces duplicate entry) |

**API design principles:** tenant‑scoped OAuth; OpenAPI in `notestalgia-contracts`; immutable audit log per request; rate limits; no cross‑operator access; erasure propagates on crypto‑shred; webhooks signed and retryable.

### Appendix — PII & data‑governance assumptions


| Topic                 | Assumption                                                                                                           |
| --------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Data categories       | Resident PII (name, room, wing, portrait) + **Art. 9 health data** (wellbeing ratings, care notes, session outcomes) |
| POC posture           | Mock data in memory on one iPad — **not production‑grade**                                                           |
| Production encryption | MongoDB Queryable Encryption (CSFLE) on sensitive fields; AWS KMS key vault; per‑resident keys for crypto‑shredding  |
| Roster search         | Server‑side only at pilot; client holds current view + cached pinned/recent — **not** full home/company roster       |
| Searchable fields     | Name, room, wing (within tenant/home RBAC + audit); care notes and clinical narrative **never indexed**              |
| Research exports      | Pseudonymized, DPIA‑gated, k‑anonymity suppressed, ethics‑approved — separate from operational dashboards            |
| Staff auth            | Email + PIN (Argon2id); no biometrics                                                                                |
| Residency             | UK primary (`eu-west-2`); tenant data zone‑pinned                                                                    |
| Compliance artefacts  | DPIA + RoPA maintained in `docs/compliance/`                                                                         |
| API / partner access  | OAuth per tenant; audit log per API call and webhook; separate from researcher export path; erasure propagates on crypto‑shred |


### Appendix — budget assumptions (UK, 2026)


| Assumption                                          | Value used                                                                 |
| --------------------------------------------------- | -------------------------------------------------------------------------- |
| Researcher salary (pro‑rata, excl. on‑costs)        | ~£38–42k/year FTE                                                          |
| Researcher budget (recommended / lean)              | **£45,000** (0.5 FTE × 18 mo) / **£32,000** (0.4 FTE × 12 mo)              |
| Employer on‑costs (NI, pension)                     | ~20%                                                                       |
| Lead developer day rate                             | **£500/day** (senior full‑stack iOS + backend + compliance‑aware delivery) |
| Developer funded days (recommended / lean)          | **~220 days** (18 mo) / **~160 days** (12 mo)                              |
| Developer effort equivalent                         | **~6 hours/day sustained** (~0.75 FTE — not claimed as 1.0 FTE)            |
| Developer budget (recommended ask)                  | **£110,000** (220 × £500)                                                  |
| Developer budget (lean ask)                         | **£80,000** (160 × £500)                                                   |
| Developer annualised equivalent                     | **~£88k/year** pro‑rata (220 days ≈ 1.0 grant years × 0.75 effort)         |
| Recommended total ask                               | **£220,000** over 18 months                                                |
| Lean total ask                                      | **£162,000** over 12 months                                                |
| Music API (B2B commercial tier)                     | ~£650–900/month + setup                                                    |
| Cloud services (AWS EKS + MongoDB Atlas, UK region) | ~£500/month × pilot duration                                               |
| Anthropic Claude subscription (lead developer)      | **~£900** recommended (18 mo) / **~£480** lean (12 mo Pro)                 |
| Tech hardware (dev Mac, test iPads, peripherals)    | **£10,000** recommended / £6,000 lean                                      |
| Pilot homes (recommended / lean)                    | 5–8 / 3–5                                                                  |
| Pilot duration (recommended / lean)                 | 18 / 12 months                                                             |
| Production scale target                             | ~17,000 UK care homes (tenant = care‑home company)                         |


**Why development is ~50% of the ask:** The app shell, UX, **tenancy/roster POC**, and outcome‑capture instrument already exist — but the **production gap** still needs **~220 funded engineering days** over 18 months. Budgeted at **£500/day** on a founder‑led day‑rate basis (~6 hours/day sustained, ~0.75 FTE equivalent) — the standard innovation‑grant model when the lead developer is not a payroll employee. This funds: legal music, **AWS/EKS + Atlas backend with PII field encryption**, **server‑side roster search & audit**, **Consent & Privacy module**, **insights aggregation**, web dashboard, offline sync, and pilot‑floor stability from month 7 onward. Under‑budgeting here is the most common reason digital health pilots fail after a promising demo.

**Developer day‑rate (£110,000 = 220 days × £500):** £500/day is market‑rate for senior mobile + backend delivery in the UK; 220 days uses the standard grant convention of a **220‑day professional year** applied across 18 months at ~0.75 effort. Funders can audit delivery against a simple day log tied to the phased timeline (build → deploy → support → handover). Not presented as 1.0 FTE payroll.

**Researcher (£45,000):** Budgeted at 0.5 FTE — appropriate for a feasibility pilot where the app auto‑captures **primary outcomes** (wellbeing, adoption, telemetry), leaving the evaluator to focus on protocol, **ethics for Art. 9 data**, **DPIA**, site liaison, analysis of pseudonymized cohorts, and the evidence report. **Exploratory medication/incident outcomes** are partner‑dependent and not assumed in the base protocol.

**Cloud services (~£11,000):** The POC stores mock PII on‑device only. A multi‑site pilot needs a secure hosted layer on **AWS (eu‑west‑2)** with **MongoDB Atlas** (tenant‑sharded, UK‑pinned, **Queryable Encryption** for sensitive fields), **KMS**, EKS, Redis, S3/CloudFront, researcher exports, audio caching, and uptime monitoring — with GDPR Art. 9 controls and backup in line with care‑setting expectations (~£9,100 over 18 months). Also includes an estimated **£900 Anthropic Claude** subscription for the lead developer (Pro at ~£20/month, with headroom for Max‑tier months during peak streaming/API integration work).

**Tech hardware (£10,000):** Engineering and QA kit for Oscillomind — development Mac(s), test iPads across iOS versions and screen sizes, and spare units for on‑site debugging during the pilot. This is **not** resident deployment hardware; pilot homes run on existing care‑home iPads, while the developer maintains a dedicated test fleet to ship reliable builds.

*Note: clinical outcome claims should be substantiated by the pilot/evaluation. This prototype is pilot‑ready and already captures the data needed to evidence impact — but **live resident PII must not be processed until the hosted, encrypted backend and DPIA are in place**. Final figures should be adjusted once streaming provider, cloud vendor, dev hardware quotes, and researcher host institution costs are confirmed. Engineering detail: see `[IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)`.*