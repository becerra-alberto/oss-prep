# PRD: oss-prep v2 -- Decomposed Workflow Migration

**Date**: 2026-02-12
**Author**: Auto-generated (Claude Code)
**Status**: Draft
**Source**: `skills/oss-prep/SKILL.md` (3,484-line monolith)
**Target**: Decomposed workflow with phase files, shared pattern libraries, persistent state, and sub-agent delegation

---

## 1. Design Decisions

The following questions would normally require user clarification. Since this PRD is being generated autonomously, each was resolved with the safest, most conventional answer.

### DD-1: Should sub-agent prompt templates be extracted as separate files, or should phase files contain their own sub-agent instructions inline?

**Decision**: Phase files contain their own sub-agent instructions inline. No separate `templates/` directory.

**Rationale**: The Claude forensic review (G2) noted that Phases 1 and 2 are structural clones and suggested a shared scanning framework. However, extracting sub-agent templates into separate files introduces a three-level indirection (orchestrator -> phase file -> template file) that makes each phase harder to understand in isolation. The CLAUDE.md extraction rules require each phase file to be "self-contained: purpose, inputs, execution steps, outputs, finding format." Inline sub-agent instructions satisfy this requirement. If duplication between Phases 1 and 2 proves painful after the migration, templates can be extracted in a follow-up -- but the v2 migration should not add abstractions that did not exist in v1. The Codex review (Phase 3, point 8) also flagged "premature abstractions disconnected from runtime" as a P2 gap in the current system.

### DD-2: Should the state schema store per-phase finding details (full structured findings arrays) or only aggregate counts?

**Decision**: Store aggregate counts per phase, not full findings arrays. The state file tracks `phase_findings: { "0": { total: N, critical: N, high: N, medium: N, low: N }, ... }` alongside the existing flat `findings` totals. Full finding details remain in the conversation context and the final report file.

**Rationale**: Storing every finding as structured JSON in `state.json` would balloon the file (Phases 1-2 alone can produce 50+ findings with multi-line context) and create a complex schema that must evolve with finding formats. The state file's purpose is resumability and phase tracking, not archival. The final report (Phase 9) already serves as the archival artifact. Aggregate counts per phase are sufficient to resume, display progress, and generate the report summary. This aligns with ralph-v2's approach where `state.json` tracks phase completion status rather than full work products.

### DD-3: Should the orchestrator read phase files itself and dispatch sub-agents, or should it dispatch a sub-agent per phase with instructions to read the phase file?

**Decision**: The orchestrator dispatches a sub-agent per phase with instructions to read the phase file. The orchestrator itself never reads phase file contents into its context.

**Rationale**: This is the core mechanism for context window preservation (pattern A6 from the Claude review). If the orchestrator reads phase files into its own context, the 166KB problem simply shifts from "one giant file" to "one context accumulating all files." The orchestrator must remain thin -- it holds only state, summaries, and sequencing logic. Each sub-agent loads only its phase file and the shared patterns it needs, executes, and returns a summary. This matches the architecture described in CLAUDE.md: "Orchestrator delegates to phase sub-agents; only summaries in main context."

### DD-4: How should the orchestrator handle the user gate -- should the sub-agent present the gate, or should the orchestrator present it after the sub-agent returns?

**Decision**: The sub-agent executes the phase work and returns a structured summary (findings counts, key highlights, actions taken). The orchestrator presents the user gate using that summary. The sub-agent does NOT interact with the user.

**Rationale**: Sub-agents spawned via the Task tool cannot interact with the user mid-execution -- they run to completion and return output. The user gate is inherently an orchestrator responsibility because it is a synchronization point between phases. This also means the orchestrator always controls phase sequencing, and a sub-agent cannot accidentally advance to the next phase. Each phase file still documents its gate prompt (as required by extraction rule 4) so the orchestrator knows what to present, but execution of the gate is the orchestrator's job.

### DD-5: Should the v2 migration preserve the v1 SKILL.md as a backup, or replace it in-place?

**Decision**: Replace in-place. The v1 SKILL.md is preserved in git history and can be recovered via `git show HEAD~N:skills/oss-prep/SKILL.md` at any point.

**Rationale**: Keeping both a v1 and v2 SKILL.md would create ambiguity about which is authoritative. The git history is the backup mechanism. The migration's Epic 3 (Story 3.1) replaces SKILL.md with the thin orchestrator as its final step. All v1 content will have been extracted into phase files and pattern libraries by that point.

---

## 2. Introduction / Overview

### Problem Statement

The oss-prep skill is a 3,484-line monolithic SKILL.md that works but suffers from five architectural problems identified by independent reviews from Claude and Codex:

1. **Context exhaustion**: By Phase 8-9, Claude cannot reliably reference Phase 1-2 pattern definitions. The 166KB file exceeds what can be maintained in working context across a 30+ minute interactive session.

2. **No persistent state**: The STATE block lives only in conversation context. Session loss (crash, timeout, terminal close) requires a complete restart of a process that can take 30+ minutes on large repositories.

3. **No phase-level commits**: If Phase 6 completes but Phase 7 fails, all of Phase 5-6's work products are uncommitted and vulnerable to loss.

4. **Design bugs**: Phase 3 requires license information only selected in Phase 5. Phase 8 deletes ALL tags (not just reachable ones), has no backup ref, no dry-run, and no uncommitted change check before the destructive orphan checkout.

5. **No sub-agent failure handling**: Phases 1, 2, 4, and 5 spawn parallel sub-agents with no retry logic, no partial result recovery, and no fallback to sequential execution.

### Solution

Decompose the monolith into a thin orchestrator (~250 lines), 10 self-contained phase files, 2 shared pattern libraries, and a persistent state schema. The orchestrator delegates each phase to a Task sub-agent, commits after each phase, persists state to disk with atomic writes, and handles sub-agent failures with retry-then-fallback semantics.

This migration adopts 8 proven patterns from ralph-v2's production-hardened pipeline while intentionally skipping 4 patterns that add complexity without proportional value for an interactive skill.

### Scope

The migration restructures the skill's file layout and execution model. It does NOT change what the skill does -- all 10 phases retain their existing audit and transformation logic. The migration adds reliability infrastructure (state persistence, commit checkpoints, failure handling) and fixes 8 known design bugs.

---

## 3. Goals

| ID | Goal | Measurable Outcome |
|----|------|--------------------|
| G-1 | Eliminate context exhaustion | Each phase executes in its own sub-agent context; orchestrator context stays under 30K tokens throughout a full run |
| G-2 | Survive session interruption | After killing a session mid-Phase-4, restarting `/oss-prep` offers resume from Phase 4 with all prior work intact |
| G-3 | Commit after every phase | `git log` on `oss-prep/ready` shows one commit per completed phase |
| G-4 | Fix Phase 3/5 license ordering bug | Phase 3 prompts for license selection if no LICENSE file exists, before running compatibility analysis |
| G-5 | Harden Phase 8 flatten | Phase 8 creates backup ref, scopes tag deletion to reachable tags, checks for uncommitted changes, and supports dry-run |
| G-6 | Handle sub-agent failure | A failed sub-agent is retried once; if retry fails, phase falls back to main context execution |
| G-7 | Preserve all existing skill behavior | Running the decomposed v2 on the same repo as v1 produces equivalent audit coverage and documentation |
| G-8 | Keep orchestrator thin | SKILL.md (the orchestrator) is under 300 lines |

---

## 4. User Stories

### Epic 1: Foundation (batch 0 -- sequential)

#### US-1.1: Shared Pattern Libraries and State Schema

**As a** phase sub-agent executing Phases 1, 2, or 8,
**I need** a shared, canonical secret and PII pattern library that I can reference by file path,
**So that** pattern definitions are consistent across phases and survive context boundaries.

**Acceptance Criteria:**
- AC-1.1.1: `patterns/secrets.md` contains the complete 11-category regex library extracted verbatim from SKILL.md Phase 1, Step 1.2 (AWS, GCP, Azure, GitHub tokens, generic API keys, database URIs, PEM keys, JWT/OAuth, SMTP, .env, vendor-specific).
- AC-1.1.2: `patterns/pii.md` contains the complete 8-category regex library extracted verbatim from SKILL.md Phase 2, Step 2.2 (email, phone, physical address, IP address, SSN, credit card, employee IDs, personal names).
- AC-1.1.3: `state-schema.json` defines the persistent state structure with fields for: schema version, current phase, completed phases array, project root, prep branch, project profile, per-phase finding counts, history flattened flag, started timestamp, and readiness rating.
- AC-1.1.4: Each pattern file includes a header documenting its consumers (which phases reference it) and a note that modifications must be reflected across all consumers.
- AC-1.1.5: The state schema includes version numbering (starting at 1) to support future schema evolution.

---

### Epic 2: Phase Extraction (batch 1 -- parallelizable)

#### US-2.1: Extract Phase 0 (Reconnaissance)

**As the** orchestrator dispatching Phase 0 to a sub-agent,
**I need** a self-contained `phases/00-recon.md` that describes all reconnaissance steps,
**So that** the sub-agent can execute Phase 0 without access to the full monolith.

**Acceptance Criteria:**
- AC-2.1.1: `phases/00-recon.md` contains Steps 0.1-0.6 extracted verbatim from SKILL.md (project root detection, branch management, project profile building, anomaly detection, profile presentation, state update).
- AC-2.1.2: The file includes a header block declaring: phase number (0), phase name (Reconnaissance), inputs (git repository), outputs (project profile, prep branch, initial state).
- AC-2.1.3: The file includes the user gate prompt specific to Phase 0 (profile confirmation).
- AC-2.1.4: The file declares its output state updates (all fields of the initial STATE block).

#### US-2.2: Extract Phase 1 (Secrets Audit)

**As the** orchestrator dispatching Phase 1 to a sub-agent,
**I need** a self-contained `phases/01-secrets.md` that references `patterns/secrets.md` instead of inlining patterns,
**So that** pattern definitions are shared with Phase 8's post-flatten verification.

**Acceptance Criteria:**
- AC-2.2.1: `phases/01-secrets.md` contains Steps 1.1, 1.3-1.7 extracted from SKILL.md (sub-agent dispatch, severity classification, finding format, remediation proposals, tool detection, consolidation).
- AC-2.2.2: Step 1.2 (Secret Pattern Library) is replaced with: "Read `patterns/secrets.md` for the complete pattern library."
- AC-2.2.3: The file includes instructions for parallel sub-agent dispatch (working tree scan + git history scan) as defined in Step 1.1.
- AC-2.2.4: The file includes the entropy calculation and severity classification rules from Step 1.3.
- AC-2.2.5: The file declares inputs (project_root, project_profile, state) and outputs (findings list with counts by severity, remediated files if any).

#### US-2.3: Extract Phase 2 (PII Audit)

**As the** orchestrator dispatching Phase 2 to a sub-agent,
**I need** a self-contained `phases/02-pii.md` that references `patterns/pii.md` instead of inlining patterns,
**So that** pattern definitions are shared with Phase 8's post-flatten verification.

**Acceptance Criteria:**
- AC-2.3.1: `phases/02-pii.md` contains all PII audit steps extracted from SKILL.md Phase 2, with the PII pattern library replaced by a reference to `patterns/pii.md`.
- AC-2.3.2: The author email audit (git author/committer information check) is preserved.
- AC-2.3.3: The PII allowlist (public/generic values like `example@example.com`, `127.0.0.1`) is preserved inline in the phase file (not extracted to patterns) since it is PII-audit-specific.
- AC-2.3.4: The file declares inputs and outputs following the extraction rules.

#### US-2.4: Extract Phase 3 (Dependencies) with License Fix

**As the** orchestrator dispatching Phase 3 to a sub-agent,
**I need** `phases/03-dependencies.md` that includes a license selection preamble,
**So that** license compatibility analysis can run without depending on Phase 5.

**Acceptance Criteria:**
- AC-2.4.1: `phases/03-dependencies.md` contains all dependency audit steps extracted from SKILL.md Phase 3.
- AC-2.4.2: A new "Step 3.0 -- License Context" preamble is added before the dependency scan. This step: (a) checks if a LICENSE file exists in the repository, (b) if yes, reads and identifies the license type, (c) if no, presents the license selection menu (MIT as default, same menu as v1 Phase 5's FR-31) and records the user's choice as the intended license for compatibility analysis.
- AC-2.4.3: The license choice is passed as an input to the compatibility analysis (replacing the previous assumption that Phase 5 would have already set it).
- AC-2.4.4: The license selection menu matches v1 exactly: MIT (default), Apache-2.0, GPL-3.0, BSD-2-Clause, BSD-3-Clause, MPL-2.0, ISC, Unlicense.
- AC-2.4.5: The selected/detected license is recorded as a state update for downstream phases (Phase 5 will use it when generating the LICENSE file).

#### US-2.5: Extract Phase 4 (Code Quality)

**As the** orchestrator dispatching Phase 4 to a sub-agent,
**I need** a self-contained `phases/04-code-quality.md`,
**So that** code quality review executes in its own context.

**Acceptance Criteria:**
- AC-2.5.1: `phases/04-code-quality.md` contains all code quality steps extracted from SKILL.md Phase 4 (architecture summary, coding standards, build verification, test execution, quality flags).
- AC-2.5.2: Build and test timeout values are preserved (5-minute build, 10-minute test).
- AC-2.5.3: The file includes instructions for parallel sub-agent dispatch within the phase (architecture review, standards check, build/test can run in parallel).
- AC-2.5.4: The file declares inputs (project_root, project_profile) and outputs (architecture summary, findings list, build status, test status).

#### US-2.6: Extract Phase 5 (Documentation) with License Adjustment

**As the** orchestrator dispatching Phase 5 to a sub-agent,
**I need** `phases/05-documentation.md` that reads the license choice from state rather than prompting for it,
**So that** license selection is not duplicated between Phase 3 and Phase 5.

**Acceptance Criteria:**
- AC-2.6.1: `phases/05-documentation.md` contains all documentation generation steps extracted from SKILL.md Phase 5.
- AC-2.6.2: The LICENSE file generation step reads the license type from state (set in Phase 3) instead of presenting the selection menu. If state contains a license type, use it. If not (Phase 3 was skipped), fall back to presenting the selection menu.
- AC-2.6.3: All 7 document types are preserved: README.md, LICENSE, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md, CLAUDE.md sanitization.
- AC-2.6.4: Instructions for parallel sub-agent dispatch (multiple docs drafted simultaneously) are preserved.

#### US-2.7: Extract Phase 6 (GitHub Setup)

**As the** orchestrator dispatching Phase 6 to a sub-agent,
**I need** a self-contained `phases/06-github-setup.md`,
**So that** GitHub repository scaffolding executes in its own context.

**Acceptance Criteria:**
- AC-2.7.1: `phases/06-github-setup.md` contains all GitHub setup steps extracted from SKILL.md Phase 6 (issue templates, PR template, CI workflow, .gitignore review).
- AC-2.7.2: CI workflow generation is tailored to the detected language/framework from the project profile.
- AC-2.7.3: The file declares inputs (project_root, project_profile) and outputs (list of files created under `.github/`, .gitignore modifications).

#### US-2.8: Extract Phase 7 (Naming & Identity)

**As the** orchestrator dispatching Phase 7 to a sub-agent,
**I need** a self-contained `phases/07-naming-identity.md`,
**So that** naming and identity review executes in its own context.

**Acceptance Criteria:**
- AC-2.8.1: `phases/07-naming-identity.md` contains all naming/identity steps extracted from SKILL.md Phase 7 (registry checks, internal identity scan, telemetry detection).
- AC-2.8.2: WebSearch-based registry availability checks are preserved with graceful degradation if web search is unavailable.
- AC-2.8.3: The file declares inputs (project_root, project_profile, package manifest paths) and outputs (findings list with registry availability results).

#### US-2.9: Extract Phase 8 (History Flatten) with Safety Hardening

**As the** orchestrator dispatching Phase 8 to a sub-agent,
**I need** `phases/08-history-flatten.md` with four safety improvements,
**So that** the most destructive operation in the skill has proper safeguards.

**Acceptance Criteria:**
- AC-2.9.1: `phases/08-history-flatten.md` contains all history flatten steps extracted from SKILL.md Phase 8 (assessment, checklist, confirmation gate, flatten execution, verification, decline path).
- AC-2.9.2: **Backup ref**: Before the flatten procedure, the phase creates a backup reference: `git update-ref refs/oss-prep/pre-flatten oss-prep/ready`. The confirmation prompt mentions this backup and how to restore from it.
- AC-2.9.3: **Scoped tag deletion**: Tag deletion is changed from `git tag -l | xargs -r git tag -d` to `git tag --merged oss-prep/ready | xargs -r git tag -d`. Only tags reachable from the preparation branch are deleted.
- AC-2.9.4: **Uncommitted change check**: Before `git checkout --orphan`, the phase runs `git status --porcelain` and refuses to proceed if there are uncommitted changes, offering `git stash` as an alternative.
- AC-2.9.5: **Dry-run mode**: A dry-run path is added that executes Steps 8.1-8.2 (assessment and checklist) and reports "What would change: N commits removed, N tags deleted, backup ref would be created at refs/oss-prep/pre-flatten" without executing any destructive operations. The orchestrator triggers dry-run mode when the user requests it.
- AC-2.9.6: Post-flatten verification references `patterns/secrets.md` and `patterns/pii.md` instead of "the patterns defined in Phase 1/2."

#### US-2.10: Extract Phase 9 (Final Report)

**As the** orchestrator dispatching Phase 9 to a sub-agent,
**I need** a self-contained `phases/09-final-report.md`,
**So that** report generation executes in its own context with access to all phase summaries.

**Acceptance Criteria:**
- AC-2.10.1: `phases/09-final-report.md` contains all report generation steps extracted from SKILL.md Phase 9 (risk matrix, summary, per-phase details, launch checklist, final presentation).
- AC-2.10.2: The phase reads cumulative state (per-phase finding counts, completed phases, history flattened flag) from the state passed by the orchestrator.
- AC-2.10.3: The readiness rating logic is preserved verbatim (Ready / Ready with Caveats / Not Ready).
- AC-2.10.4: The report file naming convention is preserved: `oss-prep-report-{YYYY-MM-DD}.md`.
- AC-2.10.5: The file declares inputs (full state with all phase summaries) and outputs (report file path, readiness rating).

---

### Epic 3: Orchestrator (batch 2 -- depends on Epic 2)

#### US-3.1: Replace SKILL.md with Thin Orchestrator

**As a** user invoking `/oss-prep`,
**I need** a thin SKILL.md orchestrator that manages state, sequencing, and sub-agent dispatch,
**So that** the skill is reliable, resumable, and stays within context limits.

**Acceptance Criteria:**
- AC-3.1.1: The new SKILL.md is under 300 lines and contains: frontmatter (name, description, user-invocable, argument-hint), state management, phase sequencing loop, sub-agent dispatch, commit strategy, user gates, grounding requirement, and startup validation.
- AC-3.1.2: **Frontmatter** preserves the v1 frontmatter fields verbatim (name: oss-prep, description, user-invocable: true, argument-hint).
- AC-3.1.3: **State management**: On startup, checks for `.oss-prep/state.json`. If found, offers resume (continue from last completed phase) or reset (delete state and start fresh). If not found, initializes state from `state-schema.json` defaults. State writes use atomic semantics: write to `.oss-prep/state.json.tmp`, validate JSON, rename to `.oss-prep/state.json`.
- AC-3.1.4: **Phase sequencing**: Iterates phases 0-9 in order. For each phase: (a) dispatch to Task sub-agent with `model: "opus"`, providing the phase file path, current state, project root, and the grounding requirement; (b) receive the sub-agent's summary output; (c) present the user gate; (d) on approval, commit phase outputs and update state; (e) on skip, update state with phase marked as skipped.
- AC-3.1.5: **Sub-agent dispatch**: Each phase is dispatched as: "Read `phases/0N-{name}.md` and execute it. Here is the current state: {state JSON}. Here is the project root: {path}. Report back with: finding counts by severity, key highlights (3-5 items), actions taken, and files created or modified."
- AC-3.1.6: **Sub-agent failure handling**: If a sub-agent fails (Task tool returns error or no usable output), retry once with a simplified prompt. If the retry fails, fall back to executing the phase in the main orchestrator context (reading the phase file directly) with a warning to the user. Log the failure.
- AC-3.1.7: **Commit strategy**: After each phase approval, commit with scoped staging: `git add -- .oss-prep/state.json {phase-specific-output-files}`. Commit message format: `oss-prep: phase {N} complete -- {phase-name}`. Never use `git add -A` or `git add .`.
- AC-3.1.8: **User gates**: Preserve the Phase-Gating Interaction Model verbatim from v1 (approve, review details, request changes, skip). The orchestrator presents the gate after receiving the sub-agent summary.
- AC-3.1.9: **Grounding requirement**: Preserve the Grounding Requirement section verbatim from v1. Include it in the orchestrator so it is passed to every sub-agent.
- AC-3.1.10: **Startup validation**: Before any phase execution, validate: (a) current directory is a git repository, (b) not a shallow clone (`git rev-parse --is-shallow-repository`), (c) git version >= 2.20, (d) no uncommitted changes (warn and offer stash if present). Report any failures with specific error messages and recovery steps.
- AC-3.1.11: **Resume support**: When resuming from existing state, display a summary of completed phases and their finding counts, then ask the user to confirm resumption before dispatching the next incomplete phase.
- AC-3.1.12: **Post-completion state transitions**: State is written to disk AFTER the commit succeeds, not before. If the commit fails, state is not advanced.
- AC-3.1.13: **Phase roadmap table**: Preserve the Phase Roadmap table from v1 so the orchestrator displays the full plan at startup.
- AC-3.1.14: **Sub-agent model policy**: All Task sub-agents use `model: "opus"`.

---

## 5. Functional Requirements

### Foundation

**FR-1**: The system SHALL provide a shared secret detection pattern library (`patterns/secrets.md`) containing all 11 regex categories from the v1 Phase 1 pattern library, formatted as scannable markdown tables.

**FR-2**: The system SHALL provide a shared PII detection pattern library (`patterns/pii.md`) containing all 8 regex categories from the v1 Phase 2 pattern library, formatted as scannable markdown tables.

**FR-3**: The system SHALL define a persistent state schema (`state-schema.json`) with version numbering, phase tracking, project profile, per-phase finding counts, and flags for history flatten status and readiness rating.

### State Persistence

**FR-4**: The orchestrator SHALL persist state to `.oss-prep/state.json` after every phase transition using atomic write semantics (write `.oss-prep/state.json.tmp`, validate JSON structure, rename to `.oss-prep/state.json`).

**FR-5**: The orchestrator SHALL detect existing state on startup and offer resume or reset.

**FR-6**: State transitions SHALL occur AFTER the phase commit succeeds, never before. If the commit fails, the state file SHALL NOT be advanced.

### Phase Execution

**FR-7**: The orchestrator SHALL dispatch each phase (0-9) to a Task sub-agent with `model: "opus"`, providing: the phase file path to read, the current state as JSON, the project root path, and the grounding requirement.

**FR-8**: Each phase file SHALL be self-contained: declaring its phase number, name, inputs (state fields read), outputs (files created, state updates), execution steps, finding format, and user gate prompt.

**FR-9**: Phase files SHALL reference shared pattern libraries by file path (`patterns/secrets.md`, `patterns/pii.md`) instead of inlining pattern definitions.

### Commit Strategy

**FR-10**: The orchestrator SHALL create a git commit after each phase approval with scoped staging (explicit file paths, never `git add -A` or `git add .`).

**FR-11**: Commit messages SHALL follow the format: `oss-prep: phase {N} complete -- {phase-name}`.

**FR-12**: Only phase-specific output files and `.oss-prep/state.json` SHALL be staged per commit. The orchestrator SHALL determine stageable files from the sub-agent's reported "files created or modified" list.

### Sub-Agent Failure Handling

**FR-13**: If a sub-agent dispatch fails (Task tool error, empty output, or unparseable output), the orchestrator SHALL retry once with a simplified prompt.

**FR-14**: If the retry also fails, the orchestrator SHALL fall back to executing the phase in the main context by reading the phase file directly, with a warning to the user that context preservation is degraded.

**FR-15**: Sub-agent failures SHALL be logged in state (`phase_failures` field) for inclusion in the final report.

### User Interaction

**FR-16**: The orchestrator SHALL preserve the Phase-Gating Interaction Model from v1: phase entry announcement, execution, phase summary with progressive disclosure, and user approval gate with four options (approve, review details, request changes, skip).

**FR-17**: The orchestrator SHALL NOT advance to the next phase until the user explicitly responds to the approval gate.

**FR-18**: The Grounding Requirement from v1 SHALL be preserved verbatim and passed to every sub-agent.

### Startup Validation

**FR-19**: On startup, the orchestrator SHALL validate: git repository presence, not a shallow clone, git version >= 2.20, and uncommitted changes status.

**FR-20**: If uncommitted changes are detected, the orchestrator SHALL warn the user and offer `git stash` before proceeding. It SHALL NOT silently proceed with uncommitted changes.

### Bug Fixes

**FR-21**: Phase 3 (`phases/03-dependencies.md`) SHALL include a license selection preamble that checks for an existing LICENSE file and prompts the user to choose a license if none exists, BEFORE running dependency compatibility analysis.

**FR-22**: Phase 8 (`phases/08-history-flatten.md`) SHALL create a backup reference (`refs/oss-prep/pre-flatten`) before executing the flatten procedure.

**FR-23**: Phase 8 SHALL scope tag deletion to tags reachable from `oss-prep/ready` using `git tag --merged oss-prep/ready`, not `git tag -l`.

**FR-24**: Phase 8 SHALL check for uncommitted changes before `git checkout --orphan` and refuse to proceed if any exist.

**FR-25**: Phase 8 SHALL support a dry-run mode that reports what would change without executing destructive operations.

---

## 6. Non-Goals

**NG-1**: **Structured signal protocol** -- Sub-agents return results via the Task tool's natural output. No `<signal>DONE</signal>` tags or machine-parseable signal protocol. The orchestrator interprets sub-agent output as prose summaries. This keeps the system simple and avoids the signal-parsing evolution that ralph-v2 went through across 3 commits.

**NG-2**: **Auto-decomposition** -- If a phase fails after retry, the orchestrator falls back to main context. It does NOT automatically decompose the phase into smaller tasks. Phases are interactive steps with user gates, not batch tasks that can be subdivided.

**NG-3**: **PID lockfile** -- The skill is interactive and user-invoked. Running two instances simultaneously would require two terminal sessions actively interacting with Claude Code, which is not a realistic scenario. Locking adds complexity without proportional value.

**NG-4**: **Timeout postmortem / per-phase metrics** -- Not implemented in v2. Metrics tracking (token usage, duration, cost per phase) is deferred to a post-migration follow-up. The infrastructure for state persistence makes metrics easy to add later.

**NG-5**: **Sub-agent prompt templates** -- No separate `templates/` directory for sub-agent prompts (see DD-1). Phase files are self-contained.

**NG-6**: **Config file** -- No external `config-defaults.json`. The orchestrator's behavior is defined in SKILL.md. Per-project configuration overrides are deferred to post-migration.

**NG-7**: **Provenance tracking** -- No SHA-256 hash tracking between source artifacts and derived outputs. Valuable but adds complexity that is not justified for a v2 migration.

**NG-8**: **All v1 non-goals remain** -- The skill still does not create GitHub repositories, provide legal advice, perform SAST/DAST, manage ongoing maintenance, audit submodule contents, publish packages, automate selective history rewriting, or require external paid services.

---

## 7. Design Considerations

### File Layout

```
skills/oss-prep/
  SKILL.md                    # Thin orchestrator (~250 lines)
  phases/
    00-recon.md               # Phase 0: Reconnaissance
    01-secrets.md             # Phase 1: Secrets Audit
    02-pii.md                 # Phase 2: PII Audit
    03-dependencies.md        # Phase 3: Dependency Audit (with license preamble)
    04-code-quality.md        # Phase 4: Code Quality
    05-documentation.md       # Phase 5: Documentation (reads license from state)
    06-github-setup.md        # Phase 6: GitHub Setup
    07-naming-identity.md     # Phase 7: Naming & Identity
    08-history-flatten.md     # Phase 8: History Flatten (with safety hardening)
    09-final-report.md        # Phase 9: Final Report
  patterns/
    secrets.md                # 11-category regex library
    pii.md                    # 8-category regex library
  state-schema.json           # Persistent state schema definition
```

### Runtime State Layout (in target repository)

```
{target-repo}/
  .oss-prep/
    state.json                # Persistent state (atomic writes)
    state.json.tmp            # Temporary write target (transient)
```

### Adopted Patterns from ralph-v2

| Pattern | Description | Where Applied |
|---------|-------------|---------------|
| Phase-Commit-Gate Sequencing | Git commit after every phase, user gate before advancing | Orchestrator (FR-10, FR-16) |
| Atomic State Persistence | `.oss-prep/state.json` with tmp-validate-rename writes | Orchestrator (FR-4) |
| Context Window Preservation | Orchestrator delegates to phase sub-agents; only summaries in main context | Orchestrator (FR-7, DD-3) |
| Scoped Staging | Explicit file paths in every `git add`, never `-A` or `.` | Orchestrator (FR-10) |
| Post-Completion State Transitions | State written AFTER commit succeeds | Orchestrator (FR-6) |
| Cross-Phase Pattern Sharing | `patterns/secrets.md` and `patterns/pii.md` referenced by phases 1, 2, and 8 | Pattern libraries (FR-1, FR-2, FR-9) |
| Startup Validation | Git state checks before any work begins | Orchestrator (FR-19, FR-20) |
| Sub-Agent Failure Containment | Retry once, fallback to main context | Orchestrator (FR-13, FR-14) |

### Phase File Contract

Every phase file follows this structure:

```markdown
# Phase {N} -- {Name}

## Header
- Phase: {N}
- Name: {Name}
- Inputs: {state fields read, files needed}
- Outputs: {files created, state updates}

## Steps
{Numbered execution steps, extracted from v1}

## Finding Format
{Finding report template for this phase}

## User Gate
{The approval prompt for this phase}
```

### Sub-Agent Dispatch Contract

The orchestrator dispatches each phase with this prompt structure:

```
You are executing Phase {N} ({Name}) of the oss-prep skill.

Read the phase file at: {skill_dir}/phases/0{N}-{name}.md

Current state:
{state JSON}

Project root: {path}

Grounding Requirement:
{verbatim grounding requirement text}

Execute all steps in the phase file. When complete, report:
1. Finding counts: {total, critical, high, medium, low}
2. Key highlights: 3-5 most important findings or actions
3. Actions taken: files created, modified, or deleted
4. Files to stage: explicit list of file paths to commit
```

### Interaction Model (Unchanged from v1)

The Phase-Gating Interaction Model is preserved exactly:

1. **Phase Entry**: Announce what the phase does
2. **Execution**: Sub-agent runs the phase
3. **Phase Summary**: Orchestrator presents findings summary from sub-agent output
4. **User Approval Gate**: Four options (Approve, Review details, Request changes, Skip)
5. **Never auto-advance**: Wait for explicit user response

### Progressive Disclosure (Unchanged from v1)

- Phase summaries show counts and highlights only
- Detailed findings shown on request ("Review details")
- Final report contains everything

---

## 8. Technical Considerations

### Migration Execution Order

The migration is structured in 3 batches with dependency constraints:

**Batch 0 (sequential)**: Story 1.1 -- Foundation files must exist before any phase extraction begins.

**Batch 1 (parallelizable)**: Stories 2.1-2.10 -- All phase extractions are independent of each other. They read from the v1 SKILL.md (which is unchanged at this point) and write to new files under `phases/`. Can be executed in any order or in parallel.

**Batch 2 (depends on Batch 1)**: Story 3.1 -- The orchestrator replacement depends on all phase files and pattern libraries existing. This is the only story that modifies SKILL.md.

### Context Window Budget

| Component | Estimated Tokens |
|-----------|-----------------|
| Orchestrator (SKILL.md) | ~3,000 |
| State JSON passed to sub-agent | ~500 |
| Phase file (largest: Phase 1 at ~800 lines) | ~8,000 |
| Pattern library (secrets.md) | ~3,000 |
| Grounding requirement | ~500 |
| **Total per sub-agent context** | **~15,000** |

This leaves ~130K tokens of usable context for the sub-agent's actual work (file reading, grep output, analysis), well within the 200K context window.

### Backward Compatibility

- The skill name (`oss-prep`) and invocation (`/oss-prep`) are unchanged.
- The frontmatter is unchanged.
- All 10 phases perform the same work as v1.
- The Phase-Gating Interaction Model is unchanged.
- The Grounding Requirement is unchanged.
- The finding format per phase is unchanged.
- Users will not notice any difference in the skill's behavior -- only in its reliability.

### Risk: Sub-Agent Cannot Interact with User

Sub-agents spawned via the Task tool run to completion without user interaction. This means:

- Phase 0's profile confirmation must happen after the sub-agent returns, at the orchestrator level.
- Phase 3's license selection (if no LICENSE exists) requires the orchestrator to pre-check for a LICENSE file and handle the license prompt BEFORE dispatching the Phase 3 sub-agent, then pass the chosen license as an input.
- Phase 8's flatten confirmation ("type flatten") must happen at the orchestrator level, not inside the sub-agent. The sub-agent performs assessment and presents the checklist; the orchestrator handles the confirmation gate; the orchestrator re-dispatches the sub-agent (or handles flatten in main context) for the actual execution.

This is the most significant architectural constraint. Each phase file documents its user interaction points, but the orchestrator is responsible for executing them.

### Risk: Phase 8 Requires Two Sub-Agent Calls

Phase 8 has a mid-phase user gate (the "type flatten" confirmation) that splits execution into two parts:
1. Assessment + checklist (sub-agent call 1)
2. Flatten execution + verification (sub-agent call 2, only if user confirms)

The orchestrator must handle this split: dispatch assessment, present gate, then dispatch execution if confirmed. This is a departure from the simple "one sub-agent per phase" pattern but is necessary because Phase 8's confirmation gate is intentionally stronger than the standard inter-phase gates.

### Error Handling

- Git command failures produce specific error messages with recovery steps (not "report an error and stop").
- Build/test failures in Phase 4 are reported but do not block subsequent phases.
- Missing package managers degrade gracefully.
- Web search failures (Phase 7 registry checks) degrade gracefully.
- State file corruption is detected by JSON validation on read; if corrupted, offer reset.

---

## 9. Success Metrics

| Metric | Target | How Measured |
|--------|--------|-------------|
| Orchestrator size | Under 300 lines | `wc -l SKILL.md` |
| Phase file completeness | All 10 phases extracted with zero logic loss | Manual diff of v1 phase sections against v2 phase files |
| Pattern library completeness | All 11 secret categories, all 8 PII categories | Count regex tables in pattern files vs. v1 |
| Resume works | Session kill at any phase, resume continues from correct phase | Kill session mid-Phase-4, restart, verify Phase 4 resumes |
| Commits per phase | One commit per completed phase in git log | `git log --oneline` on `oss-prep/ready` shows N commits for N phases |
| State persistence | State file exists and is valid JSON after each phase | `cat .oss-prep/state.json | python -m json.tool` |
| Sub-agent failure recovery | Retry fires on simulated failure, fallback fires on double failure | Verify by inspecting orchestrator's failure handling logic |
| Bug fixes embedded | All 8 design bugs addressed in their target files | Review each target file for the specific fix |
| Behavioral equivalence | v2 produces equivalent audit output to v1 on the same repository | Run both versions on a test repo and compare findings |

---

## 10. Open Questions

**OQ-1**: **Phase 8 sub-agent split** -- Phase 8 requires two sub-agent dispatches (assessment, then execution) due to its mid-phase confirmation gate. Should the orchestrator handle flatten execution in its own context (simpler, but puts destructive git commands in the orchestrator) or dispatch a second sub-agent (cleaner separation, but more complex orchestrator logic)? The current design says "dispatch a second sub-agent" but this should be validated during implementation.

**OQ-2**: **Phase 3/5 license handoff mechanism** -- Phase 3 selects the license and records it in state. Phase 5 reads it from state. But if Phase 3 is skipped, Phase 5 must fall back to its own license prompt. Should the orchestrator handle this conditional logic, or should Phase 5's file contain its own fallback? The current design puts the fallback in Phase 5's file (AC-2.6.2) which keeps the orchestrator simple, but means Phase 5 has two code paths for license handling.

**OQ-3**: **State schema migration** -- `state-schema.json` starts at version 1. If a user resumes from a v2-early state file after a schema change, how should migration work? The current design defers this ("version numbering to support future schema evolution" in AC-1.1.5) but does not specify the migration mechanism. Should the orchestrator include a `_state_ensure_schema()` equivalent, or is version 1 sufficient for the initial release?

**OQ-4**: **Dry-run scope** -- AC-2.9.5 adds dry-run for Phase 8 only. Should the orchestrator support a global dry-run mode that runs all phases in read-only mode (no file writes, no commits)? This was suggested in the Claude review (E6) but significantly increases scope. The current design limits dry-run to Phase 8 where the risk is highest.

**OQ-5**: **Review details flow** -- When the user selects "Review details" at a gate, the sub-agent has already returned and its detailed findings are not in the orchestrator's context. Should the orchestrator (a) ask the sub-agent to include full details in its output (increases orchestrator context), (b) re-dispatch a sub-agent to present details (expensive), or (c) instruct the user to read the phase's output file directly? This is a UX question that affects context management.
