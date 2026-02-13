---
id: "2.10"
epic: 2
title: "Extract Phase 9: Final Readiness Report"
status: done
source_prd: "tasks/prd-oss-prep-v2.md"
priority: critical
estimation: medium
depends_on: ["1.1"]
---

# Story 2.10 — Extract Phase 9: Final Readiness Report

## User Story
As a developer preparing a repo for open-source release, I want the final readiness report phase extracted into a self-contained phase file so that the comprehensive report aggregating all phase results can be generated in a dedicated sub-agent context with access to the full cumulative state.

## Technical Context
Phase 9 content lives in SKILL.md between the `<!-- PHASE_9_START -->` and `<!-- PHASE_9_END -->` markers (approximately lines 3221-3484). It covers Steps 9.1 through 9.7: report file generation, risk matrix table, summary with readiness rating, per-phase detail sections, launch checklist, final user-facing presentation, and terminal state update.

The extracted file must be self-contained per the CLAUDE.md extraction rules: header block, declared I/O, execution steps, finding format, and user gate.

Phase 9 is unique among phases in several ways:
1. It performs NO new scanning or code changes -- it is purely a synthesis/aggregation phase.
2. It READS the most state of any phase: the full cumulative state with all per-phase finding counts, completed phases, history flattened flag, and all prior phase summaries.
3. It WRITES a file to disk (the report markdown file) using the Write tool.
4. It is the TERMINAL phase -- no further phases follow.
5. Its readiness rating logic determines the final verdict of the entire skill.

**State dependency**: Phase 9 depends heavily on the state structure defined in Story 1.1 (state-schema.json). The sub-agent must receive the full state including per-phase finding counts (`phase_findings`), `phases_completed` array, `history_flattened` flag, `project_profile`, and cumulative `findings` totals. The orchestrator passes all of this as part of the standard sub-agent dispatch.

**Sub-agent interaction constraint**: Phase 9's final presentation varies by readiness rating (Ready / Ready with Caveats / Not Ready). Since the sub-agent generates the report file and computes the rating, it returns the rating and key summary to the orchestrator, which then presents the appropriate final message to the user. The phase file documents all three presentation variants.

### Key content to extract:
- Step 9.1: Report file generation (filename convention, header with project metadata)
- Step 9.2: Risk matrix table (columns: Phase, Category, Severity, Finding, Status; status definitions: Resolved/Accepted/Outstanding; sorting rules)
- Step 9.3: Summary with readiness rating (three-tier rating logic: Ready / Ready with Caveats / Not Ready)
- Step 9.4: Per-phase detail sections (template for phases 0-8 with scope, findings, actions, outstanding items)
- Step 9.5: Launch checklist (7 post-report manual steps)
- Step 9.6: Final user-facing presentation (three variants by rating)
- Step 9.7: Terminal state update

### Content to preserve verbatim:
- Report filename convention: `oss-prep-report-{YYYY-MM-DD}.md`
- Report header template (repo name, date, project root, prep branch, language, framework)
- Risk matrix column definitions and status definitions (Resolved, Accepted, Outstanding)
- Risk matrix sorting rules (by severity then phase number)
- Readiness rating logic table (3 tiers with exact criteria)
- Summary format template (readiness rating, total/severity/status count tables)
- Per-phase detail section template (scope, findings, actions, outstanding)
- Phase name list (Phase 0: Reconnaissance through Phase 8: History Flatten)
- Launch checklist (7 items)
- All three final presentation variants (Ready, Ready with Caveats, Not Ready)
- Phase summary template with readiness rating and finding totals

## Acceptance Criteria

### AC1: Phase file structure follows extraction rules
- **Given** the CLAUDE.md extraction rules requiring header block, I/O declarations, steps, finding format, and user gate
- **When** Phase 9 is extracted to `phases/09-final-report.md`
- **Then** the file starts with a header block containing: phase number (9), phase name (Final Readiness Report), inputs list, and outputs list

### AC2: Inputs and outputs are explicitly declared
- **Given** Phase 9 reads the full cumulative state from all prior phases
- **When** the I/O declarations are written
- **Then** inputs include: `state.project_root`, `state.prep_branch`, `state.project_profile` (language, framework), `state.phases_completed` (array of completed phase numbers), `state.phase_findings` (per-phase finding counts with severity breakdowns), `state.findings` (cumulative totals), `state.history_flattened` (boolean), and per-phase summaries from orchestrator context
- **And** outputs include: report file (`{project_root}/oss-prep-report-{YYYY-MM-DD}.md`), `state.readiness_rating` (Ready / Ready with Caveats / Not Ready), terminal state update with `phases_completed: [0,1,2,3,4,5,6,7,8,9]`

### AC3: Report file naming convention is preserved
- **Given** the v1 report uses a date-based filename
- **When** the report generation step is extracted
- **Then** the filename convention is preserved: `oss-prep-report-{YYYY-MM-DD}.md`
- **And** the report is written to `{project_root}/` using the Write tool
- **And** the report header template is preserved with: repo name, generated date, project root, preparation branch, primary language, framework

### AC4: Risk matrix table structure is preserved
- **Given** the risk matrix is the centerpiece of the report
- **When** the risk matrix step is extracted
- **Then** the column definitions are preserved: Phase, Category, Severity, Finding, Status
- **And** the 9 category options are preserved: secrets, PII, license, dependency, code-quality, documentation, ci-cd, naming, history
- **And** the 4 severity levels are preserved: critical, high, medium, low
- **And** the 3 status definitions are preserved verbatim: Resolved, Accepted, Outstanding
- **And** the sorting rule is preserved: by severity (critical first) then by phase number
- **And** the zero-findings variant is preserved ("No findings were recorded across any phase. The repository scan was clean.")

### AC5: Readiness rating logic is preserved verbatim
- **Given** the readiness rating determines the final verdict
- **When** the rating logic is extracted
- **Then** all three tiers are preserved with their exact criteria:
  - **Ready**: Zero outstanding critical or high findings. Zero outstanding findings of any severity, or only accepted low-severity items remain.
  - **Ready with Caveats**: Zero outstanding critical findings, but some high or medium findings remain outstanding or accepted.
  - **Not Ready**: Any outstanding critical findings, OR history was not flattened AND secrets or PII were found in git history during Phases 1-2.
- **And** the summary format template is preserved with the readiness rating, findings counts table, and status counts table

### AC6: Per-phase detail sections cover all 9 phases
- **Given** the report includes a section for each phase
- **When** the per-phase template is extracted
- **Then** the template includes: scope, findings count with severity, actions taken, outstanding items, and skipped-phase handling
- **And** all 9 phase names are listed: Phase 0 (Reconnaissance), Phase 1 (Secrets & Credentials Audit), Phase 2 (PII Audit), Phase 3 (Dependency Audit), Phase 4 (Code Architecture & Quality Review), Phase 5 (Documentation Generation), Phase 6 (GitHub Repository Setup & CI/CD), Phase 7 (Naming, Trademark & Identity Review), Phase 8 (History Flatten)

### AC7: Launch checklist is preserved
- **Given** the report ends with a manual launch checklist
- **When** the checklist is extracted
- **Then** all 7 items are preserved: create GitHub repo, push preparation branch, set visibility to public, verify CI/CD, add collaborators, create initial release/tag, announce the project
- **And** items are presented as unchecked markdown checkboxes
- **And** a note states these are manual post-report steps the skill does not execute

### AC8: All three final presentation variants are preserved
- **Given** the final user-facing message varies by readiness rating
- **When** the presentation step is extracted
- **Then** the "Ready" variant is preserved (repository ready, all findings resolved, report path)
- **And** the "Ready with Caveats" variant is preserved (ready with caveats listed, review recommended, report path)
- **And** the "Not Ready" variant is preserved (warning, critical issues listed, re-run recommendation, report path)

### AC9: Terminal state is documented
- **Given** Phase 9 is the final phase with no further phases following
- **When** the state update step is extracted
- **Then** the terminal state structure is documented: phase 9, phases_completed [0-9], readiness_rating field, and the note "This is the terminal state of the skill. Phase 9 is the final phase -- there is no Phase 10."

### AC10: User gate and self-containment
- **Given** Phase 9 is the terminal phase
- **When** the phase is extracted
- **Then** the phase summary template is included with: readiness rating, report file path, total findings across all phases, resolved/accepted/outstanding counts, key highlights (up to 5)
- **And** the terminal announcement is preserved: "Phase 9 (Final Readiness Report) complete. The OSS Prep process is finished."
- **And** the note "No further phases or user approval gates follow" is preserved
- **And** the file is fully self-contained: a sub-agent can generate the complete report with only this phase file, the cumulative state, and the project root

## Test Definition

### Structural Tests
- File exists at `phases/09-final-report.md`
- File begins with a header block containing: Phase number (9), Phase name (Final Readiness Report), Inputs section, Outputs section
- File contains all step numbers: 9.1 through 9.6 (9.7 state update documented as expected terminal state change)
- File contains the report filename convention `oss-prep-report-{YYYY-MM-DD}.md`
- File contains the risk matrix table column definitions
- File contains the readiness rating logic table with all three tiers
- File contains the per-phase detail section template
- File contains the launch checklist with all 7 items
- File contains all three final presentation variants (Ready, Ready with Caveats, Not Ready)
- File contains the phase summary template
- File does NOT contain content from other phases (no scanning patterns, no generation templates)

### Content Verification Tests
- Risk matrix status definitions include exactly: Resolved, Accepted, Outstanding
- Readiness rating "Not Ready" criteria includes the condition about unflattened history with secrets/PII
- Per-phase detail template references all 9 phase names in the correct order
- Launch checklist has exactly 7 checkbox items
- Inputs declaration references: phase_findings, phases_completed, history_flattened, findings (cumulative), project_profile, project_root, prep_branch
- Outputs declaration references: report file path and readiness_rating
- Terminal state includes phases_completed array with all 10 phases [0-9]

## Files to Create/Modify
- `phases/09-final-report.md` -- extracted Phase 9 content (create)
