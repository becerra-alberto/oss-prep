---
id: "2.6"
epic: 2
title: "Extract Phase 5: Documentation Generation"
status: done
source_prd: "tasks/prd-oss-prep-v2.md"
priority: high
estimation: large
depends_on: ["1.1"]
---

# Story 2.6 — Extract Phase 5: Documentation Generation

## User Story
As a developer preparing a repo for open-source release, I want the documentation generation phase extracted into a self-contained phase file so that it can execute in its own sub-agent context without loading the full monolith, while correctly reading the license choice already made in Phase 3 instead of re-prompting.

## Technical Context
Phase 5 content lives in SKILL.md between the `<!-- PHASE_5_START -->` and `<!-- PHASE_5_END -->` markers (approximately lines 1753-2169). It covers Steps 5.1 through 5.8: documentation completeness matrix, existing-file preservation rule, license selection/verification, parallel sub-agent dispatch for doc generation (README, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CLAUDE.md sanitization), CHANGELOG generation, user review gate, summary, and state update.

The extracted file must be self-contained per the CLAUDE.md extraction rules: header block, declared I/O, execution steps, finding format, and user gate.

**BUG FIX COMPANION (PRD AC-2.6.2)**: In v1, Phase 5 contains the license selection menu (Step 5.3). In v2, license selection was moved to Phase 3 (Story 2.4) as a preamble to dependency compatibility analysis. The extracted Phase 5 file must READ `state.license_choice` instead of presenting the license selection menu. If `state.license_choice` is set (Phase 3 ran), use it directly. If `state.license_choice` is not set (Phase 3 was skipped), fall back to presenting the license selection menu as a fallback path. This creates two code paths for license handling in Phase 5, but keeps the orchestrator simple (PRD OQ-2).

**Sub-agent interaction constraint (PRD Section 8, "Risk: Sub-Agent Cannot Interact with User")**: Phase 5's license selection fallback requires user interaction. The orchestrator must handle this: if `state.license_choice` is not set, the orchestrator prompts the user for license selection BEFORE dispatching the Phase 5 sub-agent, then passes the chosen license as input. The phase file documents this interaction point but the orchestrator executes it.

### Key content to extract:
- Step 5.1: Documentation completeness matrix (7 files: README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CHANGELOG, CLAUDE.md)
- Step 5.2: Three-tier existing-file preservation rule (Generate / Enhance / Review Only)
- Step 5.3: License verification (modified -- reads state.license_choice, fallback only)
- Step 5.4: Parallel sub-agent dispatch for doc generation (Sub-Agents A-E)
- Step 5.5: CHANGELOG.md generation (sequential, depends on git history)
- Step 5.6: User review gate for all generated/enhanced files
- Step 5.7: Phase summary consolidation
- Step 5.8: State update

### Content to preserve verbatim:
- README.md generation template with all 7 required sections (FR-29)
- CONTRIBUTING.md generation template with all 5 sections
- CODE_OF_CONDUCT.md generation instructions (Contributor Covenant v2.1)
- SECURITY.md generation template with all 3 sections
- CLAUDE.md sanitization rules (preserves/removes/flags categories)
- CHANGELOG.md Keep a Changelog format
- Three-tier file handling table
- Enhancement suggestion format
- File review presentation format
- Phase summary template
- License menu options (MIT, Apache-2.0, GPL-3.0, BSD-2-Clause, BSD-3-Clause, MPL-2.0, ISC, Unlicense)

## Acceptance Criteria

### AC1: Phase file structure follows extraction rules
- **Given** the CLAUDE.md extraction rules requiring header block, I/O declarations, steps, finding format, and user gate
- **When** Phase 5 is extracted to `phases/05-documentation.md`
- **Then** the file starts with a header block containing: phase number (5), phase name (Documentation Generation), inputs list, and outputs list

### AC2: Inputs and outputs are explicitly declared
- **Given** Phase 5 reads project profile, license choice, and prior phase data from state
- **When** the I/O declarations are written
- **Then** inputs include: `state.project_root`, `state.project_profile` (language, framework, package_manager, build_system, test_framework), `state.license_choice` (from Phase 3), `state.phases_completed`, and `state.findings`
- **And** outputs include: files created/modified (README.md, LICENSE, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md, sanitized CLAUDE.md), state updates (phase_findings for phase 5, cumulative findings totals, phases_completed updated)

### AC3: License handling reads state instead of prompting
- **Given** the Phase 3/5 license ordering bug fix (PRD AC-2.6.2, FR-21)
- **When** the license verification step (Step 5.3) is extracted
- **Then** the primary path reads `state.license_choice` and uses it to generate/validate the LICENSE file without presenting the selection menu
- **And** a clearly marked fallback path exists for when `state.license_choice` is not set (Phase 3 skipped), which notes that the orchestrator must handle the interactive license prompt before dispatching the sub-agent
- **And** the license menu options are preserved verbatim for the fallback path: MIT (default), Apache-2.0, GPL-3.0, BSD-2-Clause, BSD-3-Clause, MPL-2.0, ISC, Unlicense

### AC4: All seven documentation files are covered
- **Given** the v1 Phase 5 covers seven documentation files
- **When** the phase is extracted
- **Then** the extracted file contains generation/enhancement instructions for all seven: README.md, LICENSE, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md, and CLAUDE.md sanitization
- **And** the README template includes all 7 required sections: project name/description, badges, installation, usage, configuration, contributing reference, license reference
- **And** the CLAUDE.md sanitization rules include all three categories: preserves, removes/redacts, and flags for user review

### AC5: Three-tier file handling rule is preserved
- **Given** the existing-file preservation rule is critical to Phase 5
- **When** the phase is extracted
- **Then** the three-tier approach is preserved: Tier A (Generate -- file does not exist), Tier B (Enhance -- file exists but incomplete), Tier C (Review Only -- file exists and is complete)
- **And** the enhancement suggestion format template is preserved
- **And** the explicit rule "never overwrite existing documentation files" is stated

### AC6: Parallel sub-agent dispatch instructions are preserved
- **Given** Phase 5 dispatches parallel sub-agents for documentation generation
- **When** the phase is extracted
- **Then** instructions for parallel dispatch of Sub-Agents A through E are preserved (README, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CLAUDE.md sanitization)
- **And** CHANGELOG.md is documented as sequential (runs after sub-agents complete, may depend on git history)
- **And** each sub-agent's instructions specify what inputs it receives (state, project_root, completeness matrix, file-specific instructions)

### AC7: User review gate is preserved
- **Given** the v1 requirement that all generated content must be presented for user review before writing
- **When** the phase is extracted
- **Then** the file review presentation format is preserved (Review: {filename} with action type, content/diff, and Approve/Edit/Skip options)
- **And** the review order is preserved: LICENSE, README, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CHANGELOG, CLAUDE.md
- **And** the rule "only write a file to disk after the user explicitly approves it" is stated

### AC8: User gate prompt is included
- **Given** extraction rule 4 requires each phase file to include its user gate
- **When** the phase is extracted
- **Then** the file includes the Phase 5 approval gate: "Phase 5 (Documentation Generation) complete. Choose one: Approve and continue / Review details / Request changes / Skip"
- **And** the gate specifies the next phase: Phase 6 (GitHub Repository Setup & CI/CD)

### AC9: Finding format is included
- **Given** Phase 5 can generate findings (e.g., unrecognized license, internal references that could not be resolved)
- **When** the phase is extracted
- **Then** the finding format for Phase 5 findings is preserved (finding ID prefix DOC5-{N}, severity, file, detail, remediation)
- **And** the phase summary template is preserved with documentation status table

### AC10: Self-contained execution
- **Given** a sub-agent receives only this phase file, the current state, and the project root
- **When** the sub-agent reads `phases/05-documentation.md`
- **Then** it contains all information needed to execute Phase 5 without referencing SKILL.md or any other phase file
- **And** no inline pattern libraries are included (this phase does not reference secrets.md or pii.md)

## Test Definition

### Structural Tests
- File exists at `phases/05-documentation.md`
- File begins with a header block containing: Phase number (5), Phase name (Documentation Generation), Inputs section, Outputs section
- File contains all step numbers: 5.1 through 5.7 (5.8 state update is an orchestrator responsibility, but documented as the expected state change)
- File contains the string `state.license_choice` in the license handling section
- File contains a fallback path for when `state.license_choice` is not set
- File contains the license menu with all 8 options
- File contains generation instructions for all 7 documentation files
- File contains the three-tier table (Generate / Enhance / Review Only)
- File contains the user gate prompt with all four options (Approve, Review details, Request changes, Skip)
- File contains a Finding Format section
- File does NOT contain content from other phases (no Phase 1 patterns, no Phase 6 CI content, etc.)

### Content Verification Tests
- README template contains all 7 sections: project name/description, badges, installation, usage, configuration, contributing reference, license reference
- CONTRIBUTING.md template contains: getting started, development workflow, pull request process, code style, reporting issues
- CODE_OF_CONDUCT.md references Contributor Covenant v2.1
- SECURITY.md template contains: security policy, reporting a vulnerability, scope
- CLAUDE.md sanitization rules list preserves, removes, and flags categories
- CHANGELOG section references Keep a Changelog format
- Phase summary template contains the documentation status table with all 7 files

## Files to Create/Modify
- `phases/05-documentation.md` -- extracted Phase 5 content with license bug fix (create)
