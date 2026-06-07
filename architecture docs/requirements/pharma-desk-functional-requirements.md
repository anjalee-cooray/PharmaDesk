# PharmaDesk — Functional Requirements Document

**Version:** 1.0  
**Date:** 2026-06-06  
**Project:** PharmaDesk  

---

## Table of Contents

1. [User Management](#1-user-management)
2. [Patient Module](#2-patient-module)
3. [Prescription Management](#3-prescription-management)
4. [Drug & Inventory Management](#4-drug--inventory-management)
5. [Billing & Payments](#5-billing--payments)
6. [Notifications & Alerts](#6-notifications--alerts)
7. [Analytics Dashboard](#7-analytics-dashboard)
8. [Mobile Application](#8-mobile-application)
9. [Non-Functional Requirements](#9-non-functional-requirements)

---

## 1. User Management

### 1.1 Roles & Permissions

| Role | Description |
|---|---|
| Patient | Registered individual who receives prescriptions and medications |
| Pharmacist | Licensed staff who manages prescriptions and dispenses medication |
| Admin | System administrator with full access to all modules |

### 1.2 Registration

**FR-UM-01** — Patient self-registration shall be available via web and mobile interfaces.  
**FR-UM-02** — Pharmacist and Admin accounts shall only be created by an Admin.  
**FR-UM-03** — Registration form shall collect: full name, email, phone number, date of birth, and role.  
**FR-UM-04** — Email address must be unique across all accounts.  
**FR-UM-05** — Upon successful registration, the system shall send an email verification link.  
**FR-UM-06** — Accounts shall remain inactive until email is verified.

### 1.3 Authentication

**FR-UM-07** — All users shall authenticate via email and password.  
**FR-UM-08** — The system shall issue a JWT access token upon successful login, valid for 15 minutes.  
**FR-UM-09** — The system shall issue a refresh token valid for 7 days to support session continuity.  
**FR-UM-10** — Logout shall invalidate the refresh token server-side.  
**FR-UM-11** — After 5 consecutive failed login attempts, the account shall be temporarily locked for 15 minutes.  
**FR-UM-12** — Users shall be able to reset their password via a time-limited email link (valid 30 minutes).

### 1.4 Role-Based Access Control

**FR-UM-13** — All API endpoints and UI routes shall enforce role-based access control.  
**FR-UM-14** — A user shall only access features and data permitted by their role.  
**FR-UM-15** — Attempting to access an unauthorized resource shall return an appropriate error and be logged.

### 1.5 Profile Management

**FR-UM-16** — All users shall be able to view and update their own profile information (name, phone, password).  
**FR-UM-17** — Patients shall additionally manage: address, emergency contact, and known allergies.  
**FR-UM-18** — Admin shall be able to deactivate or reactivate any user account.  
**FR-UM-19** — Deactivated users shall not be able to log in.

---

## 2. Patient Module

### 2.1 Patient Profile

**FR-PT-01** — The system shall maintain a patient profile containing: name, date of birth, contact details, address, known allergies, and account status.  
**FR-PT-02** — Pharmacists and Admins shall be able to search patients by name, email, or patient ID.  
**FR-PT-03** — Patient records shall be paginated when displayed in list views.

### 2.2 Prescription Viewing

**FR-PT-04** — Patients shall be able to view all their prescriptions (active and past) from their dashboard.  
**FR-PT-05** — Each prescription entry shall display: drug name, dosage, frequency, prescribed date, status, and dispensing pharmacist.  
**FR-PT-06** — Patients shall be able to filter prescriptions by status (active, completed, cancelled) and date range.

### 2.3 Refill Requests

**FR-PT-07** — Patients shall be able to submit a refill request for any active prescription that is eligible for refill.  
**FR-PT-08** — A prescription shall be eligible for refill only if the refill count has not been exhausted.  
**FR-PT-09** — Refill requests shall appear in the pharmacist's queue for review and action.  
**FR-PT-10** — Patients shall receive a notification when their refill request is approved or rejected.

### 2.4 Pickup Status

**FR-PT-11** — Patients shall be able to view the current pickup status of each dispensed prescription.  
**FR-PT-12** — Pickup statuses shall include: Ready for Pickup, Picked Up, Expired (not collected within 7 days).  
**FR-PT-13** — The system shall notify the patient when their prescription is ready for pickup.

### 2.5 Refill Reminders

**FR-PT-14** — The system shall automatically send a refill reminder to the patient 7 days before the estimated end of their current medication supply.

---

## 3. Prescription Management

### 3.1 Creating Prescriptions

**FR-RX-01** — Pharmacists shall be able to create a new digital prescription for a registered patient.  
**FR-RX-02** — A prescription shall include: patient, drug name, dosage, frequency, duration, number of refills allowed, and pharmacist notes.  
**FR-RX-03** — The system shall validate that the prescribed drug exists in the drug catalog.  
**FR-RX-04** — The system shall check for duplicate or conflicting prescriptions for the same patient and drug and display a warning before submission.

### 3.2 Prescription Workflow

**FR-RX-05** — Each prescription shall progress through the following statuses:

```
Pending → Verified → Dispensed → Rejected
```

**FR-RX-06** — Only a Pharmacist or Admin may change the status of a prescription.  
**FR-RX-07** — A prescription in Dispensed or Rejected status shall not be editable.  
**FR-RX-08** — When a prescription is dispensed, the system shall automatically deduct the dispensed quantity from the drug's stock.

### 3.3 Reviewing & Verifying

**FR-RX-09** — Pharmacists shall see a queue of all pending prescriptions sorted by creation date (oldest first).  
**FR-RX-10** — Pharmacists shall be able to add or edit notes on any prescription that is not yet dispensed or rejected.  
**FR-RX-11** — Pharmacists shall be able to reject a prescription with a mandatory rejection reason.

### 3.4 Modifying & Cancelling

**FR-RX-12** — A prescription in Pending or Verified status may be modified (dosage, frequency, refills) by a Pharmacist or Admin.  
**FR-RX-13** — A prescription in Pending or Verified status may be cancelled by a Pharmacist or Admin.  
**FR-RX-14** — Patients shall not be able to modify or cancel prescriptions directly.

### 3.5 Prescription History & Audit Trail

**FR-RX-15** — The system shall maintain a complete audit trail for every prescription, recording: action taken, user who performed it, timestamp, and before/after values.  
**FR-RX-16** — Pharmacists and Admins shall be able to view the full history of any prescription.  
**FR-RX-17** — Audit logs shall be immutable; no user shall be able to edit or delete them.

---

## 4. Drug & Inventory Management

### 4.1 Drug Catalog

**FR-DG-01** — The system shall maintain a catalog of drugs, each with: name, generic name, category, dosage forms, unit price, and active status.  
**FR-DG-02** — Pharmacists and Admins shall be able to add, edit, or deactivate drugs in the catalog.  
**FR-DG-03** — Deactivated drugs shall not appear in prescription creation forms but shall remain visible in historical records.  
**FR-DG-04** — The drug catalog shall be searchable and filterable by name, category, and status.

### 4.2 Stock Management

**FR-DG-05** — Each drug shall have an associated stock record tracking: quantity on hand, unit of measure, low stock threshold, and expiry date(s).  
**FR-DG-06** — Stock levels shall be automatically decremented when a prescription is dispensed.  
**FR-DG-07** — Pharmacists and Admins shall be able to manually adjust stock levels with a mandatory reason note.  
**FR-DG-08** — The system shall support multiple stock batches per drug to track different expiry dates.

### 4.3 Expiry Tracking

**FR-DG-09** — The system shall flag any drug batch expiring within 30 days and display a warning in the inventory view.  
**FR-DG-10** — The system shall send an expiry alert notification to pharmacists 30 days and 7 days before a batch expires.  
**FR-DG-11** — Expired batches shall be visually marked and excluded from dispensing.

### 4.4 Low Stock Alerts

**FR-DG-12** — Each drug shall have a configurable low stock threshold.  
**FR-DG-13** — When stock falls at or below the threshold, the system shall trigger a low stock alert to pharmacists.  
**FR-DG-14** — The low stock dashboard widget shall list all drugs currently below threshold.

### 4.5 Suppliers & Purchase Orders

**FR-DG-15** — The system shall maintain a supplier directory with: name, contact person, phone, email, and address.  
**FR-DG-16** — Pharmacists and Admins shall be able to create purchase orders specifying: supplier, drug, quantity, and expected delivery date.  
**FR-DG-17** — Purchase orders shall have statuses: Draft, Submitted, Received, Cancelled.  
**FR-DG-18** — Marking a purchase order as Received shall automatically increment the corresponding drug's stock.

---

## 5. Billing & Payments

### 5.1 Invoice Generation

**FR-BL-01** — The system shall automatically generate an invoice when a prescription is moved to Dispensed status.  
**FR-BL-02** — Each invoice shall include: invoice number, patient name, drug(s), quantity, unit price, applicable discounts, total amount, and date issued.  
**FR-BL-03** — Invoice numbers shall be unique and auto-incremented.

### 5.2 Discounts

**FR-BL-04** — Pharmacists and Admins shall be able to define discount rules (percentage or fixed amount) applicable to specific drugs or patient groups.  
**FR-BL-05** — Applicable discounts shall be automatically applied during invoice generation and displayed as line items.

### 5.3 Payment Tracking

**FR-BL-06** — Each invoice shall have a payment status: Pending, Paid, or Partial.  
**FR-BL-07** — Pharmacists shall be able to record payment against an invoice, specifying amount and payment method (cash, card, bank transfer).  
**FR-BL-08** — Partial payments shall be tracked, and the outstanding balance shall be displayed.  
**FR-BL-09** — An invoice shall move to Paid status automatically when the full amount is received.

### 5.4 Billing History

**FR-BL-10** — Patients shall be able to view their own billing history from their dashboard.  
**FR-BL-11** — Pharmacists and Admins shall be able to view and filter billing records by patient, date range, and payment status.  
**FR-BL-12** — Invoices shall be exportable as PDF.

---

## 6. Notifications & Alerts

### 6.1 Notification Channels

**FR-NT-01** — The system shall support in-app notifications for all users.  
**FR-NT-02** — The system shall support email notifications for key events.  
**FR-NT-03** — The mobile app shall support push notifications for patients.

### 6.2 Notification Events

| Event | Recipient | Channel |
|---|---|---|
| Prescription ready for pickup | Patient | In-app, email, push |
| Refill request approved/rejected | Patient | In-app, email, push |
| Refill reminder (7 days before supply ends) | Patient | In-app, email, push |
| Low stock alert | Pharmacist | In-app, email |
| Drug batch expiry warning (30 days, 7 days) | Pharmacist | In-app, email |
| New prescription created | Pharmacist | In-app |
| Purchase order received | Admin, Pharmacist | In-app |

**FR-NT-04** — Users shall be able to configure which email notifications they receive from their profile settings.  
**FR-NT-05** — All notifications shall be stored and accessible in an in-app notification centre.  
**FR-NT-06** — Users shall be able to mark notifications as read individually or all at once.

---

## 7. Analytics Dashboard

### 7.1 Access

**FR-AN-01** — The analytics dashboard shall be accessible to Pharmacists and Admins only.  
**FR-AN-02** — Admins shall see system-wide analytics; Pharmacists shall see data relevant to their activity.

### 7.2 Dashboard Widgets

**FR-AN-03 — Most Dispensed Drugs:** Display a ranked list of the top 10 most dispensed drugs for a selectable time period (weekly, monthly, yearly).

**FR-AN-04 — Monthly Revenue Summary:** Display total invoiced amount, total collected, and outstanding balance per month, presented as a chart and summary table.

**FR-AN-05 — Low Stock Overview:** Display all drugs currently at or below their low stock threshold with current quantity and threshold value.

**FR-AN-06 — Prescription Volume Trends:** Display the number of prescriptions created, dispensed, and rejected over time as a line or bar chart, filterable by date range.

### 7.3 Export

**FR-AN-07** — Admins shall be able to export any dashboard report as CSV or PDF.

---

## 8. Mobile Application

*Platform: React Native (iOS & Android) — Patient role only.*

### 8.1 Authentication

**FR-MB-01** — The mobile app shall support login and logout using the same JWT-based authentication as the web app.  
**FR-MB-02** — The app shall support biometric authentication (Face ID / fingerprint) as a secondary login option after initial password login.  
**FR-MB-03** — The app shall securely store the refresh token using the device's secure storage.

### 8.2 Prescription View

**FR-MB-04** — Patients shall be able to view their active and past prescriptions from the mobile app.  
**FR-MB-05** — Each prescription shall display drug name, dosage, frequency, status, and pickup status.

### 8.3 Medication Schedule

**FR-MB-06** — The app shall generate a daily medication schedule based on the patient's active prescriptions and dosage frequencies.  
**FR-MB-07** — The app shall send local push notifications at the scheduled medication times as reminders.  
**FR-MB-08** — Patients shall be able to mark a dose as taken from the notification or in-app.

### 8.4 Refill Requests

**FR-MB-09** — Patients shall be able to submit refill requests from the mobile app.  
**FR-MB-10** — The app shall display the refill eligibility status for each active prescription.

### 8.5 Barcode Scanning

**FR-MB-11** — The app shall allow patients to scan a prescription barcode using the device camera.  
**FR-MB-12** — Scanning a valid barcode shall navigate the patient to the corresponding prescription detail view.  
**FR-MB-13** — Scanning an invalid or unrecognised barcode shall display an appropriate error message.

---

## 9. Non-Functional Requirements

### 9.1 Security

**FR-NF-01** — All API endpoints shall be protected by JWT authentication unless explicitly public (e.g., registration, login).  
**FR-NF-02** — Role guards shall be applied at the route level to enforce permissions server-side.  
**FR-NF-03** — All passwords shall be hashed using bcrypt with a minimum cost factor of 12.  
**FR-NF-04** — All data in transit shall be encrypted using HTTPS/TLS 1.2 or higher.  
**FR-NF-05** — Sensitive data (tokens, passwords) shall never be logged.

### 9.2 Input Validation

**FR-NF-06** — All user-submitted form inputs shall be validated on both client and server sides.  
**FR-NF-07** — Validation errors shall return clear, field-specific error messages.  
**FR-NF-08** — The system shall sanitize all inputs to prevent SQL injection and XSS attacks.

### 9.3 Performance & Pagination

**FR-NF-09** — All list views (patients, drugs, prescriptions, invoices) shall be paginated with a default page size of 20 records.  
**FR-NF-10** — Page size shall be configurable by the user up to a maximum of 100 records per page.  
**FR-NF-11** — API responses for paginated endpoints shall include total record count and current page metadata.

### 9.4 Audit Logging

**FR-NF-12** — All create, update, and delete operations on prescriptions, invoices, and drug stock shall be captured in an audit log.  
**FR-NF-13** — Audit log entries shall be immutable and shall not be deletable by any user role.  
**FR-NF-14** — Each audit log entry shall record: entity type, entity ID, action, user, timestamp, and changed fields.

### 9.5 UI & Accessibility

**FR-NF-15** — The web application shall be fully responsive across desktop, tablet, and mobile screen sizes.  
**FR-NF-16** — The UI shall conform to WCAG 2.1 Level AA accessibility standards.
