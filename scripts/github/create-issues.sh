#!/bin/bash
# =============================================================================
# create-issues.sh
# Bulk-creates all 42 RTM issues for PharmaDesk on GitHub.
# Each issue is linked to the correct milestone, labels, and RTM/FR IDs.
#
# Prerequisites:
#   - gh CLI installed and authenticated (gh auth login)
#   - create-labels.sh already run
#   - create-milestones.sh already run
#
# Usage: REPO=owner/repo bash scripts/github/create-issues.sh
# =============================================================================

set -e

REPO=${REPO:?"Set REPO=owner/repo before running this script"}

# Fetch milestone IDs by title
get_milestone_id() {
  gh api repos/"$REPO"/milestones --jq ".[] | select(.title == \"$1\") | .number"
}

echo "Fetching milestone IDs..."
M_1_1=$(get_milestone_id "Phase 1.1 — Infrastructure & Auth")
M_1_2=$(get_milestone_id "Phase 1.2 — Prescriptions & Patients")
M_1_3=$(get_milestone_id "Phase 1.3 — Inventory, Billing & Mobile Auth")
M_2_1=$(get_milestone_id "Phase 2.1 — Notifications & Alerts")
M_2_2=$(get_milestone_id "Phase 2.2 — Refills, Pickup & Patient Alerts")
M_2_3=$(get_milestone_id "Phase 2.3 — Payments & Billing History")
M_2_4=$(get_milestone_id "Phase 2.4 — Mobile Core Features")
M_3_1=$(get_milestone_id "Phase 3.1 — Analytics Dashboard")
M_3_2=$(get_milestone_id "Phase 3.2 — Suppliers, Discounts & Mobile Barcode")
M_4=$(get_milestone_id  "Phase 4 — Polish & Production")
echo "✅ Milestones loaded"

# Helper: create one issue
# Usage: issue TITLE BODY MILESTONE_ID "label1,label2,..."
issue() {
  local title="$1"
  local body="$2"
  local milestone="$3"
  local labels="$4"

  gh issue create \
    --repo "$REPO" \
    --title "$title" \
    --body "$body" \
    --milestone "$milestone" \
    --label "$labels" \
    && echo "  ✅ $title" \
    || echo "  ❌ FAILED: $title"
}

echo ""
echo "── User Management ──────────────────────────────────────"

issue "[RTM-UM-01] Role-based access control — Patient, Pharmacist, Admin" \
"## RTM Reference
**RTM-UM-01** | Priority: P1

## Functional Requirements
FR-UM-01, FR-UM-02, FR-UM-03

## Description
Implement three distinct user roles — Patient, Pharmacist, Admin — via Okta group membership. Map Okta groups to Spring \`GrantedAuthority\` via \`OktaJwtRoleConverter\`.

## Acceptance Criteria
- [ ] \`pharmadesk-admins\` group → \`ROLE_ADMIN\`
- [ ] \`pharmadesk-pharmacists\` group → \`ROLE_PHARMACIST\`
- [ ] \`pharmadesk-patients\` group → \`ROLE_PATIENT\`
- [ ] Role hierarchy configured: Admin ⊃ Pharmacist ⊃ Patient
- [ ] \`@PreAuthorize\` annotations enforce roles on all endpoints" \
"$M_1_1" "p1-critical,module:user-management,type:feature,phase:1-mvp,status:ready"

issue "[RTM-UM-02] User registration" \
"## RTM Reference
**RTM-UM-02** | Priority: P1

## Functional Requirements
FR-UM-01 to FR-UM-06

## Description
Patient and Pharmacist self-registration via Okta hosted signup flow. On first authenticated API call, sync Okta profile (name, email) to local \`users\` table.

## Acceptance Criteria
- [ ] Okta hosted registration flow accessible from web and mobile
- [ ] First-request profile sync creates local \`User\` record
- [ ] Duplicate email detection handled by Okta
- [ ] NFR-SEC-06 (bcrypt) enforced by Okta — verify policy is configured" \
"$M_1_1" "p1-critical,module:user-management,type:feature,phase:1-mvp"

issue "[RTM-UM-03] Login and logout (Okta OAuth2)" \
"## RTM Reference
**RTM-UM-03** | Priority: P1

## Functional Requirements
FR-UM-07 to FR-UM-11

## Description
Auth Code + PKCE login via Okta. API exposes \`POST /auth/logout\` to revoke token and clear server-side context. Mock OAuth2 server emulates Okta locally.

## API Contract
\`POST /api/v1/auth/logout\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Web and mobile clients complete PKCE flow successfully
- [ ] \`POST /auth/logout\` revokes token at Okta
- [ ] Expired tokens return 401 on all endpoints
- [ ] mock-oauth2-server wired in \`docker-compose.yml\` for local dev" \
"$M_1_1" "p1-critical,module:user-management,type:feature,phase:1-mvp"

issue "[RTM-UM-04] Password reset" \
"## RTM Reference
**RTM-UM-04** | Priority: P2

## Functional Requirements
FR-UM-12

## Description
Password reset handled entirely by Okta's self-service flow. API has no involvement. Verify Okta email template is configured with PharmaDesk branding.

## Acceptance Criteria
- [ ] Okta self-service password reset enabled for all groups
- [ ] Reset email delivers within 2 minutes
- [ ] After reset, old tokens are invalidated (Okta policy)" \
"$M_1_1" "p2-high,module:user-management,type:chore,phase:1-mvp"

issue "[RTM-UM-05] Role-based access control — server-side enforcement" \
"## RTM Reference
**RTM-UM-05** | Priority: P1

## Functional Requirements
FR-UM-13, FR-UM-14, FR-UM-15

## Description
Every API endpoint enforces RBAC server-side via \`@PreAuthorize\`. Client-side guards are supplemental only. Rate limiting applied per-user via Bucket4j + Redis.

## Acceptance Criteria
- [ ] All endpoints in \`openapi.yaml\` have matching \`@PreAuthorize\` annotation
- [ ] Patient cannot access another patient's data (row-level enforcement)
- [ ] 403 returned (not 404) when role is insufficient
- [ ] NFR-SEC-12: rate limit 100 req/min authenticated, 20 req/min unauthenticated" \
"$M_1_1" "p1-critical,module:user-management,type:feature,phase:1-mvp"

issue "[RTM-UM-06] User profile management" \
"## RTM Reference
**RTM-UM-06** | Priority: P2

## Functional Requirements
FR-UM-16 to FR-UM-19

## API Contract
\`GET /api/v1/users/me\`, \`PATCH /api/v1/users/me\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Users can view and update their own profile (name, phone)
- [ ] Okta remains source of truth for email — email cannot be changed via API
- [ ] Profile changes reflected immediately without re-login" \
"$M_1_1" "p2-high,module:user-management,type:feature,phase:1-mvp"

echo ""
echo "── Patient Module ───────────────────────────────────────"

issue "[RTM-PT-01] Patient profile CRUD" \
"## RTM Reference
**RTM-PT-01** | Priority: P1

## Functional Requirements
FR-PT-01 to FR-PT-03

## API Contract
\`GET /api/v1/patients\`, \`GET /api/v1/patients/{id}\`, \`PATCH /api/v1/patients/{id}\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Pharmacist and Admin can list patients (paginated, searchable by name/email)
- [ ] Pharmacist and Admin can view and update allergies, address, notes
- [ ] Patient can view own profile via \`GET /users/me\`
- [ ] NFR-COMP-02: patients cannot access other patients' records" \
"$M_1_2" "p1-critical,module:patient,type:feature,phase:1-mvp,status:ready"

issue "[RTM-PT-02] Patient prescription view (filter by status and date)" \
"## RTM Reference
**RTM-PT-02** | Priority: P1

## Functional Requirements
FR-PT-04 to FR-PT-06

## API Contract
\`GET /api/v1/prescriptions/my\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Patient can list own prescriptions filtered by status and date range
- [ ] Response uses standard pagination envelope
- [ ] Dispensed date visible on each card" \
"$M_1_2" "p1-critical,module:patient,type:feature,phase:1-mvp"

issue "[RTM-PT-03] Refill request submission and pharmacist review" \
"## RTM Reference
**RTM-PT-03** | Priority: P2

## Functional Requirements
FR-PT-07 to FR-PT-10

## API Contract
\`POST /api/v1/prescriptions/{id}/refill\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Patient can request refill on a DISPENSED prescription
- [ ] Refill creates a new PENDING prescription linked to the original
- [ ] Pharmacist sees refill requests in their queue (tagged as refill)
- [ ] 422 returned if original prescription is not in DISPENSED status" \
"$M_2_2" "p2-high,module:patient,type:feature,phase:2-operational"

issue "[RTM-PT-04] Pickup status tracking" \
"## RTM Reference
**RTM-PT-04** | Priority: P2

## Functional Requirements
FR-PT-11 to FR-PT-13

## Description
Patient can track pickup status (Ready, Picked Up, Expired) on dispensed prescriptions via the prescription detail view.

## Acceptance Criteria
- [ ] Pickup status field visible on prescription detail
- [ ] Status updates reflected in real-time (or on refresh)
- [ ] Expired pickup (>7 days uncollected) shown with warning" \
"$M_2_2" "p2-high,module:patient,type:feature,phase:2-operational"

issue "[RTM-PT-05] Refill reminder notifications (7 days before supply ends)" \
"## RTM Reference
**RTM-PT-05** | Priority: P2

## Functional Requirements
FR-PT-14

## Description
\`AlertScheduler\` runs daily at 02:00 UTC. Publishes refill reminder to \`pharmadesk-alerts\` for any active prescription where \`estimated_end_date = today + 7\`. \`alert-handler-fn\` Lambda dispatches the notification.

## Acceptance Criteria
- [ ] \`estimated_end_date\` calculated correctly on prescription dispense
- [ ] Scheduler publishes reminder exactly 7 days before end date
- [ ] Patient receives in-app + push notification per their preferences" \
"$M_2_2" "p2-high,module:patient,type:feature,phase:2-operational"

echo ""
echo "── Prescription Management ──────────────────────────────"

issue "[RTM-RX-01] Pharmacist creates digital prescriptions" \
"## RTM Reference
**RTM-RX-01** | Priority: P1

## Functional Requirements
FR-RX-01 to FR-RX-03

## API Contract
\`POST /api/v1/prescriptions\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Pharmacist can create prescription (patientId, drugId, dosage, quantity, instructions)
- [ ] Drug must be active and have sufficient stock
- [ ] New prescription created in PENDING status
- [ ] \`estimated_end_date\` calculated and stored on creation" \
"$M_1_2" "p1-critical,module:prescription,type:feature,phase:1-mvp,status:ready"

issue "[RTM-RX-02] Duplicate and conflicting drug detection" \
"## RTM Reference
**RTM-RX-02** | Priority: P1

## Functional Requirements
FR-RX-04

## Description
On prescription creation, detect if the patient already has an active (PENDING or VERIFIED) prescription for the same drug. Return 409 with a clear message.

## Acceptance Criteria
- [ ] 409 returned when duplicate active prescription exists
- [ ] Conflict check runs within the same \`@Transactional\` block as creation
- [ ] Pharmacist can override with explicit flag (future — out of scope for P1)" \
"$M_1_2" "p1-critical,module:prescription,type:feature,phase:1-mvp"

issue "[RTM-RX-03] Prescription workflow state machine" \
"## RTM Reference
**RTM-RX-03** | Priority: P1

## Functional Requirements
FR-RX-05 to FR-RX-08

## Description
Sealed \`PrescriptionEvent\` FSM. Valid transitions: PENDING→VERIFIED, PENDING→REJECTED, VERIFIED→DISPENSED (decrements stock, generates invoice), any active→CANCELLED.

## Acceptance Criteria
- [ ] Invalid transitions return 422
- [ ] DISPENSED transition is atomic: stock deducted + invoice created in single \`@Transactional\` call
- [ ] FEFO (First Expired, First Out) algorithm used for stock deduction
- [ ] Every transition writes to \`prescription_audit_log\`" \
"$M_1_2" "p1-critical,module:prescription,type:feature,phase:1-mvp"

issue "[RTM-RX-04] Pharmacist prescription queue — review, verify, reject" \
"## RTM Reference
**RTM-RX-04** | Priority: P1

## Functional Requirements
FR-RX-09 to FR-RX-11

## API Contract
\`GET /api/v1/prescriptions\`, \`PATCH /api/v1/prescriptions/{id}\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Pharmacist can filter prescriptions by status=PENDING
- [ ] PATCH with status=VERIFIED transitions to VERIFIED
- [ ] PATCH with status=REJECTED requires rejectionReason (validated)
- [ ] Response time p95 ≤ 300ms (NFR-PERF-01)" \
"$M_1_2" "p1-critical,module:prescription,type:feature,phase:1-mvp"

issue "[RTM-RX-05] Cancel or modify pending prescriptions" \
"## RTM Reference
**RTM-RX-05** | Priority: P2

## Functional Requirements
FR-RX-12 to FR-RX-14

## API Contract
\`PATCH /api/v1/prescriptions/{id}\`, \`DELETE /api/v1/prescriptions/{id}\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Pharmacist can modify dosage/quantity/instructions while status is PENDING
- [ ] DELETE cancels prescription (status → CANCELLED), valid only from PENDING or VERIFIED
- [ ] Cancelled prescription releases no stock (not yet dispensed)
- [ ] All modifications recorded in audit log" \
"$M_1_3" "p2-high,module:prescription,type:feature,phase:1-mvp"

issue "[RTM-RX-06] Full prescription audit trail" \
"## RTM Reference
**RTM-RX-06** | Priority: P1

## Functional Requirements
FR-RX-15 to FR-RX-17

## API Contract
\`GET /api/v1/prescriptions/{id}/audit\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Every state transition writes an immutable audit log entry
- [ ] Entry captures: action, performedBy, performedAt, field diff (from/to)
- [ ] Audit log is append-only — no UPDATE or DELETE on \`prescription_audit_logs\`
- [ ] NFR-AUD-04: logs retained minimum 5 years" \
"$M_1_3" "p1-critical,module:prescription,type:feature,phase:1-mvp"

echo ""
echo "── Drug & Inventory ─────────────────────────────────────"

issue "[RTM-DG-01] Drug catalog management" \
"## RTM Reference
**RTM-DG-01** | Priority: P1

## Functional Requirements
FR-DG-01 to FR-DG-04

## API Contract
\`GET /api/v1/drugs\`, \`POST /api/v1/drugs\`, \`PATCH /api/v1/drugs/{id}\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Pharmacist/Admin can add, edit, and soft-deactivate drugs
- [ ] All roles can search the catalog (paginated, filterable by category)
- [ ] Drug name + dosage form combination must be unique
- [ ] Drug catalog cached in Redis (TTL 5 min) — NFR-PERF-05" \
"$M_1_2" "p1-critical,module:drug-inventory,type:feature,phase:1-mvp,status:ready"

issue "[RTM-DG-02] Stock level tracking — FEFO deduction on dispense" \
"## RTM Reference
**RTM-DG-02** | Priority: P1

## Functional Requirements
FR-DG-05 to FR-DG-08

## API Contract
\`GET /api/v1/drugs/{id}/stock\`, \`POST /api/v1/drugs/{id}/stock\`, \`PATCH /api/v1/drugs/{id}/stock/{batchId}\` — see \`openapi.yaml\`

## Description
Stock tracked per batch with expiry date. Dispense uses FEFO algorithm (earliest-expiring batch first) via \`SequencedCollection.getFirst()\`.

## Acceptance Criteria
- [ ] Batches stored with expiry date and returned sorted expiry ascending
- [ ] Dispense deducts from earliest-expiring batch first (FEFO)
- [ ] Stock cannot go negative — 422 returned if insufficient stock
- [ ] Manual stock adjustment requires a reason and is audit-logged" \
"$M_1_3" "p1-critical,module:drug-inventory,type:feature,phase:1-mvp"

issue "[RTM-DG-03] Expiry date tracking and alerts" \
"## RTM Reference
**RTM-DG-03** | Priority: P2

## Functional Requirements
FR-DG-09 to FR-DG-11

## Description
\`AlertScheduler\` publishes expiry warning to \`pharmadesk-alerts\` for batches expiring within 30 days. Pharmacist receives in-app + email alert.

## Acceptance Criteria
- [ ] Scheduler runs daily at 02:00 UTC
- [ ] 30-day and 7-day warnings published separately
- [ ] Expired batches flagged in stock list view (UI)
- [ ] Expired batches not included in available stock count" \
"$M_2_1" "p2-high,module:drug-inventory,type:feature,phase:2-operational"

issue "[RTM-DG-04] Low stock threshold alerts" \
"## RTM Reference
**RTM-DG-04** | Priority: P2

## Functional Requirements
FR-DG-12 to FR-DG-14

## Description
Each drug has a configurable \`low_stock_threshold\`. When total stock ≤ threshold after a dispense, a \`LowStockEvent\` is published to \`pharmadesk-alerts\`. Pharmacist receives alert. Dashboard shows low-stock widget.

## Acceptance Criteria
- [ ] \`low_stock_threshold\` configurable per drug (default 0 = disabled)
- [ ] Low stock check runs within dispense \`@Transactional\` block
- [ ] Alert not repeated more than once per day per drug
- [ ] Analytics low-stock widget (\`GET /analytics/low-stock\`) reflects current state" \
"$M_2_1" "p2-high,module:drug-inventory,type:feature,phase:2-operational"

issue "[RTM-DG-05] Supplier directory and purchase order lifecycle" \
"## RTM Reference
**RTM-DG-05** | Priority: P3

## Functional Requirements
FR-DG-15 to FR-DG-18

## Description
Supplier CRUD and purchase order lifecycle: Draft → Submitted → Received → Cancelled. Received PO auto-adds a stock batch.

## Acceptance Criteria
- [ ] Pharmacist/Admin can manage supplier directory
- [ ] PO transitions enforce valid state machine
- [ ] Receiving a PO creates a stock batch with PO batch number
- [ ] PO history is audit-logged" \
"$M_3_2" "p3-medium,module:drug-inventory,type:feature,phase:3-advanced"

echo ""
echo "── Billing & Payments ───────────────────────────────────"

issue "[RTM-BL-01] Auto-generate invoice on prescription dispense" \
"## RTM Reference
**RTM-BL-01** | Priority: P1

## Functional Requirements
FR-BL-01 to FR-BL-03

## Description
When a prescription is dispensed, an invoice is created atomically in the same \`@Transactional\` block. Invoice status starts as PENDING.

## Acceptance Criteria
- [ ] Invoice created with: drug, quantity, unit price, subtotal, total
- [ ] Invoice creation is atomic with stock deduction (single transaction)
- [ ] No invoice created for REJECTED or CANCELLED prescriptions
- [ ] \`GET /api/v1/invoices/{id}\` returns full invoice with line items" \
"$M_1_3" "p1-critical,module:billing,type:feature,phase:1-mvp,status:ready"

issue "[RTM-BL-02] Discount rules and auto-application on invoices" \
"## RTM Reference
**RTM-BL-02** | Priority: P3

## Functional Requirements
FR-BL-04, FR-BL-05

## Description
Strategy pattern for discounts (PercentageDiscount, FixedAmountDiscount, NoDiscount). Admin configures rules; discounts applied automatically on invoice generation.

## Acceptance Criteria
- [ ] Admin can configure discount rules (percent or fixed, per drug or category)
- [ ] Discount calculated and stored on invoice at generation time (not recalculated)
- [ ] \`discountAmount\` visible on invoice response" \
"$M_3_2" "p3-medium,module:billing,type:feature,phase:3-advanced"

issue "[RTM-BL-03] Payment recording — full, partial, multiple payments" \
"## RTM Reference
**RTM-BL-03** | Priority: P2

## Functional Requirements
FR-BL-06 to FR-BL-09

## API Contract
\`POST /api/v1/invoices/{id}/payments\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Pharmacist can record payments against any PENDING or PARTIAL invoice
- [ ] Multiple payments allowed until invoice is fully paid
- [ ] Invoice status auto-updates: PENDING → PARTIAL → PAID
- [ ] Overpayment returns 422 with clear message" \
"$M_2_3" "p2-high,module:billing,type:feature,phase:2-operational"

issue "[RTM-BL-04] Billing history — patient and pharmacist/admin views" \
"## RTM Reference
**RTM-BL-04** | Priority: P2

## Functional Requirements
FR-BL-10 to FR-BL-12

## API Contract
\`GET /api/v1/invoices\`, \`GET /api/v1/invoices/my\`, \`GET /api/v1/invoices/{id}/pdf\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Patient can view own invoice history (\`/invoices/my\`)
- [ ] Pharmacist/Admin can filter all invoices by status, patient, date range
- [ ] PDF invoice generated within 5 seconds (NFR-PERF-06)
- [ ] PDF streams as \`application/pdf\` (not stored)" \
"$M_2_3" "p2-high,module:billing,type:feature,phase:2-operational"

echo ""
echo "── Notifications & Alerts ───────────────────────────────"

issue "[RTM-NT-01] Low stock alert to pharmacist (Lambda)" \
"## RTM Reference
**RTM-NT-01** | Priority: P2

## Functional Requirements
FR-NT-02, FR-NT-06

## Description
Low stock event published to \`pharmadesk-alerts\` SQS queue. \`alert-handler-fn\` Lambda dispatches in-app + email notification to all Pharmacists.

## Acceptance Criteria
- [ ] \`alert-handler-fn\` Lambda deployed and receiving SQS messages
- [ ] In-app notification created in \`notifications\` table
- [ ] Email dispatched via SendGrid
- [ ] DLQ monitored — failed alerts surface in admin panel after 3 retries" \
"$M_2_1" "p2-high,module:notification,type:feature,phase:2-operational"

issue "[RTM-NT-02] Prescription ready for pickup notification to patient (Lambda)" \
"## RTM Reference
**RTM-NT-02** | Priority: P2

## Functional Requirements
FR-NT-01, FR-NT-02, FR-NT-03

## Description
On prescription DISPENSED transition, \`OutboxPublisher\` sends messages to \`pharmadesk-email\` and \`pharmadesk-push\`. Lambdas dispatch to SendGrid and FCM/APNs.

## Acceptance Criteria
- [ ] Notification sent within 30 seconds of dispense
- [ ] Patient receives in-app, email, and push based on their preferences
- [ ] \`email-handler-fn\` and \`push-handler-fn\` Lambdas deployed" \
"$M_2_1" "p2-high,module:notification,type:feature,phase:2-operational"

issue "[RTM-NT-03] Drug expiry warnings to pharmacist (Lambda)" \
"## RTM Reference
**RTM-NT-03** | Priority: P2

## Functional Requirements
FR-NT-02, FR-NT-06

## Description
\`AlertScheduler\` publishes 30-day and 7-day expiry warnings daily to \`pharmadesk-alerts\`. \`alert-handler-fn\` dispatches to all Pharmacists.

## Acceptance Criteria
- [ ] 30-day warning published when batch expiry = today + 30
- [ ] 7-day warning published when batch expiry = today + 7
- [ ] Warnings not duplicated if scheduler runs multiple times (idempotency key)" \
"$M_2_1" "p2-high,module:notification,type:feature,phase:2-operational"

issue "[RTM-NT-04] Refill reminder notification to patient (Lambda)" \
"## RTM Reference
**RTM-NT-04** | Priority: P3

## Functional Requirements
FR-NT-01 to FR-NT-03

## Description
\`AlertScheduler\` publishes refill reminders 7 days before \`estimated_end_date\`. \`alert-handler-fn\` dispatches to patient via in-app + push.

## Acceptance Criteria
- [ ] Reminder sent exactly once per prescription per refill cycle
- [ ] Patient receives notification per their preferences
- [ ] Deep link in push notification opens the prescription detail screen" \
"$M_2_2" "p3-medium,module:notification,type:feature,phase:2-operational"

issue "[RTM-NT-05] In-app notification centre and user preferences" \
"## RTM Reference
**RTM-NT-05** | Priority: P3

## Functional Requirements
FR-NT-04 to FR-NT-06

## API Contract
\`GET /api/v1/notifications\`, \`PATCH /notifications/{id}/read\`, \`POST /notifications/read-all\`, \`GET|PATCH /notifications/preferences\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Notification feed paginated, newest first
- [ ] Mark as read (single + bulk)
- [ ] User can configure channels per notification type (IN_APP, EMAIL, PUSH)
- [ ] Unread count badge visible in web and mobile nav" \
"$M_2_2" "p3-medium,module:notification,type:feature,phase:2-operational"

echo ""
echo "── Analytics Dashboard ──────────────────────────────────"

issue "[RTM-AN-01] Analytics access control — Pharmacist and Admin only" \
"## RTM Reference
**RTM-AN-01** | Priority: P2

## Functional Requirements
FR-AN-01, FR-AN-02

## Description
\`analytics-api-fn\` Lambda validates Okta JWT and enforces \`ROLE_PHARMACIST\` or \`ROLE_ADMIN\` on all \`/analytics/**\` routes.

## Acceptance Criteria
- [ ] Patient role returns 403 on all analytics endpoints
- [ ] JWT validated against Okta JWKS in Lambda (cached after SnapStart)
- [ ] \`analytics-api-fn\` deployed behind API Gateway" \
"$M_3_1" "p2-high,module:analytics,type:feature,phase:3-advanced"

issue "[RTM-AN-02] Most dispensed drugs widget" \
"## RTM Reference
**RTM-AN-02** | Priority: P3

## Functional Requirements
FR-AN-03

## API Contract
\`GET /api/v1/analytics/top-drugs?period=MONTHLY&limit=10\` — see \`openapi.yaml\`

## Description
\`analytics-projector-fn\` maintains \`analytics.drug_dispense_counts\` projection. Top-K heap algorithm used to rank drugs efficiently.

## Acceptance Criteria
- [ ] Returns top N drugs by dispense count for WEEKLY/MONTHLY/YEARLY
- [ ] Data lags domain events by ≤ 1 second (SQS delivery time)
- [ ] Query responds within 300ms (reads from projection table)" \
"$M_3_1" "p3-medium,module:analytics,type:feature,phase:3-advanced"

issue "[RTM-AN-03] Monthly revenue summary" \
"## RTM Reference
**RTM-AN-03** | Priority: P3

## Functional Requirements
FR-AN-04

## API Contract
\`GET /api/v1/analytics/revenue?from=2026-01&to=2026-06\` — see \`openapi.yaml\`

## Description
\`analytics-projector-fn\` maintains \`analytics.monthly_revenue\` projection updated on every \`InvoicePaidEvent\`.

## Acceptance Criteria
- [ ] Returns invoiced, collected, and outstanding per month
- [ ] Supports arbitrary date range (validated: max 12 months)
- [ ] Admin can export as CSV or PDF via \`/analytics/export\`" \
"$M_3_1" "p3-medium,module:analytics,type:feature,phase:3-advanced"

issue "[RTM-AN-04] Low stock overview widget" \
"## RTM Reference
**RTM-AN-04** | Priority: P2

## Functional Requirements
FR-AN-05

## API Contract
\`GET /api/v1/analytics/low-stock\` — see \`openapi.yaml\`

## Description
Reads from \`analytics.stock_snapshots\` projection. Returns all drugs where \`current_stock <= threshold\`. Available from Phase 2.3.

## Acceptance Criteria
- [ ] Widget shows drug name, current stock, and threshold
- [ ] Sorted by severity (most depleted first)
- [ ] Updates in near-real-time via domain event projection" \
"$M_2_3" "p2-high,module:analytics,type:feature,phase:2-operational"

issue "[RTM-AN-05] Prescription volume trends chart" \
"## RTM Reference
**RTM-AN-05** | Priority: P3

## Functional Requirements
FR-AN-06

## API Contract
\`GET /api/v1/analytics/prescription-volume?period=MONTHLY\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Returns prescription counts bucketed by WEEKLY/MONTHLY/YEARLY
- [ ] Supports date range filter
- [ ] Projection updated on every \`PrescriptionDispensedEvent\`" \
"$M_3_1" "p3-medium,module:analytics,type:feature,phase:3-advanced"

issue "[RTM-AN-06] Analytics report export — CSV and PDF" \
"## RTM Reference
**RTM-AN-06** | Priority: P4

## Functional Requirements
FR-AN-07

## API Contract
\`GET /api/v1/analytics/export?format=PDF&dateFrom=...&dateTo=...\` — see \`openapi.yaml\`

## Acceptance Criteria
- [ ] Admin only (403 for Pharmacist)
- [ ] Supports CSV and PDF output
- [ ] Max date range: 12 months (422 otherwise)
- [ ] Completes within 30 seconds for 12 months of data (NFR-PERF-07)" \
"$M_4" "p4-low,module:analytics,type:feature,phase:4-polish"

echo ""
echo "── Mobile Application ───────────────────────────────────"

issue "[RTM-MB-01] Mobile authentication — login, logout, biometric" \
"## RTM Reference
**RTM-MB-01** | Priority: P1

## Functional Requirements
FR-MB-01 to FR-MB-03

## Description
React Native Expo app. Auth Code + PKCE via Okta. Tokens stored in iOS Keychain / Android Keystore. Biometric unlock (Face ID / fingerprint) added in Phase 3.

## Acceptance Criteria
- [ ] PKCE login flow completes on iOS and Android
- [ ] Tokens stored in secure platform storage (NFR-SEC-13)
- [ ] Auto-refresh token before expiry
- [ ] Biometric unlock implemented (Phase 3 — RTM-MB-05 dependency)" \
"$M_1_3" "p1-critical,module:mobile,type:feature,phase:1-mvp,status:ready"

issue "[RTM-MB-02] Mobile prescription list and pickup status view" \
"## RTM Reference
**RTM-MB-02** | Priority: P1

## Functional Requirements
FR-MB-04, FR-MB-05

## Description
Patient dashboard showing active prescriptions and pickup status. Uses \`GET /prescriptions/my\` API. Offline support via TanStack Query stale-while-revalidate.

## Acceptance Criteria
- [ ] Prescription list renders within 2 seconds of login (NFR-PERF-03)
- [ ] Pickup status badge visible on each card
- [ ] Offline mode shows cached data with 'Offline' banner (NFR-USE-09)" \
"$M_1_3" "p1-critical,module:mobile,type:feature,phase:1-mvp"

issue "[RTM-MB-03] Daily medication schedule with local push reminders" \
"## RTM Reference
**RTM-MB-03** | Priority: P2

## Functional Requirements
FR-MB-06 to FR-MB-08

## Description
Medication schedule derived from active prescriptions (dosage instructions parsed). Local push reminders scheduled via Expo Notifications SDK.

## Acceptance Criteria
- [ ] Schedule shows all active prescriptions with dosage times
- [ ] Local push notification fires at configured times
- [ ] User can snooze or dismiss reminders
- [ ] Touch target ≥ 44×44pt (NFR-USE-08)" \
"$M_2_4" "p2-high,module:mobile,type:feature,phase:2-operational"

issue "[RTM-MB-04] Mobile refill request submission" \
"## RTM Reference
**RTM-MB-04** | Priority: P2

## Functional Requirements
FR-MB-09, FR-MB-10

## Description
Patient can submit refill request from mobile via \`POST /prescriptions/{id}/refill\`. Failed requests queued in-memory and retried on reconnect.

## Acceptance Criteria
- [ ] Refill button visible on DISPENSED prescriptions
- [ ] Offline: request queued and retried when connectivity restored
- [ ] Success confirmation displayed; prescription list refreshed" \
"$M_2_4" "p2-high,module:mobile,type:feature,phase:2-operational"

issue "[RTM-MB-05] Prescription barcode scanner and biometric auth" \
"## RTM Reference
**RTM-MB-05** | Priority: P3

## Functional Requirements
FR-MB-11 to FR-MB-13

## Description
Pharmacist scans prescription barcode to pull up patient record instantly. Biometric auth (Face ID / fingerprint) for app unlock.

## Acceptance Criteria
- [ ] Camera barcode scan decodes prescription ID
- [ ] Decoded ID fetches prescription via \`GET /prescriptions/{id}\`
- [ ] Fallback to manual ID entry if scan fails
- [ ] Biometric unlock added for all roles
- [ ] Tested on minimum-spec Android device" \
"$M_3_2" "p3-medium,module:mobile,type:feature,phase:3-advanced"

echo ""
echo "── Infrastructure & Non-Functional ─────────────────────"

issue "[INFRA] Local development environment — Docker Compose + SAM Local" \
"## Description
Set up and validate the full local development stack described in \`docker-compose.yml\`.

## Checklist
- [ ] \`docker compose up --build\` starts all services cleanly
- [ ] LocalStack SQS queues created by \`sqs-init\` container
- [ ] mock-oauth2-server issues valid JWTs for all three roles
- [ ] \`sam local start-lambda --port 3001\` starts notification Lambdas
- [ ] \`sam local start-lambda --port 3002\` starts analytics Lambdas
- [ ] README documents complete local setup in ≤ 5 commands" \
"$M_1_1" "p1-critical,type:chore,phase:1-mvp,status:ready"

issue "[INFRA] CI/CD pipeline — GitHub Actions per service" \
"## Description
GitHub Actions workflows for Core Monolith (ECS deploy) and Lambda functions (SAM deploy).

## Checklist
- [ ] Core: lint → test → build Docker image → push ECR → ECS rolling update
- [ ] Notification: \`sam build\` → \`sam deploy --stack-name pharmadesk-stg\`
- [ ] Analytics: \`sam build\` → \`sam deploy --stack-name pharmadesk-stg\`
- [ ] Each pipeline independent — a Lambda change does not trigger Core deploy
- [ ] Manual approval gate before production deploy" \
"$M_1_1" "p1-critical,type:chore,phase:1-mvp"

issue "[NFR] API rate limiting — Bucket4j + Redis" \
"## NFR Reference
NFR-SEC-12

## Description
100 req/min per authenticated user, 20 req/min for unauthenticated endpoints. Implemented via Bucket4j + Redis in the Spring Security filter chain.

## Acceptance Criteria
- [ ] Rate limiter applied before JWT validation
- [ ] 429 returned with \`Retry-After\` header when limit exceeded
- [ ] Limits load-tested and confirmed under 100 concurrent users" \
"$M_4" "p1-critical,type:feature,phase:4-polish"

issue "[NFR] Load testing — validate p95 ≤ 300ms under 100 concurrent users" \
"## NFR Reference
NFR-PERF-01

## Description
Run load test against staging environment to confirm API response time p95 ≤ 300ms.

## Tool
k6 or Gatling. Test script covers: login flow, prescription list, prescription create, dispense, invoice fetch.

## Acceptance Criteria
- [ ] p95 ≤ 300ms across all critical endpoints
- [ ] p99 ≤ 800ms
- [ ] Zero 5xx errors under sustained 100-user load for 10 minutes" \
"$M_4" "p1-critical,type:chore,phase:4-polish"

echo ""
echo "════════════════════════════════════════════════════"
echo "✅ All issues created for $REPO"
echo "   View board: https://github.com/$REPO/issues"
echo "════════════════════════════════════════════════════"
