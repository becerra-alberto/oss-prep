`ralph-v2` is now pipeline-first; “workflow” is the UX layer on top of that pipeline.

**Phase 1 — Evolution Analysis (Commit-Level Inflection Points)**

| Shift | Trigger Problem | What Changed | Emergent Principle | Evidence |
|---|---|---|---|---|
| 1. Monolith to modular runtime | `ralph.sh` + ad hoc state could not scale to parallel/recovery | Split into `bin/ralph` + `lib/*` modules + templates | Separate orchestration, execution, state, and prompts | `548b93b` → `2c47424` |
| 2. Portability hardening | macOS/Bash/runtime fragility | Bash4 re-exec pathing, safer modules/hooks | Portability is a reliability feature | `c35e9e2`, `/Users/albertobecerra/Tools/ralph-v2/bin/ralph:5`, `/Users/albertobecerra/Tools/ralph-v2/lib/hooks.sh:38` |
| 3. Reliability through test ladder | rapid feature changes caused regressions | Tiered tests (unit→e2e), later incident tests | Every reliability fix needs a regression test | `e19d794`, `1118999`, `9ff051d`, `8b68aa8` |
| 4. Planning pipeline formalization | manual PRD/spec flow was slow and inconsistent | `/ralph` skill generates v2 specs directly; large PRDs parallelized | Planning artifacts are first-class pipeline inputs | `1b86607`, `da1b32c` |
| 5. Dashboard strategy reversal | real-time ANSI/TUI broke under parallel churn | Switched to append-only progress display | In parallel systems, observability must be contention-safe | `1c34e2c` → `8940aa8`, `/Users/albertobecerra/Tools/ralph-v2/docs/post-mortem.md:97` |
| 6. Real parallel incident hardening | first real run: empty output files, stale worktrees, hangs | pipe capture, worktree timeouts, stale lock cleanup, cleanup-always | Failure paths are primary paths | `9febfac`, `741d292`, `30f9db5`, `/Users/albertobecerra/Tools/ralph-v2/docs/post-mortem.md:13`, `/Users/albertobecerra/Tools/ralph-v2/docs/changelog-parallel-hardening.md:21` |
| 7. Recovery model upgrade | successful branch work was misclassified as failed/lost | lockfile, commit-fallback “tentative success”, reconcile command | Preserve work first, reconcile second | `978e836`, `/Users/albertobecerra/Tools/ralph-v2/lib/runner.sh:39`, `/Users/albertobecerra/Tools/ralph-v2/lib/parallel.sh:500`, `/Users/albertobecerra/Tools/ralph-v2/lib/reconcile.sh:7` |
| 8. Deterministic merge and retry behavior | merge order and retry outcomes were nondeterministic | sorted merge order, stronger retry/cleanup logic | Determinism reduces conflict entropy | `0631550`, `a67fd0b`, `/Users/albertobecerra/Tools/ralph-v2/lib/parallel.sh:771` |
| 9. Input/control-plane validation | bad queue/patterns gave false-success behavior | empty-queue detection, unresolved template detection | Fail fast on malformed control inputs | `09b7df3`, `e29cb07`, `/Users/albertobecerra/Tools/ralph-v2/lib/specs.sh:17` |
| 10. Provenance + traceability | PRD/spec drift and unclear lineage | `provenance.json` + verify flow + integration tests | Pipeline needs auditable lineage | `6ad001b`, `7c65fd4`, `/Users/albertobecerra/Tools/ralph-v2/lib/provenance.sh:21` |
| 11. Adaptive decomposition and timeout postmortems | repeated retry exhaustion on large stories | timeout postmortem signals + automatic story decomposition | When retries fail, reduce task size automatically | `c6ff52f`, `4d6cc60`, `/Users/albertobecerra/Tools/ralph-v2/lib/decompose.sh:52` |
| 12. Runtime-safe prompting/staging | broad staging and unsafe generation patterns | `commit.stage_paths`, stage-only instructions in prompt, hook/timeouts | Prompt contract is runtime safety policy | `96f5c9d`, `/Users/albertobecerra/Tools/ralph-v2/lib/prompt.sh:185`, `/Users/albertobecerra/Tools/ralph-v2/templates/init/config.json:23` |
| 13. Workflow→pipeline split | one skill mixed orchestration modes and drifted | explicit pipeline skills (`interactive`, `full-auto`) + command entrypoints | Separate execution engine from operator UX modes | `46d1a19`, `5d68f58`, `562d54a`, `/Users/albertobecerra/Tools/ralph-v2/skills/ralph-pipeline-full-auto/SKILL.md:37` |
| 14. Repository boundary cleanup | tooling repo polluted by target-project artifacts | removed Stackz files from `ralph-v2` | Keep tool/runtime code isolated from generated work | `98de768` |

**Phase 2 — Transferable Patterns**

**A) Architectural Patterns (6)**

1. **Name:** Engine-First Orchestration  
Description: All execution flows through one runtime (`ralph run`) with shared state/signal semantics.  
Why it matters: Prevents forked behavior between “script path” and “runtime path.”  
`oss-prep` gap: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/run-ralph.sh:66` calls `claude` directly, bypassing engine semantics.

2. **Name:** Control-Plane Artifact Set  
Description: Treat `.ralph/config.json`, `.ralph/stories.txt`, `.ralph/state.json`, `.ralph/provenance.json`, `.ralph/runs/` as required system files.  
Why it matters: Enables resumability, traceability, and diagnostics.  
`oss-prep` gap: missing `.ralph/state.json`, `.ralph/provenance.json`, `.ralph/runs/`.

3. **Name:** Deterministic Parallel Contract  
Description: Parallel workers must merge in deterministic order with stable cleanup behavior.  
Why it matters: Reproducible conflict patterns and fewer heisenbugs.  
`oss-prep` gap: avoids parallel entirely due single-file coupling (`/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/.ralph/stories.txt:4`), so architecture cannot evolve.

4. **Name:** Path Normalization at Project Root  
Description: Specs and prompts must target root-relative paths only.  
Why it matters: Prevents path duplication and write failures across cwd variants.  
`oss-prep` gap: path prefix drift in specs and run script (`/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/run-ralph.sh:23`, plus `specs/*` references to `skills/oss-prep/SKILL.md`).

5. **Name:** Provenance Chain  
Description: Track PRD hash → expected stories → generated specs.  
Why it matters: Detects drift before runtime failures.  
`oss-prep` gap: no provenance tracking artifacts or verify workflow.

6. **Name:** Adaptive Decomposition Tree  
Description: If retries exhaust, decompose story into children and continue.  
Why it matters: Converts hard failures into bounded work.  
`oss-prep` gap: no decomposition config/state path in `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/.ralph/config.json`.

**B) Workflow Reliability Patterns (6)**

1. **Name:** Dual Success Criteria  
Description: DONE signal + commit-diff fallback for tentative success.  
Why it matters: avoids losing completed work when signaling fails.  
`oss-prep` gap: direct loop trusts process exit/output only; no tentative branch reconciliation path.

2. **Name:** Single-Run Locking  
Description: PID lockfile with stale lock detection.  
Why it matters: blocks concurrent orchestrator corruption.  
`oss-prep` gap: no lock in `run-ralph.sh`; contrast `/Users/albertobecerra/Tools/ralph-v2/lib/runner.sh:5`.

3. **Name:** Cleanup-Always Semantics  
Description: Cleanup executes even on all-failed batches.  
Why it matters: prevents stale branches/worktrees from blocking next run.  
`oss-prep` gap: no structured worker cleanup model (direct sequential CLI loop).

4. **Name:** Timeout Budgeting + Postmortem  
Description: reserve postmortem window and persist timeout analysis.  
Why it matters: turns timeouts into actionable learnings.  
`oss-prep` gap: no postmortem path in current config and no timeout workflow.

5. **Name:** Multi-Layer Validation  
Description: preflight (queue/spec), per-story validation, post-run checks.  
Why it matters: catches invalid control input and unsafe outputs early.  
`oss-prep` gap: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/.ralph/config.json:16` has empty validation commands.

6. **Name:** Destructive-Op Safety Protocol  
Description: explicit typed confirmation, scoped branch checks, post-op rescans.  
Why it matters: minimizes irreversible mistakes.  
`oss-prep` partial: strong phrase gate exists, but flatten execution uses broad staging/tag deletion (`/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/SKILL.md:3055`, `:3060`, `:3081`).

**C) Developer Ergonomics Patterns (6)**

1. **Name:** End-of-Run Summary  
Description: timings/outcomes/git delta + next actions.  
Why it matters: fast diagnosis and operator trust.  
`oss-prep` gap: no structured summary in direct run loop.

2. **Name:** Persistent Run Metrics  
Description: per-run JSON stats and story-level token/cost/turn metrics.  
Why it matters: supports trend analysis and sizing corrections.  
`oss-prep` gap: no `.ralph/runs/` persistence.

3. **Name:** Reconcile Entry Point  
Description: dry-run/apply reconcile for orphan branches.  
Why it matters: safe recovery without manual surgery.  
`oss-prep` gap: no reconcile workflow in local run tooling.

4. **Name:** Scoped Staging Contract  
Description: never `git add -A`; stage explicit paths from spec/config.  
Why it matters: prevents accidental secret/PII/unrelated commits.  
`oss-prep` gap: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/run-ralph.sh:75` uses `git add -A`.

5. **Name:** Incident-Driven Test Expansion  
Description: each incident yields fixed test coverage.  
Why it matters: reliability improves monotonically.  
`oss-prep` gap: no test harness for pipeline artifacts under skill directory.

6. **Name:** Workflow Mode Split  
Description: interactive and full-auto commands share runtime contract, differ in UX.  
Why it matters: prevents docs/runtime drift.  
`oss-prep` gap: inference: generated assets reflect pre-hardening style (direct `claude` loop) despite runtime-safe directives now existing in `ralph-v2`.

**Phase 3 — oss-prep Gap Analysis (Concrete Findings)**

1. **[P0] Runtime bypass**  
Finding: execution bypasses `ralph` engine and calls `claude` directly.  
Evidence: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/run-ralph.sh:66`.  
Impact: loses lockfile, state, signal parsing, tentative fallback, reconcile, summaries, metrics.

2. **[P0] Unscoped staging + silent commit failure**  
Finding: `git add -A` and `git commit ... || true`.  
Evidence: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/run-ralph.sh:75`.  
Impact: accidental inclusion of unrelated/sensitive files and hidden commit failures.

3. **[P0] Destructive flatten risk zone**  
Finding: orphan checkout + global stage + tag deletion are encoded as default execution steps.  
Evidence: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/SKILL.md:3055`, `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/SKILL.md:3060`, `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/SKILL.md:3081`.  
Impact: irreversible data/history operations without runtime containment hooks.

4. **[P1] Path normalization drift**  
Finding: target path includes duplicated root segment.  
Evidence: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/run-ralph.sh:23`, `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/specs/epic-1/story-1.2-phase0-reconnaissance.md:93`.  
Impact: brittle writes and portability issues across cwd contexts.

5. **[P1] Missing validation layers**  
Finding: validation commands and blocked commands are empty.  
Evidence: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/.ralph/config.json:16`.  
Impact: no pre-commit guardrail for malformed skill sections or unsafe commands.

6. **[P1] Missing resumability artifacts**  
Finding: no state/provenance/runs artifacts are present.  
Evidence: absent `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/.ralph/state.json`, absent `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/.ralph/provenance.json`, absent `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/.ralph/runs/`.  
Impact: weak restart semantics and no forensic audit trail.

7. **[P1] Monolithic coupling**  
Finding: all stories mutate one file; queue explicitly serializes for this reason.  
Evidence: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/.ralph/stories.txt:4`, `SKILL.md` size is 3483 lines.  
Impact: no safe parallel boundary, high context pressure, large conflict surface.

8. **[P2] Premature abstractions disconnected from runtime**  
Finding: config has parallel/commit settings but run path ignores runtime config behavior.  
Evidence: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/.ralph/config.json:28`, `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/.ralph/config.json:40`, `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/run-ralph.sh:66`.  
Impact: false confidence that settings are enforced.

9. **[P2] Unsafe rollback template**  
Finding: failure path suggests `git checkout .`.  
Evidence: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/.ralph/templates/implement.md:25`.  
Impact: can wipe unrelated working-tree edits.

10. **[P2] Missing learnings pipeline output**  
Finding: learnings index exists but no extracted entries.  
Evidence: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/.ralph/learnings/_index.json:1`.  
Impact: no feedback loop from failures/retries.

11. **Strength already present (keep)**  
Finding: phase-gating and grounding rules are strong and explicit.  
Evidence: `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/SKILL.md:51`, `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/SKILL.md:113`.  
Impact: good policy layer; needs runtime enforcement layer.

**Phase 4 — Migration Plan (Practical, Code-Grounded)**

**Migration Phases (M0–M6)**

1. **M0: Runtime Alignment (immediate hard stop on drift)**  
Scope: replace direct `claude` loop with engine invocation.  
Actions: make `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/run-ralph.sh` a thin wrapper around `ralph run` and `ralph status/stats/reconcile`; remove inline commit logic.  
Checkpoint commit: `refactor(oss-prep): route execution through ralph runtime only`.

2. **M1: Control-Plane Parity**  
Scope: bring `.ralph/config.json` up to hardened runtime schema.  
Actions: add `commit.stage_paths`, `postmortem.*`, `decomposition.*`, `hooks.pre_worktree`, `hooks.pre_worktree_timeout`; define non-empty `validation.commands`; set explicit blocked destructive commands for non-phase-8 stories.  
Checkpoint commit: `chore(oss-prep): harden control-plane config`.

3. **M2: Spec Discipline + Path Correction**  
Scope: enforce root-relative paths and queue integrity.  
Actions: rewrite all spec “Files to Create/Modify” targets to `SKILL.md` (or future modular phase files), add automated checker for unresolved templates/path duplication/empty queue.  
Checkpoint commit: `fix(oss-prep): normalize spec paths and add control-plane lint`.

4. **M3: Break Monolithic Coupling (pipeline-oriented content model)**  
Scope: stop having every story edit one giant file.  
Actions: introduce phase modules under `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/pipeline/phases/phase-*.md`; stories edit module files; add build step that compiles modules into `/Users/albertobecerra/Tools/ai-dev-toolkit/skills/oss-prep/SKILL.md`; keep `SKILL.md` as generated artifact.  
Checkpoint commit: `refactor(oss-prep): modularize phase content and generate SKILL.md`.

5. **M4: Failure Containment + Recovery**  
Scope: destructive-op safety and recovery flow.  
Actions: add pre-flatten safety precheck script (branch verification, backup tag/branch, dry-run summary), keep explicit `flatten` phrase gate, add reconcile runbook/command path for partial failures.  
Checkpoint commit: `feat(oss-prep): add flatten safety rails and reconcile workflow`.

6. **M5: Observability + Learnings**  
Scope: resumability and diagnostics.  
Actions: persist `.ralph/state.json`, `.ralph/provenance.json`, `.ralph/runs/*`; enforce run summary artifact; extract/store per-story learnings into `.ralph/learnings/`.  
Checkpoint commit: `feat(oss-prep): persist state provenance metrics and learnings`.

7. **M6: End-to-End Qualification**  
Scope: first true full pipeline run.  
Actions: run on a disposable repo fixture, then on a realistic non-production repo; verify resume path, timeout path, reconcile path, flatten decline path, flatten execute path, post-flatten secret/PII rescans.  
Checkpoint commit: `test(oss-prep): add e2e qualification artifacts and runbook`.

**Target Orchestrator Responsibilities**

1. Load/validate control-plane artifacts before any story execution.  
2. Acquire/release run lock and reject concurrent runs.  
3. Select next story from queue + state, not from ad hoc file parsing only.  
4. Enforce stage-path scoped commits.  
5. Apply dual-success classification (`DONE` signal plus commit fallback).  
6. Persist outcomes to state/progress/spec status consistently.  
7. Run post-story and post-run validations.  
8. Persist metrics and learnings.  
9. Offer reconcile and resume commands as first-class recovery.

**Target Sub-Agent Boundaries**

1. `phase-0-recon` agent: repo profile + branch safety checks.  
2. `phase-1-secrets` agent split: working-tree scan and history scan.  
3. `phase-2-pii` agent split: working-tree scan and history scan.  
4. `phase-3/4/5/6/7` agents: each phase module owned by one agent output file.  
5. `phase-8-flatten` agent: assessment/report only; execution remains orchestrator-owned.  
6. `phase-9-report` agent: synthesis from persisted phase artifacts only.

**Validation Layers to Implement**

1. Control-plane lint: config schema, unresolved templates, root-relative paths, non-empty queue.  
2. Story preflight: spec exists, depends_on valid, target files allowed.  
3. Story postflight: required validation commands pass, scoped staged paths only.  
4. Destructive-op gate: branch confirmation + backup created + explicit user phrase.  
5. Final verification: secret/PII rescans and report integrity checks.

**Commit and Checkpoint Strategy**

1. One migration checkpoint commit per M0–M6 phase.  
2. During story runs, keep one commit per story with deterministic format and scoped staging.  
3. On high-risk transitions (before flatten), create explicit safety checkpoint tag/branch.  
4. After each run, persist summary + metrics + learnings as auditable artifacts.  

Inference note: `oss-prep` appears generated from an earlier pipeline template revision, because its current run path and path targets conflict with newer runtime-compatibility directives now present in `ralph-v2` pipeline skills (`/Users/albertobecerra/Tools/ralph-v2/skills/ralph-pipeline-full-auto/SKILL.md:37`, `/Users/albertobecerra/Tools/ralph-v2/skills/ralph-pipeline-full-auto/SKILL.md:182`).