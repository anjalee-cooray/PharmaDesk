-- ---------------------------------------------------------------------------
-- init.sql
-- Runs once when the PostgreSQL container is first created.
-- Flyway owns all schema migrations — this file only sets up
-- extensions and the analytics read-model schema (separate from
-- the Core Monolith's Flyway-managed schema).
-- ---------------------------------------------------------------------------

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Analytics projections schema
-- These tables are written by analytics-projector-fn (Lambda)
-- and read by analytics-api-fn (Lambda). They are NOT managed
-- by Flyway — the projector owns their lifecycle.

CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.drug_dispense_counts (
    drug_id         UUID        PRIMARY KEY,
    drug_name       TEXT        NOT NULL,
    weekly_count    INT         NOT NULL DEFAULT 0,
    monthly_count   INT         NOT NULL DEFAULT 0,
    yearly_count    INT         NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS analytics.monthly_revenue (
    month           CHAR(7)     PRIMARY KEY,  -- YYYY-MM
    invoiced        NUMERIC(12,2) NOT NULL DEFAULT 0,
    collected       NUMERIC(12,2) NOT NULL DEFAULT 0,
    outstanding     NUMERIC(12,2) NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS analytics.stock_snapshots (
    drug_id         UUID        PRIMARY KEY,
    drug_name       TEXT        NOT NULL,
    current_stock   INT         NOT NULL DEFAULT 0,
    threshold       INT         NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS analytics.prescription_volume (
    date_bucket     DATE        NOT NULL,
    period          VARCHAR(10) NOT NULL,   -- WEEKLY | MONTHLY | YEARLY
    count           INT         NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (date_bucket, period)
);
