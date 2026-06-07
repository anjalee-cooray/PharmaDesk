# PharmaDesk

A pharmacy management platform for Patients, Pharmacists, and Admins — covering prescription lifecycle, drug inventory, billing, notifications, and analytics.

Built as a portfolio project to demonstrate production-grade system design: hybrid monolith + serverless architecture, event-driven async flows, and a full local development environment.

---

## Architecture

PharmaDesk uses a **hybrid architecture**: a layered Spring Boot monolith for tightly-coupled transactional work (prescriptions, patients, drugs, billing), with two Lambda groups extracted at natural async boundaries.

```
Clients (Web SPA + React Native)
         │
         ▼
Core Monolith — ECS Fargate, Spring Boot 3.2, Java 21
         │
         ├── PostgreSQL (primary) + Redis (cache)
         │
         └── SQS Queues ──▶ Notification Lambdas (email / push / alert)
                        └──▶ Analytics Projector Lambda ──▶ PostgreSQL Read Replica
                                                               ▲
                                                  Analytics API Lambda ◀── API Gateway
```

**Why not microservices everywhere?** Prescriptions, patients, drugs, and billing share a single transaction boundary — splitting them would require distributed transactions with no real benefit. Notifications and analytics have zero synchronous dependency on the core and are a natural fit for Lambda: they can fail, scale, or be redeployed independently without affecting prescription workflows.

---

## Repository Layout

```
PharmaDesk/
├── api/                          # Core Monolith — Spring Boot 3.2
│   ├── Dockerfile                  Multi-stage Java 21 build (ZGC + virtual threads)
│   └── src/main/resources/
│       └── application-local.yml   Local Spring profile (reads from Docker env vars)
│
├── notification-service/         # Notification Lambdas — plain Java, no Spring
│   ├── template.yaml               AWS SAM: email-handler-fn, push-handler-fn, alert-handler-fn
│   ├── env.local.json              SAM Local env vars (LocalStack endpoint, stub API keys)
│   └── src/                        Java Lambda handler code (to be implemented)
│
├── analytics-service/            # Analytics Lambdas — plain Java, no Spring
│   └── src/                        analytics-projector-fn + analytics-api-fn (to be implemented)
│
├── web/                          # React SPA (TypeScript, Vite, TanStack Query, shadcn/ui)
│   └── src/                        Frontend source (to be implemented)
│
├── infra/
│   ├── local/                    # Files Docker Compose needs to boot
│   │   ├── init.sql                Creates analytics projection tables on first DB start
│   │   ├── localstack-init.sh      Creates all SQS queues + DLQs in LocalStack
│   │   └── mock-oauth2-config.json Maps client_ids to roles (admin / pharmacist / patient)
│   │
│   └── aws/                      # Cloud deployment config
│       ├── ecs/core-task-definition.json   ECS Fargate task for Core Monolith
│       ├── sqs/queues.json                 SQS queue + DLQ definitions for all 4 queues
│       ├── rds/                            RDS config (placeholder)
│       └── elasticache/                    ElastiCache config (placeholder)
│
├── scripts/github/               # One-time GitHub board setup (run once after repo creation)
│   ├── create-labels.sh            26 labels (priority / module / type / phase / status)
│   ├── create-milestones.sh        10 milestones across the 17-week roadmap
│   ├── create-issues.sh            46 issues (42 RTM entries + 4 infra/NFR)
│   └── README.md                   Run order and post-run board setup instructions
│
├── architecture docs/
│   ├── requirements/
│   │   ├── pharma-desk-requirements.md             High-level requirements by role
│   │   ├── pharma-desk-functional-requirements.md  FR-XX-## numbered, 9 modules
│   │   ├── pharma-desk-non-functional-requirements.md  NFR-SEC/PERF/SCL/AVL etc.
│   │   ├── pharma-desk-rtm.md                      42-entry requirements traceability matrix
│   │   └── pharma-desk-delivery-roadmap.md         4-phase, 17-week delivery plan
│   │
│   └── architecture-and-engineering/
│       ├── pharma-desk-sdd.md      System Design Document v5.0 — diagrams, schema, patterns
│       ├── pharma-desk-adrs.md     19 Architecture Decision Records
│       └── openapi.yaml            OpenAPI 3.0.3 — 27 endpoints, 54 schemas, Okta JWT auth
│
└── docker-compose.yml            Local dev stack (see Local Development below)
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Core API | Java 21, Spring Boot 3.2, virtual threads |
| Lambdas | Java 21, AWS Lambda SnapStart (no Spring) |
| Database | PostgreSQL 16 (primary + read replica via RDS Proxy) |
| Cache | Redis 7 |
| Queues | Amazon SQS (4 queues + DLQs) |
| Auth | Okta — OIDC / OAuth2 Resource Server |
| Infrastructure | ECS Fargate (core), AWS Lambda + API Gateway (notifications + analytics) |
| IaC | AWS SAM (`template.yaml` per Lambda service) |
| Web | React, TypeScript, Vite, TanStack Query, shadcn/ui |
| Mobile | React Native (patient-facing) |
| Local emulation | Docker Compose, LocalStack (SQS), mock-oauth2-server (Okta), SAM Local (Lambdas) |

---

## Local Development

### Prerequisites

- Docker + Docker Compose
- AWS SAM CLI (`brew install aws-sam-cli`)
- Java 21

### Start the core stack

```bash
docker compose up --build        # first run
docker compose up -d             # subsequent runs
docker compose down              # stop (preserve data)
docker compose down -v           # stop + wipe all data
```

This starts: PostgreSQL → Redis → LocalStack (SQS + queue init) → mock-oauth2-server → Core API → Web app.

| Service | URL |
|---|---|
| Core API | http://localhost:8080 |
| Web App | http://localhost:5173 |
| Mock Okta | http://localhost:8090/pharmadesk |
| LocalStack (SQS) | http://localhost:4566 |
| PostgreSQL | localhost:5432 |
| Redis | localhost:6379 |

### Start the Lambda services (separate terminals)

Notification and Analytics Lambdas are **not** in Docker Compose — they run via SAM Local against the same LocalStack SQS instance.

```bash
# Terminal 1 — Notification Lambdas
cd notification-service
sam local start-lambda --port 3001 --env-vars env.local.json

# Terminal 2 — Analytics Lambdas
cd analytics-service
sam local start-lambda --port 3002 --env-vars env.local.json
```

---

## SQS Queues

| Queue | Purpose | Consumer |
|---|---|---|
| `pharmadesk-email` | Email dispatch events | `email-handler-fn` Lambda |
| `pharmadesk-push` | Push notification events | `push-handler-fn` Lambda |
| `pharmadesk-alerts` | Pharmacist alert events (low stock, expiry) | `alert-handler-fn` Lambda |
| `pharmadesk-domain-events` | Business domain events (dispense, payment, stock) | `analytics-projector-fn` Lambda |

All queues have a paired DLQ. Lambda SQS triggers use `ReportBatchItemFailures` for partial batch failure handling.

---

## Lambda Design Notes

All Lambda functions use **Java 21 + SnapStart**:
- All heavyweight initialisation (SDK clients, DB pools, JWKS cache) happens in the constructor — captured in the SnapStart snapshot, not incurred on each invocation.
- No Spring Boot container. Plain `RequestHandler<SQSEvent, Void>` implementations.
- No random seeds or timestamps at init time (security concern with frozen memory snapshots).

`analytics-projector-fn` connects to PostgreSQL via **RDS Proxy** to avoid connection exhaustion under Lambda concurrency.

---

## GitHub Board Setup

After creating the GitHub repo, run these once to populate the full Kanban board:

```bash
export REPO=your-github-username/PharmaDesk
export START_DATE=2026-06-09    # adjust to your Week 1 start date

bash scripts/github/create-labels.sh
bash scripts/github/create-milestones.sh
bash scripts/github/create-issues.sh
```

See [`scripts/github/README.md`](scripts/github/README.md) for full instructions and post-run board setup steps.

---

## Documentation

All architecture documentation lives in [`architecture docs/`](architecture%20docs/).

Start with:
1. [`pharma-desk-sdd.md`](architecture%20docs/architecture-and-engineering/pharma-desk-sdd.md) — full system design, diagrams, and rationale
2. [`pharma-desk-adrs.md`](architecture%20docs/architecture-and-engineering/pharma-desk-adrs.md) — 19 ADRs explaining every major technical choice
3. [`openapi.yaml`](architecture%20docs/architecture-and-engineering/openapi.yaml) — complete API contract
