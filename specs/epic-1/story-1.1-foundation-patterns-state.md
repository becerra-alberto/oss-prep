---
id: "1.1"
epic: 1
title: "Create shared pattern libraries and state schema"
status: done
source_prd: "tasks/prd-oss-prep-v2.md"
priority: critical
estimation: medium
depends_on: []
---

# Story 1.1 — Create shared pattern libraries and state schema

## User Story

**As a** phase sub-agent executing Phases 1, 2, or 8,
**I need** a shared, canonical secret and PII pattern library that I can reference by file path, and a persistent state schema that all phases write to,
**So that** pattern definitions are consistent across phases, survive context boundaries, and the orchestrator can persist/resume state across sessions.

## Technical Context

The current v1 SKILL.md is a 3,484-line monolith. The secret regex patterns live inline in **Step 1.2 — Secret Pattern Library** (lines 431-525) and the PII regex patterns live inline in **Step 2.2 — PII Pattern Library** (lines 803-868). Both are consumed by their respective phases and also referenced by Phase 8's post-flatten verification scan (lines 3091-3099). Extracting them into standalone files under `patterns/` enables cross-phase sharing without duplicating pattern definitions into each phase file.

The v1 STATE block (lines 22-40) is an in-conversation construct that is lost on session crash. This story defines a JSON schema for the persistent on-disk equivalent at `.oss-prep/state.json`, incorporating per-phase finding counts (DD-2 from the PRD) and version numbering (AC-1.1.5).

**Source material locations in SKILL.md:**
- Secret patterns: lines 431-525 (Step 1.2), 11 categories with markdown tables
- Secret severity: lines 526-559 (Step 1.3) — referenced for false-positive guidance
- PII patterns: lines 803-868 (Step 2.2), 8 categories with markdown tables
- PII allowlist: lines 870-925 (Step 2.3) — stays in phase file, NOT extracted
- PII severity: lines 927-943 (Step 2.4) — referenced for false-positive guidance
- STATE block: lines 22-40 (State Tracking section)
- Terminal STATE: lines 3434-3454 (Step 9.7) — includes `readiness_rating`
- Phase 8 post-flatten references: lines 3091-3099

**PRD references:** FR-1, FR-2, FR-3, AC-1.1.1 through AC-1.1.5, DD-2.

## Acceptance Criteria

### AC1: `patterns/secrets.md` contains the complete 11-category secret regex library

- **Given** the v1 SKILL.md Step 1.2 (lines 431-525) defines 11 secret pattern categories
- **When** Ralph creates `skills/oss-prep/patterns/secrets.md`
- **Then** the file contains all 11 categories extracted verbatim, each with markdown tables preserving the Pattern/Regex/Notes columns:
  1. **AWS Credentials** (3 patterns): `AKIA[0-9A-Z]{16}`, `(?i)aws_secret_access_key\s*[=:]\s*[A-Za-z0-9/+=]{40}`, `(?i)aws_session_token\s*[=:]\s*[A-Za-z0-9/+=]+`
  2. **GCP Credentials** (3 patterns): `"type"\s*:\s*"service_account"`, `AIza[0-9A-Za-z_-]{35}`, `(?i)client_secret.*[0-9a-zA-Z_-]{24,}`
  3. **Azure Credentials** (2 patterns): `(?i)(azure|subscription)[_-]?(key|secret)\s*[=:]\s*[0-9a-f]{32}`, `(?i)(DefaultEndpointsProtocol|AccountKey)\s*=\s*[A-Za-z0-9/+=]+`
  4. **GitHub Tokens** (6 patterns): `ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_` (all `[0-9a-zA-Z]{36}`), and `github_pat_[0-9a-zA-Z_]{82}`
  5. **Generic API Keys and Tokens** (6 patterns): API key, API token, secret key, auth token, private key, password assignment
  6. **Database Connection Strings** (6 patterns): MongoDB, PostgreSQL, MySQL, Redis, MSSQL, JDBC URIs
  7. **Private Keys (PEM Format)** (7 patterns): RSA, DSA, EC, OpenSSH, PKCS#8, encrypted PKCS#8, PGP
  8. **JWT & OAuth** (2 patterns): JWT signing secret, OAuth client secret
  9. **SMTP Credentials** (2 patterns): SMTP URI, SMTP password
  10. **`.env` File Contents** (2 patterns): non-empty env var, quoted env value — with scope note restricting to `.env*` files
  11. **Vendor-Specific Tokens** (6 patterns): Slack, Stripe, Twilio, SendGrid, Heroku, Notion
- **And** the file includes a header block listing consumers: Phase 1 (secrets audit), Phase 8 (post-flatten verification)
- **And** the file includes a "Modification Policy" note stating that changes must be reflected across all consumer phases

### AC2: `patterns/pii.md` contains the complete 8-category PII regex library

- **Given** the v1 SKILL.md Step 2.2 (lines 803-868) defines 8 PII pattern categories
- **When** Ralph creates `skills/oss-prep/patterns/pii.md`
- **Then** the file contains all 8 categories extracted verbatim, each with markdown tables preserving the Pattern/Regex/Notes columns:
  1. **Email Addresses** (2 patterns): general email `[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}`, personal provider email (gmail, yahoo, hotmail, outlook, icloud, protonmail, aol, mail, zoho)
  2. **Phone Numbers** (4 patterns): North American parenthesized `\(\d{3}\)\s?\d{3}[.\-]\d{4}`, dashed `\b\d{3}[.\-]\d{3}[.\-]\d{4}\b`, E.164 `\+1\d{10}\b`, international E.164 `\+\d{1,3}\s?\d{4,14}\b`
  3. **Physical/Mailing Addresses** (2 patterns): US street address (number + street name + suffix), US city/state/zip
  4. **IP Addresses** (1 pattern): IPv4 public-only with negative lookaheads excluding localhost, private ranges, and RFC 5737 documentation ranges — plus the IPv6 note about skipping `::1` and `fe80::`
  5. **Social Security Numbers** (1 pattern): `\b(?!000|666|9\d{2})\d{3}-(?!00)\d{2}-(?!0000)\d{4}\b` with context-awareness note about date false positives
  6. **Credit Card Numbers** (4 patterns): Visa `\b4\d{3}...`, Mastercard `\b5[1-5]\d{2}...`, American Express `\b3[47]\d{2}...`, Discover `\b6(?:011|5\d{2})...` — with Luhn validation note
  7. **Internal Employee Identifiers** (4 patterns): TODO/FIXME with name, Jira ticket `[A-Z][A-Z0-9]+-\d+`, Slack channel `#[a-z][a-z0-9\-_]+`, employee/badge ID assignment — with context-awareness for Jira
  8. **Hardcoded Personal Names** (3 patterns): names in TODO/FIXME, names in file headers (`@author`, `written by`, etc.), names in test data — with false-positive note
- **And** the file includes a header block listing consumers: Phase 2 (PII audit), Phase 8 (post-flatten verification)
- **And** each category includes any associated context-awareness, false-positive, or scope notes from the v1 source (e.g., the IPv6 note under IP Addresses, the Luhn note under Credit Cards, the Jira context note under Employee Identifiers)
- **And** the file includes a "Modification Policy" note stating that changes must be reflected across all consumer phases
- **And** the PII Allowlist (Step 2.3, lines 870-925) is NOT included in this file — it remains PII-audit-specific and will stay in the Phase 2 file (per PRD AC-2.3.3)

### AC3: `state-schema.json` defines the persistent state structure

- **Given** the v1 STATE block (lines 22-40) and terminal STATE (lines 3434-3454) and PRD DD-2 (aggregate counts per phase, not full findings)
- **When** Ralph creates `skills/oss-prep/state-schema.json`
- **Then** the file is valid JSON and defines the following fields with types and defaults:
  - `schema_version` (integer, default: `1`) — for future schema evolution
  - `phase` (integer, range 0-9, default: `0`) — current/next phase to execute
  - `project_root` (string, default: `""`) — absolute path to the git repository root
  - `prep_branch` (string, default: `"oss-prep/ready"`) — the branch name for preparation work
  - `project_profile` (object) with sub-fields:
    - `language` (string, default: `""`)
    - `framework` (string, default: `""`)
    - `package_manager` (string, default: `""`)
    - `build_system` (string, default: `""`)
    - `test_framework` (string, default: `""`)
  - `findings` (object) — cumulative totals across all phases:
    - `total` (integer, default: `0`)
    - `critical` (integer, default: `0`)
    - `high` (integer, default: `0`)
    - `medium` (integer, default: `0`)
    - `low` (integer, default: `0`)
  - `phases_completed` (array of integers, default: `[]`)
  - `history_flattened` (boolean, default: `false`)
  - `phase_findings` (object, keyed by phase number as string) — per-phase aggregate counts:
    - Each value is an object with: `total`, `critical`, `high`, `medium`, `low` (all integers), and `status` (string enum: `"completed"`, `"skipped"`, `"failed"`)
    - Default: `{}` (empty object, populated as phases complete)
  - `license_choice` (string, default: `""`) — set during Phase 3 license preamble, consumed by Phase 5
  - `readiness_rating` (string, default: `""`) — set in Phase 9 to `"Ready"`, `"Ready with Caveats"`, or `"Not Ready"`
  - `started_at` (string, ISO 8601 timestamp, default: `""`) — when the preparation began
  - `phase_failures` (object, default: `{}`) — keyed by phase number, records sub-agent failure events per PRD FR-15
- **And** the schema is structured as a JSON object with a top-level `"$schema"` description comment field, `"type": "object"`, `"properties"` defining each field with its type, default, and description, and a `"required"` array listing all top-level fields

### AC4: Pattern files include severity guidance for consumers

- **Given** that phase sub-agents need to classify findings after pattern matching
- **When** Ralph creates both pattern files
- **Then** `patterns/secrets.md` includes a "Severity Guidance" section summarizing the entropy-based classification rules from Step 1.3 (lines 526-559): entropy calculation formula, threshold bands (H > 3.5 high, 2.0-3.5 moderate, H <= 2.0 low), the four severity levels (CRITICAL/HIGH/MEDIUM/LOW) with their criteria, and special cases (encrypted private keys, git-history-only findings, `.env.example` files, lock files to skip)
- **And** `patterns/pii.md` includes a "Severity Guidance" section summarizing the classification rules from Step 2.4 (lines 927-943): the four severity levels with criteria, and special cases (git-history-only, test/example file downgrade, comments vs. code downgrade, license file skip)

### AC5: All three files pass structural validation

- **Given** the three newly created files
- **When** validation checks are run
- **Then**:
  - `patterns/secrets.md` contains exactly 11 `####` category headings, each followed by a markdown table with `| Pattern | Regex | Notes |` headers
  - `patterns/pii.md` contains exactly 8 `####` category headings, each followed by a markdown table with `| Pattern | Regex | Notes |` headers
  - `state-schema.json` is valid JSON that can be parsed by `python3 -m json.tool` without errors
  - `state-schema.json` contains all required top-level fields: `schema_version`, `phase`, `project_root`, `prep_branch`, `project_profile`, `findings`, `phases_completed`, `history_flattened`, `phase_findings`, `license_choice`, `readiness_rating`, `started_at`, `phase_failures`
  - No content was fabricated — every regex pattern in the pattern files traces back to the v1 SKILL.md source sections identified in this spec

## Test Definition

### Unit Tests

These validation checks should be performed after file creation:

1. **Secret pattern count**: Count lines matching `^\| .+ \| `.+` \|` (table data rows) in `patterns/secrets.md`. Expected: 45 patterns total (3 AWS + 3 GCP + 2 Azure + 6 GitHub + 6 Generic + 6 Database + 7 PEM + 2 JWT/OAuth + 2 SMTP + 2 .env + 6 Vendor).

2. **Secret category count**: Count lines matching `^#### ` in `patterns/secrets.md`. Expected: 11 category headings.

3. **PII pattern count**: Count lines matching `^\| .+ \| `.+` \|` (table data rows) in `patterns/pii.md`. Expected: 21 patterns total (2 Email + 4 Phone + 2 Address + 1 IP + 1 SSN + 4 Credit Card + 4 Employee ID + 3 Names).

4. **PII category count**: Count lines matching `^#### ` in `patterns/pii.md`. Expected: 8 category headings.

5. **State schema JSON validity**: `python3 -m json.tool skills/oss-prep/state-schema.json` exits with code 0.

6. **State schema required fields**: Parse `state-schema.json` and verify the `properties` object contains keys: `schema_version`, `phase`, `project_root`, `prep_branch`, `project_profile`, `findings`, `phases_completed`, `history_flattened`, `phase_findings`, `license_choice`, `readiness_rating`, `started_at`, `phase_failures`.

7. **State schema version default**: Verify `properties.schema_version.default` equals `1`.

8. **Consumer headers present**: Verify `patterns/secrets.md` contains the string "Phase 1" and "Phase 8" in a header/consumers section. Verify `patterns/pii.md` contains the string "Phase 2" and "Phase 8".

9. **PII allowlist NOT present**: Verify `patterns/pii.md` does NOT contain `example@example.com` or `4242424242424242` or "Allowlist" as a heading — confirming the allowlist was correctly left out (it stays in the Phase 2 file).

10. **Severity guidance present**: Verify `patterns/secrets.md` contains "Severity Guidance" or "Severity Classification" as a heading. Verify `patterns/pii.md` contains the same.

## Files to Create/Modify

- `skills/oss-prep/patterns/secrets.md` — 11-category secret detection regex library extracted from SKILL.md Step 1.2 (lines 431-525), with consumer header, severity guidance from Step 1.3, and modification policy (create)
- `skills/oss-prep/patterns/pii.md` — 8-category PII detection regex library extracted from SKILL.md Step 2.2 (lines 803-868), with consumer header, severity guidance from Step 2.4, and modification policy (create)
- `skills/oss-prep/state-schema.json` — Persistent state schema for `.oss-prep/state.json` with JSON Schema structure defining all fields, types, defaults, and descriptions (create)
