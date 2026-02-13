---
id: "2.2"
epic: 2
title: "Extract Phase 1: Secrets Audit to phases/01-secrets.md"
status: done
source_prd: "tasks/prd-oss-prep-v2.md"
priority: critical
estimation: large
depends_on: ["1.1"]
---

# Story 2.2 — Extract Phase 1: Secrets Audit to phases/01-secrets.md

## User Story

As a developer preparing a repo for open-source release, I want the secrets audit phase extracted into a self-contained file that references the shared pattern library so that secret detection patterns are consistent across phases and a sub-agent can execute the full audit without loading the monolith.

## Technical Context

Phase 1 content lives between the `<!-- PHASE_1_START -->` and `<!-- PHASE_1_END -->` markers in SKILL.md (approximately lines 381-728). It is one of the largest phases, containing 9 steps:

- **Step 1.1 -- Dispatch Parallel Sub-Agents**: Instructions for launching two sub-agents (Working Tree Scan + Git History Scan) with specific instructions for each, including file skip lists and scan commands (`git log -p --all --diff-filter=D`, `git log -p --all -S "PATTERN"`).
- **Step 1.2 -- Secret Pattern Library**: The 11-category regex library (AWS, GCP, Azure, GitHub tokens, Generic API keys, Database URIs, PEM keys, JWT/OAuth, SMTP, .env, Vendor-specific). This is the content that was extracted to `patterns/secrets.md` in Story 1.1.
- **Step 1.3 -- Severity Classification**: Shannon entropy calculation formula, entropy thresholds (H > 3.5 high, 2.0-3.5 moderate, <= 2.0 low), 4-level classification rules (CRITICAL/HIGH/MEDIUM/LOW) with detailed criteria, and special cases (encrypted keys, history-only, .env.example, lock files).
- **Step 1.4 -- Finding Report Format**: The `S1-{N}` finding template with severity, category, location, matched pattern, matched value (with partial redaction rules), entropy, context, and remediation fields.
- **Step 1.5 -- Remediation Proposals**: 5 remediation types (hardcoded credential in source, .env with real credentials, private key files, git history-only, config files with embedded secrets) with language-specific environment variable patterns for 8 languages.
- **Step 1.6 -- Opportunistic Tool Detection**: Check for trufflehog and gitleaks, run supplementary scans if available, merge results.
- **Step 1.7 -- Consolidate and Present Findings**: Deduplication rules, severity sorting, sequential numbering (S1-1 through S1-N), phase summary format, and the user approval gate with 5 options (Approve/Review details/Apply remediations/Request changes/Skip).
- **Step 1.8 -- Apply Remediations (If Approved)**: Per-finding approval workflow, Edit tool usage, re-scan verification.
- **Step 1.9 -- Update STATE**: State block update template with cumulative findings.

**Critical extraction change**: Step 1.2 (the pattern library) must be replaced with a reference to `patterns/secrets.md`. The extracted phase file must say "Read `patterns/secrets.md` for the complete pattern library" instead of inlining the 11 regex tables. All other steps (1.1, 1.3-1.9) are extracted verbatim.

The sub-agent instructions in Step 1.1 currently say "copy the patterns section below into the sub-agent prompt" -- this must be updated to say "read `patterns/secrets.md` and include its contents in the sub-agent prompt."

## Acceptance Criteria

### AC1: Phase file structure

- **Given** the current SKILL.md with Phase 1 content between `<!-- PHASE_1_START -->` and `<!-- PHASE_1_END -->`
- **When** the phase is extracted to `phases/01-secrets.md`
- **Then** the file starts with a header block containing:
  - Phase: 1
  - Name: Secrets & Credentials Audit
  - Inputs: project_root, project_profile, state (from Phase 0)
  - Outputs: findings list with counts by severity, remediated files (if any), state update with cumulative finding counts

### AC2: Self-contained execution steps

- **Given** a sub-agent that reads `phases/01-secrets.md` and `patterns/secrets.md`
- **When** it executes the phase
- **Then** it can perform all steps without referencing any other file, including:
  - Parallel sub-agent dispatch (working tree + git history) with complete instructions for each
  - Severity classification with entropy calculation
  - Finding report formatting with redaction rules
  - Remediation proposals with language-specific patterns
  - Opportunistic tool detection (trufflehog, gitleaks)
  - Finding consolidation, deduplication, and presentation

### AC3: Shared pattern reference replaces inline patterns

- **Given** the extracted phase file
- **When** the location where Step 1.2 was in the monolith is examined
- **Then** it contains a directive: "Read `patterns/secrets.md` for the complete 11-category secret detection pattern library"
- **And** the sub-agent dispatch instructions (Step 1.1) reference `patterns/secrets.md` instead of saying "copy the patterns section below"
- **And** no inline regex tables from the original Step 1.2 appear in the phase file

### AC4: Parallel sub-agent instructions preserved

- **Given** the extracted phase file
- **When** Step 1.1 is reviewed
- **Then** it contains complete instructions for both sub-agents:
  - Sub-agent A (Working Tree Scan): per-pattern Grep instructions, file skip list (binary extensions), .env-specific scanning scope, recording format (file path + line number)
  - Sub-agent B (Git History Scan): `git log -p --all --diff-filter=D` command, `git log -p --all -S "PATTERN"` for high-priority patterns, recording format (commit hash + author + date + file path), note about working-tree vs history-only status

### AC5: Severity classification and entropy preserved

- **Given** the extracted phase file
- **When** Step 1.3 is reviewed
- **Then** it contains:
  - Shannon entropy formula: `H = -SUM(p(c) * log2(p(c)))`
  - Three entropy thresholds (>3.5, 2.0-3.5, <=2.0)
  - Four severity levels with full criteria tables
  - All special cases (encrypted keys as MEDIUM, history-only note, .env.example as LOW, lock file skip)

### AC6: Remediation proposals preserved

- **Given** the extracted phase file
- **When** Step 1.5 is reviewed
- **Then** it contains all 5 remediation types and environment variable patterns for all 8 languages (JavaScript, Python, Ruby, Go, Rust, Java, PHP, Shell)

### AC7: User gate documented

- **Given** the extracted phase file
- **When** the user gate section is reviewed
- **Then** it contains the Phase 1-specific approval prompt with 5 options:
  - Approve and continue (to Phase 2)
  - Review details (show all findings)
  - Apply remediations (per-finding approval workflow)
  - Request changes (re-scan or adjust)
  - Skip
- **And** a note that the orchestrator presents this gate after the sub-agent returns (per DD-4)

### AC8: I/O declaration

- **Given** the extracted phase file
- **When** checked against extraction rules
- **Then** it declares:
  - **Inputs**: project_root, project_profile (from state), patterns/secrets.md
  - **Outputs**: findings list (S1-1 through S1-N), finding counts by severity, remediated files (if Apply remediations chosen), state update (phase: 2, cumulative findings, phases_completed adds 1)

### AC9: Validation

- **Given** the completed phase file
- **When** checked against all 5 extraction rules from CLAUDE.md
- **Then** it satisfies each rule:
  1. Self-contained: all steps, classification rules, remediation types, and presentation formats are inline
  2. Declares I/O: Inputs and Outputs sections present in header
  3. References shared patterns: `patterns/secrets.md` referenced instead of inline regexes
  4. Includes user gate: 5-option approval prompt documented
  5. Starts with header block: phase number, name, inputs, outputs

## Test Definition

### Structural Tests

- File exists at `phases/01-secrets.md`
- Contains required sections: header block (with Phase, Name, Inputs, Outputs), Steps (1.1 through 1.9), Finding Format, User Gate
- Header block declares Phase: 1, Name: Secrets & Credentials Audit
- Contains reference to `patterns/secrets.md` (exact string)
- Does NOT contain inline regex tables (no `AKIA[0-9A-Z]{16}`, no `ghp_[0-9a-zA-Z]{36}`, etc.)
- Contains Shannon entropy formula
- Contains all 4 severity level definitions (CRITICAL, HIGH, MEDIUM, LOW)
- Contains the `S1-{N}` finding format template
- Contains the value redaction rule (first 4 / last 4 characters)
- Contains environment variable patterns for 8 languages
- Contains trufflehog and gitleaks detection commands
- Contains deduplication rules for working tree vs history findings
- Contains the phase summary format template

### Content Tests

- Sub-agent A instructions include the binary file skip list
- Sub-agent B instructions include `git log -p --all --diff-filter=D`
- Sub-agent B instructions include `git log -p --all -S "PATTERN"` for high-priority patterns
- Severity classification special cases are all present (encrypted keys, history-only, .env.example, lock files)
- All 5 remediation types are present
- Step 1.8 (Apply Remediations) workflow is present with per-finding approval

## Files to Create/Modify

- `phases/01-secrets.md` -- extracted Phase 1 content with pattern library reference (create)
