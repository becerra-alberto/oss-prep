# CLAUDE.md — oss-prep v2 Migration

## Migration Intent

This directory contains the **oss-prep** skill, being restructured from a monolithic 3,484-line SKILL.md into a workflow with decomposed phase files, shared pattern libraries, persistent state, and sub-agent delegation.

## Target Architecture

```
skills/oss-prep/
├── SKILL.md                    # Thin orchestrator (~250 lines)
├── phases/
│   ├── 00-recon.md             # Phase 0: Reconnaissance
│   ├── 01-secrets.md           # Phase 1: Secrets Audit
│   ├── 02-pii.md               # Phase 2: PII Audit
│   ├── 03-dependencies.md      # Phase 3: Dependency Audit
│   ├── 04-code-quality.md      # Phase 4: Code Quality
│   ├── 05-documentation.md     # Phase 5: Documentation
│   ├── 06-github-setup.md      # Phase 6: GitHub Setup
│   ├── 07-naming-identity.md   # Phase 7: Naming & Identity
│   ├── 08-history-flatten.md   # Phase 8: History Flatten
│   └── 09-final-report.md      # Phase 9: Final Report
├── patterns/
│   ├── secrets.md              # 11-category regex library
│   └── pii.md                  # 8-category regex library
└── state-schema.json           # Persistent state schema
```

## Extraction Rules (for every phase file)

Each phase file MUST:
1. **Be self-contained**: purpose, inputs, execution steps, outputs, finding format
2. **Declare I/O**: `Inputs:` (state fields read) and `Outputs:` (files created, state updates)
3. **Reference shared patterns**: `Read patterns/secrets.md` instead of inlining regexes
4. **Include its user gate**: the approval prompt specific to this phase
5. **Start with a header block**: phase number, name, inputs, outputs

## Orchestrator Requirements (SKILL.md)

The thin orchestrator (~250 lines) MUST:
1. **Persist state** to `.oss-prep/state.json` after every phase (atomic: write tmp, validate, rename)
2. **Commit after every phase** with scoped staging (explicit file paths, never `git add -A` or `git add .`)
3. **Delegate each phase** to a Task sub-agent (model: opus)
4. **Handle sub-agent failure**: retry once, then fallback to main context
5. **Validate on startup**: git repo checks, uncommitted changes, shallow clone detection
6. **Support resume**: detect existing `.oss-prep/state.json`, offer continue/reset
7. **Preserve verbatim**: Phase-Gating Interaction Model and Grounding Requirement from current SKILL.md

## Design Bug Fixes to Embed

| Bug | Fix | Target File |
|-----|-----|-------------|
| Phase 3 needs license choice (done in Phase 5) | Add license selection preamble to Phase 3 | `phases/03-dependencies.md` |
| Phase 8 deletes ALL tags | Scope to `git tag --merged oss-prep/ready` | `phases/08-history-flatten.md` |
| Phase 8 no backup before flatten | Create `oss-prep/pre-flatten` ref | `phases/08-history-flatten.md` |
| Phase 8 no uncommitted change check | Check before orphan checkout | `phases/08-history-flatten.md` |
| Phase 8 no dry-run | Add dry-run path showing what would change | `phases/08-history-flatten.md` |
| No persistent state | `.oss-prep/state.json` with atomic writes | `state-schema.json` + orchestrator |
| No phase-level commits | Orchestrator commits after each phase | Orchestrator |
| Context exhaustion at Phase 8-9 | Each phase runs as Task sub-agent | Orchestrator |

## Patterns Adopted from Ralph v2

- **Phase-Commit-Gate Sequencing**: Git commit after every phase, user gate before advancing
- **Atomic State Persistence**: `.oss-prep/state.json` with tmp-validate-rename writes
- **Context Window Preservation**: Orchestrator delegates to phase sub-agents; only summaries in main context
- **Scoped Staging**: Explicit file paths in every `git add`, never `-A` or `.`
- **Post-Completion State Transitions**: State written AFTER commit succeeds
- **Cross-Phase Pattern Sharing**: `patterns/secrets.md` and `patterns/pii.md` referenced by phases 1, 2, and 8
- **Startup Validation**: Git state checks before any work begins
- **Sub-Agent Failure Containment**: Retry once, fallback to main context

## Patterns Intentionally Skipped

- Structured signal protocol (sub-agents return via Task tool)
- Auto-decomposition (phases are interactive steps)
- PID lockfile (interactive skill)
- Timeout postmortem / metrics (defer to post-migration)

## Source Material

- `SKILL.md` — the current 3,484-line monolith (source for all extraction)
- `claude-forensic-architecture-review.md` — Claude's architecture review
- `codex-forensic-architecture-review.md` — Codex's architecture review
- `tasks/prd-oss-prep.md` — original v1 PRD

## Sub-Agent Model Policy

All sub-agents spawned via the Task tool MUST use `model: "opus"`. Never use sonnet or haiku.

## Commit Convention

Ralph stories should commit with: `feat(story-{{id}}): {{title}}`

Files to stage per story: only the files that story creates/modifies. Never use `git add -A`.
