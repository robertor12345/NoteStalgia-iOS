# Organisation & home onboarding — plan (28 Oct 2026, not started)

How a care company and its homes get onto NoteStalgia without an engineer seeding them. Today a care
company exists only if `POST /v1/admin/seed` created it (demo data, seed token); households self-serve
(`/auth/household-signup`); staff invites are planned for the production web dashboard
(`docs/IMPLEMENTATION_PLAN.md` §6, todo `staff-onboarding`). This plan fills the gap in front of those:
**request → verify → approve → activate → set up the organisation → add homes → invite staff → bring
residents → set up devices → ready**. It is written to be built on the POC Worker first and carried into
the .NET backend unchanged in shape.

Status (28 Oct 2026): **implemented on the Worker and the iPad** — slice A in full and most of slice B (CSV import
on device with a sample spreadsheet, domain claims by email code, suspend / restore / remove / admin PIN reset,
device registration, the Ready checklist with nudges, audit trail). Not yet: DNS-TXT domains, per-home export,
real mail (Resend is wired behind `RESEND_API_KEY` + `EMAIL_FROM`; the demo deployment exposes codes instead),
the operator console beyond `scripts/org-requests.ts`. Details and file map: `docs/HANDOFF_PLAN.md` ("Organisation
& home onboarding"). Android: nothing yet — invite acceptance first when it starts.

---

## 1. Principles

1. **One tenancy model.** An organisation is a `careCompany` tenant; homes are `homes`; people are
   `accounts` with `supervisor` / `homeLead` / `orgAdmin` roles. No parallel "customer" objects.
2. **Invite-first for B2B.** Staff never self-register; the only way into an organisation is an invite from
   an admin (or being the person who requested the workspace). Household self-serve stays the one open door.
3. **Verify before activate.** Work email verified by one-time code; organisation approved by a NoteStalgia
   operator before anyone can push resident data (B2B is invoiced and carries special-category data).
4. **Least privilege, assignments not fields.** Home access follows assignments (today `home_ids_json`,
   later the assignments table in §5 of the implementation plan); an org admin spans the organisation.
5. **Everything audited.** Requests, approvals, invites, acceptances, role and home changes, domain claims,
   consent acceptances, suspensions: append-only, actor + time + IP.
6. **Works on the iPad.** The POC has no web app, so the wizard is an iPad flow for the org admin; in
   production the same steps move to `notestalgia-web` and the iPad keeps invite acceptance, device setup
   and the home lead's lighter admin.
7. **Same visual grammar.** Cards, section headers, inset tiles, chips and the accessible segmented choice
   from `Core/BrandDataDisplay.swift`; Back top-left, Log out top-right; every step a VoiceOver header.

---

## 2. People in the flow

| Who | What they do | Role on file |
|---|---|---|
| **Requester** | Asks for a workspace from the sign-in screen; usually a registered manager or operations lead | becomes `orgAdmin` on activation |
| **NoteStalgia operator** | Approves (or declines) the request, sets the plan / trial, can later suspend | internal — operator token, not a tenant account |
| **Org admin** | Organisation profile, domains, homes, invites, residents import, device guidance, exports, offboarding | `orgAdmin` |
| **Home lead** | Invites supervisors for their home, imports that home's residents, sees the dashboard | `homeLead` |
| **Supervisor** | Accepts an invite, sets a PIN, runs sessions | `supervisor` |

---

## 3. The flow, stage by stage

### Stage 0 — Request a workspace (sign-in screen)

Entry: a third link under the sign-in card, beside the household one:
*"Setting up a care home or organisation? Request a workspace."*

Form (one card, same fields style as the Care at home sign-up):

- Organisation name · your name · **work email** · phone (optional) · your role (registered manager /
  operations / IT / other) · how many homes (1 / 2–5 / 6+) · CQC provider ID (optional; UK only, validated
  as `1-` + 9–10 digits) · anything we should know (optional).
- Consent line: "We'll use these details to set up your workspace and contact you about it" → stored as a
  consent record with version and time.

Submit → `POST /v1/auth/org-request` → **202** always (no enumeration). A six-digit code is sent to the work
email (see §7 for how the POC sends mail). Screen: "Check your email" → code entry (`SixDigitPinInput`
with label "Verification code") → `POST /v1/auth/org-request/verify`.

Rules: a work email on a domain already verified by another organisation is refused with that
organisation's name ("Sunrise Care already uses this domain — ask your admin for an invite"). Free-mail
domains (gmail, outlook, icloud…) are allowed but flagged `needsManualDomainCheck` for the operator. Rate
limits per IP and per email; disposable-email denylist.

After verification: "Thanks — we check every organisation by hand. You'll hear from us within one working
day." The request sits in `org_requests` as `verified`.

### Stage 1 — Approval and activation

Operator reviews the request (POC: `scripts/org-requests.ts list | approve <id> | decline <id> --reason`,
calling an operator route guarded by the existing seed-token pattern; production: an operator page in
`notestalgia-web`). Approval sets plan (`trial` 30 days / `standard`), seat allowance per home and the
data region (`weur` for UK), then emails the requester an **activation link + code** (single use, 7 days).

Activation in the app: sign-in screen → *"I have an activation code"* → email + code →
`POST /v1/auth/org-activate` creates, in one batch, the `tenant` (`careCompany`, `status: active`), the
requester's `orgAdmin` account (PIN chosen on the same screen, hashed with the live pepper), the
organisation's first consent records (DPA + terms, versioned), and the audit entries; returns a token pair
like household sign-up does. The app lands on the **setup wizard** (Stage 2).

Declines email a reason; the request is kept 90 days then deleted.

### Stage 2 — Organisation profile

Wizard step 1 of 6 ("Your organisation"):

- Name, trading name (optional), address and postcode, CQC provider ID (prefilled), data region (read-only:
  United Kingdom), a short privacy statement of what is stored and where.
- **Verified domains**: the requester's email domain is claimed automatically once verified (unless free
  mail). Further domains: enter → verify by a code emailed to `postmaster@` / `admin@` **or** a DNS TXT
  record (`_notestalgia.<domain>`); the Worker checks TXT via DNS-over-HTTPS. A verified domain makes
  household sign-ups on it refuse and point to staff sign-in (today's `tenant_domains` rule, now real).
- Settings (defaults, editable later): PIN re-prompt after idle (shared iPads), session retention (plan §7),
  whether home leads may invite staff, whether supervisors may add residents.

### Stage 3 — Homes

Wizard step 2 ("Your homes"):

- Add a home: name, CQC location ID (optional, `1-` + digits), address/postcode, capacity (beds), wings
  with suggested defaults (Residential · Memory care · Day programme; add/rename/remove; min one wing).
- Name the **home lead**: an email → an invite is queued (Stage 4) with role `homeLead` for that home; or
  "that's me" (the org admin takes the lead role on this home too).
- A home is `status: settingUp` until its first resident or staff member exists, then `active`. Archive later.
- Sync: `/me` already returns homes from `home_ids_json`; a new home is appended to the admin's list and
  shows in the home picker on the next `/me` refresh (the app refreshes the principal after each wizard step).

### Stage 4 — Staff

Wizard step 3 ("Your team"), also the standing *Team* screen afterwards:

- Invite one: email, display name (optional), role (supervisor / home lead), homes (one or more), optional
  **end date** for temporary cover (closes access automatically).
- Invite many: paste emails (one per line) or CSV (`email,name,role,home`) → preview → send.
- Each invite: 32 random bytes, stored as a SHA-256 hash, **single use, 7 days**, resend creates a new
  token and voids the old one, revoke before acceptance. The email carries a deep link
  (`notestalgia://invite?code=…`) and the code itself for typing.
- Pending / accepted / expired lists with resend and revoke. Seat allowance from the plan is a soft warning
  in the POC (hard stop in production billing).

**Acceptance on the iPad** (the supervisor's first contact with the app):
sign-in screen → *"I have an invite code"* → email + code → `POST /v1/auth/invite/accept` → choose and
confirm a 6-digit PIN → acknowledge the data-handling terms (one screen, versioned consent record;
training acknowledgement if the organisation turned it on) → account `active`, token pair issued,
roster opens. The invite email must match the account email (case-insensitive); a mismatch is a plain
"That code doesn't match this email", never "the code is for someone else".

Offboarding is the same screen in reverse: suspend (keeps data, revokes refresh tokens, closes assignments)
or remove (anonymises the account, keeps session authorship as "former staff member").

### Stage 5 — Residents

Wizard step 4 ("Residents"), per home:

- **Add one** — today's path (new resident → discovery → save), unchanged.
- **Import from a spreadsheet** — CSV picked with the Files picker (`UIDocumentPickerViewController`):
  columns `name, room, wing, date_of_birth|age, nationality, favourite_genre, notes`; a preview table with
  per-row validation (unknown wing → pick one, missing age → required, duplicate name + room → skip or
  keep), then import. Rows become residents with `isProvisional: false`, `discoveryDone: false`, and the
  usual Codable JSON, pushed through **the existing sync push** (`/sync/push`, idempotent upserts) so nothing
  new touches the resident wire shape. A template CSV is offered to download.
- Later (production, plan §9): pull from care-planning systems through the interoperability API.
- Every imported resident shows on the roster with a "Discovery not yet run" hint; the first-week nudge
  (Stage 7) lists them.

### Stage 6 — Devices

Wizard step 5 ("The iPads"), guidance rather than enforcement in the POC:

- Shared iPad on the floor: Guided Access for resident sessions, auto-lock, no personal accounts, the app's
  idle PIN re-prompt (setting from Stage 2).
- Managed deployment: Apple Business Manager + a supervised iPad profile per home, MDM-pushed app, lost-mode;
  a checklist with links, not an integration.
- Optional **device registration** (`devices` table: id, tenant, home, label, model, first seen, last seen):
  "This iPad belongs to Maple Lodge · Day programme" shown on the welcome screen and in the admin's device
  list, so a tablet found in the wrong wing can be identified. Registration is a tap on the iPad while signed
  in as an admin or home lead; no MDM dependency.

### Stage 7 — Ready

Wizard step 6 ("Ready"): a checklist card with live state — organisation ✓ · N homes ✓ · N invites sent,
M accepted · N residents (K without discovery) · devices registered — plus **"Try a demo session"** (a
seeded sandbox resident, clearly labelled, deleted when the first real resident exists) and the home lead's
dashboard link. The checklist stays as a card on the org admin's dashboard until every line is ticked, then
collapses to "Set up complete on <date>".

First-week nudges (the planner's nudge style, on the roster): "3 residents haven't had a discovery pass",
"Margaret's invite expires tomorrow", "Add a home lead for Riverside House".

### Ongoing administration (after onboarding)

Organisation: profile, domains, settings, consents and DPA versions, **export** (per home, CSV + JSON),
**suspend / delete organisation** (operator-confirmed; crypto-shred after the plan §7 grace window).
Homes: edit, archive (residents must be moved or archived first). Team: invite, change role/homes,
temporary cover, suspend, remove, admin-initiated PIN reset. Audit: a filterable list, exportable.

---

## 4. Data model (D1 now, Mongo later — same names)

New tables, all ids lowercase UUIDs, ISO-8601 timestamps, `tenant_id` on everything tenant-scoped:

```
org_requests  (id, org_name, requester_name, email, email_domain, phone, role, homes_band,
               cqc_provider_id, notes, status: pending|verified|approved|declined|activated,
               verify_code_hash, verify_expires_at, verify_attempts, activation_hash,
               activation_expires_at, needs_manual_domain_check, plan, region, decided_by,
               decided_at, decline_reason, created_at)
invites       (id, tenant_id, email, display_name, role, home_ids_json, ends_at, token_hash,
               expires_at, status: pending|accepted|revoked|expired, invited_by, accepted_account_id,
               created_at, accepted_at)
domain_claims (domain PK, tenant_id, method: email|dns|auto, token_hash, verified_at, created_at)
consents      (id, tenant_id, account_id, kind: dpa|terms|training|request_contact, version,
               accepted_at, ip, user_agent)
audit_log     (id, tenant_id, actor_account_id, actor_kind: account|operator|system, action,
               subject_kind, subject_id, details_json, ip, at)   -- append only, no UPDATE/DELETE
devices       (id, tenant_id, home_id, label, model, os, first_seen_at, last_seen_at, registered_by)
```

Column additions: `tenants(status: pending|active|suspended|deleted, cqc_provider_id, address_json,
settings_json, plan, trial_ends_at, region)`, `homes(status, cqc_location_id, address_json, capacity)`,
`accounts(status: invited|active|suspended|removed, invited_by, activated_at, access_ends_at)`.
`tenant_domains` is replaced by `domain_claims` (a view keeps the old name for the sign-up check).

Migration `0004_onboarding.sql`. The resident / session / group-session wire shapes do not change
(`WireSchema.version` stays), because residents arrive through the existing push.

---

## 5. API (contract additions, `contracts/openapi.yaml`)

Public (no auth, rate-limited, non-enumerating):

- `POST /v1/auth/org-request` → 202 · `POST /v1/auth/org-request/verify {email, code}` → 204
- `POST /v1/auth/org-activate {email, code, pin, acceptedVersions}` → 201 token pair (+ principal)
- `POST /v1/auth/invite/accept {email, code, pin, acceptedVersions}` → 201 token pair
- `GET /v1/auth/invite/preview?code=` → `{orgName, homeNames, role, expiresAt}` for the acceptance screen
  (only with a valid, unexpired code; otherwise 404 with a neutral message)

Operator (seed-token pattern, later the operator role in the web app):

- `GET /v1/operator/org-requests` · `POST /v1/operator/org-requests/{id}/approve {plan, region, seats}` ·
  `POST …/decline {reason}` · `POST /v1/operator/tenants/{id}/suspend|restore`

Tenant admin (`auth()` + `requireRole(orgAdmin | homeLead)`, home-scoped for leads):

- `GET|PUT /v1/orgs/me` · `GET|PUT /v1/orgs/me/settings`
- `POST /v1/orgs/me/domains {domain, method}` · `POST /v1/orgs/me/domains/{domain}/verify {code?}` ·
  `DELETE …`
- `GET|POST /v1/homes` · `PUT /v1/homes/{id}` · `POST /v1/homes/{id}/archive`
- `GET|POST /v1/invites` · `POST /v1/invites/bulk` · `POST /v1/invites/{id}/resend` · `DELETE /v1/invites/{id}`
- `GET /v1/orgs/me/accounts` · `PUT /v1/accounts/{id} {role, homeIds, accessEndsAt}` ·
  `POST /v1/accounts/{id}/suspend|restore|remove` · `POST /v1/accounts/{id}/pin-reset`
- `POST /v1/homes/{id}/residents/import` (multipart CSV or JSON rows) → `{preview}` with `?dryRun=1`,
  else `{applied, skipped, errors}`; writes go through the same upsert statements as `/sync/push`
- `GET|POST /v1/devices` · `DELETE /v1/devices/{id}`
- `GET /v1/orgs/me/audit?since=&kind=` · `GET /v1/orgs/me/export?homeId=` (async; 202 + poll)

`GET /v1/me` is unchanged; the app refreshes it after every wizard step so new homes appear.

---

## 6. iOS (POC) — where it lives

- **New store** `OnboardingStore` (requests, wizard step, drafts, invite lists, import preview) —
  `SessionPOCState` stays the thin coordinator (`beginOrgRequest()`, `activateOrganisation()`,
  `acceptInvite()`, `advanceSetupStep()`).
- **Phases**: `.orgRequest`, `.orgRequestVerify`, `.orgActivate`, `.inviteAccept`, `.orgSetup` (one view
  with six steps and the pinned-bottom Next / Back bar the planner uses), `.orgTeam`, `.orgDevices`,
  `.orgAudit`. The org admin's welcome routes to `.orgSetup` while the checklist is incomplete, else to the
  dashboard with the "Set up" card.
- **Sign-in screen** gains two links beside the household one: *Request a workspace* and *I have an invite
  or activation code* (one screen; the code's prefix tells them apart: `INV-` vs `ORG-`).
- **Reuse**: `BrandCard`, `BrandSectionHeader`, `BrandInsetTile`, `BrandStatusChip` (invite states),
  `BrandSegmentedChoice` (role, homes band), `SixDigitPinInput` (verification code, PIN),
  `HouseholdTextField`, `CareSenseNoteRow` for settings rows, `InsightChipFlow` for wing chips.
- **CSV import**: Files picker → parse on a background task → preview rows in a `BrandCard` list with chips
  per problem → import → residents land in `careData` through the existing outbox, so the roster updates
  offline-first and syncs like any other edit.
- **Offline**: request, activation and invite acceptance need the network (clear "You need to be online"
  state); the wizard's drafts persist locally; everything after activation degrades to offline as the
  rest of the app does.
- **Identifiers** for the walkthrough: `onboarding.request.*`, `onboarding.code`, `onboarding.step.<n>`,
  `onboarding.addHome`, `onboarding.invite.*`, `onboarding.import.*`, `onboarding.done`.
- **Demo**: a scripted Part I ("A new organisation") in `DemoUITests`, running against a local Worker with
  the operator script approving in between; narration keys `v8_onb_*`.

---

## 7. Email in the POC

The Worker cannot send SMTP. Options, in order: **Resend** (HTTPS API, free tier is enough for a POC)
behind an `EMAIL_PROVIDER` var with the API key as a secret; **dev fallback** that returns the code in
the response outside production (the PIN-reset route's `devCode` pattern), so local runs and the scripted
demo never need a mailbox. Production uses SES as the implementation plan already says. Every message is
plain text first, no tracking pixels, from `no-reply@` on a verified sending domain.

---

## 8. Security and compliance

- Codes: six digits for email verification (10-minute expiry, 5 attempts, then a new request); 32-byte
  tokens for invites and activation (hashed at rest, single use, 7 days, resend voids the old one).
- Responses never say whether an email, code or organisation exists; wrong email + right code and right
  email + wrong code read the same.
- Rate limits per IP and per email on every public route (the `rate_limits` table already exists); the
  seed-token pattern guards operator routes in the POC; App Attest on the public calls in production.
- PINs: the live pepper + PBKDF2 today, Argon2id in production (plan §6); invite acceptance revokes any
  earlier refresh tokens for that account.
- Consents are records (kind, version, actor, time, IP), shown back in the org's audit; DPA text is
  versioned and re-asked when it changes.
- Data residency: the organisation's region is set at approval and stored on the tenant; the POC has one
  region (`weur`), production routes by it.
- Audit log is append-only (no UPDATE/DELETE grants; a nightly check that row counts only grow).
- Nothing in onboarding stores resident data before activation; the demo sandbox resident is synthetic.

---

## 9. Phasing

**A — POC on the Worker (first slice):** org request + verification + operator approve/decline script +
activation + wizard steps 1–3 (organisation, homes, invites by code) + invite acceptance + audit log +
`/me` refresh. Dev-mode codes in responses; Resend behind a flag.
**B — POC, second slice:** CSV resident import with preview, domain claims (email method), device
registration, the Ready checklist with nudges, export per home, suspend/remove staff, the scripted demo.
**C — Production (web dashboard, per the implementation plan):** the same steps in `notestalgia-web`,
SES, DNS domain verification, CQC lookup (provider / location IDs validated against the CQC API), plan and
seat enforcement through Billing & Entitlements, SSO / SCIM for larger groups, MDM integration, operator
console with approvals and suspensions, retention and DSAR hooks.

Android: after iOS slice A is accepted — invite acceptance first (the floor supervisor's path), then the
admin wizard only if Android tablets are used by admins.

---

## 10. Acceptance (what "done" means for slice A)

- A new organisation can go from the sign-in screen to a working roster with two homes and three invited
  supervisors without anyone running the seed script; every step appears in the audit list.
- Worker tests: request on a claimed domain refused; verification code expires and limits attempts; invite
  single use, expiry, resend voids, wrong-email neutral; activation creates tenant + account + consents in
  one batch; home-lead scope cannot invite into another home; `/me` reflects a new home.
- iOS: wizard steps are headers for VoiceOver, every control ≥ 44 pt, the accessible segmented choice at
  large text, Back / Log out placement as everywhere else; the walkthrough Part I runs end to end against a
  local Worker.

---

## 11. Open questions for the product owner

1. **Approval**: operator approval for every organisation (proposed), or instant activation when the work
   email's domain passes a business-domain check, with approval only for free-mail requesters?
2. **Trial and billing**: 30-day trial, then invoiced per home? Seat limits per home, or per organisation?
3. **CQC**: validate provider / location IDs against the CQC API at onboarding, or just store them?
4. **Agency and bank staff** who work across organisations: one account per organisation (simplest, proposed)
   or a cross-organisation identity with per-organisation assignments?
5. **Resident import sources**: CSV only for the POC, or is a specific care-planning system (e.g. an export
   format) worth supporting first?
6. **Household → care home transfer** (a family that was using Care at home when their relative moves in):
   out of scope here, but the data model should not block it — flagged in the implementation plan already.
