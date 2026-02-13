# Premortem 2 Report -- oss-prep

**Date**: 2026-02-12
**Analyst**: Claude Opus 4.6
**Stories analyzed**: 1.1, 1.2, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.4, 4.1, 4.2
**Batches**: 11 (sequential, per premortem 1 restructuring)
**Premortem 1 reference**: `.ralph/premortem-1-report.md` (18 issues: 5 critical fixed, 5 warnings, 8 observations)

---

## Critical Issues (fixed)

None.

---

## Warnings (fixed / skipped with reason)

### W1: config.json specs.pattern has mismatched template braces (fixed)

**Issue**: The `specs.pattern` field in `.ralph/config.json` reads:
```
"specs/epic-{{epic}/story-{{id}}-*.md}"
```
The brace nesting is malformed -- `{{epic}` has two opening braces and one closing brace, and the closing `}` at the end of the string matches the opening `{` from `{{id}`, leaving the outer structure inconsistent. This should be either `{{epic}}/story-{{id}}-*.md` (Mustache-style double braces, no wrapping braces) or a consistent template format.

**Impact**: Low. The `run-ralph.sh` script does not use this pattern -- it performs its own `find` lookup (line 49). The config.json pattern is metadata only and has no runtime effect. However, if a future Ralph version uses config.json for spec resolution, this would fail.

**Likelihood**: Low.

**Fix applied**: Corrected the pattern to `specs/epic-{{epic}}/story-{{id}}-*.md` (consistent Mustache-style double braces).

---

## Observations

### O1: Batch ordering enforces SKILL.md serialization, not captured in spec depends_on

Stories 2.2, 2.3, 3.1, 3.2, 3.3, and 3.4 all have `depends_on: ["1.2"]` in their spec frontmatter, meaning they logically depend only on Phase 0 being complete. The sequential batch ordering (batches 3-9) enforces that they run one at a time because they all edit the same SKILL.md file. This is a known and intentional design: `depends_on` captures logical/content dependencies, while batch ordering captures file-level serialization constraints. No fix needed -- this distinction is correct and the premortem 1 note in stories.txt ("All stories edit the SAME file. Batches MUST be sequential.") documents the rationale.

### O2: Sequential execution time is ~2.5-3.5 hours, within acceptable range

Estimated execution time: 6 medium stories at ~12 min each (72 min) + 5 large stories at ~20 min each (100 min) = ~172 min (~2.9 hours). This is within the acceptable range for a Ralph autonomous run. The `loop.timeout_seconds: 1800` (30 min) per story in config.json provides adequate headroom for each individual story, including the largest ones (2.1, 2.3, 3.2, 4.1, 4.2).

### O3: Story 4.1 depends_on omits 1.1 and 1.2 explicitly but covers them transitively

Story 4.1's `depends_on: ["2.1", "2.2", "2.3", "3.1", "3.2", "3.3", "3.4"]` does not list stories 1.1 and 1.2. This is correct because dependencies 2.1, 2.2, and 2.3 themselves depend on 1.2, which depends on 1.1. Transitive coverage is complete. No fix needed.

### O4: Story 2.2 estimated as "medium" despite comparable scope to "large" Story 2.1

Story 2.2 (Phase 2: PII Audit) is estimated as "medium" while Story 2.1 (Phase 1: Secrets Audit) is "large". Both have similar structures: pattern libraries, sub-agent parallelization, severity classification, and remediation proposals. Story 2.2 actually uses 3 sub-agents (vs. 2 for 2.1) and includes an allowlist. However, the "medium" estimation is defensible because Phase 2 follows the same structural template established by Phase 1 -- the Ralph sub-agent implementing 2.2 can follow 2.1's pattern rather than inventing a new structure. The pattern-following effect reduces the effective complexity. No fix needed, but noted for execution monitoring -- if story 2.2 takes longer than expected, this is why.

### O5: run-ralph.sh commit format differs from config.json commit format

The `run-ralph.sh` script uses commit format `"ralph: implement story $id -- $title"` (line 70), while `config.json` specifies `"feat(story-{{id}}): {{title}}"` (line 30). The run-ralph.sh script is the actual execution path, so its format is what will be used. The config.json format is metadata that would be used by a more sophisticated Ralph runner. This inconsistency has no runtime impact but is worth noting for future Ralph versions.

### O6: Premortem 1 fixes have no cascading side effects

The four substantive changes from premortem 1 were verified for cascading effects:

1. **Sequential batch restructuring** (6 batches -> 11 sequential): No cascading issues. The sequential ordering is strictly more conservative than the original parallel batches. No story logic assumed parallel execution.

2. **Story 4.1 expanded depends_on**: No cascading issues. Adding more dependencies to 4.1 only makes the dependency graph stricter. Story 4.2's transitive dependency chain through 4.1 now covers all stories. No circular dependencies introduced.

3. **run-ralph.sh echo updates**: No cascading issues. Display-only change, no logic affected.

4. **Story 4.1 spec pattern cross-referencing guidance**: No cascading issues. The added language in the technical context section ("reference the pattern definitions in the Phase 1 and Phase 2 sections of SKILL.md by section heading") is purely instructional and does not affect any other story's spec or implementation.

### O7: The skill architecture is inherently idempotent-safe

Each story appends a new phase section to SKILL.md. If a story fails mid-implementation, the file may be left with a partial section. The `run-ralph.sh` script commits after each story (line 70) and exits on failure (line 64-67), so the user can inspect the partial result, fix it, and resume. The `git add -A && git commit` pattern also means uncommitted partial work is captured before failure. This is a robust design.

---

## Summary: 1 issue found, 1 fixed, 0 skipped

The premortem 1 fixes introduced no cascading effects. The sequential batch restructuring is strictly correct. The expanded dependency graph on story 4.1 is complete and acyclic. The only new finding was a cosmetic brace-matching typo in config.json (fixed). The plan is ready for execution.
