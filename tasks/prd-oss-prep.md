# PRD: Open-Source Preparation Tool (`/oss-prep`)

**Date**: 2026-02-12
**Author**: Auto-generated (Claude Code)
**Status**: Draft
**Skill location**: `skills/oss-prep/SKILL.md`

---

## 1. Design Decisions

The following questions would normally require user clarification. Since this PRD is being generated autonomously, each was resolved with the safest, most conventional answer.

### DD-1: Should history flattening (Phase 8) default to squash-to-one-commit or offer multiple strategies?

**Decision**: Offer multiple strategies (squash-all, squash-per-phase, rebase-interactive outline) but default to **squash-all into a single "Initial public release" commit**. This is the safest default because it eliminates all risk of leaked secrets or PII in history with zero ambiguity. The user can override to a more granular strategy if they want to preserve meaningful history.

**Rationale**: The primary purpose of history flattening is risk elimination. A single-commit flatten is the only strategy that provides a binary guarantee: either ALL history is gone or it is not. More granular strategies require auditing each remaining commit, which reintroduces the risk the phase exists to eliminate.

### DD-2: Should the tool modify files in-place or work on a branch/copy?

**Decision**: The tool operates on a **dedicated preparation branch** (`oss-prep/ready`) created from the current branch at the start of Phase 0. All modifications (documentation generation, .gitignore updates, CI/CD setup, history flatten) happen on this branch. The original branch is never modified. The final flatten (Phase 8) replaces this branch's history.

**Rationale**: Working on a branch preserves the user's existing work and provides a natural rollback mechanism (`git branch -D oss-prep/ready`). It also makes it clear which changes are "oss-prep artifacts" vs. the user's original code.

### DD-3: What license should be suggested as the default when no LICENSE file exists?

**Decision**: Present a menu of common licenses (MIT, Apache-2.0, GPL-3.0, BSD-2-Clause, BSD-3-Clause, MPL-2.0, ISC, Unlicense) with **MIT as the highlighted default**. The tool must never auto-select a license without user confirmation.

**Rationale**: MIT is the most permissive widely-used license and is the conventional choice for open-source projects that want maximum adoption. However, license selection is a legal decision that must always involve explicit user consent.

### DD-4: How should the tool handle repos that use git submodules or monorepo structures?

**Decision**: The tool operates on the **current repository only**. If submodules are detected, warn the user that submodule contents are not audited and recommend running `/oss-prep` separately inside each submodule that will also be open-sourced. Monorepo structures (e.g., Lerna, Nx, Turborepo) are handled as a single repo -- all packages are audited together.

**Rationale**: Submodules are independent git repositories with their own histories, secrets, and licenses. Auditing them transitively would create confusion about scope and could lead to modifications in repos the user does not intend to open-source. Monorepos, by contrast, are a single repository and should be treated holistically.

### DD-5: Should the tool integrate with external scanning services (e.g., Snyk, Trivy, GitGuardian) or rely entirely on local analysis?

**Decision**: Rely entirely on **local analysis using built-in tools** (grep, git log, file inspection). Do not require or invoke external services. If external tools are installed locally (e.g., `trufflehog`, `gitleaks`, `trivy`), detect and use them opportunistically to enhance results, but never fail if they are absent.

**Rationale**: The tool must work in any environment without requiring API keys, network access, or paid subscriptions. Opportunistic use of locally-installed tools provides enhanced coverage for users who have them, without creating a hard dependency.

---

## 2. Introduction / Overview

### Problem Statement

Converting a private repository to a public open-source project is a high-stakes operation with irreversible consequences. Once code is pushed to a public repository, secrets, PII, proprietary references, and embarrassing history are permanently exposed. Developers typically attempt this conversion manually, relying on memory and incomplete checklists, which leads to:

- **Leaked credentials** (API keys, tokens, passwords committed months ago and forgotten)
- **Exposed PII** (email addresses, internal usernames, company references in code comments)
- **License violations** (dependencies with incompatible licenses bundled without attribution)
- **Missing documentation** (no README, no CONTRIBUTING guide, no CODE_OF_CONDUCT)
- **Unprofessional presentation** (messy git history, no CI/CD, broken builds)
- **Trademark and naming conflicts** (project name already taken on npm/PyPI/crates.io)

### Solution

`/oss-prep` is a Claude Code skill that conducts a thorough, 10-phase audit and transformation of any private git repository, preparing it for public release on GitHub. It is interactive, phase-gated, and grounds every finding in actual code -- never hallucinating files or issues. Each phase produces a summary and requires user approval before proceeding. The final output is a comprehensive readiness report and a clean, well-documented codebase ready for `git push`.

### Scope

The tool is a single `SKILL.md` file invoked as `/oss-prep` from Claude Code. It works on any git repository the user runs it from (not limited to the ai-dev-toolkit repo). It leverages sub-agents for parallelizable audit phases and produces a master report at the end.

---

## 3. Goals

| ID | Goal | Measurable Outcome |
|----|------|--------------------|
| G-1 | Eliminate secrets from the codebase and git history | Zero secrets detected in post-flatten verification scan |
| G-2 | Eliminate PII from the codebase and git history | Zero PII findings in post-flatten verification scan |
| G-3 | Ensure license compatibility across all dependencies | All dependencies have identified licenses; incompatible licenses flagged and resolved |
| G-4 | Generate complete open-source documentation suite | README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY.md, and CHANGELOG all exist and pass quality checks |
| G-5 | Produce a clean, professional git history | History is flattened (or cleaned) with user approval; no leaked data in any remaining commit |
| G-6 | Set up CI/CD and GitHub repository scaffolding | `.github/` directory with issue/PR templates and at least one CI workflow |
| G-7 | Verify build and test integrity | Project builds and tests pass (or failures are documented) before release |
| G-8 | Produce a comprehensive readiness report | Final report covers all 10 phases with risk matrix, findings, and launch checklist |
| G-9 | Work on any repository | Tool is repo-agnostic; auto-detects language, framework, and project structure |
| G-10 | Preserve user control over destructive operations | Every destructive operation (file deletion, history rewrite) requires explicit user confirmation |

---

## 4. User Stories

### US-1: Secret Detection and Removal

**As a** developer preparing to open-source a private repo,
**I want** the tool to find all secrets (API keys, tokens, passwords) in both the current codebase and git history,
**So that** I don't accidentally expose credentials when the repo goes public.

**Acceptance Criteria:**
- AC-1.1: The tool scans all files in the working tree for patterns matching API keys, tokens, passwords, connection strings, and private keys.
- AC-1.2: The tool scans git history (`git log -p`) for secrets that were committed and later removed.
- AC-1.3: Each finding includes the file path (or commit hash), line number, the matched pattern, and a severity rating.
- AC-1.4: The tool proposes surgical remediation (e.g., replace with environment variable reference, add to `.gitignore`) rather than blanket file deletion.
- AC-1.5: No remediation is applied without user approval.

### US-2: PII Detection and Removal

**As a** developer preparing to open-source a private repo,
**I want** the tool to find personally identifiable information in the codebase and git history,
**So that** I don't expose personal data (emails, names, internal identifiers) to the public.

**Acceptance Criteria:**
- AC-2.1: The tool detects email addresses, phone numbers, IP addresses, internal usernames/employee IDs, and hardcoded names in code and comments.
- AC-2.2: The tool distinguishes between public/generic PII (e.g., `noreply@github.com`, `127.0.0.1`) and genuinely sensitive PII.
- AC-2.3: Git author information is flagged if it uses a personal email rather than a noreply address.
- AC-2.4: Each finding is presented with context and a remediation suggestion.

### US-3: Dependency License Audit

**As a** developer preparing to open-source a private repo,
**I want** the tool to inventory all dependencies and verify license compatibility,
**So that** I don't violate any license terms when publishing.

**Acceptance Criteria:**
- AC-3.1: The tool reads package manifests (`package.json`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Gemfile`, `pom.xml`, etc.) and produces a dependency inventory.
- AC-3.2: Each dependency's license is identified (from lock files, manifest metadata, or local analysis).
- AC-3.3: License compatibility is checked against the project's chosen license.
- AC-3.4: Private/internal dependencies (e.g., `@company/internal-lib`) are flagged for removal or replacement.
- AC-3.5: Known vulnerabilities are checked if local tooling is available.

### US-4: Documentation Generation

**As a** developer preparing to open-source a private repo,
**I want** the tool to generate all standard open-source documentation files,
**So that** the repository looks professional and is contributor-friendly from day one.

**Acceptance Criteria:**
- AC-4.1: The tool generates or validates: README.md, LICENSE, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md.
- AC-4.2: If a CLAUDE.md exists, it is reviewed for internal/private references and sanitized.
- AC-4.3: README.md includes sections for: project description, installation, usage, contributing, and license.
- AC-4.4: All generated documentation is presented for user review before writing.
- AC-4.5: Existing documentation files are preserved and enhanced, not overwritten.

### US-5: Git History Management

**As a** developer preparing to open-source a private repo,
**I want** the tool to assess my git history for risks and flatten it if needed,
**So that** sensitive information in old commits is not exposed.

**Acceptance Criteria:**
- AC-5.1: The tool presents a history risk assessment (number of commits, detected secrets/PII in history, large binary files).
- AC-5.2: A pre-flatten checklist is presented showing what will be lost (tags, branches, blame attribution).
- AC-5.3: Phase 8b (pre-flatten checklist) BLOCKS until the user provides explicit confirmation.
- AC-5.4: After flattening, a verification scan confirms no secrets or PII remain.
- AC-5.5: The original branch is never modified; all changes happen on the preparation branch.

### US-6: Final Readiness Report

**As a** developer preparing to open-source a private repo,
**I want** a comprehensive readiness report covering all audit phases,
**So that** I have confidence the repository is safe to publish and a checklist for the actual launch.

**Acceptance Criteria:**
- AC-6.1: The report includes a risk matrix with severity ratings across all phases.
- AC-6.2: Each phase has a detailed section with findings, actions taken, and remaining items.
- AC-6.3: A launch checklist summarizes all remaining manual steps (e.g., "Create GitHub repo", "Set repo to public", "Verify GitHub Actions run").
- AC-6.4: The report is written to a file in the repository for future reference.

### US-7: Naming and Identity Review

**As a** developer preparing to open-source a private repo,
**I want** the tool to check for naming conflicts and internal identity leaks,
**So that** my project name is available and no internal company references are exposed.

**Acceptance Criteria:**
- AC-7.1: The tool checks if the project name is available on relevant package registries (npm, PyPI, crates.io, etc.).
- AC-7.2: Internal company names, team names, and internal tool references are flagged in code and documentation.
- AC-7.3: Any telemetry, analytics, or phone-home code is detected and disclosed.
- AC-7.4: Findings are presented with remediation suggestions (rename, remove, disclose).

---

## 5. Functional Requirements

### Phase 0: Reconnaissance

**FR-1**: The tool SHALL detect the project root via `git rev-parse --show-toplevel` and warn if running inside a submodule.

**FR-2**: The tool SHALL create a preparation branch (`oss-prep/ready`) from the current HEAD. If the branch already exists, ask the user whether to reset it or resume.

**FR-3**: The tool SHALL build a project profile including: primary language(s), framework(s), package manager(s), build system, test framework, directory structure, total file count, total lines of code, git history depth (commit count), and presence of CI/CD configuration.

**FR-4**: The tool SHALL detect and report: submodules, large binary files (>1MB), symlinks, and non-standard file permissions.

**FR-5**: The tool SHALL present the project profile to the user and ask for confirmation before proceeding.

### Phase 1: Secrets & Credentials Audit

**FR-6**: The tool SHALL scan the current working tree for secrets using pattern matching against at least these categories: AWS keys, GCP keys, Azure keys, GitHub tokens, generic API keys/tokens, database connection strings, private keys (RSA, DSA, EC, Ed25519), JWT secrets, OAuth client secrets, SMTP credentials, and `.env` file contents.

**FR-7**: The tool SHALL scan git history (`git log -p --all`) for secrets that were committed and later removed, reporting the commit hash, author, date, and file path for each finding.

**FR-8**: The tool SHALL classify each secret finding by severity: CRITICAL (confirmed credential with high entropy), HIGH (pattern match with context suggesting a real secret), MEDIUM (potential false positive), LOW (example/placeholder value).

**FR-9**: The tool SHALL propose surgical remediation for each finding: replacement with environment variable references, addition to `.gitignore`/`.env.example`, or content redaction. The tool SHALL NOT delete files without user approval.

**FR-10**: The tool SHALL present all findings with remediation proposals and wait for user approval before applying any changes.

### Phase 2: PII Audit

**FR-11**: The tool SHALL scan the current working tree for PII including: email addresses, phone numbers, physical addresses, IP addresses (excluding localhost/private ranges), social security numbers, credit card numbers, internal employee IDs, and hardcoded personal names in code comments or strings.

**FR-12**: The tool SHALL scan git history for PII that was committed and later removed.

**FR-13**: The tool SHALL check git author/committer information for personal email addresses and flag them with a recommendation to use `noreply@github.com` or a project-specific email.

**FR-14**: The tool SHALL distinguish between genuinely sensitive PII and public/generic values (e.g., `example@example.com`, `127.0.0.1`, RFC 5737 documentation addresses).

**FR-15**: The tool SHALL present findings with remediation proposals and wait for user approval before applying changes.

### Phase 3: Dependency Audit

**FR-16**: The tool SHALL detect and read all package manifests in the repository (`package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `requirements.txt`, `Pipfile`, `pyproject.toml`, `poetry.lock`, `Cargo.toml`, `Cargo.lock`, `go.mod`, `go.sum`, `Gemfile`, `Gemfile.lock`, `pom.xml`, `build.gradle`, `composer.json`, etc.).

**FR-17**: The tool SHALL produce a dependency inventory table listing: package name, version (pinned or range), license (if detectable), and whether the dependency is direct or transitive (when lock files are available).

**FR-18**: The tool SHALL check license compatibility by comparing each dependency's license against the project's LICENSE file (or intended license). Incompatible licenses SHALL be flagged as CRITICAL (e.g., GPL dependency in an MIT project).

**FR-19**: The tool SHALL flag private/internal dependencies (packages from private registries, scoped packages matching internal naming conventions like `@company/*`, or dependencies with `file:` or `link:` protocols).

**FR-20**: The tool SHALL opportunistically check for known vulnerabilities if `npm audit`, `pip-audit`, `cargo audit`, or similar tools are available locally.

### Phase 4: Code Architecture & Quality Review

**FR-21**: The tool SHALL produce a high-level architecture summary: directory structure, module boundaries, entry points, and key abstractions.

**FR-22**: The tool SHALL check coding standards: consistent formatting, linting configuration presence, type checking configuration, and build scripts.

**FR-23**: The tool SHALL verify the project builds successfully by running the detected build command (e.g., `npm run build`, `cargo build`, `python -m py_compile`). Build failures SHALL be reported but SHALL NOT block subsequent phases.

**FR-24**: The tool SHALL verify tests run by executing the detected test command (e.g., `npm test`, `pytest`, `cargo test`). Test results SHALL be reported.

**FR-25**: The tool SHALL flag code quality concerns relevant to open-source readiness: dead code, TODO/FIXME/HACK comments referencing internal context, commented-out code blocks, and hardcoded configuration values.

### Phase 5: Documentation

**FR-26**: The tool SHALL check for the existence and completeness of: `README.md`, `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `CHANGELOG.md`, and `CLAUDE.md`.

**FR-27**: For each missing documentation file, the tool SHALL generate a draft tailored to the project's language, framework, and structure. Generated content SHALL be presented for user review before writing.

**FR-28**: For existing documentation files, the tool SHALL review for: internal/private references, incomplete sections, broken links, and outdated information. Findings SHALL be presented as suggestions, not automatic edits.

**FR-29**: The tool SHALL generate a `README.md` (or enhance an existing one) with sections for: project name and description, badges (build status, license, version), installation instructions, usage examples, configuration, contributing guidelines reference, and license reference.

**FR-30**: For `CLAUDE.md`, the tool SHALL sanitize any internal references (private API endpoints, internal tool names, employee names) while preserving project-relevant development instructions.

**FR-31**: For `LICENSE`, the tool SHALL present a license selection menu if no LICENSE file exists (see DD-3). If a LICENSE file exists, the tool SHALL verify it is a recognized open-source license and that the copyright holder information is appropriate for public release.

### Phase 6: GitHub Repository Setup & CI/CD

**FR-32**: The tool SHALL generate `.github/ISSUE_TEMPLATE/bug_report.md` and `.github/ISSUE_TEMPLATE/feature_request.md` if they do not exist.

**FR-33**: The tool SHALL generate `.github/PULL_REQUEST_TEMPLATE.md` if it does not exist.

**FR-34**: The tool SHALL generate a CI workflow file (`.github/workflows/ci.yml`) appropriate for the detected language and test framework. The workflow SHALL include: lint, build, and test steps at minimum.

**FR-35**: The tool SHALL review `.gitignore` for completeness, adding entries for: OS files (`.DS_Store`, `Thumbs.db`), IDE files (`.idea/`, `.vscode/`), language-specific artifacts (e.g., `node_modules/`, `__pycache__/`, `target/`), and environment files (`.env`, `.env.local`).

**FR-36**: All generated files SHALL be presented for user review before writing.

### Phase 7: Naming, Trademark & Identity Review

**FR-37**: The tool SHALL check the project name's availability on relevant package registries by inspecting the package manifest (e.g., check npm if `package.json` exists, PyPI if `pyproject.toml` exists, crates.io if `Cargo.toml` exists). Availability checks SHALL use web searches or registry API queries where feasible.

**FR-38**: The tool SHALL scan the codebase for internal identity leaks: company names, team names, internal tool names, internal URLs (e.g., `*.internal.company.com`, Jira/Confluence links), and Slack channel references.

**FR-39**: The tool SHALL detect telemetry, analytics, or phone-home code (e.g., Segment, Mixpanel, custom analytics endpoints, usage tracking) and flag it for disclosure in the README or removal.

**FR-40**: The tool SHALL present findings with remediation suggestions: rename project, remove internal references, add telemetry disclosure section, or acknowledge.

### Phase 8: History Flatten

**FR-41**: The tool SHALL present a history assessment including: total commits, number of contributors, date range, branches, tags, secrets/PII found in history (from Phases 1-2), and large files in history.

**FR-42**: The tool SHALL present a pre-flatten checklist clearly stating what will be lost: all commit history, all tags, all branch references, git blame attribution, and any unsigned commits becoming the sole authored commit.

**FR-43**: The tool SHALL NOT proceed past the pre-flatten checklist (Phase 8b) without explicit user confirmation. The confirmation prompt SHALL include the word "irreversible" and require the user to type a confirming response (not just "y").

**FR-44**: Upon confirmation, the tool SHALL execute the flatten by: creating a new orphan branch, adding all current files, creating a single commit with a message like "Initial public release" (customizable by the user), and force-updating the preparation branch to point to this commit.

**FR-45**: After flattening, the tool SHALL run a verification scan (re-running the secret and PII detection from Phases 1-2) on the new single commit to confirm no sensitive data remains.

**FR-46**: If the user declines flattening, the tool SHALL offer alternatives: selective history rewriting (e.g., `git filter-repo` commands for specific files), or proceeding without flattening (with appropriate risk warnings in the final report).

### Phase 9: Final Report

**FR-47**: The tool SHALL generate a comprehensive readiness report saved to `oss-prep-report-{YYYY-MM-DD}.md` in the project root.

**FR-48**: The report SHALL include a risk matrix table with columns: Phase, Category, Severity, Finding, Status (Resolved/Accepted/Outstanding).

**FR-49**: The report SHALL include a summary section with: overall readiness rating (Ready / Ready with Caveats / Not Ready), count of findings by severity, count of findings by status.

**FR-50**: The report SHALL include detailed sections for each phase (0-8) listing: what was checked, what was found, what was remediated, and what remains outstanding.

**FR-51**: The report SHALL include a launch checklist with remaining manual steps, including at minimum: "Create GitHub repository", "Push preparation branch", "Set repository to public", "Verify CI/CD pipeline runs", "Add collaborators/teams", "Create initial release/tag", "Announce the project".

**FR-52**: The tool SHALL present the final report summary to the user and congratulate them or warn them based on the overall readiness rating.

### Cross-Cutting Requirements

**FR-53**: The tool SHALL use sub-agents (via the Task tool) aggressively for parallelizable work within each phase. At minimum, Phases 1 and 2 (secrets and PII scanning of current tree vs. git history) SHALL be parallelized.

**FR-54**: The tool SHALL present a brief summary after each phase and ask for user approval before proceeding to the next phase. The summary SHALL include: findings count by severity, actions taken, and any items requiring attention.

**FR-55**: Every finding SHALL be grounded in actual code -- the tool SHALL include file paths, line numbers, commit hashes, or other concrete references. The tool SHALL NEVER fabricate or hallucinate findings.

**FR-56**: The tool SHALL maintain a running state block (similar to the changelog skill's state tracking) to survive autocompaction. The state SHALL include: current phase, preparation branch name, project profile summary, and cumulative findings count.

**FR-57**: The tool SHALL work on any git repository regardless of language, framework, or structure. Language-specific checks (dependency audit, build verification) SHALL gracefully degrade for unsupported or unrecognized project types.

**FR-58**: The tool SHALL prefer surgical remediation (targeted edits) over blanket deletion. File deletion SHALL only be suggested when no surgical alternative exists.

---

## 6. Non-Goals

**NG-1**: The tool will NOT create the actual GitHub repository. It prepares the codebase for release; the user creates and pushes to the remote repository themselves. (The launch checklist will include this as a manual step.)

**NG-2**: The tool will NOT provide legal advice. License compatibility checks are informational. The tool will recommend consulting a lawyer for complex licensing situations.

**NG-3**: The tool will NOT perform penetration testing, SAST, or DAST security scanning beyond secrets/PII pattern matching. It is not a replacement for dedicated security tools.

**NG-4**: The tool will NOT manage ongoing open-source maintenance (issue triage, PR reviews, community management). It is a one-time preparation tool.

**NG-5**: The tool will NOT audit git submodule contents. Submodules are flagged for separate treatment (see DD-4).

**NG-6**: The tool will NOT upload or publish packages to any registry (npm, PyPI, crates.io, etc.). Package publishing is a post-launch activity.

**NG-7**: The tool will NOT rewrite git history selectively (e.g., using `git filter-repo` on specific files) as an automated operation. It will suggest commands but leave selective history rewriting to the user. Only full flatten is automated.

**NG-8**: The tool will NOT integrate with external paid scanning services (Snyk, GitGuardian, Veracode, etc.) as required dependencies.

---

## 7. Design Considerations

### Interaction Model

The tool follows an **interactive, phase-gated** model:

1. **Phase entry**: Brief description of what the phase does.
2. **Execution**: Scanning, analysis, or generation (using sub-agents where beneficial).
3. **Phase summary**: Findings count, severity breakdown, and key highlights.
4. **User gate**: "Phase N complete. N findings (X critical, Y high). Proceed to Phase N+1?" The user can review details, request changes, or skip the phase.

This model ensures the user is never surprised by changes and always has the opportunity to review and redirect.

### Progressive Disclosure

- Phase summaries show counts and highlights only.
- Detailed findings are available on request ("Show me the details for Phase 1").
- The final report contains everything in one document.

### Destructive Operation Safeguards

Three levels of confirmation for destructive operations:

| Operation | Confirmation Level |
|-----------|-------------------|
| File edits (remediation) | Present diff, ask "Apply?" |
| File deletion | Present justification + affected files, ask "Delete these N files?" |
| History flatten | Present pre-flatten checklist, require explicit confirmation with "irreversible" warning |

### State Tracking

The skill maintains a state block that is restated between phases to survive autocompaction:

```
STATE:
  phase: {0-9}
  project_root: {path}
  prep_branch: {branch name}
  project_profile: {language, framework, package_manager}
  findings: {total: N, critical: N, high: N, medium: N, low: N}
  phases_completed: [0, 1, 2, ...]
  history_flattened: {true/false}
```

### Sub-Agent Strategy

Sub-agents are used for:
- **Within-phase parallelism**: Scanning current tree and git history simultaneously (Phases 1, 2).
- **Independent analysis**: Architecture review, coding standards check, build verification can run in parallel (Phase 4).
- **Documentation generation**: Multiple documentation files can be drafted in parallel (Phase 5).

All sub-agents use `model: "opus"` per the user's global instructions.

---

## 8. Technical Considerations

### Constraints

- **Single-file skill**: The entire tool is a single `SKILL.md` file. All logic is expressed as instructions to Claude Code, not as executable scripts.
- **No external dependencies**: The tool cannot require the user to install any software. It uses only `git`, standard shell tools, and Claude Code's built-in capabilities (Read, Write, Edit, Glob, Grep, Bash, Task).
- **Context window management**: A full audit of a large repository could exceed Claude's context window. The skill must use sub-agents, temp files, and state tracking to manage this.
- **Rate limiting**: Git history scanning on large repos can produce enormous output. The tool must use pagination (offset/limit on Read), temp files, and targeted searches rather than loading entire histories into context.

### Integration Points

- **Git**: The tool relies heavily on git commands (`git log`, `git diff`, `git rev-parse`, `git checkout`, `git filter-branch`/`git filter-repo`). It must handle repos of varying sizes and configurations.
- **Package managers**: The tool must recognize and parse manifests for npm, pip, cargo, go, ruby, java, and php ecosystems at minimum.
- **Claude Code tools**: The skill uses all standard Claude Code tools. Sub-agents via the Task tool are critical for performance.
- **Web search**: Name availability checks (FR-37) use WebSearch to query package registries. This is best-effort and may not work in all environments.

### Performance

- For repos with >10,000 commits, git history scanning must be targeted (search for specific patterns) rather than exhaustive (reading every diff).
- For repos with >1,000 files, file scanning should use Grep with pattern matching rather than reading every file.
- Sub-agent parallelism should be used wherever phases have independent work streams.

### Error Handling

- Build failures (Phase 4) are reported but do not block subsequent phases.
- Missing package managers or unrecognized project types degrade gracefully (skip that ecosystem's checks).
- Git operations that fail (e.g., orphan branch creation in a worktree) produce clear error messages with manual fallback instructions.
- Network-dependent checks (name availability) fail gracefully with "Could not verify" rather than blocking.

---

## 9. Success Metrics

| Metric | Target | How Measured |
|--------|--------|-------------|
| Secret detection rate | Zero secrets remaining after remediation + flatten | Post-flatten verification scan (FR-45) returns zero findings |
| PII detection rate | Zero PII remaining after remediation + flatten | Post-flatten verification scan returns zero findings |
| Documentation completeness | All 6 core docs exist and pass quality check | Presence check + content validation in Phase 5 |
| Build integrity | Project builds successfully on the preparation branch | Build command exit code (Phase 4) |
| User control | Zero destructive operations without explicit approval | Every edit/delete/flatten is preceded by a confirmation prompt |
| Phase completion | All 10 phases execute without error | Phase counter reaches 9 with no skipped phases (or documented skip reasons) |
| Report quality | Final report covers all phases with actionable findings | Report includes risk matrix, all phase sections, and launch checklist |
| Repo agnosticism | Tool works on repos in at least 5 different languages/frameworks | Manual testing across diverse repos |

---

## 10. Open Questions

**OQ-1**: **Git filter-repo vs. orphan branch for history flatten** -- The current design uses an orphan branch approach for simplicity. Should we also support `git filter-repo` for users who want to preserve some history while removing specific files/patterns? This adds complexity but provides a middle ground between "keep all history" and "flatten everything."

**OQ-2**: **Monorepo package-level licensing** -- In monorepo setups (e.g., Lerna, Nx), different packages may have different licenses. Should the tool audit licenses per-package or only at the repo root level? Per-package auditing significantly increases scope.

**OQ-3**: **Git LFS handling** -- Repos using Git LFS may have large binary files tracked externally. Should the tool audit LFS-tracked files for secrets/PII, or treat them as opaque binaries? LFS files could contain sensitive data (e.g., database dumps, config archives).

**OQ-4**: **Re-runnability** -- Should the tool support re-running on a repo that was previously prepared (e.g., after making additional changes)? The current design creates a fresh preparation branch each time. A "resume" or "re-audit" mode could be valuable but adds state management complexity.

**OQ-5**: **Telemetry detection depth** -- FR-39 requires detecting telemetry/analytics code. How deep should this analysis go? Surface-level (import statements, known SDK names) is feasible. Detecting custom phone-home code (arbitrary HTTP calls to hardcoded URLs) is significantly harder and more prone to false positives.
