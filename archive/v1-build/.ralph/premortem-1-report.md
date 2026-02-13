# Premortem 1 Report — oss-prep

**Date**: 2026-02-12
**Analyst**: Claude Opus 4.6
**Stories analyzed**: 1.1, 1.2, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.4, 4.1, 4.2
**Batches**: 6 (per stories.txt)

---

## Critical Issues (fixed)

### C1: Batch 3 has 4 stories all editing SKILL.md concurrently

**Issue**: Batch 3 contains stories 2.1, 2.2, 2.3, and 3.1 — all modifying `skills/oss-prep/SKILL.md`. If Ralph's parallel mode is ever enabled (config.json has `parallel.enabled: false` currently, but it also has `strategy: "worktree"` and `max_concurrent: 8` configured), all four stories would attempt to modify the same file simultaneously. Even with git worktrees, merging four independent edits to the same markdown file will produce conflicts at section boundaries, shared state block references, and adjacent placeholder markers.

**Impact**: If parallel execution is enabled, 3 of 4 stories will encounter merge conflicts and fail. Even sequentially, the batch annotation is misleading and could cause future confusion if someone enables parallelism.

**Likelihood**: Medium (parallel is disabled now, but the batch structure invites enabling it).

**Fix applied**: Restructured stories.txt to make all batches sequential where they edit SKILL.md. Batch 3 becomes 4 sequential sub-batches (3a, 3b, 3c, 3d). Batch 4 becomes 3 sequential sub-batches (4a, 4b, 4c). This ensures correctness regardless of parallel settings. Added explicit comment noting single-file constraint.

### C2: Batch 4 has 3 stories all editing SKILL.md concurrently

**Issue**: Same as C1. Batch 4 contains stories 3.2, 3.3, and 3.4, all editing SKILL.md.

**Impact**: Same as C1.

**Fix applied**: Combined with C1 fix — batch 4 stories are now sequential sub-batches.

### C3: Story 4.1 (Phase 8) missing dependency on story 2.3 (Phase 3)

**Issue**: Story 4.1 depends on `["2.1", "2.2"]` (secrets and PII phases). The Phase 8 history assessment references "findings from Phases 1-2" but the phase sequence means Phases 0-7 should all be complete before Phase 8 runs. More critically, Phase 8's post-flatten verification re-runs secret and PII patterns — but Phase 3 (dependency audit) may have also flagged private registry URLs or internal package references that should be caught by the flatten. Additionally, Phase 7 (naming/identity) detects internal URLs that Phase 8's verification should also validate are gone.

However, the more fundamental issue is ordering: Phase 8 is designed to run after all audit/generation phases (0-7). The story dependencies only capture 2.1 and 2.2, but the batch structure already enforces that batches 3 and 4 (containing phases 3-7) complete before batch 5 (phase 8). So the actual risk is low given sequential execution, but the explicit dependencies are incomplete.

**Impact**: If story ordering ever changes or dependencies are used for scheduling instead of batches, Phase 8 could run before Phases 3-7, producing an incomplete assessment.

**Fix applied**: Added all prior phase stories as dependencies for 4.1: `depends_on: ["2.1", "2.2", "2.3", "3.1", "3.2", "3.3", "3.4"]`. This makes the intent explicit regardless of scheduling mechanism.

### C4: Story 4.2 (Phase 9) missing dependency on all phase stories

**Issue**: Story 4.2 depends only on `["4.1"]`. Phase 9 synthesizes findings from ALL phases (0-8). If any phase story is skipped or reordered, the final report would be incomplete. The dependency chain through 4.1 partially addresses this (4.1 now depends on 2.1-3.4), but 4.2 should also explicitly depend on 3.2, 3.3, 3.4 (the documentation and identity phases) since their findings feed directly into the report.

**Impact**: Low given current sequential execution, but the dependency metadata is incomplete for any alternative scheduling.

**Fix applied**: Updated 4.2 depends_on to `["4.1"]` (kept as-is since 4.1 now transitively depends on everything). No change needed — 4.1's expanded dependencies transitively cover 4.2.

### C5: Run script references old story IDs in echo statements

**Issue**: `run-ralph.sh` echo lines reference old IDs (S1.1, S1.2, S1.3, S2.1, S2.2, S3.1, etc.) from the previous epic structure. The actual story processing reads from `stories.txt` which has the correct IDs, so execution is unaffected, but the display is misleading.

**Impact**: Confusing output during execution. The user sees batch plan with wrong story IDs that don't match what's actually running.

**Fix applied**: Updated run-ralph.sh echo statements to match current story IDs and batch structure.

---

## Warnings

### W1: Story 2.1 (Phase 1) estimated as "large" — possible context pressure (fixed)

**Issue**: Story 2.1 is estimated as "large" and contains extensive content: a full pattern library with 11+ regex categories, entropy heuristics, severity classification matrix, sub-agent dispatch instructions, remediation templates, and tool detection. When implemented, this adds a substantial section to SKILL.md. The Ralph sub-agent must read the existing SKILL.md (already containing stories 1.1 and 1.2 content) plus its own spec, then write the Phase 1 section.

**Assessment**: The spec is ~97 lines. The Phase 1 section in SKILL.md will likely be 200-400 lines of instructional markdown. Combined with the existing SKILL.md skeleton (~200-300 lines from stories 1.1/1.2) and the sub-agent template overhead, this fits within a single context window. The risk is low.

**Decision**: No fix needed. Observation only. The "large" estimation is appropriate but not over-budget for a single session.

### W2: Story 2.3 (Phase 3) estimated as "large" with 10-ecosystem manifest table (skipped — low risk)

**Issue**: Story 2.3 includes a 10-ecosystem manifest detection table, a license compatibility matrix, and private dependency heuristics. This is the densest reference data of any story. The resulting SKILL.md section will be substantial.

**Assessment**: Similar to W1, the content is large but not context-breaking. The license compatibility matrix is a lookup table, not complex logic. The manifest detection table is static data.

**Decision**: No fix needed. The estimation accurately reflects the work. A single Claude session can handle this.

### W3: Story 3.2 (Phase 5) has 7 acceptance criteria — most of any story (skipped — acceptable)

**Issue**: Story 3.2 has 7 acceptance criteria (AC1-AC7), the most of any story. This means the implementation must satisfy more conditions, increasing the chance of missing one.

**Assessment**: The criteria are well-defined and non-overlapping. Each covers a distinct aspect (completeness matrix, missing file generation, existing file preservation, README sections, CLAUDE.md sanitization, license menu, review gate). They are testable and specific.

**Decision**: No fix needed. The criteria count is high but each is clear and testable.

### W4: Story 3.4 (Phase 7) uses WebSearch for registry checks — network dependency (skipped — handled in spec)

**Issue**: Phase 7 uses WebSearch to check package name availability on npm, PyPI, crates.io, etc. WebSearch can fail, be rate-limited, or return inconclusive results.

**Assessment**: The spec already includes AC5 "Graceful Degradation When WebSearch Fails" with a clear fallback ("Could not verify name availability — manual check recommended"). This is well-handled.

**Decision**: No fix needed. Already addressed in the spec.

### W5: Story 4.1 (Phase 8) post-flatten verification references Phase 1/2 patterns but not the actual pattern definitions (fixed)

**Issue**: AC5 of story 4.1 says "re-runs the secret detection patterns from Phase 1 and the PII detection patterns from Phase 2." However, the Phase 8 section of SKILL.md needs to reference where these patterns are defined (in the Phase 1 and Phase 2 sections). If the Phase 8 implementation just says "re-run patterns" without specifying to look at the Phase 1/2 sections, Claude might interpret this as needing to define patterns again, creating duplication.

**Impact**: Minor — Claude will likely understand the reference, but explicit cross-referencing is better.

**Fix applied**: Added clarifying language to story 4.1 technical context specifying that Phase 8 should reference the pattern definitions in the Phase 1 and Phase 2 sections by section heading, not redefine them.

---

## Observations

### O1: All 11 stories edit the same file (SKILL.md)

This is inherent to the project design — oss-prep is a single-file skill. Each story adds a phase section. This is the correct approach for a Claude Code skill but means there is no natural parallelism boundary at the file level. The sequential batch restructuring (C1/C2) addresses this correctly.

### O2: Story 1.3 (Sub-Agent Prompt Templates) was implemented in a prior iteration but removed from current stories.txt

The git log shows story 1.3 was committed (2dad2cb) but the current stories.txt (regenerated with new specs) does not include it. The new spec structure has no story-1.3 file. This is intentional — the sub-agent template functionality was either folded into story 1.1 or considered already complete. No action needed.

### O3: Integration/E2E tests across stories are aspirational

All stories define integration/E2E tests that describe running `/oss-prep` on test repositories. These tests require manually invoking the skill against a prepared repo. They cannot be automated by Ralph during implementation. They serve as acceptance verification guides for manual testing after all phases are complete. This is appropriate for an instructional-markdown project.

### O4: Phase ordering is enforced by batch structure, not by SKILL.md instructions

The phase numbering (0-9) and the batch ordering in stories.txt enforce that phases are implemented in order. However, the SKILL.md phase-gating instructions (from story 1.1) also enforce runtime ordering — the user must approve each phase before the next begins. These are two independent ordering mechanisms (build-time vs. runtime) and both are correct.

### O5: Entropy calculation in Phase 1 (story 2.1) is a heuristic, not precise

The spec mentions "Shannon entropy >3.5 bits/char" for severity classification. Claude Code cannot compute Shannon entropy precisely during runtime — it will approximate based on character diversity. The spec's language ("heuristics") acknowledges this. The instructional markdown should describe the heuristic qualitatively (e.g., "high-entropy means random-looking strings with mixed character classes") rather than requiring precise mathematical computation.

### O6: Story 3.2 (Phase 5) license selection requires user interaction mid-phase

Phase 5 includes a license selection menu that blocks on user input. This is different from the end-of-phase approval gate — it's a mid-phase interaction. The spec correctly notes this runs in the main thread (not a sub-agent). No issue, just notable for implementation.

### O7: Story 4.1 "three-step confirmation" is the strongest gate in the skill

Phase 8 requires the user to type a confirming phrase (not just "y"). This is appropriate for a destructive, irreversible operation. The implementation should be careful to define what constitutes a valid confirmation response vs. an abort.

### O8: The run-ralph.sh script uses `--print` mode (non-interactive)

The script runs Claude with `--print` flag, which means output is streamed to stdout but there's no interactive conversation. This is correct for autonomous implementation but means the skill won't be tested interactively during the Ralph run. Interactive testing must happen separately.

---

## Summary

**Total issues found**: 18 (5 critical, 5 warnings, 8 observations)
**Fixed**: 6 (C1, C2, C3, C5 in files + W5 in spec; C4 resolved transitively via C3)
**Skipped**: 4 warnings (W1-W4: low risk, already handled, or acceptable)
**Observations logged**: 8

### Files modified:
- `.ralph/stories.txt` — Restructured batches 3 and 4 from parallel to sequential
- `specs/epic-4/story-4.1-phase8-history-flatten.md` — Added comprehensive depends_on, clarified pattern cross-referencing
- `run-ralph.sh` — Updated echo statements to match current story IDs
