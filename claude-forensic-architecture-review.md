# Forensic Architecture Review: ralph-v2 → oss-prep

## Context

Ralph v2 evolved from a 607-line monolith (`ralph.sh`) into a 22-module, 5000+ line pipeline system over 15 days and 182 commits. Every architectural principle was extracted from a production failure — not designed upfront. The oss-prep skill (166KB single SKILL.md) has not yet been executed end-to-end. This review reverse-engineers ralph-v2's design evolution and applies those learnings to transform oss-prep from an overstuffed monolithic skill into a mature, pipeline-oriented system.

---

# Phase 1 — Evolution Analysis of ralph-v2

## Architectural Inflection Points

### 1. Monolith Decomposition (Jan 30 — commit `2c47424`)
- **Problem:** 607-line `ralph.sh` embedded inside a product repo, tightly coupled to Stackz conventions
- **Change:** Single commit introduced 2,721 lines across 24 files — 16 libraries, CLI entry point, templates, config
- **Principle:** **Decompose into single-responsibility modules that can be tested independently**

### 2. Entry Point Extraction (Jan 30 — commit `c35e9e2`)
- **Problem:** `bin/ralph` was 475 lines — still doing too much. Code review found 17 issues
- **Change:** Extracted `_run_sequential()` into `lib/runner.sh`; centralized EXIT trap registry
- **Principle:** **Entry points dispatch, they don't execute. Logic belongs in libraries**

### 3. Output Capture Discovery (Feb 6 — commit `9febfac`)
- **Problem:** All 7 of 8 parallel stories completed successfully, but Ralph missed every one — output files were 0 bytes. Claude CLI buffers differently than standard Unix tools
- **Change:** All capture switched from `> file 2>&1` to `2>&1 | cat > file`
- **Principle:** **Platform-specific I/O behavior must be verified empirically, not assumed**

### 4. Infinite Retry Loop (Feb 2 — commit `297e550`)
- **Problem:** `_handle_failure()` used `exit 1` in subshell; state I/O failure left retry counter at 0; loop reached iteration 9,849+
- **Change:** Three-layer fix: `return 1` instead of `exit`, check return at all 5 call sites, add local retry counter independent of state.json
- **Principle:** **Every loop needs two independent termination mechanisms**

### 5. Dashboard Architecture Pivot (Jan 31 – Feb 11, 7 commits, culminating in `8940aa8`)
- **Problem:** tput-based scroll regions + cursor positioning corrupted terminal when parallel workers wrote concurrently
- **Change:** Complete rewrite to append-only display model — no cursor manipulation, no scroll regions
- **Principle:** **Append-only output is the only safe model for concurrent processes**

### 6. State Machine Hardening (Feb 6-9 — commits `0631550`, `978e836`)
- **Problem:** `state_mark_done()` called after execution but before merge in parallel mode — stories skipped on resume
- **Change:** State transitions moved to post-ALL-phases-complete; schema extended with `absorbed_stories`, `merged_stories`, `decomposed_stories`; backwards-compatible upgrade via `_state_ensure_schema()`
- **Principle:** **State transitions are post-completion only — never mark done until all side effects are confirmed**

### 7. Signal Parsing Evolution (3 commits: `c35e9e2` → `30f9db5` → `c6ff52f`)
- **Problem:** Single regex on last line missed signals when Claude emitted multiple in one run
- **Change:** Full-output scan, last match wins; extended to hierarchical IDs and postmortem signals
- **Principle:** **Parse the full output; last match wins. Agents are not reliable single-signal emitters**

### 8. Decomposition System (Feb 11 — commit `4d6cc60`)
- **Problem:** Some stories too complex for one shot, even with retries — max retries exhausted means story lost
- **Change:** New sub-agent spawned post-max-retries that breaks failed story into 2-4 sub-stories with hierarchical IDs and depth guard
- **Principle:** **Self-healing over hard failure — decompose before declaring dead**

### 9. Skills-to-Pipeline Transition (Feb 9-12 — commits `6bbfe46`, `46d1a19`, `4e88ba4`)
- **Problem:** Content pipeline (PRD, specs, premortem) scattered across disconnected skills with no consistent naming or ordering
- **Change:** Restructured into `commands/ralph-v2/step_N-*` files; added full pipeline orchestration (interactive + full-auto); added reconcile and metrics skills
- **Principle:** **Pipeline steps must be enumerated, ordered, independently invokable, and have explicit input/output contracts**

### 10. Provenance & Drift Detection (Feb 9 — commit `6ad001b`)
- **Problem:** No way to know if a PRD changed after specs were generated — specs could be stale
- **Change:** SHA-256 hash tracking linking PRD to specs; 5-point verification (hash mismatch, missing stories, missing specs, orphaned specs, orphaned stories)
- **Principle:** **Every derived artifact must be traceable to its source, and drift must be detectable**

## Reliability Failures and Fixes (Chronological)

| Date | Commit | Bug | Root Cause | Fix | Principle |
|------|--------|-----|------------|-----|-----------|
| Jan 30 | `c35e9e2` | 17 macOS issues | GNU assumptions, no trap registry | Portable readlink, centralized traps | Test on target platform |
| Feb 1 | `10af396` | Worktree paths wrong | Relative paths after `cd` | Resolve to absolute before subshell | Subshells need absolute paths |
| Feb 2 | `297e550` | Infinite retry loop | `exit 1` + state I/O failure | return + check + local counter | Dual termination |
| Feb 6 | `9febfac` | Empty output files | `> file` buffering | `\| cat > file` | Platform I/O verification |
| Feb 6 | `805e247` | 124/17 progress count | Historical completions inflated | Queue-filtered count | Count from source of truth |
| Feb 6 | `741d292` | Merge crash | ERR trap on resolution | If-guard around resolution | Contain merge failures |
| Feb 6 | `30f9db5` | `eval` in hooks | Security risk | `bash -c` sandboxing | Never eval user input |
| Feb 7 | `978e836` | Concurrent instances | No locking | PID lockfile + stale detection | Exclusive resource locks |
| Feb 7 | `978e836` | Signal miss but work done | DONE lost but commits exist | Commit-count fallback | Validate artifacts, not just signals |
| Feb 9 | `0631550` | Done before merge | state_mark_done too early | Move to post-merge | Post-completion transitions only |
| Feb 9 | `0631550` | Undeclared array crash | `_PARALLEL_ALL_SUCCESSFUL` assumed | Verify at declaration site | Cross-module verification |
| Feb 10 | `a67fd0b` | Orphaned workers on Ctrl+C | Only PID files removed | Kill actual PIDs | Track and kill all child processes |
| Feb 10 | `1e46399` | Specs invisible to worktrees | Uncommitted files | Auto-commit specs | Worktrees only see committed files |
| Feb 11 | `8940aa8` | Terminal corruption | tput + concurrent writes | Append-only display | No cursor manipulation in concurrent contexts |
| Feb 12 | `8b68aa8` | Boolean config silently ignored | jq `//` treats `false` as falsy | Remove `//` entirely | Test edge values, not just happy paths |

## Workflow Design Shifts

| Shift | From | To | Trigger |
|-------|------|----|---------|
| Sub-agent isolation | All work in main process | Decomposition, postmortem, merge resolution as separate agents | Stories too complex for single shot |
| Spec validation | Glob-only discovery | Template variable validation + provenance tracking + drift detection | `{{VAR}}` leftovers causing runtime errors |
| Run script hardening | 17 commits to runner.sh | Production-faithful test mode, HITL hooks, scoped staging, append-only display | Each real run exposed new failure class |
| Config formalization | Hardcoded values | Deep-merge defaults with project overrides | Different projects needed different settings |
| Commit strategy | `git add -A` | Scoped staging from spec metadata; never `git add .` | Accidental inclusion of secrets/binaries |
| Pipeline orchestration | Scattered skills | Enumerated phases with commit checkpoints between each | No way to resume interrupted pipelines |

## Developer Experience Improvements

| Improvement | Commit(s) | What Changed |
|-------------|-----------|--------------|
| End-of-run summary | `615b4b5` | Rich summary: progress, timing, git stats, per-story outcomes, learnings |
| Metrics dashboard | `e8143bf` | Per-story token/cost tracking, cumulative stats, cost trend chart |
| CLI flag growth | Multiple | 10 flags added incrementally based on real usage needs |
| Resumability | `2c47424` + `978e836` | State.json tracking + schema upgrades + legacy bootstrap from progress.txt |
| Learnings injection | `2c47424` | Cross-story keyword-scored learning selection injected into prompts |
| Process lock | `978e836` | PID lockfile prevents concurrent corruption |

---

# Phase 2 — Transferable Patterns

## Architectural Patterns

### A1. Phase-Commit-Gate Sequencing
- **Description:** Pipeline phases execute in strict order. Each phase commits its artifacts before the next begins. Configurable gates (human approval or self-evaluation) control transitions.
- **Why it matters:** Provides resumability (restart from last commit), auditability (git log = execution trace), and quality control (gates catch errors before they propagate).
- **oss-prep violation:** No commits between phases. The STATE block is in-memory only. Session loss = total restart.

### A2. Atomic State with Schema Evolution
- **Description:** State persisted as JSON with atomic writes (tmp → validate → mv). New fields added via `_state_ensure_schema()` at init — never requires migration scripts.
- **Why it matters:** Prevents corrupted state from partial writes. Enables backwards-compatible evolution as the system grows.
- **oss-prep violation:** State is a conversation-context text block with no persistence to disk. No schema, no validation, no recovery.

### A3. Structured Signal Protocol
- **Description:** All agents communicate via typed, parseable signal tags (`<ralph>DONE/FAIL/LEARN</ralph>`). Full-output scan with last-match-wins semantics.
- **Why it matters:** Makes agent output machine-readable. Handles multi-signal emission gracefully. Decouples output format from consumption.
- **oss-prep violation:** Sub-agents return unstructured text. The orchestrator must interpret prose output, introducing ambiguity.

### A4. Defaults-Plus-Override Configuration
- **Description:** Full default config shipped with the tool. Project-specific overrides via deep merge. Lazy-loaded, cached, namespaced by concern.
- **Why it matters:** Every project works out of the box. Users only specify what they want to change.
- **oss-prep violation:** Configuration is hardcoded within the SKILL.md prose. No external config file. No per-project overrides.

### A5. Provenance and Drift Detection
- **Description:** Every derived artifact tracked via SHA-256 hash to its source. Five-point verification catches hash mismatches, missing artifacts, and orphans.
- **Why it matters:** Prevents stale artifacts from silently propagating through the pipeline.
- **oss-prep violation:** No provenance tracking. If a repo changes between phases, earlier findings may be stale. No mechanism detects this.

### A6. Context Window Preservation
- **Description:** Main context orchestrates only — all heavy scanning/generation delegated to sub-agents via Task tool. Only summaries flow back to the orchestrator.
- **Why it matters:** A 166KB SKILL.md + 10 phases of accumulated findings will exhaust context. Earlier phase definitions become unreferenceable.
- **oss-prep gap:** The SKILL.md IS 166KB. By Phase 8-9, Claude cannot reliably reference Phase 1-2 pattern definitions. No delegation strategy for heavy scanning.

### A7. Exclusive Resource Management
- **Description:** Run locks with PID-based stale detection. Dashboard timers stopped before new ones start. Git index locks cleaned on startup.
- **Why it matters:** Prevents concurrent corruption and resource leaks.
- **oss-prep gap:** No locking. Running `/oss-prep` twice in parallel would produce conflicting branch operations.

## Workflow Reliability Patterns

### W1. Dual Termination Mechanisms
- **Description:** Every loop has both a state-based check AND a local in-process counter. If state I/O fails, the local counter still terminates.
- **Why it matters:** Prevents infinite loops when external state (disk, JSON) becomes unreliable.
- **oss-prep gap:** Sub-agent dispatch has no timeout budgeting or local safety counters.

### W2. Escalation Ladder (Retry → Decompose → Halt)
- **Description:** Failure triggers retry. Max retries triggers automatic decomposition into smaller tasks. Decomposition failure triggers human intervention request.
- **Why it matters:** Maximizes automated recovery before escalating to a human.
- **oss-prep gap:** Sub-agent failures have no retry logic, no decomposition, no graceful degradation. A failed parallel scan loses all partial results.

### W3. Post-Completion-Only State Transitions
- **Description:** Never mark a phase as done until ALL side effects (file writes, commits, merges) are confirmed complete.
- **Why it matters:** Prevents resume from skipping unfinished work. The most common source of silent data loss in ralph-v2.
- **oss-prep gap:** The STATE block updates phase completion before verifying that all file operations succeeded.

### W4. Tentative Success with Validation
- **Description:** If an agent produces artifacts but fails to emit a completion signal, validate the artifacts independently. Accept if validation passes.
- **Why it matters:** Agents are unreliable signal emitters. Work done without acknowledgment is still work.
- **oss-prep gap:** No artifact validation independent of agent output. If a sub-agent's scan completes but doesn't return cleanly, results are lost.

### W5. Scoped Staging (Never `git add -A`)
- **Description:** Commits scope to explicitly declared file paths, extracted from phase metadata. Never use `git add .` or `git add -A`.
- **Why it matters:** Prevents accidental commit of secrets, credentials, large binaries, or unrelated changes.
- **oss-prep gap:** Phase 5-6 file writes don't declare their outputs formally. No mechanism prevents accidental staging of remediation artifacts alongside documentation.

### W6. Cleanup-Always Semantics
- **Description:** Resource cleanup (worktrees, locks, temp files) runs unconditionally — even on total failure, Ctrl+C, or crash. Registered via exit trap.
- **Why it matters:** Prevents state corruption that blocks subsequent runs.
- **oss-prep gap:** Branch creation in Phase 0 has no cleanup on failure. If Phase 0 crashes mid-branch-creation, subsequent runs may find inconsistent state.

### W7. Deterministic Ordering
- **Description:** Parallel results merged in sorted order (by ID), not arrival order. Prevents nondeterministic merge conflicts.
- **Why it matters:** Reproducibility. Same inputs → same merge sequence → same result.
- **oss-prep gap:** Parallel sub-agent results in Phases 1, 2, 4, 5 are consolidated in arrival order, which varies by run.

## Developer Ergonomics Patterns

### E1. Per-Run Metrics Persistence
- **Description:** Each run writes a timestamped JSON file with per-phase timing, token usage, cost, and outcome. Cumulative dashboards show trends.
- **Why it matters:** Provides budget visibility, identifies expensive phases, enables optimization over time.
- **oss-prep gap:** No metrics. No way to know which phase consumed the most tokens or how much a full run costs.

### E2. Cross-Run Learning Injection
- **Description:** Insights extracted from one run (via `<ralph>LEARN</ralph>` tags) are keyword-scored and injected into subsequent run prompts.
- **Why it matters:** The system gets smarter over time. Common pitfalls for a specific repo type are captured and reused.
- **oss-prep gap:** No learning system. Each `/oss-prep` invocation starts from zero, even on the same repo.

### E3. Progressive Disclosure in Output
- **Description:** Summaries first, details on request. Box-drawing for section headers. Severity-sorted findings.
- **Why it matters:** Keeps interaction manageable. Users aren't overwhelmed by 200 findings at once.
- **oss-prep status:** This pattern IS present in oss-prep — phase summaries with "review details" option. One of its strengths.

### E4. Resumability from Persistent State
- **Description:** State file tracks completed phases. On restart, `find_next()` returns the first incomplete phase. Legacy bootstrap can reconstruct from artifacts.
- **Why it matters:** Long pipelines (oss-prep can take 30+ minutes) must survive session interruption.
- **oss-prep gap:** No persistent state file. The STATE block reconstructs from "last known values" which is inherently lossy.

### E5. Explicit Error Messages with Recovery Steps
- **Description:** Every error message includes what failed, why, and what the user can do about it. No bare "Error occurred."
- **Why it matters:** Users can self-serve recovery without understanding internals.
- **oss-prep gap:** Git command failures in Phase 8 say "report an error and stop" with no recovery guidance.

### E6. Dry-Run Mode
- **Description:** `-d` flag prints what would be done without executing. Works in all modes.
- **Why it matters:** Users can preview destructive operations before committing.
- **oss-prep gap:** No dry-run. Phase 8 (history flatten) is all-or-nothing with only the "type flatten" gate.

### E7. Configurable Timeouts per Phase
- **Description:** Each phase type has its own timeout with postmortem window reservation.
- **Why it matters:** Prevents hung phases from blocking the pipeline indefinitely. Allows diagnostic capture on timeout.
- **oss-prep gap:** Phase 4 has hardcoded 5-min/10-min timeouts for build/test. Other phases have no timeouts at all.

---

# Phase 3 — oss-prep Gap Analysis

## Monolithic Coupling

### G1. Single 166KB SKILL.md File
**Severity: Critical**

The entire skill is a single 3,484-line markdown file. By the time Phase 8-9 executes, Claude must reference pattern definitions from Phase 1-2 (thousands of tokens earlier). Context compaction will drop critical definitions.

Ralph-v2 solved this by decomposing into 22 modules with clear interfaces. The oss-prep equivalent would be phase-specific files with a thin orchestrator.

### G2. Phase 1 and Phase 2 Are Structural Clones
**Severity: High**

Both phases implement identical architecture: parallel sub-agents → pattern library → severity classification → finding format → remediation templates → consolidation. The only difference is the pattern sets (secrets vs PII) and Phase 2's author email audit.

A shared scanning framework (parameterized by pattern set and severity rules) would eliminate ~350 lines of duplication and ensure both phases evolve together.

### G3. Phase 5 Bundles 7-8 Distinct Workflows
**Severity: Medium**

Phase 5 handles README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CLAUDE.md sanitization, and CHANGELOG — each with its own generation logic, review gate, and approval flow. This is 7-8 mini-skills crammed into one phase.

### G4. Phase 3 Runs Before Phase 5 (Temporal Ordering Bug)
**Severity: Medium**

Phase 3 checks dependency license compatibility against "the project's own license." Phase 5 is where the license is selected if none exists. For repos without a LICENSE file, Phase 3 cannot perform compatibility analysis.

## Missing Orchestration Boundaries

### G5. No Persistent State
**Severity: Critical**

The STATE block lives only in conversation context. No `.oss-prep/state.json` written to disk. Session loss (crash, timeout, terminal close) = complete restart. For a pipeline that can take 30+ minutes on a large repo, this is unacceptable.

### G6. No Phase-Level Commits
**Severity: Critical**

No commits between phases. If Phase 6 completes but Phase 7 fails, the user must re-run Phases 5-6 because their work products were never committed. Ralph-v2's pipeline commits after every phase, making each phase's output durable.

### G7. No Sub-Agent Failure Handling
**Severity: High**

Phases 1, 2, 4, and 5 spawn 2-5 parallel sub-agents. If one sub-agent fails (timeout, context overflow, crash), there is:
- No retry logic
- No partial result recovery
- No fallback to sequential execution
- No diagnostic capture

Ralph-v2's escalation ladder (retry → decompose → halt) would prevent total phase failure from one sub-agent problem.

## Missing Validation Layers

### G8. No Input Validation at Startup
**Severity: High**

No check that:
- The repo is a clean git state (uncommitted changes could be lost)
- Required tools are available (git version, disk space)
- The user has write permission to the repo
- The repo isn't a shallow clone (history scanning would be incomplete)

### G9. No Cross-Phase Consistency Verification
**Severity: Medium**

Phase 8 references "the secret detection patterns defined in Phase 1" and "the PII detection patterns defined in Phase 2." If Phase 1 or 2 patterns change (or were lost to context compaction), Phase 8's post-flatten verification silently becomes inconsistent. No mechanism detects this drift.

### G10. No Artifact Verification
**Severity: Medium**

When Phase 5 generates README.md, there is no verification that the written file matches what was approved (no hash comparison, no re-read-and-diff). The Write tool could silently fail or write partial content.

## Missing Resumability

### G11. Phase Completion Not Tracked Persistently
**Severity: Critical**

There is no equivalent of `state_mark_done()` writing to disk. The STATE block's "Completed Phases" list is in-memory only. Even the git branch (`oss-prep/ready`) doesn't track which phases have been completed — it only has the accumulated file changes.

### G12. No Idempotency
**Severity: High**

Running `/oss-prep` twice on the same repo produces duplicate findings, duplicate documentation, and conflicting state. The branch resume/reset in Phase 0 partially addresses this, but there's no awareness of "Phase 3 already completed."

## Risk Zones

### G13. Phase 8 Tag Deletion Is Overly Broad
**Severity: High**

`git tag -l | xargs -r git tag -d` deletes ALL local tags — not just tags reachable from `oss-prep/ready`. Tags on other branches, release tags, deployment tags — all gone.

### G14. No Pre-Flatten Backup
**Severity: High**

Phase 8 creates an orphan branch that replaces `oss-prep/ready`. There is no snapshot/backup ref created before the flatten. If the flatten produces an unexpected result, there's no automated way to recover the pre-flatten state.

### G15. Silent Uncommitted Change Loss
**Severity: Medium**

Phase 0 creates `oss-prep/ready` with `git checkout -b`. If the user has uncommitted changes, they carry over. Phase 8's `git checkout --orphan` silently carries staged changes into the orphan state. No warning is given about uncommitted work.

### G16. Build/Test Command Execution Without Sandboxing
**Severity: Medium**

Phase 4 runs arbitrary build and test commands discovered from the project profile. These commands execute with full user permissions. A malicious `postinstall` script or build hook could compromise the system.

## Premature Abstractions

### G17. Finding ID Scheme Is Over-Engineered
**Severity: Low**

The `S1-N`, `P2-N`, `D3-N`, `Q4-N`, `DOC5-N`, `N7-N` numbering convention across 6 phases creates a complex cross-referencing system that Phase 9 must consolidate. A simpler `{phase}-{severity}-{N}` scheme would be more maintainable.

---

# Phase 4 — Migration Plan

## Target Architecture

Transform oss-prep from a single 166KB SKILL.md into a pipeline of phase-specific skills orchestrated by a thin coordinator, with persistent state, commit checkpoints, and failure containment.

```
skills/oss-prep/
├── SKILL.md                      # Thin orchestrator (~200 lines)
├── config-defaults.json          # Full default config with per-phase settings
├── phases/
│   ├── 00-recon.md               # Phase 0: Reconnaissance
│   ├── 01-secrets.md             # Phase 1: Secrets Audit
│   ├── 02-pii.md                 # Phase 2: PII Audit
│   ├── 03-dependencies.md        # Phase 3: Dependency Audit
│   ├── 04-code-quality.md        # Phase 4: Code Quality Review
│   ├── 05-documentation.md       # Phase 5: Documentation Generation
│   ├── 06-github-setup.md        # Phase 6: GitHub Setup & CI/CD
│   ├── 07-naming-identity.md     # Phase 7: Naming & Identity
│   ├── 08-history-flatten.md     # Phase 8: History Flatten
│   └── 09-final-report.md        # Phase 9: Final Report
├── patterns/
│   ├── secrets-patterns.md       # Shared secret detection patterns (used by phases 01, 08)
│   └── pii-patterns.md           # Shared PII detection patterns (used by phases 02, 08)
├── templates/
│   ├── scan-agent.md             # Generic parallel scan sub-agent template
│   ├── remediation-agent.md      # Remediation sub-agent template
│   └── doc-gen-agent.md          # Documentation generation sub-agent template
└── state-schema.json             # State file schema definition
```

## Migration Phases

### Migration Phase 1: State Infrastructure (Foundation)
**Goal:** Persistent, resumable state that survives session loss.

**Tasks:**
1. Define state schema in `state-schema.json`:
   ```json
   {
     "version": 1,
     "current_phase": null,
     "completed_phases": [],
     "project_root": null,
     "prep_branch": "oss-prep/ready",
     "project_profile": {},
     "findings": { "phase_01": [], "phase_02": [], ... },
     "phase_outputs": {},
     "started_at": null,
     "metrics": { "tokens_in": 0, "tokens_out": 0, "duration_ms": 0 }
   }
   ```
2. Add state file write after every phase transition — write to `.oss-prep/state.json`
3. Add state file read at startup — detect existing state, offer resume or reset
4. Add atomic write semantics (write to `.tmp`, validate JSON, then `mv`)
5. Add git commit after each phase's state write: `oss-prep: complete phase N — {phase-name}`

**Validation:** Interrupt mid-pipeline (kill session). Restart `/oss-prep`. Verify it resumes from last completed phase.

### Migration Phase 2: Decompose the Monolith
**Goal:** Split 166KB SKILL.md into phase-specific files with a thin orchestrator.

**Tasks:**
1. Create `SKILL.md` as thin orchestrator (~200 lines):
   - Phase sequencing loop
   - State management (load, save, resume logic)
   - Gate logic (approval prompts between phases)
   - Context preservation directives
   - Delegation instructions: "For Phase N, read `phases/0N-{name}.md` and execute via Task sub-agent"
2. Extract each phase (0-9) into `phases/0N-{name}.md`:
   - Each phase file is self-contained: purpose, inputs, execution steps, outputs, finding format
   - Each phase declares its input requirements and output artifacts
   - Each phase includes its own user gate definition
3. Extract shared pattern libraries:
   - `patterns/secrets-patterns.md` — the 11-category regex library from Phase 1
   - `patterns/pii-patterns.md` — the 8-category regex library from Phase 2
   - Both referenced by Phase 8's post-flatten verification scan
4. Extract sub-agent prompt templates:
   - `templates/scan-agent.md` — parameterized by pattern set, scope (working tree vs history), and severity rules
   - `templates/remediation-agent.md` — parameterized by finding type and remediation strategy
   - `templates/doc-gen-agent.md` — parameterized by document type and project profile

**Validation:** Diff total content of new files against original SKILL.md. No logic should be lost, only restructured.

### Migration Phase 3: Orchestrator Hardening
**Goal:** Apply ralph-v2's reliability patterns to the orchestrator.

**Tasks:**
1. **Sub-agent failure handling:** Add retry logic for sub-agent dispatch. If a sub-agent fails:
   - Retry once with a simplified prompt
   - If retry fails, fall back to sequential execution (run the scan in the main context)
   - Log the failure with diagnostic context
2. **Phase-level commits:** After each phase completes and state is written:
   ```
   git add -- .oss-prep/state.json [phase-specific-outputs]
   git commit -m "oss-prep: phase N complete — {phase-name}"
   ```
   Scoped staging only — never `git add .`
3. **Input validation at startup (Phase 0 preamble):**
   - Check git repo (not shallow clone, not bare)
   - Check for uncommitted changes (warn, offer stash)
   - Check git version >= 2.20
   - Check disk space (warn if < 500MB free)
4. **Deterministic result ordering:** Sort parallel sub-agent results by category before consolidation (not arrival order)
5. **Timeout budgeting:** Each phase gets a configurable timeout. Phase 4 build/test timeouts already exist; extend to all phases. If a sub-agent times out, capture partial output for diagnostic.

**Validation:** Kill a sub-agent mid-execution. Verify retry fires. Verify partial results are captured. Verify subsequent phases still run.

### Migration Phase 4: Fix Design Bugs
**Goal:** Address the concrete issues found in the gap analysis.

**Tasks:**
1. **Phase ordering fix (G4):** Move license selection from Phase 5 to Phase 3 preamble. If no LICENSE exists, prompt for license choice before running dependency compatibility analysis.
2. **Phase 8 tag safety (G13):** Change tag deletion from `git tag -l | xargs -r git tag -d` to only delete tags reachable from `oss-prep/ready`: `git tag --merged oss-prep/ready | xargs -r git tag -d`
3. **Phase 8 backup ref (G14):** Before flatten, create a backup ref: `git branch oss-prep/pre-flatten oss-prep/ready`. Document in the user confirmation prompt.
4. **Uncommitted change protection (G15):** Phase 0 must check for uncommitted changes before `git checkout -b`. If present: warn, offer `git stash`, refuse to proceed if user declines.
5. **Cross-phase pattern consistency (G9):** Phase 8's post-flatten scan must reference the shared pattern files (`patterns/secrets-patterns.md`, `patterns/pii-patterns.md`), not "the patterns defined in Phase 1." This eliminates the context-compaction drift risk.
6. **Idempotency (G12):** State file records completed phases. On re-run, skip completed phases by default. Offer `--force-phase N` to re-execute a specific phase.

**Validation:** Run the full pipeline twice on the same repo. Verify the second run detects prior completion and either skips or offers reset.

### Migration Phase 5: Observability & Ergonomics
**Goal:** Add metrics, learning, and dry-run capabilities.

**Tasks:**
1. **Metrics per phase:** Track token usage, duration, finding counts per phase. Write to `.oss-prep/metrics.json` after each phase.
2. **Dry-run mode:** `--dry-run` flag that executes each phase's analysis but skips all file writes, commits, and destructive operations. Phase 8 reports what would be flattened without executing.
3. **End-of-run summary:** After Phase 9, display: total findings by severity, phases completed, total tokens/cost, files created/modified, time elapsed.
4. **Cross-run learnings:** Extract repo-type-specific insights (e.g., "Python repos commonly have hardcoded database URLs in settings.py") and persist to `.oss-prep/learnings.json`. Inject into subsequent runs on similar repos.
5. **Phase-specific error recovery guidance:** Every error in every phase must include: what failed, why it likely failed, and what the user can do (specific commands to run).

**Validation:** Run with `--dry-run` on a real repo. Verify zero file modifications. Verify metrics file is written. Verify summary is displayed.

## Sub-Agent Boundaries

| Phase | Sub-Agent(s) | Input | Output | Timeout |
|-------|-------------|-------|--------|---------|
| 01 | scan-agent x 2 (working tree, git history) | Pattern set, scope, repo root | Structured findings JSON | 5 min each |
| 02 | scan-agent x 3 (working tree, git history, author emails) | Pattern set, scope, repo root | Structured findings JSON | 5 min each |
| 04 | analysis-agent x 3 (architecture, standards, quality) | Repo root, project profile | Analysis report | 3 min each |
| 05 | doc-gen-agent x 5 (one per document) | Project profile, existing file (if any), template | Generated document | 3 min each |
| 08 | scan-agent x 2 (post-flatten verification) | Pattern sets, repo root | Verification findings | 3 min each |

All sub-agents use the shared `templates/scan-agent.md` or `templates/doc-gen-agent.md` templates, parameterized per invocation.

## Failure Containment Strategy

```
Phase execution
  |-- Sub-agent dispatch (parallel)
  |     |-- Success -> collect results
  |     |-- Timeout -> capture partial output, retry once
  |     |     |-- Retry success -> collect results
  |     |     +-- Retry fail -> fall back to sequential in main context
  |     +-- Error -> log diagnostic, retry once
  |           |-- Retry success -> collect results
  |           +-- Retry fail -> mark sub-agent as failed, continue with remaining results
  |-- Consolidation (all available results)
  |-- User gate
  |     |-- Approve -> commit phase, advance state
  |     |-- Skip -> commit state (phase skipped), advance
  |     |-- Review -> show details, return to gate
  |     +-- Abort -> commit current state, halt pipeline with resume instructions
  +-- State write + commit (atomic)
```

No single sub-agent failure should halt the pipeline. Partial results are always better than no results.

## Commit and Checkpoint Strategy

| Event | Commit Message | Files Staged |
|-------|---------------|--------------|
| Phase 0 complete | `oss-prep: init — project profile captured` | `.oss-prep/state.json` |
| Phase 1 complete | `oss-prep: secrets audit complete — N findings` | `.oss-prep/state.json`, remediated files (if any) |
| Phase 2 complete | `oss-prep: pii audit complete — N findings` | `.oss-prep/state.json`, remediated files (if any) |
| Phase 3 complete | `oss-prep: dependency audit complete` | `.oss-prep/state.json` |
| Phase 4 complete | `oss-prep: code quality review complete` | `.oss-prep/state.json` |
| Phase 5 complete | `oss-prep: documentation generated` | `.oss-prep/state.json`, README, LICENSE, CONTRIBUTING, etc. |
| Phase 6 complete | `oss-prep: github setup complete` | `.oss-prep/state.json`, `.github/**` |
| Phase 7 complete | `oss-prep: naming review complete` | `.oss-prep/state.json` |
| Phase 8 complete | `oss-prep: history flattened` | `.oss-prep/state.json` (on orphan branch) |
| Phase 9 complete | `oss-prep: readiness report generated` | `.oss-prep/state.json`, `oss-prep-report-*.md` |

All commits on the `oss-prep/ready` branch. Scoped staging only — explicit file paths, never `git add .`

## Verification Plan

1. **Unit test:** Each phase file can be invoked standalone via `/oss-prep:phase-01` (if Claude Code supports namespaced skill invocation) or by reading the phase file and executing it
2. **Integration test:** Run full pipeline on a known test repo (create a small private repo with planted secrets, PII, missing docs, and messy history)
3. **Resumability test:** Kill session mid-Phase-4. Restart. Verify resume from Phase 4
4. **Idempotency test:** Run twice on same repo. Verify second run detects prior completion
5. **Dry-run test:** Run with `--dry-run`. Verify zero file modifications
6. **Sub-agent failure test:** Add a deliberate timeout (very low timeout value) to one sub-agent. Verify retry + fallback fires. Verify pipeline continues
7. **Phase 8 safety test:** Run flatten on a repo with tags. Verify only reachable tags are deleted. Verify backup ref exists. Verify post-flatten scan runs
