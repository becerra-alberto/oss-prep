# oss-prep

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Version](https://img.shields.io/github/v/release/{owner}/oss-prep)

A Claude Code skill that prepares private git repositories for public open-source release. It runs a 10-phase audit covering secrets, PII, dependencies, code quality, documentation, CI/CD, naming, and history -- then produces a comprehensive readiness report.

## Overview

`oss-prep` is designed to be used as a skill within [Claude Code](https://claude.ai/code) (Anthropic's CLI for Claude). When invoked with `/oss-prep` from the root of any git repository, it walks through a structured 10-phase workflow to audit and prepare the repository for public release.

### Phases

| Phase | Name | Description |
|-------|------|-------------|
| 0 | Reconnaissance | Detect project language, framework, package manager, build system, and test framework |
| 1 | Secrets Audit | Scan for API keys, tokens, credentials, and other secrets using regex pattern libraries |
| 2 | PII Audit | Scan for personally identifiable information (emails, names, phone numbers, etc.) |
| 3 | Dependency Audit | Analyze dependencies for license compatibility and known vulnerabilities |
| 4 | Code Quality | Review code for quality issues, dead code, TODOs, and internal references |
| 5 | Documentation | Generate or enhance README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, and CHANGELOG |
| 6 | GitHub Setup | Configure GitHub repository settings, branch protection, and CI/CD |
| 7 | Naming & Identity | Audit naming conventions and project identity for public consumption |
| 8 | History Flatten | Optionally flatten git history to remove sensitive commits before going public |
| 9 | Final Report | Produce a comprehensive readiness report summarizing all findings |

## Installation

### As part of ai-dev-toolkit

`oss-prep` is distributed as part of the [ai-dev-toolkit](https://github.com/bettos12/ai-dev-toolkit) and is typically installed via git submodule:

```bash
# Add the toolkit as a submodule in your project
git submodule add git@github.com:bettos12/ai-dev-toolkit.git _infra

# Run the installer to symlink skills
./_infra/install.sh
```

### Standalone

Clone this repository and copy the skill directory into your Claude Code skills path:

```bash
git clone https://github.com/{owner}/oss-prep.git
cp -r oss-prep ~/.claude/skills/oss-prep
```

## Usage

From the root of any git repository you want to prepare for open-source release:

```
/oss-prep
```

The skill will:

1. **Validate** the git repository (not shallow, no uncommitted changes, git version >= 2.20)
2. **Walk through each phase** sequentially, presenting findings and requesting approval at each gate
3. **Persist state** to `.oss-prep/state.json` so you can resume if interrupted
4. **Commit after each phase** with scoped staging (explicit file paths, never `git add -A`)

### Resuming a Previous Run

If a previous run was interrupted, `/oss-prep` will detect the existing `.oss-prep/state.json` and offer to continue from where you left off or reset and start over.

### Key Features

- **Phase-gated workflow**: Each phase requires explicit user approval before advancing
- **Grounded findings**: Every finding is backed by actual file paths, line numbers, or tool output
- **Pattern libraries**: Shared regex libraries for secrets (11 categories) and PII (8 categories)
- **Non-destructive**: Existing documentation files are enhanced, never overwritten
- **History safety**: Phase 8 creates backup refs before any history rewriting

## Configuration

No additional configuration is required. The skill reads project metadata from standard manifest files (`package.json`, `Cargo.toml`, `pyproject.toml`, etc.) during Phase 0 reconnaissance.

State is stored in `.oss-prep/state.json` within the target repository. Add `.oss-prep/` to your `.gitignore` if you do not want to track preparation state.

## Project Structure

```
oss-prep/
├── SKILL.md                    # Thin orchestrator for phase sequencing
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
│   ├── secrets.md              # 11-category regex pattern library
│   └── pii.md                  # 8-category regex pattern library
└── state-schema.json           # JSON Schema for persistent state
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

This project is licensed under the MIT License -- see the [LICENSE](LICENSE) file for details.
