# PharmaDesk — Architecture Decision Records (ADRs)

**Version:** 1.0  
**Date:** 2026-06-06  
**Project:** PharmaDesk  

---

## Index

| ADR | Title | Status |
|---|---|---|
| [ADR-001](#adr-001-layered-monolith-over-microservices) | Layered Monolith over Microservices | Superseded by ADR-016 |
| [ADR-002](#adr-002-java-21-with-virtual-threads-over-reactive-stack) | Java 21 with Virtual Threads over Reactive Stack | Accepted |
| [ADR-003](#adr-003-okta-for-authentication-and-authorisation) | Okta for Authentication and Authorisation | Accepted |
| [ADR-004](#adr-004-amazon-sqs-for-async-job-processing) | Amazon SQS for Async Job Processing | Accepted |
| [ADR-005](#adr-005-outbox-pattern-for-reliable-message-delivery) | Outbox Pattern for Reliable Message Delivery | Accepted |
| [ADR-006](#adr-006-postgresql-as-primary-database) | PostgreSQL as Primary Database | Accepted |
| [ADR-007](#adr-007-flyway-for-database-schema-migrations) | Flyway for Database Schema Migrations | Accepted |
| [ADR-008](#adr-008-sealed-classes-for-prescription-state-machine) | Sealed Classes for Prescription State Machine | Accepted |
| [ADR-009](#adr-009-fefo-for-drug-stock-deduction) | FEFO for Drug Stock Deduction | Accepted |
| [ADR-010](#adr-010-soft-deletes-for-patient-prescription-and-invoice-records) | Soft Deletes for Patient, Prescription and Invoice Records | Accepted |
| [ADR-011](#adr-011-shared-rest-api-for-web-and-mobile-no-bff) | Shared REST API for Web and Mobile — No BFF | Accepted |
| [ADR-012](#adr-012-spring-data-jpa-specifications-for-dynamic-filtering) | Spring Data JPA Specifications for Dynamic Filtering | Accepted |
| [ADR-013](#adr-013-strategy-pattern-for-discount-calculation) | Strategy Pattern for Discount Calculation | Accepted |
| [ADR-014](#adr-014-react--react-native-for-frontend-and-mobile) | React + React Native for Frontend and Mobile | Accepted |
| [ADR-015](#adr-015-gradle-with-kotlin-dsl-over-maven) | Gradle with Kotlin DSL over Maven | Accepted |
| [ADR-016](#adr-016-hybrid-architecture-monolith-core-with-extracted-services) | Hybrid Architecture — Monolith Core with Extracted Services | Accepted |
| [ADR-017](#adr-017-notification-service-extraction) | Notification Service Extraction | Accepted |
| [ADR-018](#adr-018-analytics-service-extraction) | Analytics Service Extraction | Accepted |

---

## ADR-001: Layered Monolith over Microservices

**Date:** 2026-06-06  
**Status:** Superseded by [ADR-016](#adr-016-hybrid-architecture-monolith-core-with-extracted-services)

### Context

The initial architecture decision was whether to build PharmaDesk as a distributed microservices system or as a structured monolith. The platform targets approximately 10,000 patients and 1,000 daily prescription transactions at launch. The team is small and the operational budget is constrained.

### Decision

PharmaDesk will be built as a **layered monolith** with clear internal package boundaries (controllers → services → repositories), deployed as a single Spring Boot application on AWS ECS Fargate.

### Consequences

**Positive:**
- Single deployment unit — simpler CI/CD pipeline, no service mesh or inter-service networking to manage
- No distributed transaction complexity; `@Transactional` boundaries work across the entire domain
- Easier local development — one Docker container for the API
- Faster to iterate in the early stages of the product

**Negative:**
- A single deployment affects all features simultaneously — a bad deploy cannot be scoped to one service
- Horizontal scaling applies to the whole application, not to individual high-load components
- As the codebase grows, discipline around module boundaries must be actively enforced

### Alternatives Considered

**Microservices** — rejected at this scale. Service discovery, distributed tracing, network latency between services, and the operational overhead of running many containers adds complexity that is not justified by the expected load. Module boundaries within the monolith can be extracted into separate services later if a specific component (e.g., analytics, notifications) becomes a bottleneck.

---

## ADR-002: Java 21 with Virtual Threads over Reactive Stack

**Date:** 2026-06-06  
**Status:** Accepted

### Context

The backend requires high concurrency to handle simultaneous API requests, background SQS listeners, and scheduled jobs without blocking threads. Two approaches were evaluated: Spring WebFlux (reactive, non-blocking) and Spring Web MVC running on Java 21 virtual threads (Project Loom).

### Decision

PharmaDesk will use **Spring Web MVC on Java 21 virtual threads**, enabled via a single Spring Boot 3.2 configuration flag:

```yaml
spring:
  threads:
    virtual:
      enabled: true
```

### Consequences

**Positive:**
- Synchronous, imperative code throughout — no reactive operators (`Mono`, `Flux`), no callback chains
- Same non-blocking I/O throughput as WebFlux — virtual threads are cheap and park instead of block
- Standard Java debugging, profiling, and stack traces — no reactor-specific tooling required
- All existing Spring libraries (JPA, Security, Validation) work unchanged
- Lower cognitive overhead for the team

**Negative:**
- Virtual threads are not a silver bullet for CPU-bound work — computationally intensive tasks should still be dispatched to a bounded thread pool
- The ecosystem is newer than WebFlux; some edge cases around thread-local state (e.g., certain connection pool implementations) require verification

### Alternatives Considered

**Spring WebFlux (Project Reactor)** — rejected due to the significant complexity cost. Reactive code propagates throughout the entire call stack — services, repositories, error handling all become reactive. For a team not already proficient with reactive programming, this is a high-risk choice for a production system.

---

## ADR-003: Okta for Authentication and Authorisation

**Date:** 2026-06-06  
**Status:** Accepted

### Context

PharmaDesk handles prescription data, a sensitive medical-adjacent domain. A robust identity solution is required that supports role-based access control, MFA enforcement per role group, and secure token lifecycle management. The options evaluated were: custom JWT implementation, AWS Cognito, Azure AD (Entra ID), and Okta.

### Decision

PharmaDesk will use **Okta** as the identity provider. The Spring Boot API will be configured as an **OAuth2 Resource Server** using `okta-spring-boot-starter`, validating JWTs via Okta's JWKS endpoint. Role assignment is managed via Okta Groups, mapped to Spring `GrantedAuthority` objects via a custom `OktaJwtRoleConverter`.

For local development, `mock-oauth2-server` (navikt) emulates Okta's OIDC endpoints so the full stack runs without a real Okta tenant.

### Consequences

**Positive:**
- Credentials and token lifecycle are fully managed by Okta — the API never handles passwords
- MFA can be enforced per group (e.g., Pharmacist and Admin groups require MFA by policy)
- Best-in-class developer experience; excellent Spring Boot integration documentation
- Group-based RBAC maps cleanly to Spring Security's `@PreAuthorize` model
- Built-in brute-force protection, account lockout, and audit logging on Okta's side
- Password reset, email verification, and social login flows are out of the box

**Negative:**
- Per-MAU pricing becomes expensive at scale — must be monitored as patient numbers grow
- Adds an external dependency to the critical authentication path; an Okta outage means users cannot log in
- Local development requires `mock-oauth2-server` to emulate the OIDC endpoints

### Alternatives Considered

**Custom JWT (jjwt)** — rejected. Building a secure auth system in-house (token rotation, password reset, brute-force protection, MFA) is a significant engineering effort and a large attack surface for a platform handling medical data.

**AWS Cognito** — rejected. While native to AWS and cost-effective, the developer experience is poor: the SDK is complex, the hosted UI is inflexible, and User Pool configuration has a steep learning curve. The operational friction was not worth the AWS-native benefit.

**Azure AD (Entra ID)** — rejected. Designed for enterprise B2B and internal employee identity. Introduces an Azure dependency alongside an AWS-native stack and is not suited to patient-facing consumer account management.

---

## ADR-004: Amazon SQS for Async Job Processing

**Date:** 2026-06-06  
**Status:** Accepted

### Context

Notification dispatch (email, push), alert evaluation (low stock, expiry), and refill reminders must be processed asynchronously so that failures in these systems do not block or roll back the core prescription and billing workflows. A job queue is required.

### Decision

PharmaDesk will use **Amazon SQS** with `Spring Cloud AWS 3` for async job processing. Three Standard queues are provisioned (`pharmadesk-email`, `pharmadesk-push`, `pharmadesk-alerts`), each with a corresponding Dead Letter Queue. Consumers are `@SqsListener` methods running on virtual threads. The Outbox pattern (ADR-005) guarantees delivery reliability. Scheduled alert jobs use Spring `@Scheduled` and publish to SQS via `SqsTemplate`. Local development uses **LocalStack** to emulate SQS.

### Consequences

**Positive:**
- Fully managed — no broker to operate, patch, or back up
- Native AWS integration; IAM-based access control with no additional credentials to manage
- Built-in DLQ support surfaces failed messages without custom dead-letter logic
- `@SqsListener` on virtual threads means no reactive boilerplate in consumer code
- LocalStack provides a faithful local emulation without a real AWS account

**Negative:**
- SQS Standard queues offer at-least-once delivery (not exactly-once) — consumers must be idempotent
- No native scheduled message delivery (delay up to 15 minutes only) — Spring `@Scheduled` fills this gap for daily cron jobs
- Adds AWS cost per million requests, though negligible at PharmaDesk's scale

### Alternatives Considered

**BullMQ (Redis-backed, Node.js)** — rejected when the backend stack moved to Java. BullMQ is a Node.js library with no Java equivalent.

**JobRunr** — considered as the Java equivalent of BullMQ. Offers a clean API and a dashboard UI. Rejected in favour of SQS because PharmaDesk is already on AWS — a managed, serverless queue removes an operational concern without adding infrastructure complexity.

**RabbitMQ** — rejected. A self-hosted message broker introduces another stateful service to operate, monitor, and back up. The fan-out capabilities of a full broker are not needed at this scale.

---

## ADR-005: Outbox Pattern for Reliable Message Delivery

**Date:** 2026-06-06  
**Status:** Accepted

### Context

Domain events (e.g., prescription dispensed, refill approved) must trigger SQS messages that dispatch notifications. Using `@TransactionalEventListener(AFTER_COMMIT)` to send SQS messages after a DB transaction commits creates a reliability gap: if the application crashes between the commit and the SQS send, the message is silently lost.

### Decision

PharmaDesk will implement the **Outbox Pattern**. When a domain operation commits, it writes a serialised `outbox_events` record to the database inside the same transaction. A separate `OutboxScheduler` (polling every 5 seconds) reads unpublished outbox records, publishes them to SQS via `SqsTemplate`, and deletes them on success. This guarantees **at-least-once delivery** without a distributed transaction.

### Consequences

**Positive:**
- No silent message loss — the outbox record and the domain state change are atomic
- Decouples the domain transaction from the availability of SQS
- Failed SQS sends are retried on the next scheduler poll cycle

**Negative:**
- Adds the `outbox_events` table and `OutboxScheduler` component to maintain
- At-least-once delivery means SQS consumers must be idempotent (deduplicate on `outbox_events.id`)
- Introduces up to 5-second latency between a domain event and the corresponding notification

### Alternatives Considered

**`@TransactionalEventListener(AFTER_COMMIT)` only** — rejected due to the crash-between-commit-and-send reliability gap described above. Acceptable for low-stakes events but not for notifications tied to prescription state changes.

**AWS EventBridge** — considered for event routing but adds another managed service dependency without solving the atomicity problem. The Outbox pattern solves the root issue regardless of the downstream messaging system.

---

## ADR-006: PostgreSQL as Primary Database

**Date:** 2026-06-06  
**Status:** Accepted

### Context

PharmaDesk's data — prescriptions, patients, stock batches, invoices — is highly relational and requires strong consistency guarantees. Audit logs must be immutable. Billing requires atomic multi-table transactions.

### Decision

PharmaDesk will use **PostgreSQL 16** hosted on AWS RDS (Multi-AZ) as the sole primary data store. Hibernate 6 / Spring Data JPA provides the ORM layer. JSONB columns are used for audit log `field_changes` where a flexible schema is beneficial.

### Consequences

**Positive:**
- Full ACID compliance — `@Transactional` boundaries across prescription, stock, and billing operations are reliable
- Native JSONB support for semi-structured audit log payloads
- Mature ecosystem; excellent Spring Data JPA and Hibernate support
- RDS Multi-AZ provides automatic failover with no application-level change
- Read replicas can be added for analytics queries without architectural changes

**Negative:**
- Vertical scaling has a ceiling; horizontal sharding of relational data is complex if volume grows dramatically
- Schema changes require migrations and careful backward compatibility management (mitigated by Flyway — ADR-007)

### Alternatives Considered

**MongoDB** — rejected. The relational nature of prescriptions, patients, drugs, and invoices makes a document model a poor fit. Enforcing referential integrity and running multi-document ACID transactions in MongoDB adds complexity without benefit.

**MySQL** — considered but PostgreSQL was preferred for its superior JSONB support, more expressive SQL features, and better handling of concurrent writes.

---

## ADR-007: Flyway for Database Schema Migrations

**Date:** 2026-06-06  
**Status:** Accepted

### Context

Database schema changes must be versioned, reproducible, and applied consistently across development, staging, and production environments. Manual schema edits on production are error-prone and unauditable.

### Decision

PharmaDesk will use **Flyway** for schema migration management. Versioned SQL scripts are stored in `src/main/resources/db/migration` and applied automatically at application startup. Each migration file follows the naming convention `V{version}__{description}.sql`.

### Consequences

**Positive:**
- Schema changes are part of the application artefact — a deployment always brings the schema and code into sync
- Migration history is tracked in the `flyway_schema_history` table, providing a full audit of schema changes
- Rollback is handled by writing a compensating migration — explicit and auditable
- Works identically across local Docker, staging, and production

**Negative:**
- Irreversible migrations (e.g., dropping a column) require careful planning
- Large data migrations (backfilling millions of rows) must be written as separate, non-blocking scripts to avoid locking tables during deployment

### Alternatives Considered

**Liquibase** — functionally similar to Flyway. Rejected in favour of Flyway for its simpler configuration, plain SQL migration files (vs. Liquibase XML/YAML changesets), and lighter dependency footprint.

**Hibernate `hbm2ddl.auto`** — rejected outright. Auto-DDL is appropriate for development only; it is unsafe in production and provides no migration history.

---

## ADR-008: Sealed Classes for Prescription State Machine

**Date:** 2026-06-06  
**Status:** Accepted

### Context

Prescriptions move through a defined set of statuses: `PENDING → VERIFIED → DISPENSED / REJECTED`. State transitions must be enforced strictly — invalid transitions (e.g., dispensing a rejected prescription) should be caught at compile time where possible, not just at runtime via conditional logic.

### Decision

Prescription state transitions will be modelled as a **sealed interface hierarchy** (`PrescriptionEvent`), with permitted implementations for each transition type. The service layer applies transitions via a **pattern matching for switch** expression, which the compiler enforces is exhaustive. Adding a new status without handling it everywhere is a compile error.

```java
sealed interface PrescriptionEvent
    permits PrescriptionEvent.Verify, PrescriptionEvent.Dispense,
            PrescriptionEvent.Reject, PrescriptionEvent.Cancel {

    record Verify(UUID pharmacistId) implements PrescriptionEvent {}
    record Dispense(UUID pharmacistId, int quantityDispensed) implements PrescriptionEvent {}
    record Reject(UUID pharmacistId, String reason) implements PrescriptionEvent {}
    record Cancel(UUID performedById) implements PrescriptionEvent {}
}
```

### Consequences

**Positive:**
- Compile-time exhaustiveness — the compiler enforces that every event type is handled in every switch expression
- New statuses cannot be silently unhandled — the build fails until all switch expressions are updated
- Events are records: immutable, self-documenting, zero boilerplate
- Aligns naturally with Java 21's pattern matching for switch

**Negative:**
- Slightly more verbose than a simple `enum` + `if/else` approach for teams unfamiliar with sealed classes
- Sealed hierarchies cannot be extended outside their defining package — intentional, but worth noting for future extensibility

### Alternatives Considered

**String/Enum status with conditional logic** — rejected. `if (status.equals("PENDING"))` chains are fragile, not compile-time safe, and easy to miss when adding a new status.

**Spring State Machine library** — considered but rejected as over-engineered for four statuses. The sealed class approach achieves the same compile-time safety with far less infrastructure.

---

## ADR-009: FEFO for Drug Stock Deduction

**Date:** 2026-06-06  
**Status:** Accepted

### Context

Drug stock is held in batches, each with its own expiry date. When a prescription is dispensed, a deduction strategy must be chosen: which batch to consume from first.

### Decision

PharmaDesk will use **FEFO (First Expiry, First Out)** — always deduct from the batch with the earliest expiry date first. Batches are queried ordered by `expiry_date ASC` and consumed using `SequencedCollection.getFirst()` (Java 21).

### Consequences

**Positive:**
- Minimises the risk of a batch expiring unused while newer stock is consumed
- Directly reduces waste and the frequency of expiry alerts
- Simple to implement and reason about; well-understood in pharmacy logistics

**Negative:**
- Marginally more complex than FIFO (requires ordering by expiry date rather than receipt date)
- Multi-batch deductions (when quantity spans more than one batch) require iterating the ordered collection

### Alternatives Considered

**FIFO (First In, First Out)** — rejected. Consuming the oldest-received batch first does not account for expiry dates. A batch received early but with a distant expiry would be consumed before a later-received batch with a sooner expiry, potentially allowing near-expiry stock to go unused.

**Manual batch selection** — rejected. Requiring pharmacists to manually select a batch for every dispense adds operational friction and introduces human error into stock management.

---

## ADR-010: Soft Deletes for Patient, Prescription and Invoice Records

**Date:** 2026-06-06  
**Status:** Accepted

### Context

Patient records, prescriptions, and invoices are sensitive data with regulatory retention requirements. Physically deleting records breaks referential integrity, removes audit trail data, and makes recovery impossible within the 30-day grace period required by the data protection policy (NFR-COMP-04).

### Decision

Patient records, prescriptions, and invoices will use **soft deletes** — a `deleted_at TIMESTAMPTZ` column that is set on deletion rather than physically removing the row. Queries filter `WHERE deleted_at IS NULL` by default via a Hibernate `@Where` annotation on the entity. Physical purge is a separate Admin-only operation available after a 30-day grace period.

### Consequences

**Positive:**
- Referential integrity is preserved — foreign keys are never orphaned
- Audit trail remains complete — deleted records are still visible in audit logs
- Data is recoverable within the grace period
- Complies with NFR-COMP-04 (soft delete + 30-day grace period before physical purge)

**Negative:**
- Queries must consistently apply the `deleted_at IS NULL` filter — Hibernate's `@Where` annotation handles this automatically but must be tested
- The `deleted_at` column adds a small amount of storage overhead across large tables
- Unique constraints (e.g., on email) must account for soft-deleted records to avoid conflicts when re-registering a previously deleted user

### Alternatives Considered

**Physical (hard) deletes** — rejected. Permanently removes data that may be required for audit compliance, breaks referential integrity, and cannot be undone.

**Archive tables** — considered (copying deleted rows to a `_deleted` shadow table before removal). Rejected as unnecessarily complex — a single `deleted_at` column achieves the same goal with less schema surface.

---

## ADR-011: Shared REST API for Web and Mobile — No BFF

**Date:** 2026-06-06  
**Status:** Accepted

### Context

PharmaDesk has two client surfaces: a React web application and a React Native mobile application (patient-facing). A Backend for Frontend (BFF) pattern would provide each client with a dedicated API layer tailored to its data needs. The alternative is to expose a single shared REST API consumed by both.

### Decision

PharmaDesk will maintain a **single shared REST API** for both web and mobile clients. No BFF layer will be introduced. The mobile app consumes the same endpoints as the web application. Response payloads are designed to be comprehensive enough for both clients, with clients responsible for rendering only the fields they need.

### Consequences

**Positive:**
- Single API surface to maintain, test, and document
- No duplication of business logic across multiple backend layers
- Simpler deployment topology
- OpenAPI documentation covers both clients from one spec

**Negative:**
- Response payloads may contain fields the mobile client does not need, consuming slightly more bandwidth on mobile connections
- If mobile and web data requirements diverge significantly in the future, retrofitting a BFF becomes more complex

### Alternatives Considered

**BFF (Backend for Frontend)** — rejected at this scale. The additional deployment unit, the duplicated business logic risk, and the maintenance overhead of two API layers are not justified when the mobile client is limited to the patient role with a well-defined, stable set of operations (view prescriptions, request refills, scan barcode, view billing).

---

## ADR-012: Spring Data JPA Specifications for Dynamic Filtering

**Date:** 2026-06-06  
**Status:** Accepted

### Context

List endpoints (prescriptions, drugs, invoices) accept multiple optional filter parameters — status, date range, patient ID, drug category, payment status. Constructing dynamic JPQL or SQL strings based on which parameters are present is error-prone and difficult to test. A structured, composable approach is required.

### Decision

PharmaDesk will use **Spring Data JPA Specifications** (`Specification<T>`) for all dynamic query filtering. Each filter criterion is a standalone `Specification` predicate. The service layer composes them with `.and()` / `.or()` at runtime based on which filter parameters are present in the request.

### Consequences

**Positive:**
- Each specification is a single, independently unit-testable predicate
- Composition via `.and()` / `.or()` is readable and type-safe
- No string concatenation or risk of JPQL injection
- New filter criteria are added as new `Specification` implementations without modifying existing ones

**Negative:**
- Generates JPA Criteria API queries under the hood — complex joins can produce verbose criteria code
- For highly complex reporting queries (e.g., analytics aggregations), native SQL or JPQL named queries are still more readable and are used in the analytics module

### Alternatives Considered

**Dynamic JPQL string building** — rejected. Fragile, hard to test, and a potential source of query injection bugs if parameters are not handled carefully.

**QueryDSL** — a strong alternative with a fluent type-safe query DSL generated from entity classes. Rejected to keep the dependency footprint minimal; Spring Data JPA Specifications cover the filtering requirements without an additional code-generation step.

---

## ADR-013: Strategy Pattern for Discount Calculation

**Date:** 2026-06-06  
**Status:** Accepted

### Context

PharmaDesk supports multiple discount rule types — percentage-based, fixed amount, and no discount. New discount types (e.g., loyalty-based, group-based) may be added in the future. Embedding discount logic as `if/else` branches inside `BillingService` would make the service harder to test and violate the open/closed principle.

### Decision

Discount calculation will be modelled using the **Strategy pattern** via a sealed `DiscountStrategy` interface with permitted record implementations: `PercentageDiscount`, `FixedAmountDiscount`, and `NoDiscount`. `BillingService` selects the correct strategy at runtime based on the discount rule and delegates the calculation to it.

### Consequences

**Positive:**
- New discount types are added as new `DiscountStrategy` implementations — `BillingService` is not modified
- Each strategy is independently unit-testable with no service dependencies
- Sealed interface ensures the compiler flags an unhandled discount type in any switch expression
- Records make strategy instances immutable and serialisation-friendly

**Negative:**
- Minor additional indirection compared to inline `if/else` logic — acceptable given the extensibility benefit

### Alternatives Considered

**Inline conditional logic in `BillingService`** — rejected. A growing list of discount types would make `BillingService` a god class, difficult to test and maintain.

---

## ADR-014: React + React Native for Frontend and Mobile

**Date:** 2026-06-06  
**Status:** Accepted

### Context

PharmaDesk requires a responsive web application (used by Patients, Pharmacists, and Admins) and a native mobile application (Patient-facing, iOS and Android). A technology decision was needed for both surfaces.

### Decision

The web application will be built with **React 18** (TypeScript, Vite, TanStack Query, shadcn/ui + Tailwind CSS). The mobile application will be built with **React Native 0.74 via Expo** (TypeScript, TanStack Query, React Navigation). Both share the same language, state management approach (Zustand), and data-fetching library, allowing team members to contribute across both surfaces.

### Consequences

**Positive:**
- Shared language (TypeScript) and core libraries across web and mobile reduce context switching
- Expo simplifies React Native tooling — OTA updates, device builds, and native module management
- TanStack Query provides consistent caching and server-state patterns on both platforms
- shadcn/ui + Tailwind gives the web UI a fast iteration cycle with accessible components out of the box

**Negative:**
- React Native is not truly native — complex animations or highly platform-specific UX may require native modules
- Expo's managed workflow has occasional limitations when accessing low-level device APIs (mitigated by the bare workflow if needed)

### Alternatives Considered

**Flutter** — considered for the mobile app. Rejected due to Dart being a separate language from the web stack — team members cannot contribute across web and mobile without context switching between two ecosystems.

**Next.js for web** — considered for SSR/SEO benefits. Rejected because PharmaDesk's web application is an authenticated dashboard with no public-facing pages requiring SEO, making SSR overhead unjustified. Vite + React SPA is faster to develop and deploy.

---

## ADR-015: Gradle with Kotlin DSL over Maven

**Date:** 2026-06-06  
**Status:** Accepted

### Context

A build tool is required for the Java 21 / Spring Boot backend. The two primary options in the Java ecosystem are Maven and Gradle.

### Decision

PharmaDesk will use **Gradle with the Kotlin DSL** (`build.gradle.kts`) as the build tool.

### Consequences

**Positive:**
- Faster incremental builds than Maven — Gradle's build cache avoids re-executing tasks with unchanged inputs
- Kotlin DSL provides type-safe, IDE-autocomplete-friendly build scripts compared to Groovy DSL or Maven XML
- Better support for custom build logic when needed (e.g., code generation tasks)
- Spring Boot's Gradle plugin is first-class and well-maintained

**Negative:**
- Gradle has a steeper initial learning curve than Maven for developers unfamiliar with it
- Build script compilation time adds a small overhead on the first run

### Alternatives Considered

**Maven** — the more widely known option in the Java enterprise space. Rejected due to slower incremental build times and verbose XML configuration. Maven's convention-over-configuration model is less flexible for customisation.

---

## ADR-016: Hybrid Architecture — Monolith Core with Extracted Services

**Date:** 2026-06-06  
**Status:** Accepted  
**Supersedes:** [ADR-001](#adr-001-layered-monolith-over-microservices)

### Context

ADR-001 chose a layered monolith. Upon further review, two modules — notifications and analytics — have characteristics that make them poor fits inside the monolith: they are purely event-driven, have no transactional dependency on the core domain, and have distinct scaling profiles. A full microservices decomposition was also evaluated but rejected due to the transactional coupling in the core prescription-billing-stock workflow.

### Decision

PharmaDesk will use a **hybrid architecture**:

- **Core Monolith** (`pharmadesk-core`) — handles all operations requiring ACID atomicity: prescriptions, patients, drugs/inventory, billing, users. Deployed as a single Spring Boot application on ECS Fargate.
- **Notification Service** (`pharmadesk-notification`) — a separately deployed Spring Boot application that consumes SQS queues and dispatches email and push notifications. No database, no REST API.
- **Analytics Service** (`pharmadesk-analytics`) — a separately deployed Spring Boot application that consumes domain events from SQS, maintains read-optimised projections, and exposes a REST API for dashboard queries. Reads from a PostgreSQL read replica.

Each service has its own Docker image, ECS task definition, and independent CI/CD pipeline.

### Consequences

**Positive:**
- The core transactional boundary remains a single `@Transactional` call — no distributed transactions or Sagas needed
- Notification and Analytics services can fail, scale, or be redeployed without any impact on core prescription workflows
- Independent CI/CD per service — a notification provider change does not require a core monolith release
- Notification Service scales on SQS queue depth; Analytics Service scales on CPU independently of core
- The SQS event boundary was already in the design — extraction required no redesign, only repackaging

**Negative:**
- Three deployment units to manage instead of one — more CI/CD pipelines, more ECS task definitions, more Docker images
- Local development requires running all three services (managed via Docker Compose)
- Domain events must be carefully versioned — a breaking change to event structure affects all consumers
- Observability (distributed tracing, log correlation) requires a shared `correlationId` propagated through SQS message attributes

### Alternatives Considered

**Pure layered monolith (ADR-001)** — superseded. Notification and analytics modules have sufficiently different characteristics (async-only, different scaling) that keeping them in the monolith unnecessarily couples their deployments to the core.

**Full microservices** — rejected. The dispense operation atomically touches prescriptions, stock batches, invoices, and the outbox. Splitting this across services would require a Saga with compensating transactions — significant complexity for a correctness-critical domain with a small team.

---

## ADR-017: Notification Service as AWS Lambda Functions

**Date:** 2026-06-06  
**Status:** Accepted  
**Supersedes:** Original decision to run Notification Service as a Spring Boot ECS Fargate task

### Context

The notification dispatch logic (email and push) communicates exclusively via SQS, has no synchronous REST dependencies, and requires no database of its own. Its only job is to consume SQS messages and call an external delivery API (SendGrid, FCM, APNs). This workload is inherently bursty — high volume after a prescription dispense event, quiet otherwise. Running a Spring Boot ECS Fargate container continuously for a stateless SQS consumer wastes compute and incurs a fixed hourly cost regardless of notification volume.

### Decision

Notification dispatching is implemented as **three AWS Lambda functions**, each triggered by a dedicated SQS event source mapping:

- `pharmadesk-email-handler` — consumes `pharmadesk-email`, calls SendGrid
- `pharmadesk-push-handler` — consumes `pharmadesk-push`, calls FCM/APNs
- `pharmadesk-alert-handler` — consumes `pharmadesk-alerts`, routes to email + push

All functions use Java 21 runtime with **Lambda SnapStart** to eliminate cold-start latency. Deployment is managed via AWS SAM (`template.yaml` in `notification-service/`).

The Core Monolith retains:
- The in-app `Notification` entity and notification centre REST endpoints (patient-facing)
- The `AlertScheduler` cron that produces alert messages to SQS
- The `OutboxPublisher` that produces notification messages to SQS after domain transactions commit

### Consequences

**Positive:**
- Zero idle compute cost — Lambda charges only per invocation; the notification layer costs nothing when no notifications are in flight
- Automatic scaling — Lambda scales to handle any SQS message volume without configuration; no need to tune ECS task counts or scaling policies
- SQS DLQ after 3 failures provides the same retry and dead-letter behaviour as the previous design
- A SendGrid or FCM outage has zero impact on the Core Monolith
- Provider swap requires only a Lambda redeploy, not a core release
- SnapStart removes the Java cold-start concern — first invocation after a dormant period is fast

**Negative:**
- Three Lambda functions to manage instead of one service — offset by SAM grouping them in a single stack
- Developers must use SAM Local instead of Docker Compose to run notification functions locally
- Maximum execution timeout of 15 minutes (non-issue for notification dispatch; each message completes in milliseconds)

### Alternatives Considered

**Spring Boot on ECS Fargate** — rejected. An always-on container for a stateless, bursty SQS consumer is inefficient. SnapStart addresses the main Java-on-Lambda objection (cold starts).

**Keep in Core Monolith** — rejected. Notification worker threads contend with API handler threads under load, and a misconfigured delivery gateway (invalid API key) can exhaust the core thread pool.

---

## ADR-018: Analytics Service as AWS Lambda Functions

**Date:** 2026-06-06  
**Status:** Accepted  
**Supersedes:** Original decision to run Analytics Service as a Spring Boot ECS Fargate task

### Context

The analytics module has two distinct responsibilities: maintaining read-model projections from domain events (write-path, event-driven) and serving dashboard queries (read-path, HTTP API). Both are low-frequency relative to the Core Monolith. The projector fires when domain events arrive on SQS; the API is called when a pharmacist or admin opens the dashboard. Running a Spring Boot container continuously for these workloads is over-provisioned.

### Decision

Analytics is split into **two AWS Lambda functions**:

**`pharmadesk-analytics-projector`** — SQS-triggered Lambda consuming `pharmadesk-domain-events`. It upserts materialised projections (dispense counts, revenue totals, stock snapshots) into PostgreSQL via **RDS Proxy** (required for connection pooling, since Lambda can open many short-lived connections).

**`pharmadesk-analytics-api`** — API Gateway HTTP-triggered Lambda serving read-only dashboard queries. It validates the Okta JWT (JWKS cached in memory after SnapStart init), queries PostgreSQL projections via RDS Proxy, and returns JSON to the client.

Both functions use Java 21 runtime with Lambda SnapStart. Both run inside the VPC to reach RDS Proxy. Deployment is managed via AWS SAM (`template.yaml` in `analytics-service/`).

### Consequences

**Positive:**
- Zero idle compute cost for both functions
- Projector scales automatically with domain event volume — no ECS scaling policy needed
- API function scales to handle concurrent dashboard requests without configuration
- RDS Proxy pools connections to PostgreSQL, preventing connection exhaustion from Lambda concurrency
- Analytics can be redeployed independently — projection changes do not require a core monolith release
- If data volume grows, the projector can be rerouted to write to ClickHouse or Redshift with no Core Monolith changes

**Negative:**
- RDS Proxy incurs an additional hourly AWS cost
- VPC configuration required for both Lambda functions (to reach RDS Proxy) — adds networking complexity
- Eventual consistency — projections lag domain events by SQS delivery time (typically < 1 second)
- Domain event schema changes require coordinated updates to the projector

### Alternatives Considered

**Spring Boot on ECS Fargate** — rejected. Same argument as ADR-017; two workloads with bursty, low-average traffic are a poor fit for always-on containers.

**Analytics queries against the primary DB without a projector** — rejected. Aggregation queries (GROUP BY, SUM across large tables) directly compete with prescription write throughput on the primary instance.

**Amazon Athena + S3** — considered as a serverless OLAP store. Rejected as over-engineered at current scale. PostgreSQL projections queried via Lambda achieve acceptable performance. Athena remains a viable upgrade path if data volume justifies it.

---

## ADR-019: Java 21 with Lambda SnapStart for Notification and Analytics Functions

**Date:** 2026-06-06  
**Status:** Accepted

### Context

The primary objection to running Java on AWS Lambda has historically been cold-start latency. When a Lambda execution environment is initialised from scratch, a Java 21 Spring Boot handler can take 5–10 seconds before the first invocation completes — unacceptable for user-facing APIs (analytics-api-fn) and wasteful for background processors (email-handler-fn, analytics-projector-fn). The alternative of using a lighter runtime (Node.js, Python) or GraalVM native image introduces a different trade-off: abandoning the Java 21 ecosystem already established in the Core Monolith.

### Decision

All five Lambda functions (`pharmadesk-email-handler`, `pharmadesk-push-handler`, `pharmadesk-alert-handler`, `pharmadesk-analytics-projector`, `pharmadesk-analytics-api`) use **Java 21 runtime with AWS Lambda SnapStart**.

SnapStart works by taking a Firecracker microVM snapshot after the `@SnapStart` init phase completes. On subsequent invocations, Lambda restores from the snapshot instead of initialising from scratch, reducing cold-start latency from seconds to milliseconds (typically 200–300 ms including restore time).

Design decisions to maximise SnapStart effectiveness:

- All heavyweight initialisation (SendGrid client, JDBC DataSource, Okta JWKS cache) happens in the constructor or `@SnapStart`-annotated init method — not on first invocation
- No random seeds, timestamps, or cryptographic nonces generated at init time (they would be frozen in the snapshot and reused across restores — a security issue)
- No Spring Boot container — handlers use plain Java with direct instantiation. This removes the Spring context startup time entirely and keeps the JAR small

### Consequences

**Positive:**
- Cold-start latency reduced to ~200 ms — acceptable for the analytics API and imperceptible for async processors
- Java 21 retained across all services — one language, one toolchain, shared library modules (e.g., domain event DTOs)
- No GraalVM native-image build complexity — SnapStart achieves comparable cold-start times with standard JVM compilation
- SnapStart is a SAM/CloudFormation configuration flag (`SnapStart: ApplyOn: PublishedVersions`) — no code changes required beyond constructor-safe initialisation

**Negative:**
- SnapStart only applies to published Lambda versions — `$LATEST` invocations do not benefit. Staging and production deployments must publish a version; local SAM Local development does not use SnapStart
- Snapshot restore introduces a brief period where environment state (file handles, open sockets) must be re-established after restore — handled by Lambda's `AfterRestore` hook if needed
- SnapStart is not available for all runtimes or regions — Java 21 on `x86_64` and `arm64` are supported in all target regions

### Alternatives Considered

**GraalVM Native Image** — would achieve sub-100 ms cold starts but requires all reflection usage to be declared in JSON configuration files, breaks many standard Java libraries, and adds significant build complexity. SnapStart achieves comparable results without these trade-offs.

**Node.js or Python runtime** — would avoid cold-start concerns entirely but requires maintaining a second language for notification and analytics logic. The Java 21 domain event DTOs and JSON serialisation code are already defined — reusing them in Lambda avoids duplication.

**Provisioned Concurrency** — AWS alternative to SnapStart: pre-warms a fixed number of execution environments. Rejected because it charges for idle warm instances, reintroducing the fixed cost that Lambda was chosen to avoid. SnapStart achieves warm-equivalent latency without provisioned cost.
