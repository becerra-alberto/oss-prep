---
id: "2.3"
epic: 2
title: "Extract Phase 2: PII Audit to phases/02-pii.md"
status: done
source_prd: "tasks/prd-oss-prep-v2.md"
priority: critical
estimation: large
depends_on: ["1.1"]
---

# Story 2.3 — Extract Phase 2: PII Audit to phases/02-pii.md

## User Story

As a developer preparing a repo for open-source release, I want the PII audit phase extracted into a self-contained file that references the shared PII pattern library so that PII detection patterns are consistent across phases and a sub-agent can execute the full audit without loading the monolith.

## Technical Context

Phase 2 content lives between the `<!-- PHASE_2_START -->` and `<!-- PHASE_2_END -->` markers in SKILL.md (approximately lines 730-1123). It is structurally similar to Phase 1 but uses three sub-agents instead of two (adding a git author/committer email audit). It contains 9 steps:

- **Step 2.1 -- Dispatch Parallel Sub-Agents**: Instructions for launching three sub-agents:
  - Sub-agent A (Working Tree PII Scan): Grep-based scan with PII pattern library, allowlist filtering, severity classification. Includes file skip list (binary extensions) and lock file skip list.
  - Sub-agent B (Git History PII Scan): `git log -p --all --diff-filter=D` and `git log -p --all -S "PATTERN"` for high-priority PII patterns (personal emails, SSNs, credit cards, phones).
  - Sub-agent C (Git Author/Committer Email Audit): `git log --format='%ae%n%ce' --all | sort -u`, checks for GitHub noreply addresses, categorizes personal provider emails vs corporate/internal emails, recommends noreply switch.
- **Step 2.2 -- PII Pattern Library**: The 8-category regex library (Email, Phone, Physical Address, IP Address, SSN, Credit Card, Internal Employee IDs, Hardcoded Personal Names). This is the content that was extracted to `patterns/pii.md` in Story 1.1.
- **Step 2.3 -- PII Allowlist**: Allowlisted values for emails (example.com, test.com, noreply addresses), IPs (localhost, private ranges, RFC 5737), SSNs (000-00-0000, 123-45-6789), credit cards (Stripe test numbers, generic test Visa), names (John Doe, Alice/Bob/Charlie, Foo Bar). Plus 4 allowlisting rules. This allowlist is PII-audit-specific and must remain INLINE in the phase file (per AC-2.3.3 from the PRD).
- **Step 2.4 -- Severity Classification**: 4-level classification (CRITICAL for identity-theft-enabling combos; HIGH for personal emails, phones, addresses, IPs, employee IDs; MEDIUM for corporate emails, TODO usernames, Jira refs, Slack refs, author metadata; LOW for fictional-seeming names, non-prod IPs, changelog Jira refs, fake phones, failed-Luhn cards). Special cases for history-only, test/example files (one-level downgrade), comments vs code, and license file exemptions.
- **Step 2.5 -- Finding Report Format**: The `P2-{N}` template with PII-specific redaction rules (email: domain only, phone: mask middle, SSN: mask first 5, credit card: last 4 only, address: city/state only, IP: show full, names: show full, employee IDs: last 2 chars).
- **Step 2.6 -- Remediation Proposals**: 8 remediation types (personal emails in source, git author emails, phone numbers, physical addresses, public IPs, SSNs/credit cards, internal employee identifiers, hardcoded personal names, git history-only).
- **Step 2.7 -- Consolidate and Present Findings**: Merge from 3 sub-agents, deduplication, allowlist secondary filter, severity sorting, sequential numbering (P2-1 through P2-N), phase summary format (with PII category breakdown), user approval gate with 5 options.
- **Step 2.8 -- Apply Remediations (If Approved)**: Per-finding approval workflow, git config changes for author emails, re-scan verification.
- **Step 2.9 -- Update STATE**: State block update template with cumulative findings from Phases 1+2.

**Critical extraction change**: Step 2.2 (the PII pattern library) must be replaced with a reference to `patterns/pii.md`. The extracted phase file must say "Read `patterns/pii.md` for the complete pattern library" instead of inlining the 8 regex tables. The PII allowlist (Step 2.3) stays inline because it is PII-audit-specific (per PRD AC-2.3.3).

## Acceptance Criteria

### AC1: Phase file structure

- **Given** the current SKILL.md with Phase 2 content between `<!-- PHASE_2_START -->` and `<!-- PHASE_2_END -->`
- **When** the phase is extracted to `phases/02-pii.md`
- **Then** the file starts with a header block containing:
  - Phase: 2
  - Name: PII Audit
  - Inputs: project_root, project_profile, state (from Phase 0-1)
  - Outputs: findings list with counts by severity, remediated files (if any), state update with cumulative finding counts

### AC2: Self-contained execution steps

- **Given** a sub-agent that reads `phases/02-pii.md` and `patterns/pii.md`
- **When** it executes the phase
- **Then** it can perform all steps without referencing any other file, including:
  - Three parallel sub-agent dispatch (working tree PII scan + git history PII scan + git author email audit)
  - PII allowlist filtering (inline in the phase file)
  - Severity classification with PII-specific rules
  - PII-specific value redaction rules
  - Remediation proposals for all 8 PII types
  - Finding consolidation from 3 sub-agents with deduplication

### AC3: Shared pattern reference replaces inline patterns

- **Given** the extracted phase file
- **When** the location where Step 2.2 was in the monolith is examined
- **Then** it contains a directive: "Read `patterns/pii.md` for the complete 8-category PII detection pattern library"
- **And** the sub-agent dispatch instructions (Step 2.1) reference `patterns/pii.md` instead of saying "copy the patterns section below"
- **And** no inline regex tables from the original Step 2.2 appear in the phase file (no email regex, no phone regex, no SSN regex, etc.)

### AC4: PII allowlist preserved inline

- **Given** the extracted phase file
- **When** Step 2.3 is reviewed
- **Then** the full PII allowlist is present inline (NOT extracted to a patterns file), including:
  - Allowlisted email addresses (example.com, test.com, noreply addresses, dependabot)
  - Allowlisted IP addresses (localhost, private ranges, RFC 5737 documentation ranges)
  - Allowlisted SSNs (000-00-0000, 123-45-6789 with context note)
  - Allowlisted credit card numbers (all 6 Stripe test numbers, generic test Visa, context-based allowlisting)
  - Allowlisted names (John/Jane Doe, Alice/Bob/Charlie/Dave/Eve/Mallory, Foo Bar, Test User, license file names)
  - All 4 allowlisting rules (case-insensitive for emails/names, exact match for IPs/SSNs/cards, complete exclusion, unexpected-context exception)

### AC5: Git author email audit preserved

- **Given** the extracted phase file
- **When** Sub-agent C instructions are reviewed
- **Then** the full author/committer email audit is present:
  - `git log --format='%ae%n%ce' --all | sort -u` command
  - GitHub noreply address skip rule
  - Generic/bot address skip rule (noreply@, bot@, github-actions@, dependabot@)
  - Personal provider email categorization (gmail.com, yahoo.com, hotmail.com, outlook.com, icloud.com, protonmail.com, aol.com, mail.com, zoho.com)
  - Corporate/internal email categorization
  - Noreply configuration command: `git config user.email "username@users.noreply.github.com"`
  - Phase 8 flatten reference and `git filter-repo --mailmap` alternative

### AC6: PII-specific redaction rules preserved

- **Given** the extracted phase file
- **When** Step 2.5 is reviewed
- **Then** all 8 PII-specific redaction rules are present:
  - Email: domain only (`****@gmail.com`)
  - Phone: mask middle (`(555) ***-4567`)
  - SSN: mask first 5 (`***-**-6789`)
  - Credit card: last 4 only (`****-****-****-4242`)
  - Address: city/state only
  - IP: show full
  - Names: show full
  - Employee IDs: last 2 chars only

### AC7: User gate documented

- **Given** the extracted phase file
- **When** the user gate section is reviewed
- **Then** it contains the Phase 2-specific approval prompt with 5 options:
  - Approve and continue (to Phase 3)
  - Review details
  - Apply remediations
  - Request changes
  - Skip
- **And** the phase summary includes the PII category breakdown (emails, phones, addresses, IPs, SSNs, credit cards, internal identifiers, hardcoded names)

### AC8: I/O declaration

- **Given** the extracted phase file
- **When** checked against extraction rules
- **Then** it declares:
  - **Inputs**: project_root, project_profile, state (from Phases 0-1), patterns/pii.md
  - **Outputs**: findings list (P2-1 through P2-N), finding counts by severity, remediated files (if Apply remediations chosen), git config changes (if author email remediation approved), state update (phase: 3, cumulative findings from Phases 1+2, phases_completed adds 2)

### AC9: Validation

- **Given** the completed phase file
- **When** checked against all 5 extraction rules from CLAUDE.md
- **Then** it satisfies each rule:
  1. Self-contained: all steps, allowlist, classification rules, redaction rules, remediation types, and presentation formats are inline
  2. Declares I/O: Inputs and Outputs sections present in header
  3. References shared patterns: `patterns/pii.md` referenced instead of inline regexes
  4. Includes user gate: 5-option approval prompt documented with PII category breakdown
  5. Starts with header block: phase number, name, inputs, outputs

## Test Definition

### Structural Tests

- File exists at `phases/02-pii.md`
- Contains required sections: header block (with Phase, Name, Inputs, Outputs), Steps (2.1 through 2.9), Finding Format, User Gate
- Header block declares Phase: 2, Name: PII Audit
- Contains reference to `patterns/pii.md` (exact string)
- Does NOT contain inline PII regex tables (no email regex `[a-zA-Z0-9._%+\-]+@`, no SSN regex `\b(?!000`, no credit card regex `\b4\d{3}`, etc.)
- DOES contain the full PII allowlist inline (allowlisted emails, IPs, SSNs, credit cards, names)
- Contains instructions for all three sub-agents (A, B, C)
- Contains `git log --format='%ae%n%ce' --all | sort -u` command
- Contains all 8 PII-specific redaction rules
- Contains all 4 severity level definitions with PII-specific criteria
- Contains all remediation types (personal emails, git author emails, phones, addresses, IPs, SSNs/cards, internal IDs, names, history-only)
- Contains the `P2-{N}` finding format template
- Contains the phase summary format with PII category breakdown

### Content Tests

- Sub-agent A instructions include file skip list AND lock file skip list
- Sub-agent B instructions include `git log -p --all --diff-filter=D` and `git log -p --all -S "PATTERN"`
- Sub-agent C instructions include personal provider email domain list (9 domains)
- Severity special cases present: history-only note, test/example one-level downgrade, comments vs code downgrade, license file exemption
- Allowlisting rules: case-insensitive for emails/names, exact match for IPs/SSNs/cards, complete exclusion, unexpected-context exception
- Deduplication logic for working tree vs history overlap

## Files to Create/Modify

- `phases/02-pii.md` -- extracted Phase 2 content with PII pattern reference, inline allowlist (create)
