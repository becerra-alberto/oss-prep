# Premortem 1 Report

**Date**: 2026-02-12
**Analyst**: Claude Opus 4.6
**Scope**: Full project plan for oss-prep v2 migration (stories 1.1, 2.1-2.10, 3.1)
**Source files**: PRD, 12 story specs, stories.txt, SKILL.md (3,483 lines), CLAUDE.md

---

## Critical Issues (fixed)

### C1: State schema field name mismatch — `phase_results` vs `phase_findings`

**Category**: Acceptance Criteria Quality
**Likelihood**: HIGH (would cause runtime key lookup failures)
**Risk of fix**: NONE
**Cost of fix**: Trivial (rename in one file)

**Problem**: Story 1.1 (state-schema.json) defined the per-phase finding counts field as `phase_results`, but the PRD (DD-2) defined it as `phase_findings`, and stories 2.6, 2.7, 2.8, 2.9, and 2.10 all reference `state.phase_findings`. If story 1.1 were implemented as written, every downstream phase would attempt to read/write a nonexistent `phase_findings` key and either silently fail or error.

**Fix applied**: Renamed all occurrences of `phase_results` to `phase_findings` in `specs/epic-1/story-1.1-foundation-patterns-state.md` (3 occurrences: field definition in AC3, required fields list in AC5, test definition #6).

**File**: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/specs/epic-1/story-1.1-foundation-patterns-state.md`

---

### C2: PII allowlist inaccessible to Phase 8 post-flatten verification

**Category**: Missing Edge Cases / Technical Risk
**Likelihood**: HIGH (Phase 8 verification would produce false positives on every run)
**Risk of fix**: LOW
**Cost of fix**: Small (clarify AC in one file, add test)

**Problem**: Story 2.9 (Phase 8) AC8 said the PII allowlist should be referenced from "its location in the PII patterns file or inline." However, per PRD AC-2.3.3 and story 1.1 AC2, the PII allowlist is explicitly NOT in `patterns/pii.md` -- it stays in `phases/02-pii.md`. The Phase 8 sub-agent only reads `phases/08-history-flatten.md`, `patterns/secrets.md`, and `patterns/pii.md`. It has no access to `phases/02-pii.md`. Without the allowlist, post-flatten PII verification would flag all test emails, Stripe test card numbers, localhost IPs, etc. as CRITICAL findings -- exactly the false positives the allowlist was designed to prevent.

**Fix applied**: Updated AC8 in story 2.9 to specify that the PII allowlist must be included inline in Phase 8's post-flatten verification section, with rationale for the duplication. Added a content verification test for allowlist presence.

**File**: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/specs/epic-2/story-2.9-phase8-history-flatten.md`

---

### C3: Orchestrator missing Phase 5 license fallback pre-check

**Category**: Missing Edge Cases / Dependency
**Likelihood**: MEDIUM (only triggers when Phase 3 is skipped, but this is a documented user flow)
**Risk of fix**: NONE
**Cost of fix**: Trivial (add one constraint to orchestrator spec)

**Problem**: Story 2.6 (Phase 5) documents that if `state.license_choice` is not set (Phase 3 was skipped), the orchestrator must handle the license selection prompt BEFORE dispatching the Phase 5 sub-agent. However, story 3.1 (orchestrator) only documented the Phase 3 license pre-check (constraint #4). The Phase 5 fallback was missing from the orchestrator's architectural constraints section. An implementer reading only story 3.1 could miss this requirement and dispatch Phase 5 without checking for the license choice, causing the sub-agent to fail silently or attempt user interaction (which Task sub-agents cannot do).

**Fix applied**: Added constraint #5 "Phase 5 license fallback" to story 3.1's architectural constraints section, mirroring the Phase 3 pre-check pattern.

**File**: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/specs/epic-3/story-3.1-orchestrator.md`

---

## Warnings (fixed / skipped with reason)

### W1: Phase 6 missing finding ID prefix convention (FIXED)

**Category**: Acceptance Criteria Quality
**Likelihood**: LOW (Phase 6 generates few findings; the summary format is defined)
**Risk of fix**: NONE
**Cost of fix**: Trivial

**Problem**: Every other audit phase defines an explicit finding ID prefix: S1-{N} (Phase 1), P2-{N} (Phase 2), D3-{N} (Phase 3), Q4-{N} (Phase 4), DOC5-{N} (Phase 5), N7-{N} (Phase 7). Phase 6 had no prefix defined in v1 or in the story spec. This would cause inconsistency in the final report's risk matrix, which aggregates findings across all phases.

**Fix applied**: Added `GH6-{N}` (GH6 = GitHub Setup Phase 6) as the finding ID prefix in story 2.7 AC9 and structural tests.

**File**: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/specs/epic-2/story-2.7-phase6-github-setup.md`

---

### W2: Story 2.2 says "Steps 1.1, 1.3-1.7" but v1 has 1.1 through 1.9 (SKIPPED)

**Category**: Acceptance Criteria Quality
**Likelihood**: LOW
**Reason for skipping**: The PRD AC-2.2.1 says "Steps 1.1, 1.3-1.7" but the full story spec (AC2-AC9) covers ALL steps 1.1 through 1.9 including 1.8 (Apply Remediations) and 1.9 (Update STATE). The structural test says "Steps (1.1 through 1.9)". The PRD shorthand was just listing the steps that differ from extraction (since 1.2 is replaced by a reference to patterns/secrets.md). The full spec correctly covers all 9 steps. No fix needed.

---

### W3: `commit.stage_paths` in Ralph config includes `SKILL.md` for all stories (SKIPPED)

**Category**: Technical Risk
**Likelihood**: NONE (staging an unmodified tracked file is a no-op)
**Reason for skipping**: The Ralph config `stage_paths: ["SKILL.md", "phases/", "patterns/", "state-schema.json"]` applies to all stories. For batch 2 stories that only create files under `phases/`, `git add SKILL.md` is harmless -- it does nothing if SKILL.md has no changes. No fix needed.

---

### W4: Story 2.5 (Phase 4) step range includes state update without orchestrator note (SKIPPED)

**Category**: Acceptance Criteria Quality
**Likelihood**: LOW
**Reason for skipping**: Story 2.5 says "Steps (4.1 through 4.4)" while stories 2.6, 2.7, 2.8, and 2.10 use the convention "Steps X through Y (state update is an orchestrator responsibility)". The inconsistency is minor and the implementer will understand from the orchestrator spec that state updates are the orchestrator's job. Fixing would require modifying an already-complete spec for cosmetic consistency.

---

## Observations

### O1: `{skill_dir}` path resolution undefined in orchestrator dispatch prompt

**Category**: Technical Risk
**Impact**: LOW

The orchestrator dispatch prompt (AC-7 in story 3.1) uses `{skill_dir}/phases/0{N}-{name}.md` but does not define how `{skill_dir}` is resolved. In Claude Code, the agent knows the skill's filesystem location from the skill loading mechanism, so this resolves naturally at runtime. However, the spec does not explicitly state how the orchestrator determines this path. An implementer should use the directory containing SKILL.md itself.

---

### O2: No explicit `phases/` and `patterns/` directory creation step

**Category**: Missing Edge Cases
**Impact**: NONE

Story 1.1 creates `patterns/secrets.md` and `patterns/pii.md` but does not mention creating the `patterns/` directory. Batch 2 stories create files under `phases/` without mentioning directory creation. The Write tool (and Claude Code's file writing) automatically creates intermediate directories, so this is not a functional risk. But if Ralph uses `mkdir -p` or similar as a pre-step, it's not documented. This is a non-issue in practice.

---

### O3: Phase 0 and Phase 8 do not have standard finding ID prefixes

**Category**: Acceptance Criteria Quality
**Impact**: NONE

Phase 0 (Reconnaissance) presents anomalies in a narrative format, not numbered findings. Phase 8 (History Flatten) re-uses Phase 1/2 finding formats for post-flatten verification and does not generate its own findings. Both are consistent with v1 behavior.

---

### O4: SKILL.md is 3,483 lines (~166KB) but this is within context limits

**Category**: Story Sizing
**Impact**: NONE

The SKILL.md source file is 3,483 lines. At approximately 48K tokens (measured by the Read tool's token count of ~48,236 tokens), it cannot be read in a single Read tool call (25K token limit per call). However, each phase extraction story only needs to read its specific phase section (identified by `<!-- PHASE_N_START -->` / `<!-- PHASE_N_END -->` markers), which ranges from ~100 to ~400 lines. Ralph implementers should use offset/limit parameters to read only the relevant section. This is manageable.

---

### O5: Batch 2 parallelism is safe -- no merge conflict risk

**Category**: Dependency & Ordering
**Impact**: NONE

All 10 batch 2 stories (2.1-2.10) create exactly one unique file each under `phases/`. No two stories touch the same file. The Ralph config uses `worktree` strategy with `auto_merge: true`, and the `stagger_seconds: 3` setting provides startup spacing. The `stories.txt` correctly identifies these as parallelizable. No merge conflict risk exists.

---

### O6: Story sizing is appropriate for all stories

**Category**: Story Sizing
**Impact**: NONE

The largest stories are 2.2 (Phase 1 Secrets, ~350 lines of SKILL.md source), 2.3 (Phase 2 PII, ~400 lines), 2.4 (Phase 3 Dependencies, ~330 lines), and 2.9 (Phase 8 History Flatten, ~280 lines plus 4 bug fixes). Each story creates exactly one file. The implementer reads one section of SKILL.md and writes one phase file. All stories are well within a single Claude context window. Story 3.1 (orchestrator) is the most complex, requiring synthesis of all phase files, but it does NOT need to read them -- it just references them by path. It only needs to read the v1 SKILL.md frontmatter, interaction model, grounding requirement, and roadmap table sections (~150 lines total).

---

### O7: Story dependency graph is correct and has no circular dependencies

**Category**: Dependency & Ordering
**Impact**: NONE

Verified dependency chain:
- Story 1.1: `depends_on: []` (batch 1, no dependencies)
- Stories 2.1-2.10: `depends_on: ["1.1"]` (batch 2, all depend only on 1.1)
- Story 3.1: `depends_on: ["2.1", "2.2", "2.3", "2.4", "2.5", "2.6", "2.7", "2.8", "2.9", "2.10"]` (batch 3, depends on all batch 2)

No circular dependencies. No implicit dependencies between batch 2 stories (each creates a unique file, each reads only from the unchanging v1 SKILL.md).

---

### O8: Review details flow (PRD OQ-5) is unresolved but non-blocking

**Category**: Missing Edge Cases
**Impact**: LOW

PRD OQ-5 asks how "Review details" works when the sub-agent has already returned and its detailed findings are not in the orchestrator's context. The orchestrator stores only summaries. Three options were listed but none was chosen. The implementation will need to decide: (a) include full details in sub-agent output (increases orchestrator context), (b) re-dispatch a sub-agent (expensive), or (c) point the user to read files directly. This is a UX design question that the implementer must resolve. It cannot cause a build failure but could cause user confusion.

---

### O9: Phase 9 finding ID prefix not defined

**Category**: Acceptance Criteria Quality
**Impact**: NONE

Phase 9 (Final Report) is a synthesis phase that does not generate new findings. It aggregates findings from all prior phases. No finding ID prefix is needed. Story 2.10 correctly does not define one.

---

### O10: `max_concurrent: 4` limits batch 2 to 4 parallel stories at a time

**Category**: Technical Risk
**Impact**: LOW

The Ralph config sets `max_concurrent: 4` for parallel execution. Batch 2 has 10 stories. They will run in groups of 4, meaning at least 3 rounds. This is fine -- it just takes longer than fully parallel execution. The `stagger_seconds: 3` also adds 3-second delays between launches. Total batch 2 wall time: approximately 3 rounds of parallel execution.

---

## Post-Fix Consistency Verification

After applying all fixes, the following consistency checks pass:

| Check | Result |
|-------|--------|
| Story IDs in specs match stories.txt | PASS (1.1, 2.1-2.10, 3.1 -- all 12 stories) |
| No circular dependencies | PASS (1.1 -> 2.1-2.10 -> 3.1, linear) |
| Valid YAML frontmatter in all specs | PASS (all 12 specs have id, epic, title, status, source_prd, priority, estimation, depends_on) |
| `phase_findings` naming consistent across all specs | PASS (after C1 fix) |
| Finding ID prefixes defined for all audit phases | PASS (S1, P2, D3, Q4, DOC5, GH6, N7; Phase 0/8/9 correctly omitted) |
| Batch assignments match stories.txt | PASS (batch 1: 1.1; batch 2: 2.1-2.10; batch 3: 3.1) |
| All batch 2 stories create unique files | PASS (10 unique files under phases/) |
| Orchestrator covers all phase-specific interaction patterns | PASS (Phase 3 license, Phase 5 license fallback, Phase 8 two-dispatch, standard gates) |

---

## Summary

**8 issues found, 4 fixed, 4 skipped (with reasons)**

| Classification | Count | Fixed | Skipped |
|---------------|-------|-------|---------|
| Critical | 3 | 3 | 0 |
| Warning | 4 | 1 | 3 |
| Observation | 10 | 0 | N/A |
| **Total** | **17** | **4** | **3** |

### Files Modified

1. `specs/epic-1/story-1.1-foundation-patterns-state.md` -- renamed `phase_results` to `phase_findings` (3 occurrences)
2. `specs/epic-2/story-2.7-phase6-github-setup.md` -- added `GH6-{N}` finding ID prefix in AC9 and structural test
3. `specs/epic-2/story-2.9-phase8-history-flatten.md` -- clarified PII allowlist must be inline (not referenced from patterns file), added test
4. `specs/epic-3/story-3.1-orchestrator.md` -- added Phase 5 license fallback pre-check as architectural constraint #5

### Assessment

The project plan is well-structured. The critical issues found were naming inconsistencies and cross-reference gaps that would have caused implementation failures. All were low-risk fixes. The batch/dependency structure is sound, the story sizing is appropriate, and there are no merge conflict risks in the parallel batch. The remaining observations are implementation-time decisions that do not block the plan.
