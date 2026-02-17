---
name: oss-prep
description: "Prepare a private git repository for public open-source release. Runs a 10-phase audit covering secrets, PII, dependencies, code quality, documentation, CI/CD, naming, and history — then produces a comprehensive readiness report."
user-invocable: true
argument-hint: "Run from the root of any git repository you want to prepare for open-source release"
---

Thin orchestrator for the oss-prep skill. All phase logic lives in `phases/00-recon.md` through `phases/10-launch.md`. Phases 0-9 form the standard audit loop; Phase 10 (Launch Automation) is an optional post-loop step. This file manages state, sequencing, sub-agent dispatch, user gates, and commits. It never reads phase or pattern files into its own context.

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
2. **Schema migration**: If `schema_version` equals 1, migrate to v2:
   a. Add missing fields with defaults: `deferred_actions: []`, `user_context: {}`, `audit_mode: "individual"`, `github_repo_url: ""`
   b. Set `schema_version` to 2
   c. Write the migrated state atomically (write to `.oss-prep/state.json.tmp`, validate JSON, rename to `.oss-prep/state.json`)
   d. Display: "Migrated state from schema v1 to v2."
3. Display a summary of completed phases with their per-phase finding counts from `phase_findings`.
4. Offer the user two options:
   - **Continue from Phase {N}** (the next incomplete phase)
   - **Reset and start over** (delete `.oss-prep/` directory and reinitialize)
5. Wait for explicit user confirmation before dispatching the next phase.

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
5. Structured findings: a JSON array where each finding has these fields:
   - `id`: string, format `S{phase}-{seq}` (e.g., `S1-1`, `S1-2`)
   - `severity`: string, one of `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`
   - `effort`: string, one of `auto-fix`, `quick-fix`, `decision-needed`, `deferred`
   - `summary`: string, one-line description of the finding
   - `file`: string or null, file path where the finding was detected
   - `line`: integer or null, line number within the file
   - `deferred_to`: integer or null, target phase number if deferred

   The structured findings list is separate from the prose summary above. The orchestrator extracts ONLY the structured list for persistence to disk. If there are zero findings, return an empty array `[]`.
```

For Phase 3 and Phase 5, append to the prompt: `License choice: {state.license_choice}`

The orchestrator NEVER reads files under `phases/` or `patterns/` into its own context. It passes the phase file path to the sub-agent, and the sub-agent reads it.

### 3. Phase 8 Two-Dispatch Pattern

Phase 8 (History Flatten) uses two separate sub-agent dispatches:

**Dispatch 1 — Assessment**: Sub-agent reads `phases/08-history-flatten.md` and executes the assessment and pre-flatten checklist steps. Returns the assessment summary and checklist. If the user requested dry-run mode at Phase 8 entry, the sub-agent also reports "What would change" and stops.

**Orchestrator gate**: Present the confirmation gate requiring the user to type `flatten` to confirm. This is stronger than standard phase gates — a simple "approve" is not sufficient.

**Commit message prompt**: After the user types `flatten`, ask: "The default commit message is: 'Initial public release'. Would you like to customize it?" Pass the chosen message to Dispatch 2.

**Dispatch 2 — Execution** (only if user typed `flatten`): Sub-agent reads `phases/08-history-flatten.md` and executes the flatten operation and post-flatten verification. Returns execution results and verification scan findings.

**Deferred action resolution**: After Dispatch 2 returns, check the sub-agent output for a `deferred_resolved` list. For each item in the list, update the corresponding entry in `state.deferred_actions` with `status: "resolved"` before writing state.

If the user declines: Update state with `history_flattened: false`, handle the decline path, and present the standard phase gate.

If the user types `dry-run`: Present the dry-run report from Dispatch 1 data (no second dispatch). Set `history_flattened: false` and proceed to the standard phase gate.

### 4. Phase Summary and User Gate

After the sub-agent returns, present the summary to the user following the Phase-Gating Interaction Model below.

### 5. Commit with Scoped Staging

After user approval, commit with scoped staging:
- Stage only phase-specific output files, `.oss-prep/state.json`, and `.oss-prep/phase-{N}-summary.json`: `git add -- .oss-prep/state.json .oss-prep/phase-{N}-summary.json {file1} {file2} ...` where the file list comes from the sub-agent's "Files to stage" report.
- NEVER use `git add -A`, `git add .`, or any unscoped staging command.
- Commit message: `oss-prep: phase {N} complete -- {phase-name}`
- If the sub-agent reports no files to stage, stage only `.oss-prep/state.json` and `.oss-prep/phase-{N}-summary.json`.

### 5b. Write Phase Summary

After the commit succeeds and before updating state, write the phase summary file:

1. Extract the structured findings array from the sub-agent's return (item 5 in its report).
2. Construct the phase summary JSON object with: `phase` (integer), `name` (string), `status` ("completed"), `findings` (the structured array), and `counts` (object with total, critical, high, medium, low — computed from the findings array).
3. Write the summary using the atomic write pattern:
   a. Write JSON to `.oss-prep/phase-{N}-summary.json.tmp`
   b. Validate the written file is valid JSON (read it back and parse)
   c. Rename `.oss-prep/phase-{N}-summary.json.tmp` to `.oss-prep/phase-{N}-summary.json`
4. If the sub-agent returned no structured findings (empty array or missing), write the summary with `"findings": []` and all counts at 0.
5. If the atomic write fails, report the error but do NOT block phase advancement — the phase commit already succeeded. Log a warning: "Failed to write phase summary file for Phase {N}. Finding details will not be available for this phase in the Mid-Point Review or final report."

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

## Phase Summary File Format

Each phase produces a `.oss-prep/phase-{N}-summary.json` file containing the full structured findings from that phase. This file is written by step 5b after the phase commit succeeds.

### Canonical JSON Structure

```json
{
  "phase": 1,
  "name": "Secrets & Credentials Audit",
  "status": "completed",
  "findings": [
    {
      "id": "S1-1",
      "severity": "MEDIUM",
      "effort": "auto-fix",
      "summary": "AWS region hardcoded in config.js:42",
      "file": "src/config.js",
      "line": 42,
      "deferred_to": null
    }
  ],
  "counts": { "total": 1, "critical": 0, "high": 0, "medium": 1, "low": 0 }
}
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `phase` | integer | Phase number (0-9) |
| `name` | string | Human-readable phase name |
| `status` | string | `"completed"` or `"skipped"` |
| `findings` | array | Structured finding objects (see below) |
| `counts` | object | Aggregate counts: `total`, `critical`, `high`, `medium`, `low` (all integers) |

### Finding Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Format `S{phase}-{seq}`, e.g., `S1-1`, `S3-12` |
| `severity` | string | One of: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` |
| `effort` | string | One of: `auto-fix`, `quick-fix`, `decision-needed`, `deferred` |
| `summary` | string | One-line description of the finding |
| `file` | string or null | File path where the finding was detected, or `null` for non-file findings |
| `line` | integer or null | Line number within the file, or `null` if not applicable |
| `deferred_to` | integer or null | Target phase number if deferred (e.g., `8` for deferred to Phase 8), or `null` |

### Notes

- **Phase 0** produces no security findings. Its summary file has `"findings": []` and all counts at 0.
- **Skipped phases** produce a summary file with `"status": "skipped"`, `"findings": []`, and all counts at 0.
- **Both `state.json` and phase summary files are maintained.** `state.json` retains lightweight aggregate counts for quick resume display. Summary files store full detail for the Mid-Point Review, Phase 9 final report, and drill-down.
- The `counts` object is computed from the `findings` array and MUST be consistent with it.

## Post-Phase-9: Optional Phase 10 Fork

After the Phase 9 user gate is approved and the Phase 9 commit succeeds (the standard loop completes with `phase` set to 10 by step 6), the orchestrator presents a fork. This is post-loop logic — it does not modify the 0-9 loop.

### 1. Present the Fork

Present the Phase 10 opt-in decision to the user:

> The audit and preparation is complete. Would you like to:
>
> (a) Stop here — the project is ready for manual launch. Use the launch checklist in the readiness report.
> (b) Continue to Phase 10 (Launch Automation) — automate GitHub repo creation, settings, and initial release.

Use **AskUserQuestion** when available with these two options, with plain-text fallback (consistent with the existing gate pattern).

### 2. "Stop Here" Path

If the user chooses "Stop here":

1. `phase` is already 10 from the loop's standard state update (step 6 sets `phase: N+1` after Phase 9). No additional phase change is needed.
2. Commit `.oss-prep/state.json` with scoped staging and message: `oss-prep: run complete -- stopped after phase 9`
3. Display: "OSS Prep complete. Your readiness report is at `{project_root}/oss-prep-report-{date}.md`. Good luck with your launch!"
4. The skill terminates.

### 3. "Continue to Phase 10" Path

If the user chooses "Continue to Phase 10":

1. `phase` is already 10 from the loop's standard state update. Phase 10's dispatch reads this as "Phase 10 is next to execute."
2. Run Phase 10 Pre-Dispatch Checks (collect the five inputs — see below).
3. Dispatch Phase 10 using the two-dispatch pattern (see "Phase 10 Two-Dispatch Pattern" below).
4. Phase 10's own state update sets `phase: 11` upon completion (whether launched or declined).

### Phase 10 Pre-Dispatch Checks

Before dispatching Phase 10's first sub-agent, the orchestrator collects five inputs from the user. These are passed as structured data in both dispatch prompts. Per DD-4, sub-agents cannot interact with users, so all interactive inputs must be resolved here.

1. **Repo owner**: Ask whether to create the repository under the user's personal GitHub account or an organization. If org is selected, prompt for the org name and validate via `gh api /orgs/{name}`. If the org returns 404, warn and ask again. If personal, resolve the username via `gh api /user --jq '.login'`.

2. **Repo name**: Pre-populate from Phase 7 namespace data if available (check `.oss-prep/phase-7-summary.json` for GitHub repo availability results). Otherwise, use the basename of `state.project_root`. Present the suggestion and allow the user to override. Validate: must match `^[a-zA-Z0-9._-]+$`, max 100 characters.

3. **Visibility**: Confirm public visibility with an explicit warning: "This will create a **PUBLIC** repository. All code, commit history, and issues will be visible to everyone on the internet." If the user declines public visibility, proceed to the decline path (Step 10.6 in the phase file).

4. **Version**: Suggest based on `state.readiness_rating`: Ready = v1.0.0, Ready with Caveats or Not Ready = v0.1.0. Allow the user to override.

5. **Funding channels**: Ask if the user wants to set up funding (GitHub Sponsors, Open Collective, Ko-fi, or none). For each selected channel, collect the required identifier (username/slug). If none, `funding_channels` is an empty array.

### Phase 10 Two-Dispatch Pattern

Phase 10 (Launch Automation) uses two separate sub-agent dispatches, following the same pattern as Phase 8:

**Dispatch 1 — Assessment**: Sub-agent reads `phases/10-launch.md` and executes the pre-launch readiness check and summary (Steps 10.1–10.2). Returns the assessment results (gh CLI auth status, state prerequisites, branch info, repo name availability) and pre-launch summary to the orchestrator. No repository creation or code push occurs.

Dispatch prompt includes: the standard state JSON, project root, pre-dispatch inputs (repo owner, repo name, visibility, version, funding channels), and the grounding requirement.

**Orchestrator gate**: Present the `launch` confirmation gate. The user must type exactly `launch` (case-insensitive) to proceed. Responses of `y`, `yes`, `ok`, `sure`, or any other input do NOT trigger the launch — they are treated as a decline. The gate message states: "This will create a **PUBLIC** repository at `{owner}/{repo}` and push all code. This action cannot be fully undone — the repository will be publicly visible immediately."

**Branch handling** (orchestrator, after `launch` confirmed): Check the current branch:
- On `oss-prep/ready`: offer to merge to `main` first ("Recommended — `main` will become the default branch on GitHub."). If accepted, run `git checkout main && git merge oss-prep/ready --no-edit`.
- On `main`: push directly, no action needed.
- On any other branch: warn and ask which branch should become the default.

The branch merge (if accepted) is performed by the orchestrator before Dispatch 2, not by the sub-agent.

**Dispatch 2 — Execution** (only if user typed `launch`): Sub-agent reads `phases/10-launch.md` and executes all GitHub operations (Steps 10.4–10.5): repo creation, settings configuration, label creation, FUNDING.yml generation, release creation, badge fixup, and post-launch verification. Returns execution results, verification status, and `github_repo_url`.

**Decline path**: If the user declines (any response other than `launch`), the orchestrator acknowledges the decision, sets `phase: 11` and `phase_findings["10"]` with `status: "skipped"`, adds 10 to `phases_completed`, commits state, and terminates the skill. The repository is not created.

**State update after Phase 10**: After Dispatch 2 succeeds (or after the decline path), update state atomically:
- Set `phase` to `11`
- Add `10` to `phases_completed`
- Set `github_repo_url` to `https://github.com/{owner}/{repo}` (if launched) or `""` (if declined)
- Set `phase_findings["10"]` with `status: "completed"` (if launched) or `"skipped"` (if declined)
- Cumulative `findings` are unchanged (Phase 10 does not produce audit findings)
- Commit `.oss-prep/state.json` with scoped staging and message: `oss-prep: phase 10 complete -- launch-automation`

---

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
| 10 | Launch Automation *(optional, post-loop)* | Create GitHub repository, configure settings, create labels, initial release, badge fixup |

> **Note**: Phases 0-9 form the standard audit and preparation loop. Phase 10 is an optional post-loop step offered after Phase 9 completes (see "Post-Phase-9: Optional Phase 10 Fork" above). Phase 10 is never included in `audit_mode: "batch"` ranges.

---

## Sub-Agent Model Policy

All sub-agents spawned via the Task tool MUST use `model: "opus"`. This is a hard requirement — never use `sonnet` or `haiku` for sub-agents in this skill.
