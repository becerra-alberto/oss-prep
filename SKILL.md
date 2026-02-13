---
name: oss-prep
description: "Prepare a private git repository for public open-source release. Runs a 10-phase audit covering secrets, PII, dependencies, code quality, documentation, CI/CD, naming, and history — then produces a comprehensive readiness report."
user-invocable: true
argument-hint: "Run from the root of any git repository you want to prepare for open-source release"
---

Thin orchestrator for `/oss-prep`. All phase logic lives in `phases/00-recon.md` through `phases/09-final-report.md`. This file manages state, sequencing, sub-agent dispatch, user gates, and commits. It never reads phase or pattern files into its own context.

## Startup Validation

Before any phase execution, run these checks in order. Each failure produces a specific error with recovery steps.

1. **Git repository**: Run `git rev-parse --is-inside-work-tree`. If it fails: "This directory is not inside a git repository. Run `/oss-prep` from the root of a git repo."
2. **Shallow clone**: Run `git rev-parse --is-shallow-repository`. If `true`: "This is a shallow clone. History-based scans require full history. Run `git fetch --unshallow` first."
3. **Git version**: Run `git --version`, parse the version number. If < 2.20: "Git version {version} is too old. oss-prep requires Git >= 2.20. Please upgrade."
4. **Uncommitted changes**: Run `git status --porcelain`. If non-empty: "You have uncommitted changes:\n{output}\nWould you like to `git stash` them before proceeding, or continue anyway?" Wait for user response. Do NOT silently proceed.

## State Management

State is persisted to `.oss-prep/state.json` following the schema in `state-schema.json`.

### Atomic Writes

Every state write uses this sequence:
1. Write JSON to `.oss-prep/state.json.tmp`
2. Validate the written file is valid JSON (read it back and parse)
3. Rename `.oss-prep/state.json.tmp` to `.oss-prep/state.json`

If validation or rename fails, report the error and do NOT advance state.

### Post-Completion Ordering

State is written to disk AFTER the phase commit succeeds, never before. If the commit fails, state is NOT advanced. On resume, the orchestrator re-executes the failed phase rather than skipping it.

### Resume Support

On startup, if `.oss-prep/state.json` exists:
1. Validate the file is parseable JSON. If corrupted, offer to reset.
2. Display a summary of completed phases with their per-phase finding counts from `phase_findings`.
3. Offer the user two options:
   - **Continue from Phase {N}** (the next incomplete phase)
   - **Reset and start over** (delete `.oss-prep/` directory and reinitialize)
4. Wait for explicit user confirmation before dispatching the next phase.

If `.oss-prep/state.json` does not exist, create `.oss-prep/` directory, initialize state from `state-schema.json` defaults (set `started_at` to current ISO 8601 timestamp, `project_root` to `git rev-parse --show-toplevel`), write initial state, and proceed to Phase 0.

## Phase Sequencing Loop

Iterate phases 0-9 in order. For each phase:

### 1. Pre-Dispatch Checks

- **Phase 3 license pre-check**: Before dispatching Phase 3, check if a LICENSE file exists. If not, prompt the user for license selection (MIT, Apache 2.0, GPL 3.0, BSD 2-Clause, BSD 3-Clause, MPL 2.0, ISC, Unlicense, or custom). Store the choice in `state.license_choice` before dispatching. This is necessary because the sub-agent cannot interact with the user (DD-4).
- **Phase 5 license fallback**: Before dispatching Phase 5, check `state.license_choice`. If empty (Phase 3 was skipped), prompt the user for license selection using the same menu as Phase 3, store in `state.license_choice`, then dispatch.

### 2. Sub-Agent Dispatch

Dispatch a Task sub-agent with `model: "opus"` using this prompt:

```
You are executing Phase {N} ({Name}) of the oss-prep skill.

Read the phase file at: {skill_dir}/phases/{NN}-{slug}.md

Current state:
{state JSON}

Project root: {project_root}

Grounding Requirement:
Every finding you report MUST be grounded in actual code artifacts. Each finding must include at least one of: file path and line number, commit hash, grep/glob match output, or tool output. Zero findings is a valid result — do not invent findings. Never report a file path without verifying it exists, never report a line number without reading that line, never report a commit hash without retrieving it from git. If uncertain, classify as MEDIUM and note the uncertainty. Prefer false negatives over false positives.

Execute all steps in the phase file. When complete, report:
1. Finding counts: {total, critical, high, medium, low}
2. Key highlights: 3-5 most important findings or actions
3. Actions taken: files created, modified, or deleted
4. Files to stage: explicit list of file paths to commit
```

For Phase 3 and Phase 5, append to the prompt: `License choice: {state.license_choice}`

The orchestrator NEVER reads files under `phases/` or `patterns/` into its own context. It passes the phase file path to the sub-agent, and the sub-agent reads it.

### 3. Phase 8 Two-Dispatch Pattern

Phase 8 (History Flatten) uses two separate sub-agent dispatches:

**Dispatch 1 — Assessment**: Sub-agent reads `phases/08-history-flatten.md` and executes the assessment and pre-flatten checklist steps. Returns the assessment summary and checklist. If the user requested dry-run mode at Phase 8 entry, the sub-agent also reports "What would change" and stops.

**Orchestrator gate**: Present the confirmation gate requiring the user to type `flatten` to confirm. This is stronger than standard phase gates — a simple "approve" is not sufficient.

**Commit message prompt**: After the user types `flatten`, ask: "The default commit message is: 'Initial public release'. Would you like to customize it?" Pass the chosen message to Dispatch 2.

**Dispatch 2 — Execution** (only if user typed `flatten`): Sub-agent reads `phases/08-history-flatten.md` and executes the flatten operation and post-flatten verification. Returns execution results and verification scan findings.

If the user declines: Update state with `history_flattened: false`, handle the decline path, and present the standard phase gate.

If the user types `dry-run`: Present the dry-run report from Dispatch 1 data (no second dispatch). Set `history_flattened: false` and proceed to the standard phase gate.

### 4. Phase Summary and User Gate

After the sub-agent returns, present the summary to the user following the Phase-Gating Interaction Model below.

### 5. Commit with Scoped Staging

After user approval, commit with scoped staging:
- Stage only phase-specific output files and `.oss-prep/state.json`: `git add -- .oss-prep/state.json {file1} {file2} ...` where the file list comes from the sub-agent's "Files to stage" report.
- NEVER use `git add -A`, `git add .`, or any unscoped staging command.
- Commit message: `oss-prep: phase {N} complete -- {phase-name}`
- If the sub-agent reports no files to stage, stage only `.oss-prep/state.json`.

### 6. State Update

After the commit succeeds, update state atomically:
- Add N to `phases_completed`
- Update `findings` with new cumulative counts
- Store per-phase counts in `phase_findings`
- Set `phase` to N+1
- Write state using atomic write pattern

### Skip Handling

If the user chooses "Skip this phase":
- Add N to `phases_completed`
- Set `phase_findings[N]` to `{ total: 0, critical: 0, high: 0, medium: 0, low: 0, status: "skipped" }`
- Do NOT update cumulative `findings`
- Set `phase` to N+1
- Commit only `.oss-prep/state.json` (no phase output files)

## Sub-Agent Failure Handling

If a sub-agent dispatch fails (Task tool returns an error, times out, or returns empty/unparseable output):

1. **Retry once** with a simplified prompt (shorter instructions, same phase file path and state).
2. If the retry also fails, **fall back to executing the phase in the main orchestrator context** by reading the phase file directly. Display a warning: "Sub-agent failed after retry. Executing Phase {N} in main context. Context preservation is degraded for this phase."
3. Log the failure in state under `phase_failures`: `{ "phase": N, "attempt": 2, "error": "{description}", "fallback": "main_context" }`.

---

## Phase-Gating Interaction Model

Every phase follows this strict interaction loop:

### 1. Phase Entry
Briefly announce the phase: what it does, what it checks, and approximately how long it may take for large repos.

### 2. Execution
Sub-agent runs the phase. The orchestrator does not execute phase logic.

### 3. Phase Summary
Present a summary to the user containing:
- **Finding counts by severity**: "N findings (X critical, Y high, Z medium, W low)"
- **Key highlights**: The 3-5 most important findings or actions, with brief descriptions
- **Actions taken**: What was generated, scanned, or modified during this phase

### 4. User Approval Gate
Ask the user to choose one of:
- **Approve and continue** — Accept the phase results and move to the next phase
- **Review details** — Show the full detailed findings for this phase (progressive disclosure)
- **Request changes** — Modify specific findings, re-run specific checks, or adjust remediation proposals
- **Skip this phase** — Mark as skipped and move on (with a note in the final report)

**CRITICAL: Do NOT advance to the next phase until the user explicitly responds.** Never auto-advance, even if zero findings are reported. The user must always confirm.

### Progressive Disclosure

- **Phase summaries** show counts and highlights only — keep them concise and scannable.
- **Detailed findings** are shown only when the user asks ("Show me the details", "Review details", or similar).
- **The final report** (Phase 9) contains everything: all phases, all findings, all details in one document.

This keeps the interaction lightweight while ensuring nothing is hidden.

### Request Changes Handling

If the user chooses "Request changes":
1. Collect the user's specific change requests
2. Re-dispatch the phase sub-agent with the original prompt plus: "Previous run summary: {sub-agent summary}. User requested changes: {user input}. Re-execute only the affected checks and update findings accordingly."
3. Present updated results through the same gate cycle

---

## Grounding Requirement

**Every finding reported by this skill MUST be grounded in actual code artifacts.** This is a non-negotiable requirement that applies to every phase.

### What "Grounded" Means
Each finding must include at least one of:
- **File path and line number** (e.g., `src/config.js:42`)
- **Commit hash** (e.g., `abc1234` for history-based findings)
- **Grep/Glob match output** (the actual matched text)
- **Tool output** (e.g., `npm audit` results, build error messages)

### Zero Findings Is a Valid Result
If a pattern search returns no results, report **zero findings**. Do not invent plausible-sounding findings to appear thorough. A clean scan is a good result.

### Anti-Hallucination Rules
- Never report a file path without having verified it exists (via Glob, Read, or Grep)
- Never report a line number without having read that line
- Never report a commit hash without having retrieved it from git
- Never claim a dependency has a specific license without having read the license declaration
- If uncertain whether something is a true positive, classify it as MEDIUM severity and note the uncertainty explicitly
- Prefer false negatives (missing a finding) over false positives (fabricating a finding) — the user can always re-run or manually check

---

## Phase Roadmap

| Phase | Name | Description |
|-------|------|-------------|
| 0 | Reconnaissance | Detect project root, create preparation branch, build project profile |
| 1 | Secrets & Credentials Audit | Scan working tree and git history for API keys, tokens, passwords, and other credentials |
| 2 | PII Audit | Scan working tree and git history for email addresses, personal names, internal identifiers |
| 3 | Dependency Audit | Inventory all dependencies, check license compatibility, flag private/internal packages |
| 4 | Code Architecture & Quality Review | Architecture summary, coding standards, build verification, test execution, code quality flags |
| 5 | Documentation Generation | Generate or validate README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CHANGELOG |
| 6 | GitHub Repository Setup & CI/CD | Generate issue/PR templates, CI workflow, review .gitignore completeness |
| 7 | Naming, Trademark & Identity Review | Check name availability on registries, scan for internal identity leaks and telemetry |
| 8 | History Flatten | Assess history risk, present pre-flatten checklist, flatten to single commit (with user confirmation) |
| 9 | Final Readiness Report | Generate comprehensive report with risk matrix, phase details, and launch checklist |

---

## Sub-Agent Model Policy

All sub-agents spawned via the Task tool MUST use `model: "opus"`. This is a hard requirement — never use `sonnet` or `haiku` for sub-agents in this skill.
