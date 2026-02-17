# oss-prep

A Claude Code skill that prepares private git repositories for public open-source release.

Runs a 10-phase interactive audit covering secrets, PII, dependencies, code quality, documentation, CI/CD, naming, and history — then produces a comprehensive readiness report.

## Quick Start

```bash
# Install as a Claude Code skill
# Then run from any git repository:
/oss-prep
```

## Phases

| # | Phase | What It Does |
|---|-------|-------------|
| 0 | Reconnaissance | Detects project type, creates working branch |
| 1 | Secrets Audit | Scans for API keys, tokens, credentials (49 patterns) |
| 2 | PII Audit | Finds personal information, internal identifiers (17+ patterns) |
| 3 | Dependencies | License compatibility, vulnerability scan, lockfile check |
| 4 | Code Quality | Linting, dead code, TODO/FIXME review |
| 5 | Documentation | README coaching, LICENSE selection, CONTRIBUTING template |
| 6 | GitHub Setup | CI/CD, issue templates, branch protection |
| 7 | Naming & Identity | Package names, internal references, API surface |
| 8 | History Flatten | Squash private commits into clean public history |
| 9 | Final Report | Readiness scorecard with pass/fail per phase |
| 10 | Launch | Publish to GitHub, npm/PyPI/crates.io automation |

Each phase runs as a sub-agent to preserve context. State is persisted to `.oss-prep/state.json` after every phase — you can resume interrupted runs.

## Architecture

```
oss-prep/
├── SKILL.md                # Thin orchestrator
├── PRODUCT-BRIEF.md        # Full product brief
├── phases/                 # 11 self-contained phase files
├── patterns/               # Regex libraries (secrets, PII)
└── state-schema.json       # JSON Schema for persistent state
```

## Requirements

- Claude Code CLI
- Git >= 2.20
- A git repository to audit

## License

MIT
