# oss-prep — Product Brief

> **Keep this file updated** when phases, patterns, or capabilities change.
> Referenced from `CLAUDE.md` as the canonical source for marketing and website content.

## Elevator Pitch

**One command. Ten phases. Zero secrets shipped.**

oss-prep is an AI-powered CLI skill for Claude Code that transforms any private git repository into a professional, safe-to-publish open-source project. It scans for leaked secrets, PII, license violations, and internal identity leaks across your entire codebase *and* git history — then generates documentation, CI/CD scaffolding, and a comprehensive readiness report. Every finding is grounded in actual code artifacts (never hallucinated), and every change requires explicit approval.

## Invocation

```
/oss-prep
```

That's it. One command. The skill handles everything from there.

---

## The 10-Phase Pipeline

| # | Phase | What It Does | Highlights |
|---|-------|-------------|------------|
| 0 | **Reconnaissance** | Detects project language, framework, build system, test framework | 13+ languages, 20+ frameworks, anomaly detection (large binaries, submodules, symlinks) |
| 1 | **Secrets Audit** | Scans working tree + full git history for credentials | 49 regex patterns across 11 categories, Shannon entropy classification, parallel sub-agents |
| 2 | **PII Audit** | Scans for personally identifiable information + git author emails | 17+ patterns, 8 categories, Luhn validation for credit cards, context-aware severity |
| 3 | **Dependency Audit** | Inventories all dependencies, checks license compatibility | 10 ecosystems, 8x11 license compatibility matrix, private package detection |
| 4 | **Code Quality** | Architecture summary, build/test verification, quality flagging | Dead code, TODO/FIXME with names, commented-out blocks, hardcoded config |
| 5 | **Documentation** | Generates/enhances 7 standard files | README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CHANGELOG, CLAUDE.md sanitization |
| 6 | **GitHub Setup** | Issue/PR templates, CI/CD workflows, .gitignore review | Language-tailored GitHub Actions, YAML frontmatter templates |
| 7 | **Naming & Identity** | Package name conflicts, internal leaks, telemetry disclosure | npm/PyPI/crates.io availability, 13+ analytics SDK detection, disclosure templates |
| 8 | **History Flatten** | Assesses risk, optionally squashes all commits | Backup ref, scoped tag deletion, dry-run, typed "flatten" confirmation, post-flatten re-scan |
| 9 | **Final Report** | Synthesizes everything into a readiness verdict | Risk matrix, per-phase summaries, launch checklist, Ready / Caveats / Not Ready rating |

### Phase Details

#### Phase 0 — Reconnaissance
- Auto-detects language(s), framework(s), package manager(s), build system, test framework via file extension analysis and manifest inspection
- Supports 13+ languages: Python, JS/TS, Rust, Go, Ruby, Java, C/C++, C#, Swift, Kotlin, PHP, Shell
- Detects 20+ frameworks: Next.js, React, Vue, Angular, Svelte, Django, Flask, FastAPI, Rails, Sinatra, Actix, Rocket, Gin, Echo, Spring Boot, Express, Nest.js, Nuxt.js, SvelteKit, Remix
- Detects 11+ package managers: npm, yarn, pnpm, Bun, Cargo, Go Modules, pip, Poetry, Bundler, Maven, Gradle, Composer
- Anomaly detection: submodules, large binary files (>1MB), symlinks, non-standard permissions
- Gathers metrics: file count, LOC, commit count, CI/CD presence

#### Phase 1 — Secrets Audit
- **Parallel sub-agent execution**: Two sub-agents scan working tree and git history simultaneously
- References shared `patterns/secrets.md` library (11 categories, 49 patterns)
- **Shannon entropy classification**: H > 3.5 = likely real credential; H <= 2.0 = likely placeholder
- Severity: CRITICAL (confirmed + high entropy or PEM key), HIGH, MEDIUM, LOW
- **Opportunistic tool integration**: Auto-detects trufflehog or gitleaks if installed
- Partial redaction of matched values in reports
- Language-aware remediation: env var syntax for JS, Python, Ruby, Go, Rust, Java, PHP, Shell

#### Phase 2 — PII Audit
- **Three parallel sub-agents**: Working tree, git history, git author/committer email audit
- References shared `patterns/pii.md` library (8 categories, 17+ patterns)
- **Luhn validation** for credit card numbers
- **Comprehensive allowlist**: Test emails, localhost/private IPs, Stripe test cards, placeholder SSNs, cryptographic persona names (Alice, Bob, Eve)
- **Context-aware severity**: PII in test files or comments downgraded one level; LICENSE file names always skipped
- Git author email audit: flags personal emails, recommends noreply@users.noreply.github.com

#### Phase 3 — Dependency Audit
- **License selection preamble**: Prompts for license choice BEFORE running compatibility analysis
- Manifest detection across **10 ecosystems**: Node.js, Python, Rust, Go, Ruby, Java/Gradle, PHP, .NET, Elixir, Swift
- **License compatibility matrix**: 8x11 matrix (MIT, ISC, BSD, Apache-2.0, GPL-2.0, GPL-3.0, AGPL-3.0, Unlicense)
- Private dependency detection: scoped packages, `file:` protocol, `git+ssh://` URLs, private registry configs
- **Graceful degradation**: Works without toolchain, extracts from manifests/lockfiles
- **Vulnerability checking**: npm audit, pip-audit, cargo-audit, bundle-audit if available

#### Phase 4 — Code Quality
- **Three parallel sub-agents**: Architecture summary, coding standards detection, quality flagging
- Architecture: directory structure, module boundaries, entry points, key abstractions
- Standards: Prettier, EditorConfig, Black, rustfmt, Biome, ESLint, Ruff, Clippy, TypeScript, mypy
- Build verification with 5-minute timeout (non-blocking)
- Test verification with 10-minute timeout (non-blocking)
- Quality: dead code, TODO/FIXME with internal context, commented-out blocks (3+ lines), hardcoded config

#### Phase 5 — Documentation
- **7 files**: README.md, LICENSE, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md, CLAUDE.md
- **Three-tier approach**: Generate (new), Enhance (additions), Review Only (check references)
- Up to 5 parallel sub-agents for generation
- README: 7 sections tailored to detected language/framework — badges, installation, usage, config, contributing, license
- CONTRIBUTING: tailored to detected tools — dev setup, branch naming, test/lint commands, PR process
- SECURITY: responsible disclosure instructions, 48-hour acknowledgment SLA
- CLAUDE.md sanitization: removes private endpoints, internal tool names, employee names, Jira references

#### Phase 6 — GitHub Setup
- Issue templates: Bug Report, Feature Request with YAML frontmatter
- PR template with type-of-change checkboxes and checklist
- **Language-tailored CI workflow**: Node.js, Python, Rust, Go
- **.gitignore review** across 4 categories: OS files, IDE files, language artifacts, environment files

#### Phase 7 — Naming & Identity
- **Package name availability**: npm, PyPI, crates.io, RubyGems, Go modules via web search
- **Internal identity leak scanning**: internal URLs, Jira/Confluence/Linear links, Slack/Teams/Discord references, company/team names
- **Telemetry detection**: 13 JS/TS SDKs, 6 Python SDKs (Segment, Mixpanel, Amplitude, GA, PostHog, etc.)
- Custom telemetry indicators: tracking functions, telemetry config patterns, outbound data transmission
- **Telemetry disclosure template**: what is collected, where sent, how to opt out

#### Phase 8 — History Flatten
- **Two-dispatch architecture**: Assessment (non-destructive) → Orchestrator gate → Execution (destructive)
- **Safety hardening**: backup ref (`refs/oss-prep/pre-flatten`), scoped tag deletion, uncommitted change check, dry-run mode
- **Stronger confirmation gate**: user must type exactly "flatten" (not y/yes/ok)
- Post-flatten verification: re-runs secret AND PII detection
- Decline path: alternative `git filter-repo` commands for selective rewriting

#### Phase 9 — Final Report
- **Risk matrix table**: every finding with Phase, Category, Severity, Status
- **Readiness rating**: Ready (0 critical/high), Ready with Caveats (0 critical, some high/medium), Not Ready (critical remaining)
- Per-phase detail sections
- **Launch checklist**: create repo, push, set public, verify CI, add collaborators, create release, announce
- Saved to `{project_root}/oss-prep-report-{YYYY-MM-DD}.md`

---

## Key Numbers

| Metric | Value |
|--------|-------|
| Secret detection patterns | 49 across 11 categories |
| PII detection patterns | 17+ across 8 categories |
| Dependency ecosystems | 10 |
| License compatibility matrix | 8x11 |
| Languages auto-detected | 13+ |
| Frameworks recognized | 20+ |
| Documentation files generated | 7 |
| Orchestrator size (v2) | 227 lines |
| Orchestrator size reduction | 94% (from 3,484 lines) |
| Phases | 10 |

---

## Secret Detection Categories

1. AWS Credentials (Access Key, Secret Key, Session Token)
2. GCP Credentials (Service Account Key, API Key, OAuth Secret)
3. Azure Credentials (Subscription Key, Connection String)
4. GitHub Tokens (PAT, OAuth, Fine-Grained — 6 patterns)
5. Generic API Keys & Tokens (6 patterns)
6. Database Connection Strings (MongoDB, PostgreSQL, MySQL, Redis, MSSQL, JDBC)
7. Private Keys — PEM Format (RSA, DSA, EC, Ed25519, PGP)
8. JWT & OAuth Secrets
9. SMTP Credentials
10. .env File Contents
11. Vendor-Specific (Slack, Stripe, Twilio, SendGrid, Heroku, Notion)

## PII Detection Categories

1. Email Addresses (with personal provider flagging)
2. Phone Numbers (NA + international E.164)
3. Physical/Mailing Addresses
4. Public IP Addresses (excludes private/docs ranges)
5. Social Security Numbers
6. Credit Card Numbers (with Luhn validation)
7. Internal Employee Identifiers (Jira tickets, Slack channels, badge IDs)
8. Hardcoded Personal Names

---

## Technical Differentiators

### Shannon Entropy Classification
Computes information entropy on matched credential values:
- **H > 3.5** bits/char → likely real credential (CRITICAL)
- **2.0 < H <= 3.5** → possibly real (HIGH)
- **H <= 2.0** → likely placeholder (MEDIUM/LOW)

### Anti-Hallucination Grounding
Every finding MUST include file path + line number, commit hash, or grep match output. Zero findings is a valid result. "Prefer false negatives over false positives."

### Atomic State Persistence
State saved to `.oss-prep/state.json` using write-validate-rename pattern. Session crashes, timeouts, terminal closures — resume from last completed phase.

### Context Window Preservation
Each phase runs in its own sub-agent context. Only summaries flow back. The orchestrator stays under 30K tokens while each sub-agent gets ~130K tokens of working space.

### Two-Dispatch Destructive Operations
Phase 8 uses a split architecture: Assessment sub-agent (non-destructive) → orchestrator gate (user types "flatten") → Execution sub-agent (destructive). The sub-agent never controls the confirmation.

### Phase-Commit-Gate Sequencing
Git commit after every phase. User gate before every advancement. Every phase's output is durable. The pipeline is always resumable.

### Sub-Agent Failure Containment
Retry once with simplified prompt. If retry fails, fall back to main context execution with degradation warning. Failures logged in state for final report.

---

## Problems It Solves

| Problem | What Happens Without oss-prep |
|---------|------------------------------|
| Leaked credentials in git history | Anyone who clones can recover old API keys, tokens, passwords |
| Exposed PII | Email addresses, names, SSNs in code comments and commit metadata |
| License violations | Ship a GPL dependency in your MIT project — legal liability |
| Missing documentation | No README, no contributing guide — contributors bounce |
| No CI/CD scaffolding | PRs merged without tests, no automated quality gates |
| Internal identity leaks | Company Jira tickets, Slack channels, internal URLs in the codebase |
| Undisclosed telemetry | Analytics SDKs nobody knows about — trust-destroying |
| Package name conflicts | Your chosen name is already taken on npm/PyPI |
| Session loss | 30+ minute audit restarts from scratch |
| Manual inconsistency | Quality depends on developer's experience and memory |

---

## Comparison: Manual Prep vs oss-prep

| Aspect | Manual Prep | oss-prep |
|--------|------------|----------|
| Secret scanning | grep for a few patterns | 49 patterns + entropy analysis + trufflehog/gitleaks integration |
| PII scanning | Search for emails manually | 17+ patterns with allowlists, Luhn validation, context-aware severity |
| Git history audit | Maybe check recent commits | Systematic scan of full `git log -p --all` |
| License compliance | Check a few deps manually | Automated across 10 ecosystems with compatibility matrix |
| Documentation | Write from scratch | Auto-generated, language-tailored, preserves existing content |
| CI/CD | Copy from another project | Generated from detected project profile |
| History flatten | Scary git commands, hope for the best | Backup ref, dry-run, scoped tags, typed confirmation |
| Resumability | Start over on interruption | Persistent state, resume from any phase |
| Consistency | Varies wildly | Grounding requirement — every finding verified |

---

## Target Audience

- **Solo devs** open-sourcing side projects
- **Startup teams** releasing internal tools
- **Enterprise developers** publishing internal libraries
- **OSS maintainers** auditing existing projects for compliance
- Anyone using **Claude Code** who wants one-command open-source prep

---

## User Interaction Model

Four options at every phase gate:
1. **Approve** — advance to next phase
2. **Review details** — see full findings
3. **Request changes** — modify before advancing
4. **Skip** — bypass this phase

Progressive disclosure: summaries first, details on demand. The user is always in control.

---

## Supported Ecosystems

**Languages**: Python, JavaScript/TypeScript, Rust, Go, Ruby, Java, C/C++, C#, Swift, Kotlin, PHP, Shell, Elixir

**Frameworks**: Next.js, React, Vue, Angular, Svelte, Django, Flask, FastAPI, Rails, Sinatra, Actix, Rocket, Gin, Echo, Spring Boot, Express, Nest.js, Nuxt.js, SvelteKit, Remix

**Package Managers**: npm, yarn, pnpm, Bun, Cargo, Go Modules, pip, Poetry, Bundler, Maven, Gradle, Composer, Mix

---

## Architecture

```
oss-prep/
├── SKILL.md                # Thin orchestrator
├── PRODUCT-BRIEF.md        # This file
├── phases/
│   ├── 00-recon.md         # Phase 0: Reconnaissance
│   ├── 01-secrets.md       # Phase 1: Secrets Audit
│   ├── 02-pii.md           # Phase 2: PII Audit
│   ├── 03-dependencies.md  # Phase 3: Dependencies
│   ├── 04-code-quality.md  # Phase 4: Code Quality
│   ├── 05-documentation.md # Phase 5: Documentation
│   ├── 06-github-setup.md  # Phase 6: GitHub Setup
│   ├── 07-naming-identity.md # Phase 7: Naming & Identity
│   ├── 08-history-flatten.md # Phase 8: History Flatten
│   ├── 09-final-report.md  # Phase 9: Final Report
│   └── 10-launch.md        # Phase 10: Launch Automation
├── patterns/
│   ├── secrets.md          # 49 patterns, 11 categories
│   └── pii.md              # 17+ patterns, 8 categories
└── state-schema.json       # JSON Schema for persistent state
```

Runtime creates `.oss-prep/state.json` in the target repo. All work happens on the `oss-prep/ready` branch — the original branch is never modified.

---

## Design Principles

1. **Never ship secrets** — scan working tree AND full git history
2. **Never hallucinate** — every finding grounded in actual code artifacts
3. **Never destroy without consent** — typed confirmation for destructive ops
4. **Never lose progress** — atomic state persistence, resume from any phase
5. **Never overwrite** — enhance existing files, generate missing ones
6. **Always local** — no external services required, opportunistic tool integration
7. **Always resumable** — session crashes are a non-event
8. **Always reversible** — dedicated branch, backup refs, dry-run mode

---

## Development History

- **v1**: 3,484-line monolithic SKILL.md — worked but suffered from context exhaustion, no persistent state, no phase commits, and design bugs
- **v2**: Decomposed into thin orchestrator + 10 phase files + 2 pattern libraries + state schema
- **Migration**: Executed across 3 epics, 12 stories
  - Epic 1 (Foundation): pattern libraries + state schema
  - Epic 2 (Phase Extraction): one story per phase (parallelizable)
  - Epic 3 (Orchestrator): replace SKILL.md (capstone)
- **Two independent architecture reviews** (Claude + Codex) identified the same critical issues
- **8 design bugs fixed** in v2

### Design Goals

| ID | Goal |
|----|------|
| G-1 | Zero secrets remaining after remediation + flatten |
| G-2 | Zero PII remaining after remediation + flatten |
| G-3 | All dependencies with identified licenses; incompatible licenses flagged |
| G-4 | Complete documentation suite |
| G-5 | Clean, professional git history |
| G-6 | CI/CD and GitHub scaffolding |
| G-7 | Build and test integrity verified |
| G-8 | Comprehensive readiness report |
| G-9 | Works on any repository (repo-agnostic) |
| G-10 | Zero destructive operations without explicit approval |

### Non-Goals

- Does NOT create GitHub repositories (manual step)
- Does NOT provide legal advice
- Does NOT perform SAST/DAST penetration testing
- Does NOT manage ongoing maintenance
- Does NOT audit submodule contents
- Does NOT publish packages to registries
- Does NOT automate selective history rewriting (only full flatten)
- Does NOT require external paid services
