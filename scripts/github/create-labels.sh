#!/bin/bash
# =============================================================================
# create-labels.sh
# Creates all GitHub labels for PharmaDesk.
# Run once after creating the repo.
#
# Prerequisites: gh CLI installed and authenticated (gh auth login)
# Usage: REPO=owner/repo bash scripts/github/create-labels.sh
# =============================================================================

set -e

REPO=${REPO:?"Set REPO=owner/repo before running this script"}

create_label() {
  local name="$1"
  local color="$2"
  local description="$3"

  if gh label list --repo "$REPO" --limit 100 | grep -q "^${name}"; then
    echo "  skip  $name (already exists)"
  else
    gh label create "$name" \
      --repo "$REPO" \
      --color "$color" \
      --description "$description"
    echo "  ✅   $name"
  fi
}

echo ""
echo "── Priority ─────────────────────────────────"
create_label "p1-critical"  "B60205" "P1 — Core function; system cannot operate without it"
create_label "p2-high"      "D93F0B" "P2 — Significant business value; required before go-live"
create_label "p3-medium"    "E4E669" "P3 — Important but not blocking"
create_label "p4-low"       "0E8A16" "P4 — Nice-to-have; can be deferred"

echo ""
echo "── Module ───────────────────────────────────"
create_label "module:user-management" "0075CA" "User registration, login, RBAC"
create_label "module:patient"         "0075CA" "Patient profiles, pickup, refills"
create_label "module:prescription"    "0075CA" "Prescription lifecycle and audit"
create_label "module:drug-inventory"  "0075CA" "Drug catalog and stock management"
create_label "module:billing"         "0075CA" "Invoices and payments"
create_label "module:notification"    "0075CA" "Email, push, in-app notifications"
create_label "module:analytics"       "0075CA" "Dashboard and report exports"
create_label "module:mobile"          "0075CA" "React Native app features"

echo ""
echo "── Type ─────────────────────────────────────"
create_label "type:feature"       "A2EEEF" "New functionality"
create_label "type:bug"           "EE0701" "Something is broken"
create_label "type:chore"         "FEF2C0" "Maintenance, refactoring, tooling"
create_label "type:documentation" "CFD3D7" "Docs, ADRs, API contract"
create_label "type:test"          "D4C5F9" "Test coverage improvement"

echo ""
echo "── Phase ────────────────────────────────────"
create_label "phase:1-mvp"        "BFD4F2" "Phase 1 — Foundation & MVP (Weeks 1–6)"
create_label "phase:2-operational" "BFD4F2" "Phase 2 — Operational Features (Weeks 7–11)"
create_label "phase:3-advanced"   "BFD4F2" "Phase 3 — Advanced Features (Weeks 12–15)"
create_label "phase:4-polish"     "BFD4F2" "Phase 4 — Polish & Production (Weeks 16–17)"

echo ""
echo "── Status ───────────────────────────────────"
create_label "status:blocked"     "E4E669" "Blocked by another issue or external dependency"
create_label "status:needs-spec"  "FBCA04" "Requires more design detail before development"
create_label "status:ready"       "0E8A16" "Fully specified and ready to pick up"

echo ""
echo "✅ All labels created for $REPO"
