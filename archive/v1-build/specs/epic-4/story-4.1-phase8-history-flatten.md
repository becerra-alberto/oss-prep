---
id: "4.1"
epic: 4
title: "Phase 8 — History Flatten"
status: pending
source_prd: "tasks/prd-oss-prep.md"
priority: high
estimation: large
depends_on: ["2.1", "2.2", "2.3", "3.1", "3.2", "3.3", "3.4"]
---

# Story 4.1 — Phase 8 — History Flatten

## User Story
As a developer preparing to open-source a private repo, I want the tool to assess my git history for risks and flatten it into a single clean commit so that secrets, PII, and embarrassing history in old commits are permanently eliminated before the repository goes public.

## Technical Context
This story adds the Phase 8 section to `SKILL.md`. Phase 8 is the most destructive operation in the entire skill -- it irreversibly replaces the preparation branch's history with a single orphan commit. Because of this, the phase has the strongest confirmation gate in the skill (stronger than file edits or deletions).

The implementation is instructional markdown telling Claude how to orchestrate the flatten. Key architectural decisions:

1. **History assessment draws on prior phases**: The secrets and PII findings from Phases 1-2 (stories 2.1, 2.2) are referenced to show the user what was found in history. This is why this story depends on 2.1 and 2.2 -- the Phase 8 instructions reference the cumulative findings from those phases to build the risk case for flattening.

2. **Three-step confirmation model**: (a) Present the history assessment with risk data, (b) present the pre-flatten checklist of what will be lost, (c) require an explicit confirmation that goes beyond a simple "y" -- the user must type a confirming phrase or sentence acknowledging the irreversibility. This maps to the "Destructive Operation Safeguards" in the PRD's design considerations.

3. **Orphan branch approach** (per DD-1): The flatten creates a new orphan branch, stages all current files, creates a single "Initial public release" commit, then force-updates the preparation branch to this commit. The original branch is never touched (per DD-2).

4. **Post-flatten verification**: After flattening, the skill re-runs the secrets and PII detection patterns from Phases 1-2 against the new single commit. This is a critical safety net -- if somehow sensitive data survived into the working tree, it is caught here. **Important**: The Phase 8 instructions must reference the pattern definitions in the Phase 1 and Phase 2 sections of SKILL.md by section heading (e.g., "Apply the secret detection patterns defined in Phase 1" and "Apply the PII detection patterns defined in Phase 2"). Do NOT redefine the patterns — cross-reference them to avoid duplication and drift.

5. **Decline path**: If the user declines flattening, the skill does not force it. Instead, it offers alternatives (manual `git filter-repo` commands for surgical history rewriting) and proceeds to Phase 9 with appropriate risk warnings that will appear in the final report.

6. **State block update**: After Phase 8 completes, the `history_flattened` field in the STATE block is set to `true` (if flattened) or remains `false` (if declined), and Phase 8 is added to `phases_completed`.

## Acceptance Criteria

### AC1: History Assessment Covers All Required Dimensions
- **Given** the skill has completed Phases 0-7 and enters Phase 8
- **When** the history assessment is presented to the user
- **Then** it includes: total commit count, number of unique contributors, date range (earliest to latest commit), list of branches, list of tags, count of secrets found in history (from Phase 1), count of PII found in history (from Phase 2), and count/list of large files (>1MB) found in history, all derived from actual git commands and prior phase findings rather than fabricated

### AC2: Pre-Flatten Checklist Clearly States What Will Be Lost
- **Given** the history assessment has been presented
- **When** the pre-flatten checklist is shown
- **Then** it explicitly lists each category of data that will be permanently lost: all commit history (N commits), all tags (listing them by name), all branch references on the preparation branch, git blame attribution for all files, and that all code will appear as authored in a single commit, and the checklist is formatted as a visible, scannable list (not buried in a paragraph)

### AC3: Confirmation Gate Requires Explicit Irreversibility Acknowledgment
- **Given** the pre-flatten checklist has been presented
- **When** the skill requests confirmation from the user
- **Then** the prompt includes the word "irreversible", explains that this cannot be undone, and requires the user to provide a confirming response beyond just "y" or "yes" (e.g., asking the user to type "flatten" or a phrase like "I understand this is irreversible"), and the skill does NOT proceed with the flatten if the user provides an ambiguous or negative response

### AC4: Orphan Branch Flatten Procedure Executes Correctly
- **Given** the user has provided explicit confirmation to flatten
- **When** the flatten is executed
- **Then** the instructions direct Claude to: (a) create a new orphan branch via `git checkout --orphan`, (b) stage all current files with `git add -A`, (c) create a single commit with a message defaulting to "Initial public release" but customizable by the user before committing, (d) force-update the preparation branch (`oss-prep/ready`) to point to this new commit, and (e) verify the resulting branch has exactly one commit

### AC5: Post-Flatten Verification Scan Confirms Clean State
- **Given** the flatten has completed successfully
- **When** the verification scan runs
- **Then** the skill re-runs the secret detection patterns from Phase 1 and the PII detection patterns from Phase 2 against the current working tree and the single commit, reports the results (expected: zero findings), and flags any remaining findings as CRITICAL issues that must be resolved before proceeding to Phase 9

### AC6: Decline Path Offers Alternatives Without Blocking Progress
- **Given** the user declines to flatten the history
- **When** the skill processes the decline
- **Then** it: (a) presents alternative selective history rewriting commands (e.g., `git filter-repo` invocations for removing specific files or patterns) that the user can run manually, (b) explains the risks of proceeding without flattening (secrets/PII may remain accessible in git history even if removed from the working tree), (c) records that history was NOT flattened in the STATE block (`history_flattened: false`), (d) proceeds to Phase 9 without blocking, and (e) ensures the final report in Phase 9 will reflect the unflattened status with appropriate risk warnings

## Test Definition

### Unit Tests
- Read the Phase 8 section of `SKILL.md` and verify it contains instructions for all six components: history assessment, pre-flatten checklist, confirmation gate, orphan branch procedure, post-flatten verification, and decline path
- Verify the history assessment instructions reference Phases 1 and 2 findings (not re-scanning from scratch for the assessment, though the post-flatten verification does re-scan)
- Verify the confirmation gate language includes the word "irreversible" and requires more than a single-character confirmation
- Verify the orphan branch procedure uses `git checkout --orphan` (not `git rebase` or `git reset`)
- Verify the post-flatten verification instructions explicitly re-run secret and PII patterns (not just a cursory check)
- Verify the decline path includes at least one concrete `git filter-repo` command example
- Verify the STATE block update instructions set `history_flattened` to the correct value based on user choice

### Integration/E2E Tests (if applicable)
- Invoke `/oss-prep` on a test repository with known secrets in git history, advance through Phases 0-7, and verify Phase 8 presents the correct history statistics (commit count, contributor count, etc.) matching actual git data
- Confirm that typing "y" or "yes" at the confirmation gate does NOT trigger the flatten (the gate requires a more explicit response)
- Execute the full flatten on a test repo and verify the preparation branch has exactly one commit afterward
- After flattening, verify the post-flatten verification scan runs and reports zero findings (assuming Phases 1-2 remediation was applied)
- Decline the flatten and verify the skill proceeds to Phase 9 with `history_flattened: false` in the STATE block

## Files to Create/Modify
- `skills/oss-prep/SKILL.md` — Add the Phase 8 (History Flatten) section covering: history assessment, pre-flatten checklist, confirmation gate, orphan branch flatten procedure, post-flatten verification scan, and decline path with alternatives (modify)
