#!/bin/bash
# =============================================================================
# create-milestones.sh
# Creates GitHub milestones mapped to the PharmaDesk delivery roadmap.
# Each milestone = one week-group from the 17-week plan.
#
# Prerequisites: gh CLI installed and authenticated (gh auth login)
# Usage: REPO=owner/repo START_DATE=2026-06-09 bash scripts/github/create-milestones.sh
#
# START_DATE defaults to next Monday if not set.
# Due dates are calculated from START_DATE + week offset.
# =============================================================================

set -e

REPO=${REPO:?"Set REPO=owner/repo before running this script"}

# Default start date: today or set via env
START_DATE=${START_DATE:-$(date +%Y-%m-%d)}

# Add N weeks to START_DATE and print as YYYY-MM-DD
add_weeks() {
  local weeks=$1
  date -d "$START_DATE + $((weeks * 7)) days" +"%Y-%m-%d" 2>/dev/null \
    || date -v "+$((weeks * 7))d" -j -f "%Y-%m-%d" "$START_DATE" +"%Y-%m-%d"
}

create_milestone() {
  local title="$1"
  local due="$2"
  local description="$3"

  gh api repos/"$REPO"/milestones \
    --method POST \
    --field title="$title" \
    --field due_on="${due}T00:00:00Z" \
    --field description="$description" \
    --silent && echo "  ✅ $title (due $due)" \
    || echo "  skip $title (may already exist)"
}

echo ""
echo "── Phase 1 — Foundation & MVP ───────────────────────────"

create_milestone \
  "Phase 1.1 — Infrastructure & Auth" \
  "$(add_weeks 2)" \
  "Weeks 1–2: Project scaffold, Okta auth, RBAC, user profile management. RTM: RTM-UM-01 to RTM-UM-06"

create_milestone \
  "Phase 1.2 — Prescriptions & Patients" \
  "$(add_weeks 4)" \
  "Weeks 3–4: Patient profiles, drug catalog, prescription workflow FSM, pharmacist queue. RTM: RTM-PT-01, RTM-RX-01 to RTM-RX-04, RTM-DG-01"

create_milestone \
  "Phase 1.3 — Inventory, Billing & Mobile Auth" \
  "$(add_weeks 6)" \
  "Weeks 5–6: Stock management, billing, audit trail, mobile auth. RTM: RTM-DG-02, RTM-RX-05, RTM-RX-06, RTM-BL-01, RTM-MB-01, RTM-MB-02"

echo ""
echo "── Phase 2 — Operational Features ──────────────────────"

create_milestone \
  "Phase 2.1 — Notifications & Alerts" \
  "$(add_weeks 8)" \
  "Weeks 7–8: Lambda notification infra, low stock and expiry alerts, pickup notifications. RTM: RTM-NT-01 to RTM-NT-03, RTM-DG-03, RTM-DG-04"

create_milestone \
  "Phase 2.2 — Refills, Pickup & Patient Alerts" \
  "$(add_weeks 9)" \
  "Week 9: Patient prescription filters, refill requests, pickup status, refill reminders. RTM: RTM-PT-02 to RTM-PT-05, RTM-NT-04, RTM-NT-05"

create_milestone \
  "Phase 2.3 — Payments & Billing History" \
  "$(add_weeks 10)" \
  "Week 10: Payment recording, billing history, invoice PDF, low stock analytics widget. RTM: RTM-BL-03, RTM-BL-04, RTM-AN-04"

create_milestone \
  "Phase 2.4 — Mobile Core Features" \
  "$(add_weeks 11)" \
  "Week 11: Mobile schedule, push reminders, refill submission, pickup push notifications. RTM: RTM-MB-03, RTM-MB-04"

echo ""
echo "── Phase 3 — Advanced Features ─────────────────────────"

create_milestone \
  "Phase 3.1 — Analytics Dashboard" \
  "$(add_weeks 13)" \
  "Weeks 12–13: Analytics Lambda deploy, top drugs, revenue, prescription trends. RTM: RTM-AN-01 to RTM-AN-03, RTM-AN-05"

create_milestone \
  "Phase 3.2 — Suppliers, Discounts & Mobile Barcode" \
  "$(add_weeks 15)" \
  "Weeks 14–15: Supplier directory, purchase orders, discounts, mobile barcode scanner, biometric auth. RTM: RTM-DG-05, RTM-BL-02, RTM-MB-05"

echo ""
echo "── Phase 4 — Polish & Production ───────────────────────"

create_milestone \
  "Phase 4 — Polish & Production" \
  "$(add_weeks 17)" \
  "Weeks 16–17: Rate limiting, performance hardening, accessibility, report export, go-live. RTM: RTM-AN-06"

echo ""
echo "✅ All milestones created for $REPO"
echo "   View at: https://github.com/$REPO/milestones"
