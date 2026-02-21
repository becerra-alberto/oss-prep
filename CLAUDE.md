# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

oss-prep is a Claude Code skill that prepares private git repositories for public open-source release through a 10-phase audit workflow.

## Architecture

```
oss-prep/
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

## Key Design Patterns

- **Phase-Commit-Gate Sequencing**: Git commit after every phase, user gate before advancing
- **Atomic State Persistence**: `.oss-prep/state.json` with tmp-validate-rename writes
- **Context Window Preservation**: Orchestrator delegates to phase sub-agents; only summaries in main context
- **Scoped Staging**: Explicit file paths in every `git add`, never `-A` or `.`
- **Cross-Phase Pattern Sharing**: `patterns/secrets.md` and `patterns/pii.md` referenced by phases 1, 2, and 8

## Phase File Conventions

Each phase file must:
1. Be self-contained: purpose, inputs, execution steps, outputs, finding format
2. Declare I/O: `Inputs:` (state fields read) and `Outputs:` (files created, state updates)
3. Reference shared patterns instead of inlining regexes
4. Include its user gate prompt
5. Start with a header block: phase number, name, inputs, outputs

## Sub-Agent Policy

All sub-agents spawned via the Task tool must use `model: "opus"`.
