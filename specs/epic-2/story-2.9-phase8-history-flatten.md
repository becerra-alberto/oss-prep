---
id: "2.9"
epic: 2
title: "Extract Phase 8: History Flatten with Safety Hardening"
status: done
source_prd: "tasks/prd-oss-prep-v2.md"
priority: critical
estimation: large
depends_on: ["1.1"]
---

# Story 2.9 — Extract Phase 8: History Flatten with Safety Hardening

## User Story
As a developer preparing a repo for open-source release, I want the history flatten phase extracted into a self-contained phase file with four critical safety improvements so that the most destructive operation in the skill has proper backup, scoped deletion, pre-flight checks, and a dry-run mode.

## Technical Context
Phase 8 content lives in SKILL.md between the `<!-- PHASE_8_START -->` and `<!-- PHASE_8_END -->` markers (approximately lines 2942-3217). It covers Steps 8.1 through 8.8: history assessment, pre-flatten checklist, confirmation gate, flatten execution (orphan branch procedure), post-flatten verification scan, decline path, phase summary, and state update.

The extracted file must be self-contained per the CLAUDE.md extraction rules: header block, declared I/O, execution steps, finding format, and user gate.

**Phase 8 is the most dangerous phase in the entire skill.** It performs an irreversible orphan commit creation that permanently destroys all commit history, blame attribution, tags, and branch references on the preparation branch. The v1 implementation has FOUR known safety gaps that this story must fix.

### CRITICAL BUG FIXES (PRD FR-22 through FR-25, AC-2.9.2 through AC-2.9.5)

**Bug Fix 1 -- Backup ref before flatten (FR-22, AC-2.9.2)**
The v1 has NO backup mechanism before the destructive flatten. If something goes wrong during the orphan checkout, the user's preparation branch work is lost.

Fix: Before the flatten procedure begins, create a backup reference:
```bash
git update-ref refs/oss-prep/pre-flatten oss-prep/ready
```
The confirmation prompt must mention this backup and explain how to restore:
```bash
git checkout -B oss-prep/ready refs/oss-prep/pre-flatten
```

**Bug Fix 2 -- Scoped tag deletion (FR-23, AC-2.9.3)**
The v1 deletes ALL tags in the repository:
```bash
git tag -l | xargs -r git tag -d      # BUG: deletes ALL tags
```
Fix: Scope tag deletion to only tags reachable from the preparation branch:
```bash
git tag --merged oss-prep/ready | xargs -r git tag -d    # FIXED: only reachable tags
```

**Bug Fix 3 -- Uncommitted change check (FR-24, AC-2.9.4)**
The v1 runs `git checkout --orphan` without checking for uncommitted changes. If the user has unstaged modifications, they could be silently incorporated into or lost during the orphan checkout.

Fix: Before the orphan checkout, run:
```bash
git status --porcelain
```
If output is non-empty, refuse to proceed and offer `git stash` as an alternative. Only continue after the working tree is clean.

**Bug Fix 4 -- Dry-run mode (FR-25, AC-2.9.5)**
The v1 has no way to preview what the flatten will do without executing it. Users must either commit to the irreversible operation or decline entirely.

Fix: Add a dry-run path that executes Steps 8.1-8.2 (assessment and checklist) and reports what would change:
- Number of commits that would be removed
- Tags that would be deleted (list them)
- Backup ref that would be created at `refs/oss-prep/pre-flatten`
- Statement: "No destructive operations were performed. This was a dry-run."

The orchestrator triggers dry-run mode when the user requests it. The phase file documents both the full-execution path and the dry-run path.

### Two Sub-Agent Dispatch Architecture (PRD Section 8, "Risk: Phase 8 Requires Two Sub-Agent Calls")

Phase 8 is unique because it has a mid-phase user gate (the "type flatten" confirmation) that is intentionally stronger than standard inter-phase gates. This splits execution into two parts:

1. **Sub-agent call 1 (Assessment)**: Runs Steps 8.1-8.2 (history assessment + pre-flatten checklist). Returns the assessment data and checklist to the orchestrator.
2. **Orchestrator gate**: Presents the confirmation gate (Step 8.3) to the user. The user types "flatten", "skip", or requests dry-run.
3. **Sub-agent call 2 (Execution)**: If user confirms with "flatten", dispatches a second sub-agent to run Steps 8.4-8.5 (backup ref creation, flatten execution, tag deletion, post-flatten verification). If user types "skip" or any other response, the orchestrator handles the decline path (Step 8.6) itself or via a simpler dispatch.

The phase file must clearly delineate which steps belong to which sub-agent call and document the orchestrator's gate responsibility between them.

### Post-flatten verification (AC-2.9.6)
The v1 post-flatten verification references "the patterns defined in Phase 1/2" which assumes those patterns are in context. The v2 extraction must reference `patterns/secrets.md` and `patterns/pii.md` instead, since the sub-agent will not have Phase 1 or Phase 2 in its context.

### Key content to extract:
- Step 8.1: History assessment (7 data points: commit count, contributor count, date range, branches, tags, secrets from Phase 1, PII from Phase 2, large files)
- Step 8.2: Pre-flatten checklist (what will be permanently lost)
- Step 8.3: Confirmation gate (stronger than standard gates -- requires typing "flatten")
- Step 8.4: Execute flatten (orphan branch procedure -- 6 substeps)
  - **NEW**: Backup ref creation before any destructive operation
  - **NEW**: Uncommitted change check before orphan checkout
  - **FIXED**: Scoped tag deletion (`git tag --merged` instead of `git tag -l`)
- Step 8.5: Post-flatten verification scan (secrets + PII using shared pattern libraries)
- Step 8.6: Decline path (alternative git filter-repo commands, risk warnings)
- Step 8.7: Phase summary
- Step 8.8: State update
- **NEW Step**: Dry-run mode path

### Content to preserve verbatim:
- History assessment bash commands and formatted table
- Pre-flatten checklist (5 bullet items of what will be permanently lost)
- Confirmation gate rules (only "flatten" proceeds, not "y" or "yes")
- Orphan branch procedure commands (with bug fixes applied)
- Post-flatten verification scan procedure (referencing patterns/secrets.md and patterns/pii.md)
- Decline path: alternative git filter-repo commands (4 examples)
- Decline path: risk warning about secrets/PII in unflattened history
- Phase summary template
- User approval gate

## Acceptance Criteria

### AC1: Phase file structure follows extraction rules
- **Given** the CLAUDE.md extraction rules requiring header block, I/O declarations, steps, finding format, and user gate
- **When** Phase 8 is extracted to `phases/08-history-flatten.md`
- **Then** the file starts with a header block containing: phase number (8), phase name (History Flatten), inputs list, and outputs list

### AC2: Inputs and outputs are explicitly declared
- **Given** Phase 8 reads cumulative state and modifies git history
- **When** the I/O declarations are written
- **Then** inputs include: `state.project_root`, `state.prep_branch`, `state.phases_completed`, `state.findings`, `state.phase_findings` (specifically phase 1 and phase 2 findings for the assessment), and `patterns/secrets.md` and `patterns/pii.md` (for post-flatten verification)
- **And** outputs include: `state.history_flattened` (boolean), backup ref `refs/oss-prep/pre-flatten` (if flatten executed), modified `oss-prep/ready` branch (single orphan commit if flattened), post-flatten verification results, state updates (phase_findings for phase 8, cumulative findings, phases_completed)

### AC3: Backup ref is created before any destructive operation
- **Given** the v1 has no backup mechanism (PRD FR-22)
- **When** the flatten execution step is extracted
- **Then** before any destructive git operation, the phase creates: `git update-ref refs/oss-prep/pre-flatten oss-prep/ready`
- **And** the confirmation prompt in Step 8.3 mentions the backup: "A backup of the current branch state will be saved to `refs/oss-prep/pre-flatten`"
- **And** the confirmation prompt includes restore instructions: `git checkout -B oss-prep/ready refs/oss-prep/pre-flatten`
- **And** the backup ref creation occurs AFTER the user confirms but BEFORE the orphan checkout

### AC4: Tag deletion is scoped to reachable tags only
- **Given** the v1 deletes ALL tags with `git tag -l | xargs -r git tag -d` (PRD FR-23)
- **When** the flatten execution step is extracted
- **Then** tag deletion uses `git tag --merged oss-prep/ready | xargs -r git tag -d`
- **And** the pre-flatten checklist updates the tag line to reference only tags reachable from the preparation branch, not all tags
- **And** the history assessment (Step 8.1) tag listing is preserved using `git tag -l` (assessment lists ALL tags for information, deletion only affects reachable ones)

### AC5: Uncommitted change check blocks flatten if dirty
- **Given** the v1 runs orphan checkout without checking for uncommitted changes (PRD FR-24)
- **When** the flatten execution step is extracted
- **Then** before `git checkout --orphan`, the phase runs `git status --porcelain`
- **And** if output is non-empty, the flatten is REFUSED with a message explaining that uncommitted changes must be resolved
- **And** `git stash` is offered as an alternative: "Run `git stash` to save your changes, then re-run Phase 8"
- **And** the phase does NOT silently proceed with uncommitted changes

### AC6: Dry-run mode shows what would change without executing
- **Given** the v1 has no dry-run capability (PRD FR-25)
- **When** the phase is extracted
- **Then** a dry-run path is documented that executes Steps 8.1-8.2 (assessment and checklist) only
- **And** the dry-run output reports: number of commits that would be removed, list of tags that would be deleted (scoped to `git tag --merged oss-prep/ready`), statement that backup ref would be created at `refs/oss-prep/pre-flatten`, and explicit statement: "No destructive operations were performed. This was a dry-run."
- **And** the phase file documents that the orchestrator triggers dry-run mode based on user request
- **And** the dry-run path sets `state.history_flattened` to false and proceeds to the phase summary

### AC7: Two sub-agent dispatch boundaries are clearly marked
- **Given** Phase 8 requires two sub-agent calls with an orchestrator gate between them (PRD Section 8)
- **When** the phase is extracted
- **Then** the file clearly delineates which steps belong to sub-agent call 1 (assessment): Steps 8.1-8.2
- **And** which steps belong to sub-agent call 2 (execution): Steps 8.4-8.5 (including backup ref, uncommitted check, flatten, verification)
- **And** the file documents that Step 8.3 (confirmation gate) is an orchestrator responsibility, not executed by the sub-agent
- **And** the file documents that Step 8.6 (decline path) is handled by the orchestrator after the user declines

### AC8: Post-flatten verification references shared pattern libraries
- **Given** the v1 references "the patterns defined in Phase 1/2" which would not be in the sub-agent's context (PRD AC-2.9.6)
- **When** the post-flatten verification step is extracted
- **Then** secret detection references `patterns/secrets.md` for the complete pattern library
- **And** PII detection references `patterns/pii.md` for the complete pattern library
- **And** the PII allowlist is included inline in Phase 8's post-flatten verification section (duplicated from Phase 2), because the Phase 8 sub-agent does not read `phases/02-pii.md` and the allowlist is not in `patterns/pii.md` (per PRD AC-2.3.3, it is PII-audit-specific). The duplication is acceptable because the allowlist is a static reference list (~50 lines) and Phase 8's verification is a critical safety check that must not miss allowlisted values.
- **And** the single-commit diff scan command is preserved: `git show --format= --diff-filter=A HEAD`

### AC9: Confirmation gate preserves stronger-than-standard rules
- **Given** Phase 8's confirmation gate is intentionally stronger than standard inter-phase gates
- **When** the confirmation gate is extracted
- **Then** the requirement to type exactly "flatten" (case-insensitive) is preserved
- **And** the rule that "y", "yes", "ok", "sure" do NOT trigger the flatten is preserved
- **And** the rule that ambiguous or negative responses proceed to the decline path is preserved
- **And** the custom commit message prompt is preserved ("The default commit message is: 'Initial public release'. Would you like to customize it?")

### AC10: Decline path is preserved with alternatives and risk warnings
- **Given** the decline path provides alternative commands and risk warnings
- **When** the decline path is extracted
- **Then** the acknowledgment message is preserved
- **And** all 4 git filter-repo alternatives are preserved: remove specific file, remove by pattern, replace string, strip large blobs
- **And** the risk warning about secrets/PII remaining in unflattened history is preserved
- **And** the instruction to proceed to Phase 9 without blocking is preserved
- **And** the `history_flattened: false` state update is documented

### AC11: History assessment data points are complete
- **Given** the v1 assessment collects 8 data points
- **When** the assessment step is extracted
- **Then** all 8 data points are preserved with their exact bash commands: total commit count, unique contributor count, date range, branch list, tag list, secrets count (from Phase 1 state), PII count (from Phase 2 state), large files in history (>1MB)
- **And** the formatted assessment table is preserved
- **And** the large files listing command is preserved verbatim (git rev-list + git cat-file + awk pipeline)

### AC12: Self-contained execution
- **Given** a sub-agent receives only this phase file, the current state, and the project root
- **When** the sub-agent reads `phases/08-history-flatten.md`
- **Then** it contains all information needed to execute its portion of Phase 8 without referencing SKILL.md or any other phase file (except patterns/secrets.md and patterns/pii.md which are referenced by path for the post-flatten scan)
- **And** the two sub-agent call boundaries are clear enough that the orchestrator knows exactly which steps to include in each dispatch

## Test Definition

### Structural Tests
- File exists at `phases/08-history-flatten.md`
- File begins with a header block containing: Phase number (8), Phase name (History Flatten), Inputs section, Outputs section
- File contains all step numbers: 8.1 through 8.7 (8.8 state update documented as expected state change)
- File contains the backup ref command: `git update-ref refs/oss-prep/pre-flatten oss-prep/ready`
- File contains the scoped tag deletion: `git tag --merged oss-prep/ready`
- File does NOT contain the v1 bug: `git tag -l | xargs -r git tag -d` in the execution step (it may appear in the assessment step for listing purposes only)
- File contains the uncommitted change check: `git status --porcelain`
- File contains the dry-run mode section with explicit "No destructive operations" statement
- File contains sub-agent dispatch boundary markers (clear delineation of call 1 vs call 2)
- File references `patterns/secrets.md` in the post-flatten verification
- File references `patterns/pii.md` in the post-flatten verification
- File contains the confirmation gate requiring "flatten" (not "y" or "yes")
- File contains the user gate prompt with options
- File does NOT contain content from other phases (no Phase 1 pattern definitions inline, no Phase 5 documentation content)

### Bug Fix Verification Tests
- **Backup ref**: Search for `refs/oss-prep/pre-flatten` -- must appear in both the execution step and the confirmation prompt
- **Scoped deletion**: Search for `--merged oss-prep/ready` -- must appear in the tag deletion command
- **v1 bug absent**: The string `git tag -l | xargs -r git tag -d` must NOT appear in Step 8.4 (it can appear in Step 8.1 for listing)
- **Uncommitted check**: Search for `git status --porcelain` -- must appear before `git checkout --orphan`
- **Stash offer**: Search for `git stash` -- must appear as the suggested alternative when uncommitted changes block the flatten
- **Dry-run**: Search for "dry-run" or "dry run" -- must appear as a documented execution path
- **Dry-run no-op**: The dry-run section must contain a statement that no destructive operations were performed

### Content Verification Tests
- History assessment contains all 8 data point bash commands
- Pre-flatten checklist contains 5 bullet items about what will be permanently lost
- Confirmation gate states only "flatten" (case-insensitive) proceeds; "y", "yes", "ok", "sure" do NOT
- Orphan procedure follows the sequence: backup ref, uncommitted check, checkout --orphan, git add -A, git commit, branch rename, commit count verification, scoped tag deletion
- Post-flatten verification references shared pattern files by path (`patterns/secrets.md`, `patterns/pii.md`), not by inlining secret/PII patterns
- Post-flatten verification contains an inline copy of the PII allowlist (since it is not in `patterns/pii.md`)
- Decline path contains 4 git filter-repo alternative commands
- Decline path contains risk warning about secrets/PII in history
- Phase summary template includes: history assessed metrics, tags found, large files, decision (Flattened/Declined), post-flatten verification (if flattened), risk level (if declined)

## Files to Create/Modify
- `phases/08-history-flatten.md` -- extracted Phase 8 content with 4 safety bug fixes (create)
