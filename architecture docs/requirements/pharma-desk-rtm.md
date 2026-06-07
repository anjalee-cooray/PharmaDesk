# PharmaDesk — Requirements Traceability Matrix (RTM)

**Version:** 1.0  
**Date:** 2026-06-06  
**Project:** PharmaDesk  

---

## Purpose

This document traces every high-level requirement to its corresponding functional requirements (FR) and non-functional requirements (NFR), ensuring complete coverage and providing a single reference for validation and testing.

---

## Priority Key

| Priority | Description |
|---|---|
| P1 — Critical | Core system function; system cannot operate without it |
| P2 — High | Significant business value; required before go-live |
| P3 — Medium | Important but not blocking; targeted for early releases |
| P4 — Low | Nice-to-have; can be deferred to later iterations |

---

## Status Key

| Status | Description |
|---|---|
| Defined | Requirement documented, not yet in development |
| In Progress | Actively being developed |
| Implemented | Development complete, pending verification |
| Verified | Tested and confirmed to meet the requirement |

---

## 1. User Management

| RTM ID | High-Level Requirement | Functional Requirements | Non-Functional Requirements | Priority | Status |
|---|---|---|---|---|---|
| RTM-UM-01 | Support roles: Patient, Pharmacist, Admin | FR-UM-01, FR-UM-02, FR-UM-03 | NFR-SEC-04 | P1 | Defined |
| RTM-UM-02 | User registration | FR-UM-01, FR-UM-02, FR-UM-03, FR-UM-04, FR-UM-05, FR-UM-06 | NFR-SEC-06, NFR-SEC-10 | P1 | Defined |
| RTM-UM-03 | Login and logout (JWT-based auth) | FR-UM-07, FR-UM-08, FR-UM-09, FR-UM-10, FR-UM-11 | NFR-SEC-01, NFR-SEC-02, NFR-SEC-03, NFR-SEC-05 | P1 | Defined |
| RTM-UM-04 | Password reset | FR-UM-12 | NFR-SEC-08 | P2 | Defined |
| RTM-UM-05 | Role-based access control across all modules | FR-UM-13, FR-UM-14, FR-UM-15 | NFR-SEC-04 | P1 | Defined |
| RTM-UM-06 | Profile management per role | FR-UM-16, FR-UM-17, FR-UM-18, FR-UM-19 | NFR-SEC-10, NFR-USE-04 | P2 | Defined |

---

## 2. Patient Module

| RTM ID | High-Level Requirement | Functional Requirements | Non-Functional Requirements | Priority | Status |
|---|---|---|---|---|---|
| RTM-PT-01 | Register and manage patient profiles | FR-PT-01, FR-PT-02, FR-PT-03 | NFR-PERF-04, NFR-NF-09 | P1 | Defined |
| RTM-PT-02 | View active and past prescriptions | FR-PT-04, FR-PT-05, FR-PT-06 | NFR-PERF-01, NFR-COMP-02 | P1 | Defined |
| RTM-PT-03 | Request prescription refills | FR-PT-07, FR-PT-08, FR-PT-09, FR-PT-10 | NFR-AVL-03 | P2 | Defined |
| RTM-PT-04 | Track medication pickup status | FR-PT-11, FR-PT-12, FR-PT-13 | NFR-PERF-01 | P2 | Defined |
| RTM-PT-05 | Receive alerts for refill due dates and pickup ready | FR-PT-13, FR-PT-14 | NFR-SCL-04 | P2 | Defined |

---

## 3. Prescription Management

| RTM ID | High-Level Requirement | Functional Requirements | Non-Functional Requirements | Priority | Status |
|---|---|---|---|---|---|
| RTM-RX-01 | Pharmacist creates digital prescriptions for patients | FR-RX-01, FR-RX-02, FR-RX-03 | NFR-SEC-04, NFR-SEC-10 | P1 | Defined |
| RTM-RX-02 | Flag duplicate or conflicting drug prescriptions | FR-RX-04 | NFR-AUD-05 | P1 | Defined |
| RTM-RX-03 | Prescription workflow: pending → verified → dispensed → rejected | FR-RX-05, FR-RX-06, FR-RX-07, FR-RX-08 | NFR-AUD-01, NFR-AUD-05 | P1 | Defined |
| RTM-RX-04 | Review, verify, and reject prescriptions with notes | FR-RX-09, FR-RX-10, FR-RX-11 | NFR-PERF-01 | P1 | Defined |
| RTM-RX-05 | Cancel or modify pending prescriptions | FR-RX-12, FR-RX-13, FR-RX-14 | NFR-AUD-01, NFR-AUD-02 | P2 | Defined |
| RTM-RX-06 | Full prescription audit trail | FR-RX-15, FR-RX-16, FR-RX-17 | NFR-AUD-01, NFR-AUD-02, NFR-AUD-03, NFR-AUD-04 | P1 | Defined |

---

## 4. Drug & Inventory Management

| RTM ID | High-Level Requirement | Functional Requirements | Non-Functional Requirements | Priority | Status |
|---|---|---|---|---|---|
| RTM-DG-01 | Maintain drug catalog (name, category, dosage forms, price) | FR-DG-01, FR-DG-02, FR-DG-03, FR-DG-04 | NFR-PERF-04, NFR-PERF-05 | P1 | Defined |
| RTM-DG-02 | Track stock levels per drug | FR-DG-05, FR-DG-06, FR-DG-07, FR-DG-08 | NFR-AUD-01, NFR-AUD-05 | P1 | Defined |
| RTM-DG-03 | Expiry date tracking with alerts | FR-DG-09, FR-DG-10, FR-DG-11 | NFR-SCL-04 | P2 | Defined |
| RTM-DG-04 | Low stock threshold alerts | FR-DG-12, FR-DG-13, FR-DG-14 | NFR-SCL-04 | P2 | Defined |
| RTM-DG-05 | Manage suppliers and purchase orders | FR-DG-15, FR-DG-16, FR-DG-17, FR-DG-18 | NFR-AUD-01, NFR-AUD-05 | P3 | Defined |

---

## 5. Billing & Payments

| RTM ID | High-Level Requirement | Functional Requirements | Non-Functional Requirements | Priority | Status |
|---|---|---|---|---|---|
| RTM-BL-01 | Auto-generate invoice when prescription is dispensed | FR-BL-01, FR-BL-02, FR-BL-03 | NFR-AUD-05, NFR-PERF-06 | P1 | Defined |
| RTM-BL-02 | Apply discounts where applicable | FR-BL-04, FR-BL-05 | NFR-AUD-01 | P3 | Defined |
| RTM-BL-03 | Payment status tracking (paid, pending, partial) | FR-BL-06, FR-BL-07, FR-BL-08, FR-BL-09 | NFR-AUD-01 | P2 | Defined |
| RTM-BL-04 | Billing history per patient | FR-BL-10, FR-BL-11, FR-BL-12 | NFR-COMP-02, NFR-PERF-04 | P2 | Defined |

---

## 6. Notifications & Alerts

| RTM ID | High-Level Requirement | Functional Requirements | Non-Functional Requirements | Priority | Status |
|---|---|---|---|---|---|
| RTM-NT-01 | Low stock alerts → pharmacist | FR-NT-02, FR-NT-06 (low stock event) | NFR-SCL-04, NFR-AVL-04 | P2 | Defined |
| RTM-NT-02 | Prescription ready for pickup → patient | FR-NT-01, FR-NT-02, FR-NT-03 (pickup event) | NFR-SCL-04, NFR-AVL-04 | P2 | Defined |
| RTM-NT-03 | Expiry warnings → pharmacist | FR-NT-02, FR-NT-06 (expiry event) | NFR-SCL-04, NFR-AVL-04 | P2 | Defined |
| RTM-NT-04 | Refill reminders → patient | FR-NT-01, FR-NT-02, FR-NT-03 (refill event) | NFR-SCL-04, NFR-AVL-04 | P3 | Defined |
| RTM-NT-05 | Notification centre and user preferences | FR-NT-04, FR-NT-05, FR-NT-06 | NFR-USE-04 | P3 | Defined |

---

## 7. Analytics Dashboard

| RTM ID | High-Level Requirement | Functional Requirements | Non-Functional Requirements | Priority | Status |
|---|---|---|---|---|---|
| RTM-AN-01 | Access control for Admin and Pharmacist | FR-AN-01, FR-AN-02 | NFR-SEC-04 | P2 | Defined |
| RTM-AN-02 | Most dispensed drugs | FR-AN-03 | NFR-PERF-07, NFR-SCL-03 | P3 | Defined |
| RTM-AN-03 | Monthly revenue summary | FR-AN-04 | NFR-PERF-07, NFR-SCL-03 | P3 | Defined |
| RTM-AN-04 | Low stock overview | FR-AN-05 | NFR-PERF-01 | P2 | Defined |
| RTM-AN-05 | Prescription volume trends | FR-AN-06 | NFR-PERF-07, NFR-SCL-03 | P3 | Defined |
| RTM-AN-06 | Export reports as CSV or PDF | FR-AN-07 | NFR-PERF-07 | P4 | Defined |

---

## 8. Mobile Application

| RTM ID | High-Level Requirement | Functional Requirements | Non-Functional Requirements | Priority | Status |
|---|---|---|---|---|---|
| RTM-MB-01 | Authentication (login / logout / biometric) | FR-MB-01, FR-MB-02, FR-MB-03 | NFR-SEC-13, NFR-SEC-14, NFR-SEC-15 | P1 | Defined |
| RTM-MB-02 | View prescriptions and pickup status | FR-MB-04, FR-MB-05 | NFR-PERF-03, NFR-USE-09 | P1 | Defined |
| RTM-MB-03 | Daily medication schedule with reminders | FR-MB-06, FR-MB-07, FR-MB-08 | NFR-USE-08 | P2 | Defined |
| RTM-MB-04 | Request refills | FR-MB-09, FR-MB-10 | NFR-AVL-03 | P2 | Defined |
| RTM-MB-05 | Scan prescription barcode | FR-MB-11, FR-MB-12, FR-MB-13 | NFR-USE-08 | P3 | Defined |

---

## 9. Non-Functional Coverage Summary

The table below confirms which NFR categories are addressed across the functional modules.

| NFR Category | NFR IDs | Covered By (RTM IDs) |
|---|---|---|
| Security — Auth & Authorisation | NFR-SEC-01 to NFR-SEC-05 | RTM-UM-03, RTM-UM-05, RTM-AN-01, RTM-MB-01 |
| Security — Data Protection | NFR-SEC-06 to NFR-SEC-09 | RTM-UM-02, RTM-UM-03 |
| Security — Input | NFR-SEC-10 to NFR-SEC-12 | RTM-UM-02, RTM-UM-06, RTM-RX-01 |
| Security — Mobile | NFR-SEC-13 to NFR-SEC-15 | RTM-MB-01 |
| Performance — Response Times | NFR-PERF-01 to NFR-PERF-03 | RTM-PT-02, RTM-RX-04, RTM-MB-02 |
| Performance — Database & Cache | NFR-PERF-04 to NFR-PERF-05 | RTM-PT-01, RTM-DG-01, RTM-BL-04 |
| Performance — Reports | NFR-PERF-06 to NFR-PERF-07 | RTM-BL-01, RTM-AN-02 to RTM-AN-06 |
| Scalability | NFR-SCL-01 to NFR-SCL-05 | RTM-NT-01 to RTM-NT-05, RTM-AN-02 to RTM-AN-05 |
| Availability & Reliability | NFR-AVL-01 to NFR-AVL-08 | RTM-NT-01 to RTM-NT-04, RTM-MB-04 |
| Usability & Accessibility | NFR-USE-01 to NFR-USE-09 | RTM-UM-06, RTM-MB-02 to RTM-MB-05 |
| Maintainability | NFR-MNT-01 to NFR-MNT-07 | All modules (cross-cutting) |
| Data Integrity & Audit | NFR-AUD-01 to NFR-AUD-06 | RTM-RX-03, RTM-RX-06, RTM-DG-02, RTM-BL-01 to RTM-BL-03 |
| Compliance & Privacy | NFR-COMP-01 to NFR-COMP-05 | RTM-PT-02, RTM-BL-04 |
| Interoperability | NFR-INT-01 to NFR-INT-06 | All modules (cross-cutting) |

---

## 10. Summary Statistics

| Module | Total RTM Entries | P1 | P2 | P3 | P4 |
|---|---|---|---|---|---|
| User Management | 6 | 3 | 3 | 0 | 0 |
| Patient Module | 5 | 2 | 3 | 0 | 0 |
| Prescription Management | 6 | 4 | 2 | 0 | 0 |
| Drug & Inventory | 5 | 2 | 2 | 1 | 0 |
| Billing & Payments | 4 | 1 | 2 | 1 | 0 |
| Notifications & Alerts | 5 | 0 | 3 | 2 | 0 |
| Analytics Dashboard | 6 | 0 | 2 | 3 | 1 |
| Mobile Application | 5 | 2 | 2 | 1 | 0 |
| **Total** | **42** | **14** | **19** | **8** | **1** |
