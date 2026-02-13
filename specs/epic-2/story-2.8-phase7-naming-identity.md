---
id: "2.8"
epic: 2
title: "Extract Phase 7: Naming, Trademark & Identity Review"
status: done
source_prd: "tasks/prd-oss-prep-v2.md"
priority: high
estimation: medium
depends_on: ["1.1"]
---

# Story 2.8 — Extract Phase 7: Naming, Trademark & Identity Review

## User Story
As a developer preparing a repo for open-source release, I want the naming, trademark, and identity review phase extracted into a self-contained phase file so that registry name checks, internal identity leak scanning, and telemetry detection execute in a dedicated sub-agent context.

## Technical Context
Phase 7 content lives in SKILL.md between the `<!-- PHASE_7_START -->` and `<!-- PHASE_7_END -->` markers (approximately lines 2612-2938). It covers Steps 7.1 through 7.6: package name availability check (with registry-specific WebSearch queries), internal identity leak scanning (4 categories of patterns), telemetry and analytics detection (known SDKs and custom indicators), remediation categories, findings consolidation, and state update.

The extracted file must be self-contained per the CLAUDE.md extraction rules: header block, declared I/O, execution steps, finding format, and user gate.

Phase 7 is a straightforward extraction with no bug fixes required. It is the final analysis phase before Phase 8's destructive operations.

**No sub-agent parallelization**: The v1 SKILL.md explicitly states that Phase 7 does not use sub-agent parallelization. WebSearch has rate considerations, and Grep-based scanning is fast enough to run sequentially. This should be preserved in the extracted file.

### Key content to extract:
- Step 7.1: Package name availability check
  - 7.1.1: Detect package manifests (6 manifest types across npm, PyPI, crates.io, RubyGems, Go modules)
  - 7.1.2: Check name availability on registries via WebSearch
  - 7.1.3: Classify name availability findings (Taken=MEDIUM, Could not verify=MEDIUM, Available=no finding)
  - 7.1.4: Graceful degradation for WebSearch failures
- Step 7.2: Internal identity leak scanning
  - 7.2.1: Identity leak pattern library (4 categories: internal URLs/CRITICAL, Jira/Confluence/MEDIUM, Slack/Teams/MEDIUM, company/team names/HIGH)
  - 7.2.2: Classify identity leak findings with remediation suggestions
- Step 7.3: Telemetry and analytics detection
  - 7.3.1: Known analytics SDK detection (13 JS/TS SDKs, 6 Python SDKs, plus manifest checks)
  - 7.3.2: Custom telemetry indicator detection (function names, telemetry configs, outbound transmission patterns)
  - 7.3.3: Classify telemetry findings
- Step 7.4: Remediation categories (Rename, Remove, Disclose, Acknowledge) with telemetry disclosure template
- Step 7.5: Findings consolidation and phase summary
- Step 7.6: State update

### Content to preserve verbatim:
- Package manifest detection table (6 manifest types with registry and name field)
- WebSearch query patterns for each registry (npm, PyPI, crates.io, RubyGems, Go)
- Name availability classification table
- All identity leak pattern tables (Categories 1-4 with regex patterns and severities)
- Identity leak remediation table (per category)
- Known analytics SDK tables (JS/TS with 13 entries, Python with 6 entries)
- Custom telemetry indicator regex patterns (3 tables)
- Remediation categories table (Rename, Remove, Disclose, Acknowledge)
- Telemetry disclosure README template
- Phase summary template with findings-by-category table
- Finding numbering convention (N7-1, N7-2, etc.)

## Acceptance Criteria

### AC1: Phase file structure follows extraction rules
- **Given** the CLAUDE.md extraction rules requiring header block, I/O declarations, steps, finding format, and user gate
- **When** Phase 7 is extracted to `phases/07-naming-identity.md`
- **Then** the file starts with a header block containing: phase number (7), phase name (Naming, Trademark & Identity Review), inputs list, and outputs list

### AC2: Inputs and outputs are explicitly declared
- **Given** Phase 7 reads project profile and package manifests from the project root
- **When** the I/O declarations are written
- **Then** inputs include: `state.project_root`, `state.project_profile` (language, framework, package_manager), `state.phases_completed`, `state.findings`, and package manifest paths detected during execution
- **And** outputs include: findings list with registry availability results, identity leak findings, telemetry findings, state updates (phase_findings for phase 7, cumulative findings totals, phases_completed updated)

### AC3: Package name availability check is fully preserved
- **Given** the v1 Phase 7 contains detailed registry checking via WebSearch
- **When** the name availability check steps are extracted
- **Then** the manifest detection table covers all 6 types: package.json, pyproject.toml, setup.py/setup.cfg, Cargo.toml, *.gemspec/Gemfile, go.mod
- **And** WebSearch query patterns are preserved for all 5 registries: npm, PyPI, crates.io, RubyGems, Go modules
- **And** the classification table is preserved (Available/Taken/Could not verify)
- **And** the fallback behavior for no-manifest projects is preserved (check repo dir name against npm, PyPI, crates.io)
- **And** graceful degradation for WebSearch failures is preserved (record as "Could not verify", continue, note in summary)

### AC4: Identity leak scanning covers all four categories
- **Given** the v1 Phase 7 defines 4 categories of identity leak patterns
- **When** the identity leak scanning is extracted
- **Then** Category 1 (Internal URLs) is preserved with all 4 regex patterns at CRITICAL severity
- **And** Category 2 (Jira/Confluence/Project Tracker) is preserved with all 5 regex patterns at MEDIUM severity
- **And** Category 3 (Slack/Internal Communication) is preserved with all 3 regex patterns at MEDIUM severity
- **And** Category 4 (Company/Team Names) is preserved with the dynamic detection method (git remote, package scopes, copyright lines) and all 4 scan targets at HIGH severity
- **And** the file exclusion list is preserved (node_modules, vendor, .git, dist, build, __pycache__, *.pyc, *.min.js, *.min.css)
- **And** the remediation table (per category) is preserved

### AC5: Telemetry detection covers known SDKs and custom indicators
- **Given** the v1 Phase 7 contains comprehensive telemetry detection
- **When** the telemetry detection is extracted
- **Then** the known analytics SDK table for JS/TS is preserved with all 13 entries (Segment, Mixpanel, Amplitude, Google Analytics, Heap, PostHog, Matomo, LaunchDarkly, Datadog RUM, Sentry, Fullstory, LogRocket, Hotjar)
- **And** the known analytics SDK table for Python is preserved with all 6 entries (Segment, Mixpanel, Amplitude, Sentry, PostHog, Datadog)
- **And** the custom telemetry indicator patterns are preserved: function/method name patterns (2 regex), telemetry class/module patterns (1 regex), telemetry config patterns (1 regex), outbound transmission patterns (2 regex)
- **And** the false-positive warning for custom telemetry indicators is preserved
- **And** manifest dependency checking is mentioned (package.json, pyproject.toml, requirements*.txt, Cargo.toml, Gemfile, go.mod)

### AC6: Remediation categories are preserved with telemetry disclosure template
- **Given** Phase 7 defines four remediation categories
- **When** the remediation section is extracted
- **Then** all four categories are preserved: Rename, Remove, Disclose, Acknowledge
- **And** the telemetry disclosure README template is preserved verbatim (with sections for what is collected, where data is sent, and how to opt out)

### AC7: User gate prompt is included
- **Given** extraction rule 4 requires each phase file to include its user gate
- **When** the phase is extracted
- **Then** the file includes the Phase 7 approval gate: "Phase 7 (Naming, Trademark & Identity Review) complete. Choose one: Approve and continue / Review details / Request changes / Skip"
- **And** the gate specifies the next phase: Phase 8 (History Flatten)
- **And** "Review details" is documented to show full findings with file paths, line numbers, and remediation suggestions

### AC8: Finding format and numbering convention is included
- **Given** Phase 7 uses a specific finding numbering convention
- **When** the phase is extracted
- **Then** the finding numbering convention is preserved: N7-1, N7-2, etc.
- **And** the phase summary template is preserved with: package names checked, name availability counts, identity leak scan results, telemetry detection results, findings total with severity breakdown, key highlights (up to 5), findings-by-category table, remediation summary

### AC9: No sub-agent parallelization is documented
- **Given** the v1 explicitly states Phase 7 does not use sub-agent parallelization
- **When** the phase is extracted
- **Then** the file documents that all checks run sequentially (no parallel sub-agents within this phase)
- **And** the rationale is preserved: WebSearch has rate considerations, Grep is fast

### AC10: Self-contained execution
- **Given** a sub-agent receives only this phase file, the current state, and the project root
- **When** the sub-agent reads `phases/07-naming-identity.md`
- **Then** it contains all information needed to execute Phase 7 without referencing SKILL.md or any other phase file
- **And** no shared pattern libraries are referenced (Phase 7 uses its own identity leak and telemetry patterns inline, not patterns/secrets.md or patterns/pii.md)

## Test Definition

### Structural Tests
- File exists at `phases/07-naming-identity.md`
- File begins with a header block containing: Phase number (7), Phase name (Naming, Trademark & Identity Review), Inputs section, Outputs section
- File contains all step numbers: 7.1 through 7.5 (7.6 state update documented as expected state change)
- File contains sub-step numbers: 7.1.1, 7.1.2, 7.1.3, 7.1.4, 7.2.1, 7.2.2, 7.3.1, 7.3.2, 7.3.3
- File contains the manifest detection table with all 6 manifest types
- File contains identity leak pattern tables for all 4 categories
- File contains the known analytics SDK tables (JS/TS and Python)
- File contains custom telemetry indicator regex patterns
- File contains the remediation categories table
- File contains the telemetry disclosure template
- File contains the user gate prompt with all four options
- File contains the finding numbering convention N7-{N}
- File does NOT contain content from other phases

### Content Verification Tests
- WebSearch queries reference all 5 registries: npmjs.com, pypi.org, crates.io, rubygems.org, pkg.go.dev
- Category 1 identity leak patterns include regex for .internal, .corp, .local, .intranet, .private, .staging, .dev subdomains
- Category 2 patterns include Jira, Confluence, and Linear link patterns
- Category 3 patterns include Slack workspace URLs and channel references
- Known JS/TS SDK table has 13 rows
- Known Python SDK table has 6 rows
- Remediation categories include: Rename, Remove, Disclose, Acknowledge
- Phase summary template includes findings-by-category table with 3 categories (Name conflicts, Internal identity leaks, Telemetry/analytics)

## Files to Create/Modify
- `phases/07-naming-identity.md` -- extracted Phase 7 content (create)
