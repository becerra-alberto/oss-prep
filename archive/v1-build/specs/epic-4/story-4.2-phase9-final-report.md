---
id: "4.2"
epic: 4
title: "Phase 9 — Final Readiness Report"
status: pending
source_prd: "tasks/prd-oss-prep.md"
priority: high
estimation: large
depends_on: ["4.1"]
---

# Story 4.2 — Phase 9 — Final Readiness Report

## User Story
As a developer who has completed all audit and preparation phases, I want a comprehensive final readiness report covering every phase so that I have full confidence in the repository's safety for public release and a clear checklist of remaining manual steps to launch.

## Technical Context
This story adds the Phase 9 section to `SKILL.md`. Phase 9 is the culmination of the entire skill -- it synthesizes findings from all prior phases (0-8) into a single, actionable report document. Unlike other phases, Phase 9 does not perform new scanning or make code changes. It aggregates, formats, and presents.

Key implementation considerations:

1. **Report file output**: The report is saved to `oss-prep-report-{YYYY-MM-DD}.md` in the project root. The instructions must tell Claude to use the current date (via `date` command or equivalent) to generate the filename. The file is written to disk using the Write tool, not just displayed in the conversation.

2. **Risk matrix format**: The report's centerpiece is a risk matrix table. Each row represents a finding from any phase, with columns: Phase (0-8), Category (secrets, PII, license, etc.), Severity (critical/high/medium/low), Finding (one-line description), and Status (Resolved, Accepted, Outstanding). "Resolved" means the skill remediated it. "Accepted" means the user acknowledged it but chose not to fix it (e.g., declined a suggestion). "Outstanding" means it remains unaddressed.

3. **Readiness rating logic**: The overall readiness rating is derived from the findings:
   - **Ready**: Zero outstanding critical or high findings, zero outstanding findings of any severity (or only accepted low-severity items)
   - **Ready with Caveats**: Zero outstanding critical findings, but some high or medium findings remain outstanding or accepted
   - **Not Ready**: Any outstanding critical findings, or history not flattened with secrets/PII found in history

4. **Per-phase sections**: Each phase (0-8) gets a section in the report summarizing: what was checked (scope), what was found (findings count and highlights), what was remediated (actions taken), and what remains outstanding. This draws on the cumulative state and findings from each phase.

5. **Launch checklist**: A template checklist of post-report manual steps. This is not auto-executed -- it is a reference for the user. The items come directly from FR-51 in the PRD.

6. **Final user-facing presentation**: After writing the report file, the skill presents a summary in the conversation. If the rating is "Ready", it congratulates the user. If "Ready with Caveats", it congratulates but highlights the caveats. If "Not Ready", it warns the user and strongly recommends resolving outstanding critical issues before publishing.

7. **State block final update**: Phase 9 is added to `phases_completed`, making it `[0,1,2,3,4,5,6,7,8,9]`. The phase field is set to 9 (completed). This is the terminal state of the skill.

## Acceptance Criteria

### AC1: Report File Is Generated with Correct Naming and Location
- **Given** all prior phases (0-8) have been completed or skipped
- **When** Phase 9 executes
- **Then** a markdown report file is written to `{project_root}/oss-prep-report-{YYYY-MM-DD}.md` using the current date, the file is written via the Write tool (not just displayed), and the user is informed of the file path

### AC2: Risk Matrix Table Covers All Findings from All Phases
- **Given** the report is being generated
- **When** the risk matrix section is composed
- **Then** it contains a markdown table with columns Phase, Category, Severity, Finding, and Status, with one row per finding from Phases 0-8, where Status is one of "Resolved" (remediated by the skill), "Accepted" (user acknowledged but did not fix), or "Outstanding" (unaddressed), and the table is sorted by severity (critical first) then by phase number

### AC3: Summary Section Includes Readiness Rating and Finding Counts
- **Given** the risk matrix has been assembled
- **When** the summary section is composed
- **Then** it includes: (a) an overall readiness rating of "Ready", "Ready with Caveats", or "Not Ready" based on the rating logic (Ready = zero outstanding critical/high, Ready with Caveats = zero outstanding critical but some high/medium outstanding or accepted, Not Ready = any outstanding critical or unflattened history with history-based secrets/PII), (b) a count of total findings, (c) a breakdown of findings by severity (critical, high, medium, low), and (d) a breakdown of findings by status (resolved, accepted, outstanding)

### AC4: Per-Phase Sections Cover What Was Checked, Found, Remediated, and Remains
- **Given** the report is being generated
- **When** the per-phase detail sections are composed
- **Then** each phase from 0 through 8 has its own section that includes: (a) a brief description of what was checked in that phase, (b) the number and nature of findings discovered, (c) what remediation actions were taken (files modified, entries added, etc.), and (d) what findings remain outstanding or were accepted without remediation, and phases that were skipped are noted as skipped with the reason

### AC5: Launch Checklist Includes All Required Manual Steps
- **Given** the report is being generated
- **When** the launch checklist section is composed
- **Then** it includes at minimum these items formatted as a checkbox list: Create GitHub repository, Push preparation branch to remote, Set repository visibility to public, Verify CI/CD pipeline runs successfully, Add collaborators or teams, Create initial release or tag, and Announce the project, and the checklist items are presented as unchecked markdown checkboxes (`- [ ]`) for the user to track manually

### AC6: Final Presentation Matches Readiness Rating with Appropriate Tone
- **Given** the report file has been written
- **When** the skill presents the final summary to the user in the conversation
- **Then** the presentation includes: (a) the readiness rating prominently displayed, (b) a congratulatory message if the rating is "Ready" (e.g., "Your repository is ready for public release"), (c) a congratulatory-but-cautionary message if "Ready with Caveats" (highlighting what the caveats are), (d) a warning message if "Not Ready" (listing the outstanding critical issues and strongly recommending they be resolved), (e) the file path to the full report for reference, and (f) the STATE block is updated with phase 9 in `phases_completed` marking the skill as complete

## Test Definition

### Unit Tests
- Read the Phase 9 section of `SKILL.md` and verify it contains instructions for all six components: report file generation, risk matrix table, summary with readiness rating, per-phase sections, launch checklist, and final presentation
- Verify the report filename template uses the `{YYYY-MM-DD}` date pattern
- Verify the risk matrix table format specifies all five columns (Phase, Category, Severity, Finding, Status) and the three status values (Resolved, Accepted, Outstanding)
- Verify the readiness rating logic is defined with clear criteria for all three ratings (Ready, Ready with Caveats, Not Ready)
- Verify the launch checklist contains at least the seven items specified in FR-51
- Verify the final presentation instructions differentiate between all three readiness ratings with distinct messaging
- Verify the STATE block update marks Phase 9 as complete

### Integration/E2E Tests (if applicable)
- Invoke `/oss-prep` on a test repository, advance through all 10 phases (0-9), and verify that a report file is created at the expected path with the current date in the filename
- Verify the report file is valid markdown that renders correctly (headings, tables, checkboxes)
- On a test repo with zero outstanding issues and flattened history, verify the readiness rating is "Ready" and the presentation is congratulatory
- On a test repo where the user declined to fix a high-severity finding, verify the readiness rating is "Ready with Caveats" and the caveat is mentioned
- On a test repo with an outstanding critical finding, verify the readiness rating is "Not Ready" and the warning identifies the critical issue
- Verify the launch checklist in the report contains all seven required items as unchecked checkboxes
- Verify each phase (0-8) has its own section in the report, even if a phase had zero findings (in which case it should note "No issues found")

## Files to Create/Modify
- `skills/oss-prep/SKILL.md` — Add the Phase 9 (Final Readiness Report) section covering: report file generation, risk matrix table, summary with readiness rating, per-phase detail sections, launch checklist, and final user-facing presentation with readiness-appropriate messaging (modify)
