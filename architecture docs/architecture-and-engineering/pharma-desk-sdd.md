# PharmaDesk — System Design Document (SDD)

**Version:** 5.0  
**Date:** 2026-06-06  
**Project:** PharmaDesk  

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [Technology Stack](#3-technology-stack)
4. [Java 21 Feature Usage](#4-java-21-feature-usage)
5. [Component Design](#5-component-design)
6. [Database Design](#6-database-design)
7. [API Design](#7-api-design)
8. [Security Architecture](#8-security-architecture)
9. [Notification Lambdas](#9-notification-lambdas)
9b. [Analytics Lambdas](#9b-analytics-lambdas)
10. [Mobile Application Architecture](#10-mobile-application-architecture)
11. [Infrastructure & Deployment](#11-infrastructure--deployment)
12. [Local Infrastructure (Docker)](#12-local-infrastructure-docker)
13. [Error Handling & Logging](#13-error-handling--logging)
14. [Key Design Decisions](#14-key-design-decisions)
15. [Design Patterns](#15-design-patterns)
16. [Algorithms](#16-algorithms)

---

## 1. System Overview

PharmaDesk is a pharmacy management platform serving three roles — Patient, Pharmacist, and Admin. It provides prescription lifecycle management, drug inventory tracking, billing, notifications, and analytics via a responsive web application and a React Native mobile app for patients.

### 1.1 System Boundaries

```
                         ┌─────────────────────┐
                         │        Okta         │
                         │  (Auth Server /     │
                         │   Universal Dir)    │
                         └──────────┬──────────┘
                                    │ OIDC / OAuth2
┌───────────────────────────────────▼──────────────────────────────────────┐
│                             PharmaDesk System                            │
│                                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐               │
│  │  Web App     │    │  Mobile App  │    │  Admin UI    │               │
│  │  (React)     │    │(React Native)│    │  (React)     │               │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘               │
│         └───────────────────┼─────────────────────┘                     │
│                             │ HTTPS / REST + Bearer Token               │
│                    ┌────────▼──────────┐   ┌─────────────────────────┐  │
│                    │   Core Monolith   │   │  API Gateway + Lambda   │  │
│                    │   (ECS Fargate)   │   │  analytics-api-fn       │  │
│                    │   Spring Boot     │   │  (dashboard queries)    │  │
│                    │   OAuth2 Resource │   └────────────┬────────────┘  │
│                    │   Server          │                │               │
│                    └────────┬──────────┘                │               │
│                             │                           │               │
│          ┌──────────────────┼──────────────┐            │               │
│          │                  │              │            │               │
│   ┌──────▼───────┐  ┌───────▼──────┐ ┌────▼────────────▼─────────┐     │
│   │  PostgreSQL  │  │    Redis     │ │        Amazon SQS          │     │
│   │  (Primary)   │  │   (Cache)    │ │                            │     │
│   └──────┬───────┘  └─────────────┘ │  pharmadesk-email   ──────▶│──┐  │
│          │ Read                      │  pharmadesk-push    ──────▶│  │  │
│   ┌──────▼───────┐                  │  pharmadesk-alerts  ──────▶│  │  │
│   │  PostgreSQL  │◀─────────────────│  pharmadesk-domain-events─▶│  │  │
│   │ Read Replica │  RDS Proxy       └────────────────────────────┘  │  │
│   └─────────────┘                                                    │  │
│                                                                      │  │
│   ┌──────────────────────────────────────────────────────────────┐   │  │
│   │                     AWS Lambda Functions                     │   │  │
│   │                                                              │◀──┘  │
│   │  email-handler-fn    push-handler-fn    alert-handler-fn     │      │
│   │  analytics-projector-fn                                      │      │
│   └──────────────────────────────┬───────────────────────────────┘      │
└──────────────────────────────────┼──────────────────────────────────────┘
                                   │
               ┌───────────────────┴───────────────────┐
               │                                       │
      ┌────────▼────────┐                    ┌─────────▼──────┐
      │ SendGrid / FCM  │                    │  PostgreSQL    │
      │    / APNs       │                    │  Read Replica  │
      └─────────────────┘                    │  (via RDS Proxy│
                                             └────────────────┘
```

### 1.2 User Roles

| Role | Primary Interface | Key Capabilities |
|---|---|---|
| Patient | Web + Mobile | View prescriptions, request refills, track pickup, view billing |
| Pharmacist | Web | Manage prescriptions, inventory, billing, receive alerts |
| Admin | Web | Full system access, user management, analytics, configuration |

---

## 2. Architecture Overview

PharmaDesk follows a **hybrid architecture**: a layered monolith for the tightly coupled transactional core, with two serverless Lambda groups extracted at natural async boundaries — Notification Lambdas and Analytics Lambdas.

The Core Monolith handles all operations requiring atomicity (prescriptions, patients, drugs, billing) and runs on ECS Fargate. Notification Lambdas consume SQS events and dispatch email and push notifications. Analytics Lambdas maintain a read-optimised PostgreSQL projection and serve dashboard queries via API Gateway. All Lambda functions are event-driven with no synchronous dependency on the core — they can fail, scale, or be redeployed independently without affecting prescription workflows.

### 2.1 Architectural Pattern

```
┌──────────────────────────────────────────┐
│              Client Layer                │
│   Web SPA (React)  │  Mobile (RN)        │
└───────────┬──────────────────┬───────────┘
            │ HTTPS / REST     │ HTTPS / REST
┌───────────▼──────────────┐   │
│      Core Monolith       │   │ (analytics dashboard)
│  (ECS Fargate)           │   ▼
│  ┌───────────────────┐   │ ┌──────────────────────────┐
│  │ Presentation      │   │ │  API Gateway             │
│  │ @RestController   │   │ │  + analytics-api-fn      │
│  │ Okta JWT          │   │ │  (Lambda SnapStart)      │
│  └─────────┬─────────┘   │ └────────────┬─────────────┘
│            │              │              │
│  ┌─────────▼─────────┐   │              │ RDS Proxy
│  │ Business Logic    │   │ ┌────────────▼─────────────┐
│  │ Sealed FSM        │   │ │  PostgreSQL Read Replica  │
│  │ Outbox Publisher  │───┼─│  (analytics projections)  │
│  └─────────┬─────────┘   │ └──────────────────────────┘
│            │         SQS  │              ▲
│  ┌─────────▼─────────┐   │              │ upsert projections
│  │ Data Access       │   │ ┌────────────┴─────────────┐
│  │ Spring Data JPA   │   │ │  analytics-projector-fn  │
│  │ Flyway            │   │ │  (Lambda SnapStart)      │
│  └───────────────────┘   │ └──────────────────────────┘
└──────────────────────────┘              ▲
            │ SQS events                  │ pharmadesk-domain-events
            ├────────────────────────────►│
            │                ┌────────────┴─────────────┐
            │                │  Notification Lambdas     │
            └───────────────►│  email-handler-fn        │
                             │  push-handler-fn         │
                             │  alert-handler-fn        │
                             │  (SnapStart, Java 21)    │
                             └──────────────────────────┘
```

### 2.2 Package Structure

Three independently deployable services, each with their own repository and deployment pipeline.

```
# ── Core Monolith ─────────────────────────────────────
com.pharmadesk.core/
├── security/       # Okta JWT converter, role extractor, security config
├── users/          # User profile sync from Okta, internal user records
├── patients/       # Patient profiles, search, pickup status
├── prescriptions/  # Prescription lifecycle, audit trail, conflict detection
├── drugs/          # Drug catalog, stock management, batch tracking
├── suppliers/      # Supplier directory, purchase orders
├── billing/        # Invoice generation, payment recording, discount rules
├── notifications/  # In-app notification centre only (DB records + preferences)
├── alerts/         # Low stock and expiry monitoring, outbox event dispatch
├── queue/          # SQS outbox publisher (produces events, does not consume)
└── common/         # Shared records, exceptions, pagination, audit

# ── Notification Service ───────────────────────────────
com.pharmadesk.notification/
├── consumer/       # @SqsListener workers (email-queue, push-queue)
├── email/          # EmailGateway → SendGrid adapter
├── push/           # PushGateway → FCM / APNs adapter
└── common/         # Shared message records, retry config

# ── Analytics Service ──────────────────────────────────
com.pharmadesk.analytics/
├── consumer/       # @SqsListener projector (domain-events-queue)
├── projection/     # Materialised view updaters (dispense counts, revenue)
├── api/            # REST endpoints for dashboard widgets and exports
└── common/         # Shared query models, pagination
```

---

## 3. Technology Stack

### 3.1 Backend

| Concern | Technology | Rationale |
|---|---|---|
| Language | Java 21 | LTS release; virtual threads, records, sealed classes, pattern matching |
| Framework | Spring Boot 3.2 | Native Java 21 support, virtual thread integration via one config flag |
| Web | Spring Web MVC (on virtual threads) | Replaces reactive stack — simpler code, same non-blocking throughput |
| Auth (IdP) | Okta | Managed identity provider — handles login, MFA, token lifecycle, RBAC groups |
| Auth (API) | Spring Security 6 + okta-spring-boot-starter | Configures API as OAuth2 Resource Server; validates Okta JWTs via JWKS |
| ORM | Spring Data JPA + Hibernate 6 | Declarative repositories, `@Transactional`, JPQL, native query support |
| Migrations | Flyway | Versioned SQL migrations, applied at startup |
| Validation | Jakarta Bean Validation 3 | `@Valid` on request DTOs, custom constraint annotations |
| Cache | Spring Cache + Redis (Lettuce) | `@Cacheable` on drug catalog and permission lookups |
| Queue | Amazon SQS + Spring Cloud AWS 3 | Managed, serverless queue; `@SqsListener` for consumer workers |
| Scheduler | Spring `@Scheduled` | Daily cron jobs (stock expiry, refill reminders) |
| Build | Gradle (Kotlin DSL) | Faster incremental builds than Maven |
| Testing | JUnit 5 + Mockito + Testcontainers + mock-oauth2-server | Unit and integration tests; real PostgreSQL, SQS Local, and mocked Okta in CI |

### 3.2 Frontend (Web)

| Concern | Technology |
|---|---|
| Framework | React 18 |
| Language | TypeScript |
| State Management | Zustand |
| Data Fetching | TanStack Query (React Query) |
| UI Component Library | shadcn/ui + Tailwind CSS |
| Forms | React Hook Form + Zod |
| Routing | React Router v6 |
| Charts | Recharts |
| Build Tool | Vite |

### 3.3 Mobile (React Native)

| Concern | Technology |
|---|---|
| Framework | React Native 0.74 (Expo) |
| Language | TypeScript |
| State Management | Zustand |
| Data Fetching | TanStack Query |
| Navigation | React Navigation v6 |
| Secure Storage | expo-secure-store |
| Push Notifications | Expo Notifications (FCM + APNs) |
| Barcode Scanner | expo-barcode-scanner |
| Local Notifications | expo-notifications |

### 3.4 Infrastructure

| Concern | Technology |
|---|---|
| Hosting | AWS ECS Fargate — 3 services: Core, Notification, Analytics |
| Web Hosting | S3 + CloudFront |
| Database (Core) | AWS RDS PostgreSQL 16 (Multi-AZ) |
| Database (Analytics) | PostgreSQL Read Replica (promoted to standalone if needed) |
| Cache | AWS ElastiCache (Redis 7) — Core only |
| Job Queue | Amazon SQS (Standard queues + Dead Letter Queues) |
| Identity Provider | Okta (Developer / Production org) |
| Email | SendGrid |
| Push Notifications | Firebase Cloud Messaging (Android) + APNs (iOS) |
| File Storage | AWS S3 |
| CI/CD | GitHub Actions — independent pipeline per service |
| Containerisation | Docker |
| Secrets Management | AWS Secrets Manager |

---

## 4. Java 21 Feature Usage

This section documents where and how Java 21 features are applied across the codebase.

### 4.1 Virtual Threads (Project Loom)

Enabled with a single Spring Boot property — no code changes required:

```yaml
# application.yml
spring:
  threads:
    virtual:
      enabled: true
```

Every incoming HTTP request and every `@SqsListener` invocation runs on a virtual thread. This gives the throughput of a reactive stack (non-blocking I/O waits are cheap) while keeping the familiar synchronous, imperative programming model across all service and repository code.

### 4.2 Records — DTOs and Value Objects

All request/response DTOs and internal value objects are Java records, eliminating boilerplate constructors, getters, `equals`, and `hashCode`:

```java
// Request DTO
public record CreatePrescriptionRequest(
    @NotNull UUID patientId,
    @NotNull UUID drugId,
    @NotBlank String dosage,
    @NotBlank String frequency,
    @Positive int durationDays,
    @Min(0) int refillsAllowed,
    String notes
) {}

// Response DTO
public record PrescriptionResponse(
    UUID id,
    String drugName,
    String dosage,
    String frequency,
    PrescriptionStatus status,
    PickupStatus pickupStatus,
    OffsetDateTime createdAt
) {}

// Internal value object — SQS message payload
public record NotificationMessage(
    String type,
    UUID recipientId,
    String title,
    String body
) {}
```

### 4.3 Sealed Classes — Prescription Status State Machine

The prescription status transitions are modelled as a sealed interface hierarchy. Pattern matching enforces exhaustiveness at compile time — adding a new status without handling it causes a compile error:

```java
public sealed interface PrescriptionEvent
    permits PrescriptionEvent.Verify,
            PrescriptionEvent.Dispense,
            PrescriptionEvent.Reject,
            PrescriptionEvent.Cancel {

    record Verify(UUID pharmacistId) implements PrescriptionEvent {}
    record Dispense(UUID pharmacistId, int quantityDispensed) implements PrescriptionEvent {}
    record Reject(UUID pharmacistId, String reason) implements PrescriptionEvent {}
    record Cancel(UUID performedById) implements PrescriptionEvent {}
}
```

The service layer applies events using pattern matching for switch:

```java
PrescriptionStatus nextStatus = switch (event) {
    case PrescriptionEvent.Verify v   -> applyVerify(prescription, v);
    case PrescriptionEvent.Dispense d -> applyDispense(prescription, d);
    case PrescriptionEvent.Reject r   -> applyReject(prescription, r);
    case PrescriptionEvent.Cancel c   -> applyCancel(prescription, c);
};
```

### 4.4 Pattern Matching for Switch — Error Mapping

The global exception handler uses pattern matching for switch to map domain exceptions to HTTP responses without instanceof chains:

```java
@ExceptionHandler
public ResponseEntity<ErrorResponse> handle(Exception ex) {
    return switch (ex) {
        case PrescriptionNotFoundException e ->
            ResponseEntity.status(404).body(error(404, e.getMessage()));
        case DuplicatePrescriptionException e ->
            ResponseEntity.status(409).body(error(409, e.getMessage()));
        case InvalidStatusTransitionException e ->
            ResponseEntity.status(422).body(error(422, e.getMessage()));
        case AccessDeniedException e ->
            ResponseEntity.status(403).body(error(403, "Access denied"));
        default ->
            ResponseEntity.status(500).body(error(500, "Internal server error"));
    };
}
```

### 4.5 Text Blocks — SQL and JSON Templates

Complex native SQL queries and notification message templates use text blocks for readability:

```java
@Query(nativeQuery = true, value = """
    SELECT d.id, d.name, COUNT(p.id) AS dispense_count
    FROM drugs d
    JOIN prescriptions p ON p.drug_id = d.id
    WHERE p.status = 'DISPENSED'
      AND p.updated_at >= :from
      AND p.updated_at < :to
    GROUP BY d.id, d.name
    ORDER BY dispense_count DESC
    LIMIT :limit
    """)
List<TopDrugProjection> findTopDispensedDrugs(
    @Param("from") OffsetDateTime from,
    @Param("to") OffsetDateTime to,
    @Param("limit") int limit
);
```

### 4.6 Sequenced Collections

Stock batch FEFO ordering leverages `SequencedCollection` to cleanly get the first-expiring batch:

```java
// Returns batches ordered by expiry_date ASC — a SequencedCollection
SequencedCollection<DrugStockBatch> batches = stockBatchRepository
    .findByDrugIdOrderByExpiryDateAsc(drugId);

DrugStockBatch earliest = batches.getFirst(); // Java 21 SequencedCollection API
```

---

## 5. Component Design

### 5.1 Authentication Flow

Okta owns the full auth lifecycle — login, MFA, token issuance, refresh, and logout. The Spring Boot API acts purely as an OAuth2 Resource Server: it never issues or stores tokens.

```
Client                       Okta                   Spring Boot API
  │                            │                           │
  │── Redirect to Okta ───────▶│                           │
  │   login page               │                           │
  │                            │── authenticate user       │
  │                            │── enforce MFA             │
  │                            │── apply group/role rules  │
  │◀── redirect back with ─────│                           │
  │    authorization code      │                           │
  │                            │                           │
  │── exchange code ──────────▶│                           │
  │                            │── return access_token     │
  │                            │   id_token, refresh_token │
  │◀── tokens ─────────────────│                           │
  │                            │                           │
  │── GET /api/v1/prescriptions/my ──────────────────────▶│
  │   Authorization: Bearer <access_token>                 │
  │                            │                           │
  │                            │◀── fetch JWKS (cached) ───│
  │                            │── return public keys ────▶│
  │                            │                           │
  │                            │   validate signature,     │
  │                            │   expiry, issuer,         │
  │                            │   audience, groups claim  │
  │                            │                           │
  │◀── 200 response ───────────────────────────────────────│
  │                            │                           │
  │── POST /api/v1/auth/logout ──────────────────────────▶│
  │                            │                           │
  │                            │── revoke token ──────────▶│
  │◀── redirect to Okta ───────────────────────────────────│
  │   logout endpoint          │                           │
```

### 5.2 Prescription Lifecycle

```
                    ┌─────────┐
                    │ PENDING │◀── Pharmacist creates prescription
                    └────┬────┘
                         │ Verify
                    ┌────▼────┐
                    │VERIFIED │
                    └────┬────┘
                         │ Dispense
                    ┌────▼────────┐         ┌──────────┐
                    │  DISPENSED  │         │ REJECTED │
                    └─────────────┘         └──────────┘
                         │                      ▲
                         │              Reject from PENDING or VERIFIED
                    ┌────▼────────┐
                    │  Invoice    │◀── auto-generated in same transaction
                    │  Created    │
                    └─────────────┘
```

Status transitions are sealed (`PrescriptionEvent`) and enforced at the service layer. Every transition writes an audit log entry inside the same `@Transactional` boundary.

### 5.3 Stock Decrement on Dispense

The following steps execute atomically inside a single `@Transactional` method:

1. Validate current prescription status is `VERIFIED`
2. Deduct dispensed quantity from earliest-expiring batch (FEFO via `SequencedCollection.getFirst()`)
3. If remaining stock ≤ threshold → publish `LowStockEvent` (handled asynchronously via SQS)
4. Update prescription status to `DISPENSED`
5. Create `Invoice` record
6. Persist `PrescriptionAuditLog` and `StockAuditLog` entries

### 5.4 Async Event Flow (Amazon SQS)

The Core Monolith produces events; Notification and Analytics Lambda functions consume them. Neither consumer has a synchronous dependency on the core.

```
Core Monolith
    │
    │ OutboxPublisher writes to SQS after @Transactional commits
    ▼
┌──────────────────────────────────────────────────────────────┐
│                       Amazon SQS                             │
│                                                              │
│  pharmadesk-email      ──▶  email-handler-fn  (Lambda)       │
│  pharmadesk-push       ──▶  push-handler-fn   (Lambda)       │
│  pharmadesk-alerts     ──▶  alert-handler-fn  (Lambda)       │
│  pharmadesk-domain-events ──▶ analytics-projector-fn (Lambda)│
│                                                              │
│  Each queue has a DLQ (max 3 receives before DLQ)            │
└──────────────────────────────────────────────────────────────┘

Notification Lambdas (Java 21, SnapStart)
    ├─▶ email-handler-fn  → SendGrid API
    ├─▶ push-handler-fn   → FCM / APNs
    └─▶ alert-handler-fn  → routes to email + push

Analytics Lambdas (Java 21, SnapStart)
    ├─▶ analytics-projector-fn → upserts projections into PostgreSQL (via RDS Proxy)
    └─▶ analytics-api-fn       → serves dashboard queries over API Gateway HTTP
```

Lambda handlers are idempotent, deduplicating on the outbox event ID. The pattern-matching switch shown below runs inside the Lambda `handleRequest` method rather than a Spring `@SqsListener`:

```java
// analytics-projector-fn handler
public Void handleRequest(SQSEvent event, Context ctx) {
    event.getRecords().forEach(record -> {
        DomainEvent domainEvent = Json.parse(record.getBody(), DomainEvent.class);
        switch (domainEvent) {
            case PrescriptionDispensedEvent e -> repo.recordDispense(e);
            case InvoicePaidEvent e           -> repo.recordRevenue(e);
            case StockAdjustedEvent e         -> repo.recordStockChange(e);
            default -> {} // unknown event types are safely ignored
        }
    });
    return null;
}
```

### 5.5 Scheduled Alert Jobs (Spring @Scheduled)

```java
@Component
public class AlertScheduler {

    @Scheduled(cron = "0 0 2 * * *", zone = "UTC")   // 02:00 UTC daily
    public void runDailyAlerts() {
        dispatchExpiryAlerts();    // batches expiring within 30 days
        dispatchLowStockAlerts();  // drugs at or below threshold
        dispatchRefillReminders(); // prescriptions ending in 7 days
    }
}
```

Each method loads qualifying records and sends a `NotificationMessage` record to the appropriate SQS queue via `SqsTemplate`.

---

## 6. Database Design

### 6.1 Entity Relationship Overview

```
users ──────────────────────────── patients
  │                                    │
  │ (pharmacist)                       │
  ▼                                    ▼
prescriptions ◀─────────────── refill_requests
  │
  ├──▶ prescription_audit_logs
  │
  ▼
invoices ──▶ invoice_payments
  │
  └──▶ discount_applications

drugs ──▶ drug_stock_batches
  │
  └──▶ suppliers ──▶ purchase_orders ──▶ purchase_order_items

notifications ──▶ users
```

### 6.2 Core Table Definitions

#### `users`

| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK, default gen_random_uuid() |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| password_hash | VARCHAR(255) | NOT NULL |
| role | ENUM(patient, pharmacist, admin) | NOT NULL |
| first_name | VARCHAR(100) | NOT NULL |
| last_name | VARCHAR(100) | NOT NULL |
| phone | VARCHAR(20) | |
| is_active | BOOLEAN | DEFAULT true |
| email_verified | BOOLEAN | DEFAULT false |
| created_at | TIMESTAMPTZ | DEFAULT now() |
| updated_at | TIMESTAMPTZ | DEFAULT now() |

#### `patients`

| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| user_id | UUID | FK → users.id, UNIQUE |
| date_of_birth | DATE | NOT NULL |
| address | TEXT | |
| emergency_contact_name | VARCHAR(100) | |
| emergency_contact_phone | VARCHAR(20) | |
| known_allergies | TEXT[] | DEFAULT '{}' |

#### `drugs`

| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| name | VARCHAR(255) | NOT NULL |
| generic_name | VARCHAR(255) | |
| category | VARCHAR(100) | NOT NULL |
| dosage_forms | TEXT[] | NOT NULL |
| unit_price | NUMERIC(10,2) | NOT NULL |
| low_stock_threshold | INTEGER | NOT NULL, DEFAULT 10 |
| is_active | BOOLEAN | DEFAULT true |
| created_at | TIMESTAMPTZ | DEFAULT now() |

#### `drug_stock_batches`

| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| drug_id | UUID | FK → drugs.id |
| quantity | INTEGER | NOT NULL, CHECK (quantity >= 0) |
| expiry_date | DATE | NOT NULL |
| received_at | TIMESTAMPTZ | DEFAULT now() |
| notes | TEXT | |

#### `prescriptions`

| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| patient_id | UUID | FK → patients.id |
| pharmacist_id | UUID | FK → users.id |
| drug_id | UUID | FK → drugs.id |
| dosage | VARCHAR(100) | NOT NULL |
| frequency | VARCHAR(100) | NOT NULL |
| duration_days | INTEGER | NOT NULL |
| refills_allowed | INTEGER | NOT NULL, DEFAULT 0 |
| refills_used | INTEGER | NOT NULL, DEFAULT 0 |
| quantity_dispensed | INTEGER | |
| status | ENUM(pending, verified, dispensed, rejected) | NOT NULL, DEFAULT pending |
| rejection_reason | TEXT | |
| notes | TEXT | |
| pickup_status | ENUM(pending, ready, picked_up, expired) | DEFAULT pending |
| created_at | TIMESTAMPTZ | DEFAULT now() |
| updated_at | TIMESTAMPTZ | DEFAULT now() |

#### `prescription_audit_logs`

| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| prescription_id | UUID | FK → prescriptions.id |
| performed_by | UUID | FK → users.id |
| action | VARCHAR(100) | NOT NULL |
| field_changes | JSONB | |
| created_at | TIMESTAMPTZ | DEFAULT now() |

#### `invoices`

| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| invoice_number | VARCHAR(20) | UNIQUE, NOT NULL |
| prescription_id | UUID | FK → prescriptions.id, UNIQUE |
| patient_id | UUID | FK → patients.id |
| subtotal | NUMERIC(10,2) | NOT NULL |
| discount_amount | NUMERIC(10,2) | DEFAULT 0 |
| total_amount | NUMERIC(10,2) | NOT NULL |
| amount_paid | NUMERIC(10,2) | DEFAULT 0 |
| payment_status | ENUM(pending, partial, paid) | DEFAULT pending |
| issued_at | TIMESTAMPTZ | DEFAULT now() |

#### `invoice_payments`

| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| invoice_id | UUID | FK → invoices.id |
| amount | NUMERIC(10,2) | NOT NULL |
| method | ENUM(cash, card, bank_transfer) | NOT NULL |
| recorded_by | UUID | FK → users.id |
| recorded_at | TIMESTAMPTZ | DEFAULT now() |

#### `notifications`

| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| user_id | UUID | FK → users.id |
| type | VARCHAR(100) | NOT NULL |
| title | VARCHAR(255) | NOT NULL |
| body | TEXT | NOT NULL |
| is_read | BOOLEAN | DEFAULT false |
| created_at | TIMESTAMPTZ | DEFAULT now() |

### 6.3 Indexes

```sql
-- Prescription lookups
CREATE INDEX idx_prescriptions_patient_id ON prescriptions(patient_id);
CREATE INDEX idx_prescriptions_status ON prescriptions(status);
CREATE INDEX idx_prescriptions_created_at ON prescriptions(created_at DESC);

-- Audit log lookups
CREATE INDEX idx_audit_logs_prescription_id ON prescription_audit_logs(prescription_id);

-- Stock batch expiry monitoring
CREATE INDEX idx_stock_batches_expiry ON drug_stock_batches(expiry_date);
CREATE INDEX idx_stock_batches_drug_id ON drug_stock_batches(drug_id);

-- Billing lookups
CREATE INDEX idx_invoices_patient_id ON invoices(patient_id);
CREATE INDEX idx_invoices_payment_status ON invoices(payment_status);

-- Notification lookups
CREATE INDEX idx_notifications_user_id ON notifications(user_id, is_read);
```

---

## 7. API Design

### 7.1 Conventions

- Base path: `/api/v1/`
- All requests and responses use `application/json`
- Field naming: `camelCase` (Jackson `SNAKE_CASE` disabled)
- Dates: ISO 8601 (`2026-06-06T10:00:00Z`)
- Paginated responses:

```json
{
  "data": [],
  "meta": {
    "page": 1,
    "pageSize": 20,
    "total": 150
  }
}
```

- Error responses:

```json
{
  "statusCode": 400,
  "error": "Bad Request",
  "message": "dosage must not be empty"
}
```

### 7.2 Endpoint Summary

#### Auth

Auth flows (login, MFA, token refresh, logout, password reset, registration) are handled entirely by Okta. The API exposes one auth-related endpoint for internal use:

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/auth/logout` | Bearer | Calls Okta token revocation endpoint, then clears server-side session context |

All other auth actions (register, forgot password, reset password) are performed directly against Okta's hosted flows or via the Okta SDK on the client.

#### Users & Patients

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/users/me` | Bearer | Get own profile |
| PATCH | `/users/me` | Bearer | Update own profile |
| GET | `/patients` | Pharmacist, Admin | List patients (paginated) |
| GET | `/patients/{id}` | Pharmacist, Admin | Get patient detail |
| PATCH | `/patients/{id}` | Pharmacist, Admin | Update patient profile |

#### Prescriptions

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/prescriptions` | Pharmacist, Admin | List all prescriptions (paginated, filterable) |
| GET | `/prescriptions/my` | Patient | List own prescriptions |
| POST | `/prescriptions` | Pharmacist | Create prescription |
| GET | `/prescriptions/{id}` | Bearer | Get prescription detail |
| PATCH | `/prescriptions/{id}` | Pharmacist, Admin | Update prescription (status, notes) |
| DELETE | `/prescriptions/{id}` | Pharmacist, Admin | Cancel prescription |
| GET | `/prescriptions/{id}/audit` | Pharmacist, Admin | Get audit trail |
| POST | `/prescriptions/{id}/refill` | Patient | Request refill |

#### Drugs & Inventory

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/drugs` | Bearer | List drugs (paginated, searchable) |
| POST | `/drugs` | Pharmacist, Admin | Add drug to catalog |
| PATCH | `/drugs/{id}` | Pharmacist, Admin | Update drug |
| GET | `/drugs/{id}/stock` | Pharmacist, Admin | Get stock batches |
| POST | `/drugs/{id}/stock` | Pharmacist, Admin | Add stock batch |
| PATCH | `/drugs/{id}/stock/{batchId}` | Pharmacist, Admin | Adjust stock manually |

#### Billing

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/invoices` | Pharmacist, Admin | List invoices (paginated, filterable) |
| GET | `/invoices/my` | Patient | List own invoices |
| GET | `/invoices/{id}` | Bearer | Get invoice detail |
| POST | `/invoices/{id}/payments` | Pharmacist, Admin | Record payment |
| GET | `/invoices/{id}/pdf` | Bearer | Download invoice PDF |

#### Notifications

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/notifications` | Bearer | List own notifications |
| PATCH | `/notifications/{id}/read` | Bearer | Mark notification as read |
| POST | `/notifications/read-all` | Bearer | Mark all as read |
| GET | `/notifications/preferences` | Bearer | Get notification preferences |
| PATCH | `/notifications/preferences` | Bearer | Update preferences |

#### Analytics

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/analytics/top-drugs` | Pharmacist, Admin | Most dispensed drugs |
| GET | `/analytics/revenue` | Pharmacist, Admin | Monthly revenue summary |
| GET | `/analytics/low-stock` | Pharmacist, Admin | Drugs below threshold |
| GET | `/analytics/prescription-volume` | Pharmacist, Admin | Prescription volume trends |
| GET | `/analytics/export` | Admin | Export report (CSV/PDF) |

---

## 8. Security Architecture

### 8.1 Okta Setup

PharmaDesk uses a single Okta org with the following configuration:

**Authorization Server:** A custom Okta Authorization Server (not the default `org` server) scoped to PharmaDesk. This allows custom claims, scopes, and access policies.

**Groups → Roles mapping:**

| Okta Group | Spring Authority | Access |
|---|---|---|
| `pharmadesk-admins` | `ROLE_ADMIN` | Full system access |
| `pharmadesk-pharmacists` | `ROLE_PHARMACIST` | Prescription, inventory, billing, alerts |
| `pharmadesk-patients` | `ROLE_PATIENT` | Own prescriptions, refills, billing |

Groups are assigned to users in Okta's Universal Directory. The custom Authorization Server includes a `groups` claim in the access token via a Groups claim rule.

**Applications registered in Okta:**

| App | Type | Grant Flow |
|---|---|---|
| PharmaDesk Web | SPA | Authorization Code + PKCE |
| PharmaDesk Mobile | Native | Authorization Code + PKCE |
| PharmaDesk API | API / Resource Server | — (validates tokens only) |

### 8.2 Spring Boot as OAuth2 Resource Server

The API never issues or stores tokens. It validates every incoming Bearer token against Okta's JWKS endpoint and extracts the `groups` claim to determine role.

Minimal configuration:

```yaml
# application.yml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://${OKTA_DOMAIN}/oauth2/${OKTA_AUTH_SERVER_ID}
```

Custom JWT converter maps the `groups` claim to Spring `GrantedAuthority` objects:

```java
@Component
public class OktaJwtRoleConverter implements Converter<Jwt, Collection<GrantedAuthority>> {

    @Override
    public Collection<GrantedAuthority> convert(Jwt jwt) {
        List<String> groups = jwt.getClaimAsStringList("groups");
        if (groups == null) return List.of();

        return groups.stream()
            .map(group -> switch (group) {
                case "pharmadesk-admins"      -> new SimpleGrantedAuthority("ROLE_ADMIN");
                case "pharmadesk-pharmacists" -> new SimpleGrantedAuthority("ROLE_PHARMACIST");
                case "pharmadesk-patients"    -> new SimpleGrantedAuthority("ROLE_PATIENT");
                default                       -> null;
            })
            .filter(Objects::nonNull)
            .toList();
    }
}
```

Spring Security configuration:

```java
@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http,
                                           OktaJwtRoleConverter converter) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt.jwtAuthenticationConverter(
                    token -> new JwtAuthenticationToken(token, converter.convert(token))
                ))
            )
            .sessionManagement(s -> s
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            );
        return http.build();
    }
}
```

Method-level role enforcement using standard Spring Security annotations:

```java
@PreAuthorize("hasRole('PHARMACIST')")
public PrescriptionResponse createPrescription(CreatePrescriptionRequest request) { … }

@PreAuthorize("hasRole('ADMIN')")
public ReportResponse exportAnalytics(ReportRequest request) { … }

@PreAuthorize("hasAnyRole('PATIENT', 'PHARMACIST', 'ADMIN')")
public PrescriptionResponse getPrescription(UUID id) { … }
```

### 8.3 Role Hierarchy

```
ROLE_ADMIN
  └─▶ ROLE_PHARMACIST
        └─▶ ROLE_PATIENT
```

Configured as a Spring Security `RoleHierarchy` bean so that `hasRole('PHARMACIST')` grants access to endpoints that require `ROLE_PATIENT` without redundant annotations.

### 8.4 User Profile Sync

Okta is the source of truth for identity (email, name, groups). On first authenticated request, the API checks whether a local `User` record exists for the Okta `sub` claim and creates one if not — syncing display name and email from the JWT claims. Subsequent requests skip the sync unless the `updated_at` claim indicates a profile change.

This keeps the local database lightweight: it stores only PharmaDesk-specific profile fields (allergies, address, preferences) while Okta owns credentials and group membership.

### 8.5 Request Pipeline

```
Incoming Request
      │
      ▼
 Rate Limiting Filter (Bucket4j + Redis)
      │
      ▼
 OAuth2 Resource Server JWT Filter
   └─▶ extract Bearer token
   └─▶ validate signature via Okta JWKS (cached)
   └─▶ validate issuer, audience, expiry
   └─▶ OktaJwtRoleConverter → GrantedAuthority list
   └─▶ set JwtAuthenticationToken in SecurityContextHolder
      │
      ▼
 @PreAuthorize role check (AOP)
      │
      ▼
 @Valid DTO validation (Jakarta Bean Validation)
      │
      ▼
 @RestController → @Service → @Repository
      │
      ▼
 @ControllerAdvice (global exception → error envelope)
```

### 8.6 Data Security

- Passwords and credentials are fully managed by Okta — the API never handles or stores passwords
- Okta enforces MFA policies per group (e.g., Pharmacist and Admin groups require MFA)
- JWKS public keys are cached in-process; Spring Security refreshes the cache automatically when a new key ID is seen
- All application secrets (DB credentials, SQS queue URLs, SendGrid key) loaded from AWS Secrets Manager at startup
- `@JsonIgnore` on all internal entity fields to prevent accidental serialisation
- SQL injection protection via parameterised JPQL and native queries only

---

## 9. Notification Lambdas

The notification layer is implemented as **three AWS Lambda functions**, each triggered by its own SQS queue via an event source mapping. There is no always-on server — Lambda functions spin up on demand, process a batch of SQS messages, and terminate. All functions use Java 21 with **Lambda SnapStart** to eliminate cold-start latency.

### 9.1 Lambda Functions

| Function | Trigger Queue | Delivery Provider | Handler Class |
|---|---|---|---|
| `pharmadesk-email-handler` | `pharmadesk-email` | SendGrid REST API | `EmailHandlerFunction` |
| `pharmadesk-push-handler` | `pharmadesk-push` | FCM / APNs | `PushHandlerFunction` |
| `pharmadesk-alert-handler` | `pharmadesk-alerts` | Routes to email + push | `AlertHandlerFunction` |

### 9.2 Event Flow

```
Core Monolith (OutboxPublisher)
      │
      │── SqsTemplate.send(emailQueue, NotificationMessage)
      │── SqsTemplate.send(pushQueue,  NotificationMessage)
      │── SqsTemplate.send(alertQueue, AlertMessage)
      ▼
┌──────────────────────────────────────────────────────────┐
│                    Amazon SQS                            │
│  pharmadesk-email  ──▶ email-handler-fn  ──▶ SendGrid   │
│  pharmadesk-push   ──▶ push-handler-fn   ──▶ FCM/APNs   │
│  pharmadesk-alerts ──▶ alert-handler-fn  ──▶ both above  │
│                                                          │
│  (DLQ after 3 failed attempts per queue)                 │
└──────────────────────────────────────────────────────────┘
```

### 9.3 SQS Queue Configuration

| Queue | Type | DLQ | Max Receives |
|---|---|---|---|
| `pharmadesk-email` | Standard | `pharmadesk-email-dlq` | 3 |
| `pharmadesk-push` | Standard | `pharmadesk-push-dlq` | 3 |
| `pharmadesk-alerts` | Standard | `pharmadesk-alerts-dlq` | 3 |
| `pharmadesk-domain-events` | Standard | `pharmadesk-domain-events-dlq` | 3 |

### 9.4 Lambda Handler Implementation

Each function implements the AWS Lambda `RequestHandler` interface directly (no Spring Boot, no embedded HTTP server). Secrets Manager is called once during SnapStart init phase and cached for the lifetime of the execution environment.

```java
// pharmadesk-email-handler
@SnapStart
public class EmailHandlerFunction
        implements RequestHandler<SQSEvent, Void> {

    // Initialised during SnapStart snapshot — not on every invocation
    private final SendGridEmailGateway gateway =
            new SendGridEmailGateway(SecretsManagerClient.create());

    @Override
    public Void handleRequest(SQSEvent event, Context context) {
        event.getRecords().forEach(record -> {
            var msg = Json.parse(record.getBody(), NotificationMessage.class);
            gateway.send(msg);
        });
        return null;
    }
}
```

### 9.5 Alert Scheduling

The alert scheduler lives in the **Core Monolith** (`AlertScheduler`). It runs daily at 02:00 UTC via `@Scheduled` and publishes `AlertMessage` records to `pharmadesk-alerts`. The Lambda simply consumes and dispatches — it has no scheduling logic.

1. Drug batches expiring within 30 days → expiry alert to pharmacist
2. Drugs where total stock ≤ `low_stock_threshold` → low stock alert to pharmacist
3. Active prescriptions where `estimated_end_date = today + 7` → refill reminder to patient

### 9.6 Deployment (AWS SAM)

The three Lambda functions are declared in a shared `notification-service/template.yaml`:

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Transform: AWS::Serverless-2016-10-31

Globals:
  Function:
    Runtime: java21
    SnapStart:
      ApplyOn: PublishedVersions
    MemorySize: 512
    Timeout: 30
    Environment:
      Variables:
        SENDGRID_SECRET_ARN: !Ref SendGridSecretArn

Resources:
  EmailHandlerFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: com.pharmadesk.notification.EmailHandlerFunction::handleRequest
      CodeUri: build/libs/notification-service.jar
      Events:
        SqsTrigger:
          Type: SQS
          Properties:
            Queue: !Sub "arn:aws:sqs:${AWS::Region}:${AWS::AccountId}:pharmadesk-email"
            BatchSize: 10

  PushHandlerFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: com.pharmadesk.notification.PushHandlerFunction::handleRequest
      CodeUri: build/libs/notification-service.jar
      Events:
        SqsTrigger:
          Type: SQS
          Properties:
            Queue: !Sub "arn:aws:sqs:${AWS::Region}:${AWS::AccountId}:pharmadesk-push"
            BatchSize: 10

  AlertHandlerFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: com.pharmadesk.notification.AlertHandlerFunction::handleRequest
      CodeUri: build/libs/notification-service.jar
      Events:
        SqsTrigger:
          Type: SQS
          Properties:
            Queue: !Sub "arn:aws:sqs:${AWS::Region}:${AWS::AccountId}:pharmadesk-alerts"
            BatchSize: 10
```

---

## 9b. Analytics Lambdas

The analytics layer is split into two Lambda functions: a **projector** that listens to domain events and updates read-model projections, and an **API function** that serves dashboard queries over HTTP via API Gateway.

### 9b.1 Lambda Functions

| Function | Trigger | Role | Handler Class |
|---|---|---|---|
| `pharmadesk-analytics-projector` | SQS `pharmadesk-domain-events` | Consume events, upsert projections into PostgreSQL via RDS Proxy | `AnalyticsProjectorFunction` |
| `pharmadesk-analytics-api` | API Gateway HTTP | Validate Okta JWT, serve dashboard REST queries | `AnalyticsApiFunction` |

### 9b.2 Architecture Diagram

```
Core Monolith (domain events)
      │
      ▼
pharmadesk-domain-events (SQS)
      │
      ▼
analytics-projector-fn
      │  upsert projections
      ▼
PostgreSQL Read Replica (via RDS Proxy)
      │
      ▼ (dashboard queries)
analytics-api-fn  ◀──  API Gateway  ◀──  Web/Mobile clients (Okta JWT)
```

RDS Proxy is required because Lambda functions can open many short-lived connections. RDS Proxy pools and manages connections to PostgreSQL, preventing connection exhaustion.

### 9b.3 Projector Implementation

```java
@SnapStart
public class AnalyticsProjectorFunction
        implements RequestHandler<SQSEvent, Void> {

    private final DataSource dataSource = RdsProxyDataSource.create();
    private final ProjectionRepository repo = new ProjectionRepository(dataSource);

    @Override
    public Void handleRequest(SQSEvent event, Context context) {
        event.getRecords().forEach(record -> {
            DomainEvent domainEvent = Json.parse(record.getBody(), DomainEvent.class);
            switch (domainEvent) {
                case PrescriptionDispensedEvent e -> repo.incrementDispenseCount(e.drugId());
                case InvoicePaidEvent e           -> repo.addRevenue(e.amount(), e.paidAt());
                case StockDecrementedEvent e      -> repo.updateStockLevel(e.drugId(), e.newLevel());
                default -> {} // ignore unrecognised events
            }
        });
        return null;
    }
}
```

### 9b.4 API Function

The analytics API Lambda validates the Okta JWT using the JWKS endpoint (cached in memory after SnapStart init), then serves read-only dashboard queries from PostgreSQL projections.

```java
@SnapStart
public class AnalyticsApiFunction
        implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    private final JwtValidator jwtValidator =
            new OktaJwtValidator(System.getenv("OKTA_ISSUER_URI"));
    private final AnalyticsQueryService queryService =
            new AnalyticsQueryService(RdsProxyDataSource.create());

    @Override
    public APIGatewayProxyResponseEvent handleRequest(
            APIGatewayProxyRequestEvent req, Context ctx) {
        jwtValidator.validateAndRequireRole(req, "ROLE_ADMIN", "ROLE_PHARMACIST");
        var result = queryService.handle(req.getPath(), req.getQueryStringParameters());
        return Response.ok(result);
    }
}
```

### 9b.5 Deployment (AWS SAM)

```yaml
# analytics-service/template.yaml
Resources:
  AnalyticsProjectorFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: com.pharmadesk.analytics.AnalyticsProjectorFunction::handleRequest
      CodeUri: build/libs/analytics-service.jar
      Runtime: java21
      SnapStart:
        ApplyOn: PublishedVersions
      MemorySize: 512
      Timeout: 60
      VpcConfig:
        SubnetIds: !Ref PrivateSubnets
        SecurityGroupIds: [!Ref LambdaSecurityGroup]
      Events:
        SqsTrigger:
          Type: SQS
          Properties:
            Queue: !Sub "arn:aws:sqs:${AWS::Region}:${AWS::AccountId}:pharmadesk-domain-events"
            BatchSize: 20

  AnalyticsApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: com.pharmadesk.analytics.AnalyticsApiFunction::handleRequest
      CodeUri: build/libs/analytics-service.jar
      Runtime: java21
      SnapStart:
        ApplyOn: PublishedVersions
      MemorySize: 512
      Timeout: 10
      VpcConfig:
        SubnetIds: !Ref PrivateSubnets
        SecurityGroupIds: [!Ref LambdaSecurityGroup]
      Environment:
        Variables:
          OKTA_ISSUER_URI: !Ref OktaIssuerUri
          RDS_PROXY_ENDPOINT: !Ref RdsProxyEndpoint
      Events:
        ApiGateway:
          Type: HttpApi
          Properties:
            Path: /api/v1/analytics/{proxy+}
            Method: ANY

  AnalyticsHttpApi:
    Type: AWS::Serverless::HttpApi
```

---

## 10. Mobile Application Architecture

### 10.1 Structure

```
src/
├── app/                  # Navigation and app entry
├── screens/              # One folder per screen
├── components/           # Shared UI components
├── hooks/                # Custom hooks (useAuth, usePrescriptions, …)
├── stores/               # Zustand stores
├── api/                  # Axios instance + TanStack Query functions
├── notifications/        # Push notification handlers
└── utils/
```

### 10.2 Offline Support

TanStack Query's stale-while-revalidate strategy serves prescription data from cache when offline, with a clear "Offline" banner in the UI. Write operations (refill requests) are queued in-memory and retried when connectivity is restored.

### 10.3 Push Notification Handling

```
FCM / APNs
    │
    ▼
Expo Notifications SDK
    │
    ├─▶ Foreground → in-app toast + notification centre update
    └─▶ Background → system tray → on tap, deep-link to relevant screen
```

---

## 11. Infrastructure & Deployment

### 11.1 Service Deployment Units

| Service | Deployment Model | Scales On | Notes |
|---|---|---|---|
| Core Monolith | ECS Fargate — `pharmadesk-core` (min 2, max 10) | CPU / request count | Handles all transactional operations |
| email-handler-fn | AWS Lambda + SQS event source mapping | Automatic (per message batch) | SnapStart; Java 21 |
| push-handler-fn | AWS Lambda + SQS event source mapping | Automatic (per message batch) | SnapStart; Java 21 |
| alert-handler-fn | AWS Lambda + SQS event source mapping | Automatic (per message batch) | SnapStart; Java 21 |
| analytics-projector-fn | AWS Lambda + SQS event source mapping | Automatic (per message batch) | SnapStart; writes projections via RDS Proxy |
| analytics-api-fn | AWS Lambda + API Gateway HTTP API | Automatic (per request) | SnapStart; Okta JWT validation |
| Web (React) | S3 + CloudFront | — | Static assets; no server |

### 11.2 Environment Tiers

| Environment | Purpose |
|---|---|
| Development | Docker Compose — Core + PostgreSQL + Redis + LocalStack (SQS) + mock-oauth2-server; Lambdas emulated via AWS SAM Local |
| Staging | Core on ECS Fargate; Notification and Analytics Lambdas deployed via SAM; mirrors production topology |
| Production | Core on ECS Fargate (Multi-AZ); Lambda functions deployed via SAM; RDS Proxy for analytics Lambda connections |

### 11.3 CI/CD Pipeline (GitHub Actions)

Each service has its own independent GitHub Actions workflow. A change to the notification Lambdas does not trigger a Core Monolith deploy.

```
Feature branch push (any service)
      │
      ▼
┌──────────────────────────────────────┐
│  CI Pipeline (per service)           │
│  ├─ Checkstyle / lint                │
│  ├─ Unit tests (JUnit 5)             │
│  ├─ Integration tests (Testcontainers│
│  │   or SAM Local for Lambda)        │
│  └─ ./gradlew build → JAR / image    │
└──────────────┬───────────────────────┘
               │ merge to main
               ▼
┌──────────────────────────────────────┐
│  CD → Staging                        │
│  Core:  Push to ECR → ECS rolling    │
│         Flyway migrations (Core only)│
│  Lambda: sam build → sam deploy      │
│          --stack-name pharmadesk-stg │
└──────────────┬───────────────────────┘
               │ manual approval
               ▼
┌──────────────────────────────────────┐
│  CD → Production                     │
│  Core:  ECS rolling update           │
│  Lambda: sam deploy                  │
│          --stack-name pharmadesk-prd │
└──────────────────────────────────────┘
```

### 11.4 Local Development Summary

Docker Compose runs the Core Monolith, PostgreSQL, Redis, LocalStack (SQS), and the mock-oauth2-server. Lambda functions are emulated locally using **AWS SAM Local**, which invokes handlers directly against LocalStack queues without requiring Docker containers per function. See Section 12 for the full docker-compose.yml and SAM Local configuration.

---

## 12. Local Infrastructure (Docker)

The local development environment runs entirely in Docker Compose. It provides the full backing service stack — PostgreSQL, Redis, and LocalStack (SQS) — so developers need no AWS account or external services to run the application.

### 12.1 Service Overview

Docker Compose runs infrastructure and the Core Monolith only. Notification and Analytics Lambdas run via **AWS SAM Local** alongside Docker Compose — they are not Docker Compose services.

| Service | Image | Port | Purpose |
|---|---|---|---|
| `core` | Local build | 8080 | Core Monolith — prescriptions, patients, drugs, billing |
| `web` | Local build | 5173 | React web application (Vite dev server) |
| `db` | postgres:16-alpine | 5432 | PostgreSQL (Core + Analytics projections) |
| `redis` | redis:7-alpine | 6379 | Application cache (Core only) |
| `localstack` | localstack/localstack | 4566 | AWS SQS emulation |
| `mock-oauth2-server` | ghcr.io/navikt/mock-oauth2-server | 8090 | Local Okta OIDC/JWT emulation |
| `sqs-init` | amazon/aws-cli | — | One-shot: creates all SQS queues on startup |
| SAM Local (notification) | AWS SAM CLI | 3001 | Emulates email-handler, push-handler, alert-handler Lambdas |
| SAM Local (analytics) | AWS SAM CLI | 3002 | Emulates analytics-projector and analytics-api Lambdas |

### 12.2 docker-compose.yml

```yaml
version: "3.9"

networks:
  pharmadesk:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  localstack_data:

services:

  # ── PostgreSQL ─────────────────────────────────────────────
  db:
    image: postgres:16-alpine
    container_name: pharmadesk-db
    restart: unless-stopped
    networks: [pharmadesk]
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: pharmadesk
      POSTGRES_USER: pharmadesk
      POSTGRES_PASSWORD: secret
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./infra/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U pharmadesk -d pharmadesk"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 20s

  # ── Redis ──────────────────────────────────────────────────
  redis:
    image: redis:7-alpine
    container_name: pharmadesk-redis
    restart: unless-stopped
    networks: [pharmadesk]
    ports:
      - "6379:6379"
    command: redis-server --save 60 1 --loglevel warning
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ── LocalStack (SQS) ───────────────────────────────────────
  localstack:
    image: localstack/localstack:3
    container_name: pharmadesk-localstack
    restart: unless-stopped
    networks: [pharmadesk]
    ports:
      - "4566:4566"
    environment:
      SERVICES: sqs
      DEFAULT_REGION: ap-southeast-1
      PERSISTENCE: 1
      DEBUG: 0
    volumes:
      - localstack_data:/var/lib/localstack
      - /var/run/docker.sock:/var/run/docker.sock
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:4566/_localstack/health | grep -q '\"sqs\": \"available\"'"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s

  # ── SQS Queue Initialiser ──────────────────────────────────
  # One-shot container: creates all queues and their DLQs then exits.
  sqs-init:
    image: amazon/aws-cli:latest
    container_name: pharmadesk-sqs-init
    networks: [pharmadesk]
    depends_on:
      localstack:
        condition: service_healthy
    environment:
      AWS_ACCESS_KEY_ID: test
      AWS_SECRET_ACCESS_KEY: test
      AWS_DEFAULT_REGION: ap-southeast-1
    entrypoint: ["/bin/sh", "-c"]
    command:
      - |
        ENDPOINT=http://localstack:4566

        create_queue() {
          aws --endpoint-url=$$ENDPOINT sqs create-queue --queue-name $$1
          echo "Created queue: $$1"
        }

        create_dlq_pair() {
          MAIN=$$1
          DLQ=$${MAIN}-dlq

          DLQ_URL=$$(aws --endpoint-url=$$ENDPOINT sqs create-queue \
            --queue-name $$DLQ \
            --query QueueUrl --output text)

          DLQ_ARN=$$(aws --endpoint-url=$$ENDPOINT sqs get-queue-attributes \
            --queue-url $$DLQ_URL \
            --attribute-names QueueArn \
            --query Attributes.QueueArn --output text)

          aws --endpoint-url=$$ENDPOINT sqs create-queue \
            --queue-name $$MAIN \
            --attributes "{
              \"RedrivePolicy\": \"{\\\"deadLetterTargetArn\\\":\\\"$$DLQ_ARN\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"
            }"

          echo "Created queue pair: $$MAIN → $$DLQ"
        }

        create_dlq_pair pharmadesk-email
        create_dlq_pair pharmadesk-push
        create_dlq_pair pharmadesk-alerts
        create_dlq_pair pharmadesk-domain-events

  # ── Mock OAuth2 Server (Okta emulation) ───────────────────
  # Emulates Okta's OIDC endpoints locally so the API's JWT
  # validation works without a real Okta tenant.
  mock-oauth2-server:
    image: ghcr.io/navikt/mock-oauth2-server:2.1.0
    container_name: pharmadesk-mock-oauth2
    restart: unless-stopped
    networks: [pharmadesk]
    ports:
      - "8090:8090"
    environment:
      SERVER_PORT: 8090
      # Issuer must match what the API and clients are configured with
      JSON_CONFIG: |
        {
          "interactiveLogin": true,
          "httpServer": "NettyWrapper",
          "tokenCallbacks": [
            {
              "issuerId": "pharmadesk",
              "requestMappings": [
                {
                  "requestParam": "client_id",
                  "match": "pharmadesk-web",
                  "claims": {
                    "groups": ["pharmadesk-pharmacists"]
                  }
                },
                {
                  "requestParam": "client_id",
                  "match": "pharmadesk-patient",
                  "claims": {
                    "groups": ["pharmadesk-patients"]
                  }
                }
              ]
            }
          ]
        }
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:8090/pharmadesk/.well-known/openid-configuration"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ── Spring Boot API ────────────────────────────────────────
  api:
    build:
      context: ./api
      dockerfile: Dockerfile
      args:
        JAVA_VERSION: 21
    container_name: pharmadesk-api
    restart: unless-stopped
    networks: [pharmadesk]
    ports:
      - "8080:8080"
    environment:
      # Datasource
      SPRING_DATASOURCE_URL: jdbc:postgresql://db:5432/pharmadesk
      SPRING_DATASOURCE_USERNAME: pharmadesk
      SPRING_DATASOURCE_PASSWORD: secret

      # Redis
      SPRING_DATA_REDIS_HOST: redis
      SPRING_DATA_REDIS_PORT: 6379

      # AWS / LocalStack
      AWS_ACCESS_KEY_ID: test
      AWS_SECRET_ACCESS_KEY: test
      AWS_DEFAULT_REGION: ap-southeast-1
      AWS_ENDPOINT_OVERRIDE: http://localstack:4566

      # SQS queue URLs
      PHARMADESK_SQS_EMAIL_QUEUE_URL: http://localstack:4566/000000000000/pharmadesk-email
      PHARMADESK_SQS_PUSH_QUEUE_URL: http://localstack:4566/000000000000/pharmadesk-push
      PHARMADESK_SQS_ALERT_QUEUE_URL: http://localstack:4566/000000000000/pharmadesk-alerts

      # Okta / mock-oauth2-server
      SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI: http://mock-oauth2-server:8090/pharmadesk

      # Spring profiles
      SPRING_PROFILES_ACTIVE: local

      # Virtual threads
      SPRING_THREADS_VIRTUAL_ENABLED: "true"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
      sqs-init:
        condition: service_completed_successfully
      mock-oauth2-server:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:8080/actuator/health | grep -q UP"]
      interval: 15s
      timeout: 5s
      retries: 5
      start_period: 40s

  # ── React Web App ──────────────────────────────────────────
  web:
    build:
      context: ./web
      dockerfile: Dockerfile.dev
    container_name: pharmadesk-web
    restart: unless-stopped
    networks: [pharmadesk]
    ports:
      - "5173:5173"
    environment:
      VITE_API_BASE_URL: http://localhost:8080/api/v1
    depends_on:
      api:
        condition: service_healthy
    volumes:
      - ./web/src:/app/src   # hot-reload in dev
```

### 12.3 API Dockerfile

Multi-stage build using Java 21 — keeps the final image small by separating the Gradle build from the runtime layer:

```dockerfile
# Stage 1 — build
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle
RUN ./gradlew dependencies --no-daemon          # cache dependency layer
COPY src ./src
RUN ./gradlew bootJar --no-daemon -x test

# Stage 2 — runtime
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -S pharmadesk && adduser -S pharmadesk -G pharmadesk
USER pharmadesk
COPY --from=builder /app/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### 12.4 Local application.yml Profile

`src/main/resources/application-local.yml` overrides production defaults for local use:

```yaml
spring:
  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
  flyway:
    enabled: true
    locations: classpath:db/migration
  data:
    redis:
      host: ${SPRING_DATA_REDIS_HOST}
      port: ${SPRING_DATA_REDIS_PORT}
  threads:
    virtual:
      enabled: true
  security:
    oauth2:
      resourceserver:
        jwt:
          # Points to mock-oauth2-server locally; overridden in staging/prod
          # with the real Okta issuer URI via AWS Secrets Manager
          issuer-uri: ${SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI}

cloud:
  aws:
    region:
      static: ap-southeast-1
    credentials:
      access-key: ${AWS_ACCESS_KEY_ID}
      secret-key: ${AWS_SECRET_ACCESS_KEY}
    sqs:
      endpoint: ${AWS_ENDPOINT_OVERRIDE}

pharmadesk:
  sqs:
    email-queue-url: ${PHARMADESK_SQS_EMAIL_QUEUE_URL}
    push-queue-url: ${PHARMADESK_SQS_PUSH_QUEUE_URL}
    alert-queue-url: ${PHARMADESK_SQS_ALERT_QUEUE_URL}

logging:
  level:
    com.pharmadesk: DEBUG
    org.hibernate.SQL: DEBUG
    org.springframework.security: DEBUG   # shows JWT validation in local dev
```

### 12.5 SAM Local — Lambda Emulation

Notification and Analytics Lambdas run locally via AWS SAM Local, which invokes the Java handlers directly and connects to LocalStack SQS. Run SAM Local in a separate terminal after Docker Compose is up.

```bash
# Build Lambda JARs first
./gradlew :notification-service:build
./gradlew :analytics-service:build

# Start notification Lambdas (SQS polling against LocalStack)
cd notification-service
sam local start-lambda --port 3001 \
  --env-vars env.local.json

# In a second terminal — start analytics Lambdas
cd analytics-service
sam local start-lambda --port 3002 \
  --env-vars env.local.json

# env.local.json supplies LocalStack endpoints and test credentials
# so SAM Local behaves identically to the cloud deployment
```

`env.local.json` for both services:

```json
{
  "Parameters": {
    "AWS_ACCESS_KEY_ID": "test",
    "AWS_SECRET_ACCESS_KEY": "test",
    "AWS_DEFAULT_REGION": "ap-southeast-1",
    "AWS_ENDPOINT_URL_SQS": "http://localhost:4566",
    "JDBC_URL": "jdbc:postgresql://localhost:5432/pharmadesk",
    "JDBC_USER": "pharmadesk",
    "JDBC_PASSWORD": "secret",
    "OKTA_ISSUER_URI": "http://localhost:8090/pharmadesk",
    "SENDGRID_API_KEY": "local-stub-key"
  }
}
```

### 12.6 Startup & Common Commands

```bash
# 1. Start infrastructure + core
docker compose up --build

# 2. In a second terminal — start notification Lambdas
cd notification-service && sam local start-lambda --port 3001 --env-vars env.local.json

# 3. In a third terminal — start analytics Lambdas
cd analytics-service && sam local start-lambda --port 3002 --env-vars env.local.json

# Tail Core API logs
docker compose logs -f api

# Open a psql shell
docker compose exec db psql -U pharmadesk -d pharmadesk

# Connect to Redis CLI
docker compose exec redis redis-cli

# List SQS queues
aws --endpoint-url=http://localhost:4566 sqs list-queues --region ap-southeast-1

# Peek at the email DLQ
aws --endpoint-url=http://localhost:4566 sqs receive-message \
  --queue-url http://localhost:4566/000000000000/pharmadesk-email-dlq \
  --region ap-southeast-1

# Stop all Docker services (preserves volumes)
docker compose down

# Full reset
docker compose down -v
```

### 12.7 Service Dependency Order

```
localstack (healthy) ──▶ sqs-init (completed) ──────────────┐
                                                             │
postgres (healthy) ──┐                                       │
                     ├──▶ core (healthy) ──▶ web             │
redis    (healthy) ──┤                                       │
mock-oauth2 (healthy)┘                                       │
                                                             ▼
                                        SAM Local (notification Lambdas)
                                        SAM Local (analytics Lambdas)
                                        (poll LocalStack SQS; analytics-api-fn
                                         queries localhost:5432 via JDBC)
```

The `api` container will not start until PostgreSQL and Redis pass their health checks, and until `sqs-init` has created all queues. SAM Local processes can be started at any point after Docker Compose is healthy.

### 12.8 Ports at a Glance

| Service | Local Port | Notes |
|---|---|---|
| Core Monolith API | 8080 | `http://localhost:8080/api/v1` |
| Core Actuator | 8080 | `http://localhost:8080/actuator/health` |
| Analytics Lambda API (SAM) | 3002 | `http://localhost:3002/api/v1/analytics` |
| React Web App | 5173 | `http://localhost:5173` |
| PostgreSQL | 5432 | Connect with any SQL client |
| Redis | 6379 | Connect with `redis-cli` |
| LocalStack (SQS) | 4566 | `http://localhost:4566` |
| mock-oauth2-server | 8090 | OIDC discovery: `http://localhost:8090/pharmadesk/.well-known/openid-configuration` |
| SAM Local (notification) | 3001 | Lambda invoke endpoint (internal only — no HTTP API) |

---

## 13. Error Handling & Logging

### 12.1 Global Exception Handler

A `@ControllerAdvice` class uses Java 21 pattern matching for switch to map domain exceptions to HTTP responses cleanly:

```java
@ExceptionHandler(Exception.class)
public ResponseEntity<ErrorResponse> handle(Exception ex) {
    return switch (ex) {
        case PrescriptionNotFoundException e ->
            ResponseEntity.status(404).body(error(404, e.getMessage()));
        case DuplicatePrescriptionException e ->
            ResponseEntity.status(409).body(error(409, e.getMessage()));
        case InvalidStatusTransitionException e ->
            ResponseEntity.status(422).body(error(422, e.getMessage()));
        case MethodArgumentNotValidException e ->
            ResponseEntity.status(400).body(validationError(e));
        case AccessDeniedException e ->
            ResponseEntity.status(403).body(error(403, "Access denied"));
        default ->
            ResponseEntity.status(500).body(error(500, "Internal server error"));
    };
}
```

### 12.2 Logging Strategy

Structured JSON logging via Logback + `logstash-logback-encoder`, shipped to AWS CloudWatch.

| Level | Usage |
|---|---|
| ERROR | Unhandled exceptions, SQS DLQ events, DB transaction failures |
| WARN | Rate limit breaches, failed login attempts, validation errors |
| INFO | Request lifecycle, prescription state transitions, SQS message processing |
| DEBUG | JPA queries, cache hits/misses (disabled in production) |

Sensitive fields (tokens, password hashes) are redacted via a custom Logback `MaskingPatternLayout` before any log output.

### 12.3 Audit Log vs Application Log

| | Audit Log | Application Log |
|---|---|---|
| Storage | PostgreSQL (`prescription_audit_logs`) | AWS CloudWatch |
| Mutability | Immutable (no UPDATE/DELETE permitted) | Rotated, retained 90 days |
| Purpose | Business compliance and traceability | Operational debugging |
| Retention | 5 years | 90 days |

---

## 14. Key Design Decisions

### 13.1 Hybrid Architecture — Monolith Core with Extracted Services

A pure microservices decomposition was ruled out at this scale — the dispense operation atomically touches prescriptions, stock, invoices, and the outbox in a single `@Transactional` call. Splitting this across services would require a Saga with compensating transactions, adding significant complexity for a domain where correctness is critical.

Instead, PharmaDesk uses a hybrid approach: the Core Monolith owns all transactionally coupled operations; Notification and Analytics functions are extracted at natural async boundaries (SQS) and deployed as AWS Lambda functions. Neither Lambda group has a synchronous dependency on the core, so they can fail, scale, or be redeployed independently. The SQS event boundary was already drawn in the design — extraction is a deployment choice, not a redesign.

### 13.2 Java 21 Virtual Threads over Reactive Stack

Spring WebFlux (reactive) was considered but rejected. Virtual threads (Project Loom) deliver the same non-blocking I/O characteristics with synchronous, imperative code — significantly reducing cognitive overhead for the team and eliminating the need for reactive operators (`Mono`, `Flux`) throughout the codebase.

### 13.2 Amazon SQS over Self-Managed Queue

SQS is a fully managed, serverless queue with built-in DLQ support, IAM-based access control, and no broker to operate. Since PharmaDesk is already on AWS, SQS removes the Redis-as-queue dependency and eliminates a class of operational concerns (Redis memory pressure, queue persistence) without adding infrastructure complexity.

### 13.3 Sealed Classes for State Machine

The prescription status FSM is modelled with sealed interfaces rather than a string enum and conditional logic. This ensures exhaustive handling at compile time — a new status requires handling everywhere it is switched on, preventing silent regressions.

### 13.4 FEFO Stock Deduction

Drug batches are deducted using First Expiry, First Out (FEFO) rather than FIFO. This minimises the risk of dispensing against stock that will expire before the patient completes the course.

### 13.5 Synchronous Invoice, Asynchronous Notifications

Invoice generation is synchronous and `@Transactional` — it succeeds or fails atomically with the dispense operation. SQS message sends happen after the transaction commits (Spring's `@TransactionalEventListener(phase = AFTER_COMMIT)`) so a notification provider outage never blocks or rolls back the core dispense workflow.

### 13.6 Flyway for Schema Migrations

Flyway applies versioned SQL migration scripts at application startup, making schema changes part of the deployment artefact. This ensures staging and production databases are always in sync with the running application version and makes rollbacks explicit and auditable.

### 13.7 Okta for Authentication and Authorisation

Managing auth in-house (custom JWT) was ruled out — it places the full security burden (token rotation, password reset flows, brute-force protection, MFA) on the team for a platform handling sensitive prescription data. Cognito was considered as the AWS-native option but rejected due to poor developer experience and limited customisation of login flows. Okta provides best-in-class developer tooling, a mature Spring Boot integration path (`okta-spring-boot-starter`), group-based RBAC that maps cleanly to Spring `GrantedAuthority`, and built-in MFA enforcement per group. The API is configured purely as an OAuth2 Resource Server — it validates tokens via Okta's JWKS endpoint and never handles credentials. For local development, `mock-oauth2-server` (navikt) emulates Okta's OIDC endpoints so the full stack runs offline without a real Okta tenant.

### 13.8 Shared API for Web and Mobile

The mobile app consumes the same REST API as the web application. No BFF (Backend for Frontend) layer is maintained. This simplifies the API surface and avoids duplicating business logic.

---

## 15. Design Patterns

### 15.1 Strategy — Discount Calculation

**Where:** `BillingService`

Discount logic varies by rule type (percentage, fixed amount, none) and must be extensible without modifying existing billing code. A sealed `DiscountStrategy` interface encapsulates each variant. The billing service selects the correct strategy at runtime based on the discount rule attached to a prescription or drug; new discount types (e.g., loyalty-based) are added as new implementations without touching existing code.

```java
sealed interface DiscountStrategy
    permits PercentageDiscount, FixedAmountDiscount, NoDiscount {

    BigDecimal apply(BigDecimal subtotal);
}

record PercentageDiscount(BigDecimal rate) implements DiscountStrategy {
    public BigDecimal apply(BigDecimal subtotal) {
        return subtotal.multiply(rate).setScale(2, HALF_UP);
    }
}

record FixedAmountDiscount(BigDecimal amount) implements DiscountStrategy {
    public BigDecimal apply(BigDecimal subtotal) {
        return amount.min(subtotal); // never discount more than the total
    }
}

record NoDiscount() implements DiscountStrategy {
    public BigDecimal apply(BigDecimal subtotal) { return BigDecimal.ZERO; }
}
```

---

### 15.2 Outbox Pattern — Reliable SQS Publishing

**Where:** `QueueModule` + `OutboxScheduler`

A plain `@TransactionalEventListener(AFTER_COMMIT)` SQS send risks silent message loss if the application crashes between the DB commit and the SQS publish. The Outbox pattern closes this gap: the `NotificationMessage` record is written to an `outbox_events` table inside the same `@Transactional` boundary as the domain operation. A separate scheduler polls the outbox and publishes to SQS, deleting each row on success. This guarantees at-least-once delivery without a distributed transaction.

```
Domain Transaction
  ├─ UPDATE prescriptions SET status = 'DISPENSED'
  ├─ INSERT invoices ...
  └─ INSERT outbox_events (type, payload, created_at)   ← same TX

OutboxScheduler (every 5s)
  ├─ SELECT * FROM outbox_events ORDER BY created_at LIMIT 50
  ├─ SqsTemplate.send(queue, event.payload())
  └─ DELETE FROM outbox_events WHERE id = event.id()
```

---

### 15.3 Specification — Dynamic Query Filtering

**Where:** Prescription list, Drug catalog list, Invoice list endpoints

List endpoints accept multiple optional filter parameters (status, date range, patient ID, drug category). Rather than building fragile dynamic JPQL strings, each filter is a `Specification<T>` predicate composed with `.and()` at runtime. Individual specifications are unit-testable in isolation.

```java
public class PrescriptionSpecs {

    public static Specification<Prescription> hasStatus(PrescriptionStatus status) {
        return (root, query, cb) ->
            status == null ? cb.conjunction()
                           : cb.equal(root.get("status"), status);
    }

    public static Specification<Prescription> createdBetween(LocalDate from, LocalDate to) {
        return (root, query, cb) ->
            from == null ? cb.conjunction()
                         : cb.between(root.get("createdAt"), from.atStartOfDay(), to.plusDays(1).atStartOfDay());
    }
}

// Usage in service layer
Specification<Prescription> spec = hasStatus(filter.status())
    .and(createdBetween(filter.from(), filter.to()))
    .and(hasPatientId(filter.patientId()));

return prescriptionRepository.findAll(spec, pageable);
```

---

### 15.4 Adapter — Third-Party Gateway Isolation

**Where:** `EmailGateway`, `PushGateway`

SendGrid, FCM, and APNs SDKs are wrapped behind internal interfaces. Production implementations call the real SDKs; test implementations are stubs. This makes notification workers fully testable without network calls and means swapping providers (e.g., SendGrid → AWS SES) changes only one class.

```java
public interface EmailGateway {
    void send(String to, String subject, String body);
}

@Component
@Profile("!test")
public class SendGridEmailGateway implements EmailGateway {
    public void send(String to, String subject, String body) {
        // SendGrid SDK call
    }
}

@Component
@Profile("test")
public class StubEmailGateway implements EmailGateway {
    public void send(String to, String subject, String body) {
        // no-op / record for assertion
    }
}
```

---

### 15.5 Facade — Dispense Orchestration

**Where:** `PrescriptionDispenseService`

The dispense operation touches prescriptions, stock batches, invoices, audit logs, and the outbox. A single facade method encapsulates this orchestration behind a clean API, keeps the controller thin, and makes the transactional boundary explicit.

```java
@Service
@Transactional
public class PrescriptionDispenseService {

    public DispenseResult dispense(UUID prescriptionId, UUID pharmacistId) {
        var prescription = prescriptionRepository.findById(prescriptionId).orElseThrow();
        applyEvent(prescription, new PrescriptionEvent.Dispense(pharmacistId, prescription.quantityRequired()));
        stockService.deductFEFO(prescription.drugId(), prescription.quantityRequired());
        var invoice = billingService.generateInvoice(prescription);
        auditLogger.log(prescription, pharmacistId, "DISPENSED");
        outboxService.enqueue(new PrescriptionDispensedEvent(prescription.id(), prescription.patientId()));
        return new DispenseResult(prescription.id(), invoice.id());
    }
}
```

---

### 15.6 Decorator — Audit Logging via AOP

**Where:** Cross-cutting, applied via `@Audited` annotation

Rather than embedding audit log writes inside every service method, a Spring AOP `@Around` advice intercepts any method annotated with `@Audited`, captures the before/after state, and persists the log entry. Business logic remains clean and the audit concern is applied consistently.

```java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Audited {
    String action();
}

@Aspect
@Component
public class AuditLoggingAspect {

    @Around("@annotation(audited)")
    public Object audit(ProceedingJoinPoint pjp, Audited audited) throws Throwable {
        Object result = pjp.proceed();
        auditLogRepository.save(AuditLog.of(
            audited.action(),
            securityContext.currentUserId(),
            OffsetDateTime.now()
        ));
        return result;
    }
}
```

---

### 15.7 Template Method — Notification Sending

**Where:** `AbstractNotificationSender`, `EmailNotificationSender`, `PushNotificationSender`

All notification senders share the same skeleton: validate recipient → resolve preferences → build message payload → send → log result. Only the `send` step differs. An abstract base class defines the template; subclasses implement only what varies.

```java
public abstract class AbstractNotificationSender {

    public final void send(NotificationMessage message) {
        if (!preferenceService.isEnabled(message.recipientId(), message.type())) return;
        String payload = buildPayload(message);   // abstract — subclass decides format
        doSend(message.recipientId(), payload);   // abstract — subclass decides channel
        notificationRepository.save(Notification.from(message));
    }

    protected abstract String buildPayload(NotificationMessage message);
    protected abstract void doSend(UUID recipientId, String payload);
}
```

---

### 15.8 Builder — Complex Domain Object Construction

**Where:** `Prescription`, `Invoice`, all response DTOs

Prescriptions and invoices have many optional fields. Lombok `@Builder` eliminates telescoping constructors and makes object construction self-documenting at call sites. Java 21 records serve the same role for immutable response DTOs via their compact canonical constructor.

```java
@Entity
@Builder
public class Prescription {
    private UUID id;
    private UUID patientId;
    private UUID drugId;
    private String dosage;
    private String frequency;
    private int durationDays;
    @Builder.Default private int refillsAllowed = 0;
    @Builder.Default private PrescriptionStatus status = PENDING;
    private String notes;
}

// Call site — intention is clear
Prescription.builder()
    .patientId(request.patientId())
    .drugId(request.drugId())
    .dosage(request.dosage())
    .frequency(request.frequency())
    .durationDays(request.durationDays())
    .refillsAllowed(request.refillsAllowed())
    .notes(request.notes())
    .build();
```

---

### Summary

| Pattern | Category | Applied In |
|---|---|---|
| Strategy | Behavioural | `BillingService` — discount calculation |
| Outbox | Reliability | `QueueModule` — guaranteed SQS delivery |
| Specification | Behavioural | List endpoints — dynamic query composition |
| Adapter | Structural | `EmailGateway`, `PushGateway` — third-party isolation |
| Facade | Structural | `PrescriptionDispenseService` — dispense orchestration |
| Decorator (AOP) | Structural | `@Audited` — cross-cutting audit logging |
| Template Method | Behavioural | `AbstractNotificationSender` — notification channel variants |
| Builder | Creational | `Prescription`, `Invoice`, response DTOs |
| State Machine | Behavioural | Sealed `PrescriptionEvent` — status transitions |
| Repository | Architectural | Spring Data JPA — data access abstraction |
| Observer | Behavioural | Spring `ApplicationEvent` — domain event dispatch |

---

## 16. Algorithms

### 16.1 FEFO — First Expiry, First Out (Stock Deduction)

**Where:** `StockService.deductFEFO()`  
**Complexity:** O(1) per deduction (batches pre-ordered by expiry date in DB)

Drug stock is held in batches, each with its own expiry date. When a prescription is dispensed, stock is always consumed from the earliest-expiring batch first. This minimises the risk of a batch expiring unused while stock from a newer batch is consumed. Implemented using `SequencedCollection.getFirst()` on a query ordered by `expiry_date ASC`.

```java
public void deductFEFO(UUID drugId, int quantity) {
    SequencedCollection<DrugStockBatch> batches =
        stockBatchRepository.findByDrugIdOrderByExpiryDateAsc(drugId);

    int remaining = quantity;
    for (DrugStockBatch batch : batches) {
        if (remaining == 0) break;
        int deduct = Math.min(batch.quantity(), remaining);
        batch.deduct(deduct);
        remaining -= deduct;
        stockBatchRepository.save(batch);
    }

    if (remaining > 0) throw new InsufficientStockException(drugId, quantity);
}
```

---

### 16.2 Token Bucket — Rate Limiting

**Where:** Security filter chain (Bucket4j + Redis)  
**Complexity:** O(1) per request

Each user has a virtual bucket of tokens stored in Redis. Every request consumes one token; the bucket refills at a fixed rate (e.g., 100 tokens/minute for authenticated users, 20/minute for public endpoints). Compared to a fixed-window counter, Token Bucket handles legitimate burst traffic gracefully — a user can send 10 rapid requests as long as they have tokens — while still enforcing the average rate over time.

```java
@Component
public class RateLimitFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest req,
                                    HttpServletResponse res,
                                    FilterChain chain) throws IOException, ServletException {
        String key = resolveKey(req);           // userId or IP for public endpoints
        Bucket bucket = bucketService.resolveBucket(key);

        if (bucket.tryConsume(1)) {
            chain.doFilter(req, res);
        } else {
            res.setStatus(429);
            res.getWriter().write("{\"error\":\"Too Many Requests\"}");
        }
    }
}
```

---

### 16.3 Top-K with Min-Heap — Most Dispensed Drugs

**Where:** `AnalyticsService.topDispensedDrugs()`  
**Complexity:** O(n log K) time, O(K) space

For the analytics dashboard's "most dispensed drugs" widget, maintaining a min-heap of size K is more efficient than sorting the full dispense record set when K is small (e.g., top 10). As each drug's dispense count is read, it is pushed onto the heap; if the heap exceeds K elements, the minimum is evicted. The heap retains only the K largest counts throughout.

For PharmaDesk's current scale this is handled by the database (`ORDER BY … LIMIT K`), but the heap approach becomes relevant for in-memory aggregation over streaming analytics data as volume grows.

```java
public List<DrugDispenseCount> topDispensedDrugs(int k, DateRange range) {
    // Min-heap ordered by dispense count ascending
    PriorityQueue<DrugDispenseCount> heap =
        new PriorityQueue<>(Comparator.comparingLong(DrugDispenseCount::count));

    drugRepository.streamDispenseCounts(range).forEach(entry -> {
        heap.offer(entry);
        if (heap.size() > k) heap.poll(); // evict the smallest
    });

    // Drain heap into descending list
    var result = new ArrayList<>(heap);
    result.sort(Comparator.comparingLong(DrugDispenseCount::count).reversed());
    return result;
}
```

---

### 16.4 Sliding Window — Login Brute-Force Detection

**Where:** Auth filter (Bucket4j or custom Redis implementation)  
**Complexity:** O(1) per login attempt

Failed login attempts are counted within a sliding time window (last 15 minutes) per email address. Unlike a fixed-window counter, a sliding window prevents the edge case where an attacker makes 4 failed attempts just before a window resets and 4 more just after — bypassing a 5-attempt limit. Implemented by storing attempt timestamps in a Redis sorted set, pruning entries older than the window on each check, and counting the remaining entries.

```
Redis sorted set key: login:attempts:{email}
Score: epoch milliseconds of each failed attempt

On each failed login:
  ZREMRANGEBYSCORE key 0 (now - 15min)   ← prune old entries
  ZADD key now now                        ← record this attempt
  count = ZCARD key
  if count >= 5 → lock account for 15 minutes
```

---

### 16.5 Exponential Moving Average — Dynamic Low-Stock Threshold

**Where:** `AlertScheduler` (optional enhancement over static threshold)  
**Complexity:** O(n) over recent dispense records, runs once daily

Rather than a fixed static threshold per drug, the daily consumption rate is estimated using an Exponential Moving Average (EMA), giving more weight to recent dispense activity. The alert threshold is set proportionally (e.g., 7-day supply at the current rate). This prevents false alerts for slow-moving drugs and missed alerts for fast-moving ones as demand patterns change.

```
EMA_today = α × dispenses_today + (1 - α) × EMA_yesterday

Where α = 2 / (period + 1), e.g., α = 0.18 for a 10-day period

Dynamic threshold = EMA_today × 7   (flag if stock < 7 days of supply)
```

---

### 16.6 Estimated Supply End Date — Refill Reminder Scheduling

**Where:** `AlertScheduler.dispatchRefillReminders()`  
**Complexity:** O(n) over active prescriptions, runs once daily

The refill reminder fires 7 days before the patient's supply runs out. The end date is derived from the dispense date, quantity dispensed, and normalised daily dose:

```
dailyDose    = normalisedDailyDose(frequency)   // e.g., "twice daily" → 2
daysSupply   = quantityDispensed / dailyDose
endDate      = dispenseDate + daysSupply (days)
reminderDate = endDate - 7 days
```

Frequency normalisation maps string values to a numeric daily dose:

| Frequency String | Daily Dose |
|---|---|
| `once daily` | 1 |
| `twice daily` | 2 |
| `three times daily` | 3 |
| `every 8 hours` | 3 |
| `every 12 hours` | 2 |
| `every 6 hours` | 4 |

---

### Summary

| Algorithm | Applied In | Complexity |
|---|---|---|
| FEFO (greedy) | `StockService` — batch stock deduction | O(1) per dispense |
| Token Bucket | Security filter — API rate limiting | O(1) per request |
| Top-K Min-Heap | `AnalyticsService` — most dispensed drugs | O(n log K) |
| Sliding Window | Auth filter — login brute-force detection | O(1) per attempt |
| Exponential Moving Average | `AlertScheduler` — dynamic stock threshold | O(n) daily |
| Supply End Date Estimation | `AlertScheduler` — refill reminder scheduling | O(n) daily |
