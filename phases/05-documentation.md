# Phase 5 — Documentation Generation

| Field   | Value |
|---------|-------|
| Phase   | 5 |
| Name    | Documentation Generation |
| Inputs  | `state.project_root`, `state.project_profile` (language, framework, package_manager, build_system, test_framework), `state.license_choice` (from Phase 3), `state.user_context.audience` (from Phase 0, optional), `state.phases_completed`, `state.findings` |
| Outputs | Files created/modified: README.md, LICENSE, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md, sanitized CLAUDE.md. State updates: `phase_findings["5"]`, cumulative `findings` totals, `phases_completed` updated to include 5. |

---

## Purpose

Phase 5 transitions from auditing (finding problems) to creating (producing documentation artifacts). It checks the completeness of seven standard documentation files (FR-26), generates missing files with project-tailored content (FR-27), enhances existing files without overwriting them (FR-28), produces a comprehensive README (FR-29), sanitizes CLAUDE.md of internal references (FR-30), and handles license verification (FR-31). After documentation generation, it evaluates README quality against five criteria (FR-31) and validates badge URLs for placeholder tokens and pre-repo dependencies (FR-32), with audience-aware coaching when `state.user_context.audience` is available (FR-33). All generated content is presented for user review before writing to disk.

---

## Step 5.1 — Documentation Completeness Matrix (FR-26)

Before generating anything, build a completeness matrix for the following seven documentation files at the project root:

1. `README.md`
2. `LICENSE`
3. `CONTRIBUTING.md`
4. `CODE_OF_CONDUCT.md`
5. `SECURITY.md`
6. `CHANGELOG.md`
7. `CLAUDE.md`

For each file, use Glob and Read to determine:
- **Exists**: Does the file exist at the project root? (yes/no)
- **Has Content**: Is the file non-empty and substantive? (yes/no/partial — "partial" means the file exists but has placeholder content, very short content (<10 lines), or is clearly a skeleton with TODO markers)
- **Contains Internal References**: Does the file contain references to internal infrastructure, private URLs, employee names, internal tool names, Slack channels, or internal ticket systems? (yes/no/not checked — "not checked" only for files that don't exist)

Present the matrix to the user:

```
### Documentation Completeness Matrix

| # | File | Exists | Has Content | Internal References |
|---|------|--------|-------------|---------------------|
| 1 | README.md | {yes/no} | {yes/no/partial} | {yes/no/not checked} |
| 2 | LICENSE | {yes/no} | {yes/no/partial} | {yes/no/not checked} |
| 3 | CONTRIBUTING.md | {yes/no} | {yes/no/partial} | {yes/no/not checked} |
| 4 | CODE_OF_CONDUCT.md | {yes/no} | {yes/no/partial} | {yes/no/not checked} |
| 5 | SECURITY.md | {yes/no} | {yes/no/partial} | {yes/no/not checked} |
| 6 | CHANGELOG.md | {yes/no} | {yes/no/partial} | {yes/no/not checked} |
| 7 | CLAUDE.md | {yes/no} | {yes/no/partial} | {yes/no/not checked} |

**Action plan**: {N} files to generate, {N} files to enhance, {N} files to review for internal references.
```

Wait for user acknowledgment before proceeding to generation.

---

## Step 5.2 — Existing-File Preservation Rule (FR-28)

**CRITICAL**: Existing documentation files are preserved and enhanced, never overwritten.

Apply the following three-tier approach to every documentation file:

| Tier | Condition | Action |
|------|-----------|--------|
| **A — Generate** | File does not exist | Generate a full draft tailored to the project. Present for user review. |
| **B — Enhance** | File exists but is incomplete (missing sections, placeholder content, partial coverage) | Suggest additions as clearly-marked enhancement blocks. Present each suggestion separately for user review. Never replace existing content. |
| **C — Review Only** | File exists and is complete | Review for internal references only. If internal references are found, present proposed redactions for user review. If no issues, report "No changes needed." |

When presenting enhancement suggestions (Tier B), format them as:

```
### Enhancement Suggestion for {filename}

**Current state**: {brief description of what exists}
**Proposed addition**: {section name or description}

--- BEGIN SUGGESTED ADDITION (insert after line {N}) ---
{the suggested content}
--- END SUGGESTED ADDITION ---

Approve this addition? (yes / edit / skip)
```

---

## Step 5.3 — License Verification (FR-31, DD-3)

### Primary Path — Read `state.license_choice` (Phase 3 completed)

If `state.license_choice` is set (non-empty string), the license was already selected during Phase 3's dependency compatibility analysis. Use it directly without re-prompting:

1. Read `state.license_choice` (e.g., `"MIT"`, `"Apache-2.0"`, `"GPL-3.0"`, etc.).
2. **If no LICENSE file exists**: Generate the full LICENSE file text using the standard template for the chosen license. Ask for the copyright holder name (suggest the git user name as a default: `git config user.name`) and the copyright year (suggest the current year as default). Present the generated LICENSE for user review before writing.
3. **If a LICENSE file exists**: Read the file and verify it matches `state.license_choice`.
   - If it matches, report: "LICENSE verified — {license type}, copyright {holder}."
   - If it does NOT match, flag as a finding and present the discrepancy for user resolution.
   - Check the copyright holder name for corporate entity names, internal team names, or employee names that should be anonymized.
   - If the license is **not recognized** as a standard OSS license, flag it:
     ```
     ### Finding DOC5-{N}: Unrecognized license

     - **Severity**: HIGH
     - **File**: LICENSE
     - **Detail**: The LICENSE file does not match any recognized open-source license template. External contributors may be uncertain about usage rights.
     - **Remediation**: Replace with a standard OSS license or verify this is intentional.
     ```

### Fallback Path — `state.license_choice` Not Set (Phase 3 skipped)

> **Orchestrator Interaction Point**: If `state.license_choice` is not set when Phase 5 is dispatched, the **orchestrator** (not this sub-agent) must prompt the user for license selection BEFORE dispatching this phase. The orchestrator passes the chosen license as input to this sub-agent via `state.license_choice`. This sub-agent does NOT present interactive license menus directly.

If the orchestrator has not provided a license choice and this phase is running, use the following license menu for the orchestrator's reference. The orchestrator should present this menu to the user and set `state.license_choice` before dispatching:

```
No LICENSE file found. Please select a license for your project:

  1. MIT (default — permissive, minimal restrictions)
  2. Apache-2.0 (permissive, includes patent grant)
  3. GPL-3.0 (strong copyleft, requires derivative works to be GPL-3.0)
  4. BSD-2-Clause (permissive, minimal restrictions)
  5. BSD-3-Clause (permissive, adds non-endorsement clause)
  6. MPL-2.0 (weak copyleft, file-level copyleft)
  7. ISC (permissive, functionally equivalent to MIT)
  8. Unlicense (public domain dedication)

Enter a number (1-8):
```

After selection:
1. Ask for the copyright holder name (suggest the git user name as a default: `git config user.name`).
2. Ask for the copyright year (suggest the current year as default).
3. Generate the full LICENSE file text using the standard template for the chosen license.
4. Present the generated LICENSE for user review before writing.

---

## Step 5.4 — Dispatch Parallel Sub-Agents for Documentation Generation

After the license is resolved (Step 5.3), launch sub-agents simultaneously via the Task tool (all with `model: "opus"`) for files that need generation or enhancement (Tier A or Tier B from Step 5.2). Each sub-agent receives:

- The current STATE block (including `project_profile` from Phase 0)
- The `project_root` path
- The documentation completeness matrix from Step 5.1
- The specific file instructions from the relevant sub-section below

Launch the following sub-agents **in parallel** for files that need work:

- **Sub-Agent A — README.md** (if missing or incomplete)
- **Sub-Agent B — CONTRIBUTING.md** (if missing or incomplete)
- **Sub-Agent C — CODE_OF_CONDUCT.md** (if missing or incomplete)
- **Sub-Agent D — SECURITY.md** (if missing or incomplete)
- **Sub-Agent E — CLAUDE.md Sanitization** (if exists and contains internal references)

**CHANGELOG.md** is handled separately in Step 5.5 after the sub-agents complete, because it may depend on git history analysis.

**Do NOT launch a sub-agent for files that are Tier C (complete, no internal references).** Simply report "No changes needed" for those files.

### Sub-Agent A — README.md Generation/Enhancement Instructions (FR-29)

Generate (or enhance) a README.md that includes **all** of the following sections, tailored to the project's actual characteristics from the Phase 0 project profile and Phase 4 architecture summary:

**1. Project Name and Description**
- Use the repository directory name as the project name (or the `name` field from `package.json` / `Cargo.toml` / `pyproject.toml` if available).
- Write a concise (2-4 sentence) description based on what the codebase actually does (infer from entry points, main modules, and any existing description in manifests).

**2. Badges**
- Include placeholder badges for:
  - Build status (e.g., `![Build Status](https://img.shields.io/github/actions/workflow/status/{owner}/{repo}/{workflow}.yml)`)
  - License (e.g., `![License](https://img.shields.io/badge/license-{license}-blue.svg)`)
  - Version (e.g., `![Version](https://img.shields.io/github/v/release/{owner}/{repo})` or language-specific: npm, crates.io, PyPI)
- Use `{owner}` and `{repo}` as placeholders if git remote information is not available.

**3. Installation**
- Tailor to the detected package manager and language:
  - **Node.js (npm)**: `npm install {package-name}`
  - **Node.js (yarn)**: `yarn add {package-name}`
  - **Node.js (pnpm)**: `pnpm add {package-name}`
  - **Python (pip)**: `pip install {package-name}`
  - **Python (poetry)**: `poetry add {package-name}`
  - **Rust**: `cargo add {package-name}` or add to `Cargo.toml`
  - **Go**: `go get {module-path}`
- If this is an application (not a library), provide clone + setup instructions instead.
- Include prerequisites (minimum language version, required system dependencies).

**4. Usage**
- Provide at least one usage example.
- For CLI tools: show the primary command with common flags.
- For libraries: show a minimal import + usage code snippet.
- For applications: show how to start and interact with the application.
- Infer usage patterns from entry points identified in Phase 4 (architecture summary).

**5. Configuration**
- Document any configuration files, environment variables, or CLI flags detected in the codebase.
- If a `.env.example` or config template exists, reference it.
- If no configuration is detected, include a brief "No configuration required" note or omit this section.

**6. Contributing Reference**
- Include a brief statement: "See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines."

**7. License Reference**
- Include: "This project is licensed under the {license type} License — see the [LICENSE](LICENSE) file for details."
- Use the actual license type from Step 5.3.

**If enhancing an existing README** (Tier B):
- Identify which of the seven sections above are missing or incomplete.
- Generate only the missing sections.
- Present each as a clearly-marked enhancement block (per Step 5.2).
- Do NOT rewrite or rearrange existing sections.

### Sub-Agent B — CONTRIBUTING.md Generation/Enhancement Instructions

Generate a CONTRIBUTING.md tailored to the project's detected tooling:

**1. Getting Started**
- Clone instructions.
- Installation of development dependencies (using the detected package manager from Phase 0).
- How to run the project locally.

**2. Development Workflow**
- Branch naming convention (suggest: `feature/`, `fix/`, `docs/` prefixes).
- How to run tests (using the detected test framework from Phase 0).
- How to run linting/formatting (using the detected tools from Phase 4).
- How to build the project (using the detected build command from Phase 4).

**3. Pull Request Process**
- Standard PR checklist: tests pass, lint passes, documentation updated if needed.
- Description requirements.
- Review process expectations.

**4. Code Style**
- Reference the detected formatter and linter from Phase 4.
- If no tools are detected, provide general guidelines appropriate to the project's language.

**5. Reporting Issues**
- How to file a bug report (suggest a template).
- How to request a feature.

### Sub-Agent C — CODE_OF_CONDUCT.md Generation Instructions

Generate a CODE_OF_CONDUCT.md using the **Contributor Covenant v2.1** template (the most widely adopted code of conduct for open-source projects):

- Use the full text of the Contributor Covenant v2.1.
- Fill in the `[INSERT CONTACT METHOD]` placeholder with a suggested contact method (e.g., "project maintainers at [EMAIL]" — leave EMAIL as a placeholder for the user to fill in).
- Do not modify the standard text — the Contributor Covenant is designed to be used as-is.

### Sub-Agent D — SECURITY.md Generation Instructions

Generate a SECURITY.md with:

**1. Security Policy**
- Which versions are currently supported with security updates.
- If version information is available from manifests, use it. Otherwise, suggest a table with "Latest" as the supported version.

**2. Reporting a Vulnerability**
- Instructions for responsible disclosure.
- Suggest a private reporting channel (e.g., "Email security@{domain}" or "Use GitHub's private vulnerability reporting feature").
- Expected response timeline (suggest: acknowledgment within 48 hours, resolution target within 90 days).
- What reporters can expect: acknowledgment, status updates, credit in the advisory.

**3. Scope**
- What is in scope (the project's code, dependencies, infrastructure if applicable).
- What is out of scope (third-party services, social engineering, denial of service testing).

### Sub-Agent E — CLAUDE.md Sanitization Instructions (FR-30)

**Only launch this sub-agent if the documentation completeness matrix shows CLAUDE.md exists with internal references.**

Read the existing CLAUDE.md and produce a sanitized version that:

**Preserves** (keep intact):
- Build commands (e.g., `npm run build`, `cargo test`)
- Architecture notes (directory structure descriptions, module boundaries)
- Coding conventions (naming patterns, formatting rules, commit message conventions)
- Development workflow instructions (how to set up a dev environment, debugging tips)
- Tool configurations (editor settings, extension recommendations)
- Project-specific technical decisions and rationale

**Removes or redacts**:
- Private API endpoints (e.g., `api.internal.company.com`, `staging.corp.net`)
- Internal tool names (e.g., "use our internal deploy-bot", "check in Pagerduty")
- Employee names (e.g., "ask @jsmith", "John's module", "per Sarah's design")
- Internal URLs (intranet links, private wiki URLs, private Slack/Teams channel links)
- Internal ticket references (e.g., "JIRA-1234", "PROJ-567", "see internal tracker")
- Team/department names used in internal context (e.g., "the platform team owns this", "backend-infra group")
- Private infrastructure details (internal IP ranges, VPN instructions, internal DNS names)

**Flags for user review** (ambiguous — present as questions):
- References that could be internal or public (e.g., a URL that might be a public API endpoint)
- Names that might be the project author's public identity (not necessarily needing removal)
- Tool names that could be internal or well-known open-source tools

Present the sanitized version as a diff showing:
- Lines removed (with explanation of why)
- Lines modified (with the original and proposed replacement)
- Lines flagged for user review (with the question to resolve)

---

## Step 5.4a — README Quality Checklist (FR-31)

After Sub-Agent A returns the README content (generated, enhanced, or pre-existing), evaluate the README.md against five quality criteria. This checklist applies regardless of whether the README was newly generated (Tier A), enhanced (Tier B), or already existed (Tier C).

Use the Read tool on the README.md file and evaluate:

| # | Check | Criteria | Severity if Missing |
|---|-------|----------|---------------------|
| 1 | Value proposition | First 2 sentences answer "what is this and why should I care?" | MEDIUM |
| 2 | Demo/screenshot | Visual proof, text-based example output, or code snippet showing the tool in action | LOW |
| 3 | Badge validation | No `{owner}` placeholders, no broken shield URLs (detailed in Step 5.4b) | HIGH |
| 4 | Install command | Copy-pasteable installation command, completable under 30 seconds | MEDIUM |
| 5 | Quick start | Zero to first use in under 5 steps | MEDIUM |

For each failing check, produce a finding with the `DOC5` prefix:

```
### Finding DOC5-{N} [{effort}] ({SEVERITY}): README missing {check name}

- **File**: README.md
- **Detail**: {description of what is missing or inadequate}
- **Remediation**: {specific guidance on how to address the gap}
```

If all five checks pass, no findings are generated for this step — report "README quality checklist: all 5 checks passed."

### Audience-Aware Coaching (FR-33)

If `state.user_context.audience` is set (populated during Phase 0), present tailored README coaching **after** the quality checklist. Coaching is presented as suggestions, not mandatory findings.

| Audience | Coaching Emphasis |
|----------|-------------------|
| Solo/hobby project | Emphasize a clear "what it does" description and quick start |
| Team/internal tool going public | Emphasize migration guide from internal setup, configuration documentation |
| Community project seeking contributors | Emphasize contributing section, "good first issue" guidance, code of conduct reference, community channels |
| Library/framework for developers | Emphasize API documentation, installation variants (npm/yarn/pnpm), type definitions, changelog reference |

Format the coaching as:

```
### README Coaching (based on your audience: {audience})

Your target audience is "{audience}". Consider these additions:
- {suggestion 1}
- {suggestion 2}
- {suggestion 3}
```

If `state.user_context.audience` is **not set** (Phase 0 was skipped or v1 state without this field), silently omit the coaching section — no error, no empty section, no placeholder.

---

## Step 5.4b — Badge Validation (FR-32)

Grep the README.md for badge URLs matching two patterns:

1. **shields.io URLs**: `https://img.shields.io/...`
2. **GitHub badge URLs**: `https://github.com/{owner}/{repo}/actions/workflows/...`

Use the Grep tool on README.md with patterns:
- `shields\.io`
- `github\.com/.*/actions/workflows`

For each badge URL found, apply two checks:

### Check 1 — Placeholder Token Detection (HIGH severity)

Flag any badge URL containing literal `{owner}`, `{repo}`, or `{username}` placeholders. These are template placeholders that will render as broken badges on publish.

```
### Finding DOC5-{N} [Quick fix] (HIGH): Badge URL contains placeholder token

- **File**: README.md, line {line_number}
- **Detail**: Badge URL contains literal placeholder `{token}`: `{full_url}`
- **Remediation**: Replace `{token}` with the actual value, or defer badge fixup to Phase 10 (Launch Automation).
```

### Check 2 — Pre-Repo Badge Detection (INFORMATIONAL)

Flag version, CI status, or release badges that reference a GitHub repository URL (not placeholders, but actual or intended repo paths). These badges will not render until the repository is publicly available.

```
### Informational: DOC5-{N}: Badge requires live repository

- **File**: README.md, line {line_number}
- **Detail**: Badge URL `{full_url}` references a GitHub repository that may not yet exist publicly.
- **Note**: This badge will activate after Phase 10 (Launch Automation) or manual repo creation.
```

Informational badge findings do **not** contribute to the phase's actionable finding count. They are presented for awareness only and are not counted in HIGH/MEDIUM/LOW severity totals.

---

## Step 5.5 — CHANGELOG.md Generation

After the parallel sub-agents from Step 5.4 complete, handle CHANGELOG.md:

### If no CHANGELOG.md exists (Tier A):

1. Read the git log to extract recent history: `git log --oneline --no-decorate -50` (last 50 commits).
2. Generate a CHANGELOG.md following the [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- {inferred from git history — new features, new files}

### Changed
- {inferred from git history — modifications, refactors}

### Fixed
- {inferred from git history — bug fixes}
```

3. Group commits into Added/Changed/Fixed categories by analyzing commit message prefixes (`feat:`, `fix:`, `refactor:`, `chore:`, etc.) or by content heuristics.
4. If git tags exist, create version sections for tagged releases.

### If CHANGELOG.md exists (Tier B or C):

- If incomplete (Tier B): suggest adding an `[Unreleased]` section if missing, or suggest recent entries that should be documented.
- If complete (Tier C): check for internal references only.

---

## Step 5.6 — User Review Gate (FR-27)

**CRITICAL**: All generated and enhanced content MUST be presented for user review before writing to disk.

After all sub-agents complete, Steps 5.4a/5.4b evaluations are done, and CHANGELOG.md is handled, present each file for review in the following order. Badge validation findings and README quality checklist results from Steps 5.4a/5.4b are included in the README.md review presentation so the user can address them before approving:

1. **LICENSE** (already handled in Step 5.3 — skip if already approved)
2. **README.md**
3. **CONTRIBUTING.md**
4. **CODE_OF_CONDUCT.md**
5. **SECURITY.md**
6. **CHANGELOG.md**
7. **CLAUDE.md** (sanitized version)

For each file, present:

```
### Review: {filename}

**Action**: {Generated (new file) | Enhanced (additions to existing) | Sanitized (internal references removed) | No changes needed}

{The full generated/enhanced content, or the diff for enhancements/sanitizations}

---
Choose one:
- **Approve** — Write this file to disk
- **Edit** — Provide specific changes you'd like made (describe what to change)
- **Skip** — Do not write this file; move to the next one
```

Process each file's response before presenting the next one. If the user requests edits, apply them and re-present the file for approval.

**Only write a file to disk after the user explicitly approves it.** Files that are skipped are noted in the phase summary but not counted as findings.

---

## Step 5.7 — Consolidate and Present Phase Summary

After all files have been reviewed, present the Phase 5 summary:

```
## Phase 5 Summary — Documentation Generation

### Category Summary

| Category | Status | Count | Top Severity | Effort |
|----------|--------|-------|-------------|--------|
| README.md | {Clean/Findings} | {N} | {HIGH/MEDIUM/LOW/—} | {Auto-fix/Quick fix/Decision needed/—} |
| LICENSE | {Clean/Findings} | {N} | {HIGH/MEDIUM/LOW/—} | {effort or —} |
| CONTRIBUTING.md | {Clean/Findings} | {N} | {HIGH/MEDIUM/LOW/—} | {effort or —} |
| CODE_OF_CONDUCT.md | {Clean/Findings} | {N} | {HIGH/MEDIUM/LOW/—} | {effort or —} |
| SECURITY.md | {Clean/Findings} | {N} | {HIGH/MEDIUM/LOW/—} | {effort or —} |
| CHANGELOG.md | {Clean/Findings} | {N} | {HIGH/MEDIUM/LOW/—} | {effort or —} |
| CLAUDE.md | {Clean/Findings} | {N} | {HIGH/MEDIUM/LOW/—} | {effort or —} |

**Documentation files audited**: 7
**Files generated**: {N} ({list filenames})
**Files enhanced**: {N} ({list filenames})
**Files sanitized**: {N} ({list filenames})
**Files skipped by user**: {N} ({list filenames})
**Files with no changes needed**: {N} ({list filenames})

### Documentation Status

| # | File | Action Taken | Status |
|---|------|-------------|--------|
| 1 | README.md | {Generated/Enhanced/No changes/Skipped} | {Approved/Skipped} |
| 2 | LICENSE | {Generated/Verified/No changes/Skipped} | {Approved/Skipped} |
| 3 | CONTRIBUTING.md | {Generated/Enhanced/No changes/Skipped} | {Approved/Skipped} |
| 4 | CODE_OF_CONDUCT.md | {Generated/Enhanced/No changes/Skipped} | {Approved/Skipped} |
| 5 | SECURITY.md | {Generated/Enhanced/No changes/Skipped} | {Approved/Skipped} |
| 6 | CHANGELOG.md | {Generated/Enhanced/No changes/Skipped} | {Approved/Skipped} |
| 7 | CLAUDE.md | {Sanitized/No changes/Skipped} | {Approved/Skipped} |

### README Quality & Badge Validation (Steps 5.4a / 5.4b)

**Quality checklist**: {N}/5 checks passed
**Badge URLs found**: {N} total
**Placeholder badges (HIGH)**: {N}
**Pre-repo badges (informational)**: {N}
**Audience coaching**: {Presented for "{audience}" / Skipped (no audience set)}

### Findings
{List any findings generated during this phase — e.g., unrecognized license, internal references, README quality gaps, badge placeholder tokens}

**Findings**: {total} total ({high} high, {medium} medium, {low} low)
**Informational**: {N} (pre-repo badges — not counted in severity totals)
```

---

## User Gate

> "Phase 5 (Documentation Generation) complete. Choose one:
> - **Approve and continue** — Accept findings and move to Phase 6 (GitHub Repository Setup & CI/CD)
> - **Review details** — Show the full documentation status and all findings
> - **Request changes** — Re-generate or re-review specific files
> - **Skip** — Mark Phase 5 as skipped and move on"

**Do NOT advance to Phase 6 until the user explicitly responds.**

---

## State Update (Step 5.8)

After Phase 5 is approved, the orchestrator updates `.oss-prep/state.json`:

- `phase`: set to `6`
- `phase_findings["5"]`: set with totals and `status: "completed"` (or `"skipped"`)
- `findings`: cumulative totals updated (Phases 1 + 2 + 3 + 4 + 5)
- `phases_completed`: append `5`

> **Note**: The state update is an orchestrator responsibility. This phase file documents the expected state change for reference.

---

## Finding Format

Findings generated during Phase 5 use the prefix `DOC5-{N}` and follow this format:

```
### Finding DOC5-{N} [{effort}] ({SEVERITY}): {title}

- **File**: {filename}
- **Detail**: {description of the issue}
- **Remediation**: {recommended action}
```

Where `{effort}` is one of the effort tags defined in SKILL.md: `[Auto-fix]`, `[Quick fix]`, `[Decision needed]`, or `[Deferred -> Phase N]`. See SKILL.md for the canonical effort tag definitions and structured finding format.

Example findings:
- `DOC5-1 [Decision needed] (HIGH)`: Unrecognized license
- `DOC5-2 [Quick fix] (MEDIUM)`: Corporate entity name in LICENSE copyright holder
- `DOC5-3 [Decision needed] (MEDIUM)`: Internal references in CLAUDE.md that could not be automatically resolved
- `DOC5-4 [Auto-fix] (LOW)`: Missing required README section
- `DOC5-5 [Quick fix] (MEDIUM)`: README missing value proposition
- `DOC5-6 [Quick fix] (LOW)`: README missing demo/screenshot
- `DOC5-7 [Quick fix] (HIGH)`: Badge URL contains `{owner}` placeholder token
- `DOC5-8 [Quick fix] (MEDIUM)`: README missing install command

### Effort Classification Guidance (Phase 5)

- **`[Auto-fix]`**: Generating a missing documentation file from scratch (README.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md). The skill can produce and write these files automatically after user approval.
- **`[Quick fix]`**: Adding a missing section to an existing README, fixing a broken badge URL, replacing placeholder tokens in badge URLs (`{owner}`, `{repo}`, `{username}`), updating a stale copyright year, or appending a missing `.gitignore` entry. These are small, targeted edits. README quality checklist failures (value proposition, demo/screenshot, install command, quick start) are also quick fixes.
- **`[Decision needed]`**: Unrecognized or non-standard license in LICENSE file, corporate or personal name in copyright holder that may need anonymization, internal references in CLAUDE.md that are ambiguous (could be internal or public). These require user judgment before resolution.
