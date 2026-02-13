---
id: "3.1"
epic: 3
title: "Replace SKILL.md with thin orchestrator"
status: done
source_prd: "tasks/prd-oss-prep-v2.md"
priority: critical
estimation: large
depends_on: ["2.1", "2.2", "2.3", "2.4", "2.5", "2.6", "2.7", "2.8", "2.9", "2.10"]
---

# Story 3.1 — Replace SKILL.md with thin orchestrator

## User Story

**As a** user invoking `/oss-prep`,
**I need** a thin SKILL.md orchestrator that manages state, sequencing, and sub-agent dispatch,
**So that** the skill is reliable, resumable, and stays within context limits throughout a full 10-phase run.

## Technical Context

This is the capstone story of the v2 migration. It replaces the entire 3,484-line monolithic SKILL.md with a ~250-line thin orchestrator. All phase logic has already been extracted into `phases/00-recon.md` through `phases/09-final-report.md` (stories 2.1-2.10), and shared pattern libraries exist at `patterns/secrets.md` and `patterns/pii.md` (story 1.1).

The orchestrator's purpose is to coordinate, not to execute. It delegates each phase to a Task sub-agent (model: opus), presents user gates after each phase returns, commits with scoped staging, persists state atomically, and handles sub-agent failures with retry-then-fallback semantics.

### Key architectural constraints (from PRD DD-3, DD-4):

1. **Context window preservation**: The orchestrator NEVER reads phase file content into its own context. It dispatches sub-agents that read phase files. The orchestrator only holds state, summaries, and sequencing logic. This is the core mechanism that solves the 166KB context exhaustion problem.

2. **Sub-agent interaction limitation**: Task sub-agents cannot interact with users mid-execution. All user gates (approve, review, request changes, skip) are the orchestrator's responsibility. Phase files document their gate prompts so the orchestrator knows what to present, but execution of the gate is always in the main context.

3. **Phase 8 two-dispatch pattern**: Phase 8 (History Flatten) has a mid-phase user gate (the "type flatten" confirmation) that requires two sub-agent dispatches: (1) assessment + checklist, then the orchestrator presents the confirmation gate, then (2) flatten execution + verification (only if user confirms). This is the sole exception to the one-dispatch-per-phase pattern.

4. **Phase 3 license pre-check**: Phase 3 requires license context for compatibility analysis. Since the sub-agent cannot prompt the user, the orchestrator must check for a LICENSE file and handle the license selection prompt BEFORE dispatching the Phase 3 sub-agent, then pass the chosen license as input.

5. **Phase 5 license fallback**: Phase 5 reads `state.license_choice` from state (set by Phase 3). If Phase 3 was skipped and `state.license_choice` is empty, the orchestrator must handle the license selection prompt BEFORE dispatching the Phase 5 sub-agent, then pass the chosen license as input. This mirrors the Phase 3 pre-check pattern.

### Files already created by prerequisite stories:

- `state-schema.json` — persistent state schema (story 1.1)
- `patterns/secrets.md` — 11-category regex library (story 1.1)
- `patterns/pii.md` — 8-category regex library (story 1.1)
- `phases/00-recon.md` through `phases/09-final-report.md` — all 10 phase files (stories 2.1-2.10)

### Sections to preserve verbatim from v1 SKILL.md:

- **Frontmatter** (lines 1-6): name, description, user-invocable, argument-hint
- **Phase-Gating Interaction Model** (the "Phase Entry / Execution / Phase Summary / User Approval Gate" section with its 4 options and progressive disclosure rules)
- **Grounding Requirement** (the "What Grounded Means", "Zero Findings Is a Valid Result", and "Anti-Hallucination Rules" sections)
- **Phase Roadmap table** (10-row table mapping phase numbers to names and descriptions)
- **Sub-Agent Model Policy** ("All sub-agents spawned via the Task tool MUST use `model: "opus"`")

## Acceptance Criteria

### AC-1: Orchestrator size and structure
The new SKILL.md is under 300 lines and contains exactly these sections: frontmatter (name, description, user-invocable, argument-hint), startup validation, state management, phase sequencing loop with sub-agent dispatch, commit strategy, sub-agent failure handling, user gates (Phase-Gating Interaction Model), grounding requirement, phase roadmap table, and sub-agent model policy. No phase execution logic is present in the orchestrator.

### AC-2: Frontmatter preservation
The v1 frontmatter is preserved verbatim:
```yaml
---
name: oss-prep
description: "Prepare a private git repository for public open-source release. Runs a 10-phase audit covering secrets, PII, dependencies, code quality, documentation, CI/CD, naming, and history -- then produces a comprehensive readiness report."
user-invocable: true
argument-hint: "Run from the root of any git repository you want to prepare for open-source release"
---
```

### AC-3: Startup validation
Before any phase execution, the orchestrator validates:
- (a) Current directory is a git repository (`git rev-parse --is-inside-work-tree`).
- (b) Not a shallow clone (`git rev-parse --is-shallow-repository` returns `false`).
- (c) Git version >= 2.20 (`git --version` parsed and compared).
- (d) Uncommitted changes check (`git status --porcelain`). If changes exist, warn the user and offer `git stash` before proceeding. Do NOT silently proceed.
Each validation failure produces a specific error message with a recovery step (not a generic "error occurred" message).

### AC-4: State persistence with atomic writes
State is persisted to `.oss-prep/state.json` using atomic write semantics: (1) write to `.oss-prep/state.json.tmp`, (2) validate the written file is valid JSON, (3) rename `.oss-prep/state.json.tmp` to `.oss-prep/state.json`. If the rename or validation fails, the orchestrator reports the error and does not advance state. State schema follows `state-schema.json` from story 1.1.

### AC-5: Post-completion state ordering
State is written to disk AFTER the phase commit succeeds, never before. If the commit fails, state is NOT advanced. This guarantees that on resume, the orchestrator re-executes the failed phase rather than skipping it.

### AC-6: Resume support
On startup, if `.oss-prep/state.json` exists:
- (a) Validate the file is parseable JSON. If corrupted, offer reset.
- (b) Display a summary of completed phases with their per-phase finding counts.
- (c) Offer the user two options: "Continue from Phase {N}" (the next incomplete phase) or "Reset and start over" (delete state and `.oss-prep/` directory).
- (d) Wait for explicit user confirmation before dispatching the next phase.

If `.oss-prep/state.json` does not exist, initialize state from `state-schema.json` defaults and proceed to Phase 0.

### AC-7: Phase sequencing loop with sub-agent dispatch
The orchestrator iterates phases 0-9 in order. For each phase, it dispatches a Task sub-agent with `model: "opus"` using this prompt structure:
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
The orchestrator NEVER reads the phase file content into its own context. It passes the phase file path to the sub-agent, and the sub-agent reads it.

### AC-8: Context window preservation
The orchestrator never reads any file under `phases/` or `patterns/` into its own context. Phase files are referenced by path only. The only content the orchestrator holds is: the state JSON (~500 tokens), sub-agent summaries (~200-500 tokens each), the grounding requirement (~500 tokens), and the orchestrator's own instructions (~3,000 tokens). This keeps the orchestrator's context under 30K tokens throughout a full run.

### AC-9: Phase-Gating Interaction Model preservation
The Phase-Gating Interaction Model is preserved verbatim from v1. It includes:
1. **Phase Entry**: Announce what the phase does.
2. **Execution**: Sub-agent runs the phase.
3. **Phase Summary**: Orchestrator presents the summary from sub-agent output (finding counts by severity, key highlights, actions taken).
4. **User Approval Gate**: Four options (Approve and continue, Review details, Request changes, Skip).
5. **Never auto-advance**: Wait for explicit user response. Never advance even if zero findings are reported.
6. **Progressive Disclosure**: Phase summaries show counts and highlights only. Detailed findings shown only on request. Final report contains everything.

### AC-10: Grounding Requirement preservation
The Grounding Requirement section is preserved verbatim from v1, including:
- "Every finding reported by this skill MUST be grounded in actual code artifacts."
- The four types of grounding evidence (file path + line number, commit hash, grep/glob match output, tool output).
- "Zero Findings Is a Valid Result."
- All six anti-hallucination rules.
The grounding requirement is included in every sub-agent dispatch prompt.

### AC-11: Commit strategy with scoped staging
After each phase approval, the orchestrator commits with scoped staging:
- Stage only phase-specific output files and `.oss-prep/state.json` using `git add -- .oss-prep/state.json {file1} {file2} ...` where the file list comes from the sub-agent's reported "Files to stage" list.
- NEVER use `git add -A`, `git add .`, or any unscoped staging command.
- Commit message format: `oss-prep: phase {N} complete -- {phase-name}`.
- If the sub-agent reports no files to stage (e.g., a scan-only phase with zero remediation), stage only `.oss-prep/state.json`.

### AC-12: Sub-agent failure handling
If a sub-agent dispatch fails (Task tool returns an error, times out, or returns empty/unparseable output):
1. **Retry once** with a simplified prompt (shorter instructions, same phase file path and state).
2. If the retry also fails, **fall back to executing the phase in the main orchestrator context** by reading the phase file directly. Display a warning to the user: "Sub-agent failed after retry. Executing Phase {N} in main context. Context preservation is degraded for this phase."
3. Log the failure in state under a `phase_failures` field: `{ "phase": N, "attempts": 2, "fallback": true }`.

### AC-13: Phase 8 two-dispatch pattern
Phase 8 (History Flatten) is dispatched as TWO separate sub-agent calls:
1. **Dispatch 1 — Assessment**: Sub-agent reads `phases/08-history-flatten.md`, executes Steps 8.1 (History Assessment) and 8.2 (Pre-Flatten Checklist), and returns the assessment summary and checklist. If the user requested dry-run mode (via their response at the Phase 8 entry announcement), the sub-agent also reports "What would change" and stops.
2. **Orchestrator gate**: The orchestrator presents the confirmation gate (from Step 8.3) requiring the user to type `flatten` to confirm. This gate is stronger than standard phase gates.
3. **Dispatch 2 — Execution** (only if user typed `flatten`): Sub-agent reads `phases/08-history-flatten.md`, executes Steps 8.4 (Execute Flatten), 8.5 (Post-Flatten Verification), and returns the execution results and verification scan findings.
4. If the user declines: The orchestrator handles the decline path (Step 8.6) itself or dispatches a sub-agent for it, updates state with `history_flattened: false`, and presents the standard phase gate.

### AC-14: Sub-agent model policy
All Task sub-agents use `model: "opus"`. This is stated explicitly in the orchestrator. No sub-agent is ever dispatched with sonnet or haiku.

## Test Definition

### Test 1: Orchestrator line count
Run `wc -l SKILL.md`. Result must be under 300 lines.

### Test 2: No phase logic in orchestrator
Grep the new SKILL.md for phase-specific patterns that should only exist in phase files: `Step [0-9]+\.[0-9]+`, `Sub-Agent A`, `Sub-Agent B`, `Sub-Agent C`, `Pattern Library`, `PII Allowlist`, `Severity Classification`, `Remediation Proposals`, `orphan branch`, `filter-repo`, `git checkout --orphan`. None of these should appear in the orchestrator (except as part of the Phase 8 confirmation gate description or the phase roadmap table).

### Test 3: Frontmatter preserved
Diff lines 1-6 of the new SKILL.md against lines 1-6 of the v1 SKILL.md. The frontmatter block (name, description, user-invocable, argument-hint) must be identical.

### Test 4: Grounding Requirement present
Grep the new SKILL.md for "Every finding reported by this skill MUST be grounded in actual code artifacts" and all six anti-hallucination rules. All must be present verbatim.

### Test 5: Phase-Gating Interaction Model present
Grep the new SKILL.md for "Approve and continue", "Review details", "Request changes", "Skip this phase", and "CRITICAL: Do NOT advance to the next phase until the user explicitly responds." All must be present.

### Test 6: Phase roadmap table present
Grep the new SKILL.md for the 10-row phase roadmap table header `| Phase | Name | Description |`. Verify all 10 phases (0-9) are listed with their names.

### Test 7: No `git add -A` or `git add .`
Grep the new SKILL.md for `git add -A` and `git add .` (unscoped staging). Neither should appear. The only `git add` pattern should be `git add --` with explicit file paths.

### Test 8: Atomic write pattern present
Grep the new SKILL.md for `state.json.tmp`, `validate`, and `rename` (or `mv`). The atomic write pattern (write tmp, validate JSON, rename to final) must be documented.

### Test 9: Sub-agent dispatch prompt includes phase file path
Grep for `phases/0` to verify the dispatch prompt references phase files by path. Verify the prompt does NOT contain inline phase content (no `Step 0.1`, `Step 1.1`, etc. in the dispatch prompt template).

### Test 10: Phase 8 two-dispatch pattern documented
Grep for `Dispatch 1` and `Dispatch 2` (or equivalent language documenting the two-call split for Phase 8). Verify the confirmation gate (`type flatten`) is handled at the orchestrator level, not delegated to the sub-agent.

### Test 11: Resume flow documented
Grep for `state.json` and `Resume` / `Reset`. Verify the orchestrator documents the resume flow: detect state, display completed phases, offer continue/reset.

### Test 12: Failure handling documented
Grep for `retry`, `fallback`, and `main context`. Verify the retry-once-then-fallback pattern is documented with the user warning message.

## Files to Create/Modify

- `SKILL.md` -- replace entirely with thin orchestrator (~250 lines) (modify)
