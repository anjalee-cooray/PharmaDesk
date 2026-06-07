# PharmaDesk — Delivery Roadmap

**Version:** 1.0  
**Date:** 2026-06-06  
**Project:** PharmaDesk  

---

## Overview

The roadmap is structured into four phases aligned with the RTM priority levels. Each phase delivers a working, testable increment of the system.

| Phase | Focus | RTM Priority | Target Duration |
|---|---|---|---|
| Phase 1 — Foundation & MVP | Core auth, prescriptions, inventory, billing | P1 | Weeks 1–6 |
| Phase 2 — Operational Features | Notifications, refills, payments, mobile core | P2 | Weeks 7–11 |
| Phase 3 — Advanced Features | Analytics, suppliers, discounts, barcode | P3 | Weeks 12–15 |
| Phase 4 — Polish & Optimisation | Exports, accessibility audit, performance tuning | P4 | Weeks 16–17 |

---

## Phase 1 — Foundation & MVP (Weeks 1–6)

**Goal:** A working system where pharmacists can manage prescriptions and patients can log in and view their records.

### Week 1–2 — Infrastructure & Auth

| Deliverable | RTM IDs | FR IDs |
|---|---|---|
| Project scaffold (API, web app, DB schema, CI/CD pipeline) | — | NFR-MNT-07 |
| JWT authentication — register, login, logout, refresh | RTM-UM-02, RTM-UM-03 | FR-UM-01 to FR-UM-12 |
| Role-based access control (Patient, Pharmacist, Admin) | RTM-UM-01, RTM-UM-05 | FR-UM-13 to FR-UM-15 |
| User profile management | RTM-UM-06 | FR-UM-16 to FR-UM-19 |

**Milestone:** All three roles can register, log in, and access role-appropriate dashboards.

---

### Week 3–4 — Patient Profile & Prescription Core

| Deliverable | RTM IDs | FR IDs |
|---|---|---|
| Patient profile CRUD | RTM-PT-01 | FR-PT-01 to FR-PT-03 |
| Drug catalog management (add, edit, deactivate, search) | RTM-DG-01 | FR-DG-01 to FR-DG-04 |
| Create and submit prescriptions | RTM-RX-01 | FR-RX-01 to FR-RX-03 |
| Duplicate/conflict detection on prescription creation | RTM-RX-02 | FR-RX-04 |
| Prescription workflow state machine (Pending → Verified → Dispensed → Rejected) | RTM-RX-03 | FR-RX-05 to FR-RX-08 |
| Pharmacist prescription queue and review UI | RTM-RX-04 | FR-RX-09 to FR-RX-11 |

**Milestone:** Pharmacist can create and process a prescription end-to-end. Patient can view their prescriptions.

---

### Week 5–6 — Inventory, Billing Core & Audit

| Deliverable | RTM IDs | FR IDs |
|---|---|---|
| Stock management — track levels, auto-decrement on dispense | RTM-DG-02 | FR-DG-05 to FR-DG-08 |
| Prescription modify and cancel | RTM-RX-05 | FR-RX-12 to FR-RX-14 |
| Full prescription audit trail | RTM-RX-06 | FR-RX-15 to FR-RX-17 |
| Auto invoice generation on dispense | RTM-BL-01 | FR-BL-01 to FR-BL-03 |
| Mobile app — authentication (login, logout, secure token storage) | RTM-MB-01 | FR-MB-01 to FR-MB-03 |
| Mobile app — prescription list view | RTM-MB-02 | FR-MB-04, FR-MB-05 |

**Milestone:** Full P1 scope complete. End-to-end prescription lifecycle works. Invoices generate automatically. Mobile login and prescription view functional. ✅ **Phase 1 Complete.**

---

## Phase 2 — Operational Features (Weeks 7–11)

**Goal:** The system handles day-to-day pharmacy operations including notifications, payments, refills, and patient-facing pickup tracking.

### Week 7–8 — Notifications & Alerts

| Deliverable | RTM IDs | FR IDs |
|---|---|---|
| Notification infrastructure (async queue, email provider integration) | — | NFR-SCL-04, NFR-INT-06 |
| In-app notification centre | RTM-NT-05 | FR-NT-05, FR-NT-06 |
| Prescription ready for pickup → patient (in-app + email) | RTM-NT-02 | FR-NT-01, FR-NT-02 |
| Low stock alert → pharmacist (in-app + email) | RTM-NT-01 | FR-NT-02 |
| Drug expiry warning → pharmacist (30-day and 7-day) | RTM-NT-03 | FR-NT-02 |
| Expiry tracking per stock batch + dashboard flag | RTM-DG-03 | FR-DG-09 to FR-DG-11 |
| Low stock threshold configuration and dashboard widget | RTM-DG-04 | FR-DG-12 to FR-DG-14 |

**Milestone:** Pharmacists receive stock and expiry alerts. Patients receive pickup notifications.

---

### Week 9 — Refills, Pickup Status & Patient Alerts

| Deliverable | RTM IDs | FR IDs |
|---|---|---|
| Patient prescription view — filter by status and date | RTM-PT-02 | FR-PT-04 to FR-PT-06 |
| Refill request submission and pharmacist review | RTM-PT-03 | FR-PT-07 to FR-PT-10 |
| Pickup status tracking (Ready, Picked Up, Expired) | RTM-PT-04 | FR-PT-11 to FR-PT-13 |
| Refill reminder notification (7 days before supply ends) | RTM-PT-05 | FR-PT-14 |
| User notification preferences | RTM-NT-05 | FR-NT-04 |

**Milestone:** Patients can request refills and track pickup. Automated refill reminders are live.

---

### Week 10 — Payments & Billing History

| Deliverable | RTM IDs | FR IDs |
|---|---|---|
| Payment recording (full, partial, multiple payments per invoice) | RTM-BL-03 | FR-BL-06 to FR-BL-09 |
| Billing history — patient view | RTM-BL-04 | FR-BL-10 |
| Billing history — pharmacist/admin view with filters | RTM-BL-04 | FR-BL-11 |
| Invoice PDF export | RTM-BL-04 | FR-BL-12 |
| Low stock analytics widget (admin/pharmacist dashboard) | RTM-AN-04 | FR-AN-05 |

**Milestone:** Full billing cycle complete. Pharmacists can record and track payments. Patients can view their billing history.

---

### Week 11 — Mobile Core Features

| Deliverable | RTM IDs | FR IDs |
|---|---|---|
| Mobile app — daily medication schedule | RTM-MB-03 | FR-MB-06 |
| Mobile app — local push notification reminders | RTM-MB-03 | FR-MB-07, FR-MB-08 |
| Mobile app — refill request submission | RTM-MB-04 | FR-MB-09, FR-MB-10 |
| Mobile app — push notifications for pickup and refill status | RTM-NT-02, RTM-NT-04 | FR-NT-03 |

**Milestone:** Mobile app fully operational for P2 scope. ✅ **Phase 2 Complete.**

---

## Phase 3 — Advanced Features (Weeks 12–15)

**Goal:** Analytics, supplier management, discounts, and the prescription barcode scanner.

### Week 12–13 — Analytics Dashboard

| Deliverable | RTM IDs | FR IDs |
|---|---|---|
| Admin/pharmacist access control for analytics | RTM-AN-01 | FR-AN-01, FR-AN-02 |
| Most dispensed drugs widget (weekly/monthly/yearly) | RTM-AN-02 | FR-AN-03 |
| Monthly revenue summary (invoiced, collected, outstanding) | RTM-AN-03 | FR-AN-04 |
| Prescription volume trends chart | RTM-AN-05 | FR-AN-06 |

**Milestone:** Analytics dashboard live for pharmacists and admins.

---

### Week 14 — Suppliers, Purchase Orders & Discounts

| Deliverable | RTM IDs | FR IDs |
|---|---|---|
| Supplier directory CRUD | RTM-DG-05 | FR-DG-15 |
| Purchase order lifecycle (Draft → Submitted → Received → Cancelled) | RTM-DG-05 | FR-DG-16 to FR-DG-18 |
| Discount rules configuration | RTM-BL-02 | FR-BL-04 |
| Auto-apply discounts on invoice generation | RTM-BL-02 | FR-BL-05 |

**Milestone:** Pharmacists can manage suppliers and purchase orders. Discounts apply automatically on invoices.

---

### Week 15 — Mobile Barcode Scanner & Notifications Polish

| Deliverable | RTM IDs | FR IDs |
|---|---|---|
| Mobile app — prescription barcode scanning | RTM-MB-05 | FR-MB-11 to FR-MB-13 |
| Biometric authentication (Face ID / fingerprint) | RTM-MB-01 | FR-MB-02 |
| Notification retry logic and failed job admin queue | — | NFR-AVL-04, NFR-AVL-05 |

**Milestone:** All P3 features delivered. Mobile app feature-complete. ✅ **Phase 3 Complete.**

---

## Phase 4 — Polish & Optimisation (Weeks 16–17)

**Goal:** Performance tuning, accessibility audit, report exports, and hardening before production release.

### Week 16 — Performance & Security Hardening

| Deliverable | RTM IDs | NFR IDs |
|---|---|---|
| API rate limiting | — | NFR-SEC-12 |
| Mobile certificate pinning | — | NFR-SEC-15 |
| Database query optimisation and index review | — | NFR-PERF-04 |
| Application-layer caching for drug catalog and permissions | — | NFR-PERF-05 |
| Load testing to validate response time targets (300 ms p95) | — | NFR-PERF-01 |
| Backup and recovery validation (RPO/RTO test) | — | NFR-AVL-06 to NFR-AVL-08 |

---

### Week 17 — Accessibility, Exports & Final QA

| Deliverable | RTM IDs | FR/NFR IDs |
|---|---|---|
| Analytics report export — CSV and PDF | RTM-AN-06 | FR-AN-07 |
| WCAG 2.1 AA accessibility audit and remediation | — | NFR-USE-02, NFR-USE-03 |
| OpenAPI 3.0 documentation review and publish | — | NFR-MNT-05 |
| End-to-end regression test pass across all modules | All | All |
| Production environment setup and go-live checklist | — | NFR-AVL-01 |

**Milestone:** System hardened, accessible, and documented. ✅ **Phase 4 Complete — Ready for Production.**

---

## Delivery Summary

```
Week  1 – 2   │ Infrastructure, Auth, RBAC
Week  3 – 4   │ Patient Profiles, Drug Catalog, Prescription Workflow
Week  5 – 6   │ Inventory, Billing Core, Audit, Mobile Auth & Rx View
              │ ✅ Phase 1 Complete — MVP
Week  7 – 8   │ Notifications Infrastructure, Stock & Expiry Alerts
Week  9       │ Refills, Pickup Status, Patient Alerts
Week 10       │ Payments, Billing History, Invoice PDF
Week 11       │ Mobile Schedule, Reminders, Refills, Push Notifications
              │ ✅ Phase 2 Complete — Operational
Week 12 – 13  │ Analytics Dashboard
Week 14       │ Suppliers, Purchase Orders, Discounts
Week 15       │ Mobile Barcode, Biometric Auth, Notification Hardening
              │ ✅ Phase 3 Complete — Advanced Features
Week 16       │ Performance & Security Hardening
Week 17       │ Accessibility, Exports, Final QA, Go-Live
              │ ✅ Phase 4 Complete — Production Ready
```

**Total Estimated Duration: 17 weeks**

---

## Risks & Assumptions

| Risk | Impact | Mitigation |
|---|---|---|
| Mobile platform review delays (App Store / Play Store) | High | Submit mobile app for review at the end of Phase 3 to allow buffer time |
| Third-party email/push provider integration complexity | Medium | Spike and select provider in Week 1 alongside infrastructure setup |
| Barcode scanning performance on low-end Android devices | Low | Test on minimum-spec devices during Phase 3; fall back to manual entry if needed |
| Scope creep from stakeholder feedback post-Phase 1 demo | Medium | Enforce change control process; new items enter backlog for Phase 3+ |
| Database performance under concurrent load | Medium | Load test at end of Phase 2; optimise before Phase 4 hardening |
