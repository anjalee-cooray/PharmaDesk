# PharmaDesk — Non-Functional Requirements Document

**Version:** 1.0  
**Date:** 2026-06-06  
**Project:** PharmaDesk  

---

## Table of Contents

1. [Security](#1-security)
2. [Performance](#2-performance)
3. [Scalability](#3-scalability)
4. [Availability & Reliability](#4-availability--reliability)
5. [Usability & Accessibility](#5-usability--accessibility)
6. [Maintainability](#6-maintainability)
7. [Data Integrity & Audit](#7-data-integrity--audit)
8. [Compliance & Privacy](#8-compliance--privacy)
9. [Interoperability](#9-interoperability)

---

## 1. Security

### 1.1 Authentication & Authorisation

**NFR-SEC-01** — All API endpoints shall require a valid JWT access token unless explicitly marked public (e.g., `/auth/login`, `/auth/register`).  
**NFR-SEC-02** — JWT access tokens shall expire after 15 minutes. Refresh tokens shall expire after 7 days.  
**NFR-SEC-03** — Refresh tokens shall be stored server-side and invalidated on logout or password change.  
**NFR-SEC-04** — Role-based access control shall be enforced server-side on every request; client-side guards are supplemental only.  
**NFR-SEC-05** — After 5 consecutive failed login attempts the account shall be locked for 15 minutes and the user notified by email.

### 1.2 Data Protection

**NFR-SEC-06** — All passwords shall be hashed using bcrypt with a minimum cost factor of 12 before storage.  
**NFR-SEC-07** — All data in transit shall be encrypted using HTTPS with TLS 1.2 or higher.  
**NFR-SEC-08** — Sensitive fields (tokens, passwords, secrets) shall never appear in application logs.  
**NFR-SEC-09** — Database credentials and API secrets shall be managed via environment variables or a secrets manager; they shall never be committed to source control.

### 1.3 Input Security

**NFR-SEC-10** — All user inputs shall be validated and sanitised on the server side to prevent SQL injection, XSS, and command injection attacks.  
**NFR-SEC-11** — File uploads (e.g., prescription attachments) shall be validated for allowed MIME types and maximum file size (5 MB).  
**NFR-SEC-12** — API rate limiting shall be applied: maximum 100 requests per minute per authenticated user, 20 per minute for unauthenticated endpoints.

### 1.4 Mobile Security

**NFR-SEC-13** — Refresh tokens on mobile devices shall be stored using the platform's secure storage (iOS Keychain / Android Keystore).  
**NFR-SEC-14** — The mobile app shall not cache sensitive patient data in plaintext on the device filesystem.  
**NFR-SEC-15** — Certificate pinning shall be implemented on the mobile app to prevent man-in-the-middle attacks.

---

## 2. Performance

### 2.1 Response Times

**NFR-PERF-01** — API endpoints shall respond within 300 ms at the 95th percentile under normal load (up to 100 concurrent users).  
**NFR-PERF-02** — Page load time for the web application shall not exceed 3 seconds on a standard broadband connection.  
**NFR-PERF-03** — The mobile app shall render the patient dashboard within 2 seconds of authentication.

### 2.2 Database

**NFR-PERF-04** — Database queries for paginated list views shall be optimised with appropriate indexes and shall complete within 100 ms.  
**NFR-PERF-05** — Frequently read data (drug catalog, role permissions) shall be cached at the application layer with a TTL of 5 minutes.

### 2.3 File & Report Generation

**NFR-PERF-06** — PDF invoice generation shall complete within 5 seconds for a single invoice.  
**NFR-PERF-07** — Analytics report exports shall complete within 30 seconds for up to 12 months of data.

---

## 3. Scalability

**NFR-SCL-01** — The backend API shall be stateless so that multiple instances can run behind a load balancer without session affinity.  
**NFR-SCL-02** — The system shall support horizontal scaling of the API layer to handle traffic increases without architectural changes.  
**NFR-SCL-03** — The database shall support read replicas to offload reporting and analytics queries from the primary instance.  
**NFR-SCL-04** — Notification dispatch (email, push) shall be handled asynchronously via a message queue to avoid blocking API responses.  
**NFR-SCL-05** — The system architecture shall support up to 10,000 registered patients and 1,000 daily prescription transactions without degradation.

---

## 4. Availability & Reliability

### 4.1 Uptime

**NFR-AVL-01** — The system shall target 99.5% uptime (excluding scheduled maintenance windows).  
**NFR-AVL-02** — Scheduled maintenance windows shall not exceed 2 hours per month and shall occur outside peak hours (06:00–22:00 local time).

### 4.2 Fault Tolerance

**NFR-AVL-03** — The system shall implement graceful degradation; if the notification service is unavailable, core prescription and billing functions shall continue to operate.  
**NFR-AVL-04** — All background jobs (notifications, report generation) shall implement retry logic with exponential backoff (max 3 retries).  
**NFR-AVL-05** — Failed background jobs shall be logged and surfaced in an admin error queue for manual review.

### 4.3 Backup & Recovery

**NFR-AVL-06** — The database shall be backed up automatically once every 24 hours with backups retained for 30 days.  
**NFR-AVL-07** — The Recovery Point Objective (RPO) shall be no more than 24 hours.  
**NFR-AVL-08** — The Recovery Time Objective (RTO) shall be no more than 4 hours in the event of a critical failure.

---

## 5. Usability & Accessibility

### 5.1 Web Application

**NFR-USE-01** — The web UI shall be fully responsive and function correctly on screen widths from 360 px (mobile) to 2560 px (wide desktop).  
**NFR-USE-02** — The web application shall conform to WCAG 2.1 Level AA accessibility standards.  
**NFR-USE-03** — All interactive elements shall be keyboard-navigable.  
**NFR-USE-04** — Error messages shall be specific, actionable, and displayed adjacent to the relevant field.  
**NFR-USE-05** — All paginated list views shall display a loading indicator during data fetch.

### 5.2 Mobile Application

**NFR-USE-06** — The mobile app shall support iOS 15+ and Android 11+.  
**NFR-USE-07** — The app shall support both light and dark mode, following the device system preference by default.  
**NFR-USE-08** — Touch targets shall be a minimum of 44 × 44 pt to comply with platform accessibility guidelines.  
**NFR-USE-09** — The app shall be usable offline for viewing cached prescriptions, with a clear indicator when operating without connectivity.

---

## 6. Maintainability

**NFR-MNT-01** — The codebase shall follow a consistent coding standard enforced by a linter (e.g., ESLint for TypeScript/JavaScript) in CI.  
**NFR-MNT-02** — Unit test coverage shall be maintained at a minimum of 80% for business logic layers (services, utilities).  
**NFR-MNT-03** — Integration tests shall cover all critical API endpoints.  
**NFR-MNT-04** — All environment-specific configuration shall be externalised via environment variables; no hardcoded configuration values shall exist in source code.  
**NFR-MNT-05** — The API shall be documented using OpenAPI 3.0 (Swagger), kept up to date with every release.  
**NFR-MNT-06** — Database schema changes shall be managed via versioned migrations; direct schema edits on production are prohibited.  
**NFR-MNT-07** — CI/CD pipelines shall run linting, tests, and build verification on every pull request before merge.

---

## 7. Data Integrity & Audit

**NFR-AUD-01** — All create, update, and delete operations on prescriptions, invoices, drug stock, and user accounts shall be recorded in an immutable audit log.  
**NFR-AUD-02** — Each audit log entry shall capture: entity type, entity ID, action performed, the user who performed it, timestamp (UTC), and a diff of changed fields.  
**NFR-AUD-03** — Audit logs shall not be modifiable or deletable by any user role, including Admin.  
**NFR-AUD-04** — Audit logs shall be retained for a minimum of 5 years.  
**NFR-AUD-05** — The system shall use database transactions to ensure atomicity for operations that affect multiple tables (e.g., dispensing a prescription decrements stock and creates an invoice in a single transaction).  
**NFR-AUD-06** — All timestamps stored in the database shall be in UTC. The UI shall display times converted to the user's local timezone.

---

## 8. Compliance & Privacy

**NFR-COMP-01** — Patient personal and medical data shall be treated as sensitive and access shall be restricted to authorised roles only.  
**NFR-COMP-02** — Patients shall only be able to view their own data; no patient shall be able to access another patient's records.  
**NFR-COMP-03** — The system shall provide a mechanism for Admin to export or delete a patient's personal data upon request, in support of applicable data protection regulations.  
**NFR-COMP-04** — Data deletion shall soft-delete records (flagged as deleted, not physically removed) to preserve referential integrity; physical purge shall require explicit Admin action after a 30-day grace period.  
**NFR-COMP-05** — The system shall log all access to patient records (who accessed, when, which record) for accountability.

---

## 9. Interoperability

**NFR-INT-01** — The backend shall expose a RESTful API following standard HTTP conventions (correct use of verbs, status codes, and headers).  
**NFR-INT-02** — All API request and response bodies shall use JSON with consistent field naming (camelCase).  
**NFR-INT-03** — Paginated responses shall include a standard envelope: `{ data: [], meta: { page, pageSize, total } }`.  
**NFR-INT-04** — The system shall support versioned API endpoints (e.g., `/api/v1/`) to allow future breaking changes without disrupting existing clients.  
**NFR-INT-05** — The mobile app shall consume the same REST API as the web application; no mobile-specific backend shall be maintained separately.  
**NFR-INT-06** — Email delivery shall use a third-party transactional email provider (e.g., SendGrid, Mailgun) via their API, not a direct SMTP server.
