# Phase 6 — GitHub Repository Setup & CI/CD

| Field   | Value |
|---------|-------|
| Phase   | 6 |
| Name    | GitHub Repository Setup & CI/CD |
| Inputs  | `state.project_root`, `state.project_profile` (language, framework, package_manager, build_system, test_framework), `state.phases_completed`, `state.findings` |
| Outputs | Files created/modified: `.github/ISSUE_TEMPLATE/bug_report.md`, `.github/ISSUE_TEMPLATE/feature_request.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/workflows/ci.yml`, `.gitignore`, `.github/CODEOWNERS`; State updates: `phase_findings["6"]`, cumulative `findings` totals, `phases_completed` updated to include `6` |

---

## Purpose

Phase 6 shifts from content quality (documentation in Phase 5) to repository infrastructure — the scaffolding that enables community participation and automated quality gates from the first public commit. It generates GitHub issue templates, a PR template, a CI/CD workflow, and reviews .gitignore completeness. All generated files are presented for user review before writing. If files already exist, they are enhanced rather than overwritten.

---

## Finding Format

Findings generated during this phase use the ID prefix `GH6-{N}`, numbered sequentially:

```
**GH6-{N}** [{effort}] ({severity: LOW | MEDIUM | HIGH | CRITICAL}): {description}
- **File**: {file path or "N/A"}
- **Details**: {specific details about the finding}
- **Recommendation**: {what should be done}
```

Where `{effort}` is one of the effort tags defined in SKILL.md: `[Auto-fix]`, `[Quick fix]`, `[Decision needed]`, or `[Deferred -> Phase N]`. See SKILL.md for the canonical effort tag definitions and structured finding format.

Example findings:
- `GH6-1 [Auto-fix] (LOW)`: Missing bug report issue template
- `GH6-2 [Auto-fix] (LOW)`: Missing CI workflow
- `GH6-3 [Quick fix] (MEDIUM)`: Incomplete .gitignore — missing Python artifacts
- `GH6-4 [Decision needed] (MEDIUM)`: CI workflow trigger configuration needs customization

### Effort Classification Guidance (Phase 6)

- **`[Auto-fix]`**: Generating missing issue templates, PR template, CI workflow, or .gitignore entries from scratch. The skill produces these files automatically based on the project profile.
- **`[Quick fix]`**: Fixing an incomplete .gitignore (appending missing entries), adding a missing lint or test step to an existing CI workflow, or adding a missing section to an existing PR template.
- **`[Decision needed]`**: Choosing CI workflow triggers or job structure when the project has an unconventional build system, deciding whether to keep or replace an existing CI workflow that uses a non-standard approach, resolving an unrecognized language for CI generation, or choosing between personal account and organization for GitHub hosting.

---

## Step 6.1 — Infrastructure Inventory

Before generating anything, scan the project for existing GitHub infrastructure files. Use Glob to check for:

1. `.github/ISSUE_TEMPLATE/bug_report.md`
2. `.github/ISSUE_TEMPLATE/feature_request.md`
3. `.github/PULL_REQUEST_TEMPLATE.md`
4. `.github/workflows/*.yml` (any existing CI/CD workflows)
5. `.gitignore`
6. `.github/CODEOWNERS`

For each file, determine:
- **Exists**: Does the file exist? (yes/no)
- **Has Content**: Is the file non-empty and substantive? (yes/no)

Present the inventory to the user:

```
### GitHub Infrastructure Inventory

| # | File | Exists | Has Content |
|---|------|--------|-------------|
| 1 | .github/ISSUE_TEMPLATE/bug_report.md | {yes/no} | {yes/no} |
| 2 | .github/ISSUE_TEMPLATE/feature_request.md | {yes/no} | {yes/no} |
| 3 | .github/PULL_REQUEST_TEMPLATE.md | {yes/no} | {yes/no} |
| 4 | .github/workflows/ci.yml | {yes/no} | {yes/no} |
| 5 | .gitignore | {yes/no} | {yes/no} |
| 6 | .github/CODEOWNERS | {yes/no} | {yes/no} |

**Action plan**: {N} files to generate, {N} files to review/enhance.
```

Wait for user acknowledgment before proceeding.

---

## Step 6.2 — Existing-File Handling Rule

**CRITICAL**: Existing infrastructure files are preserved and enhanced, never overwritten.

Apply the following approach to every infrastructure file:

| Tier | Condition | Action |
|------|-----------|--------|
| **A — Generate** | File does not exist | Generate a full draft tailored to the project. Present for user review. |
| **B — Enhance** | File exists but is incomplete (missing sections, missing steps, incomplete coverage) | Suggest additions or improvements. Present each suggestion separately for user review. Never replace existing content. |
| **C — Review Only** | File exists and is complete | Report "No changes needed" for this file. |

When presenting enhancement suggestions (Tier B), format them as:

```
### Enhancement Suggestion for {filename}

**Current state**: {brief description of what exists}
**Proposed change**: {description of the suggested improvement}

--- BEGIN SUGGESTED ENHANCEMENT ---
{the suggested content or diff}
--- END SUGGESTED ENHANCEMENT ---

Approve this change? (yes / edit / skip)
```

---

## Step 6.3 — Issue Templates

Generate two issue templates in `.github/ISSUE_TEMPLATE/`. Each template uses GitHub's standard format with YAML frontmatter and a markdown body.

**Note**: The Write tool will create intermediate directories (`.github/ISSUE_TEMPLATE/`), but verify the path structure exists or will be created before writing.

### Bug Report Template — `.github/ISSUE_TEMPLATE/bug_report.md`

Generate with the following structure:

```markdown
---
name: Bug Report
description: Report a bug in {project_name}
labels: ["bug"]
assignees: []
---

## Description
A clear and concise description of the bug.

## Steps to Reproduce
1. Go to '...'
2. Run '...'
3. See error

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened. Include error messages or screenshots if applicable.

## Environment
- OS: [e.g., macOS 14.0, Ubuntu 22.04, Windows 11]
- {language/runtime} version: [e.g., Node.js 18.x, Python 3.11, Rust 1.75]
- {project_name} version: [e.g., 1.0.0]

## Additional Context
Add any other context about the problem here.
```

Substitute `{project_name}` from the Phase 0 project profile. Substitute the language/runtime field to match the detected primary language (e.g., "Node.js version" for JavaScript projects, "Python version" for Python projects, "Rust version" for Rust projects).

### Feature Request Template — `.github/ISSUE_TEMPLATE/feature_request.md`

Generate with the following structure:

```markdown
---
name: Feature Request
description: Suggest an idea for {project_name}
labels: ["enhancement"]
assignees: []
---

## Problem Statement
A clear and concise description of the problem this feature would solve.
Ex. I'm always frustrated when [...]

## Proposed Solution
A clear and concise description of what you want to happen.

## Alternatives Considered
A description of any alternative solutions or features you've considered.

## Additional Context
Add any other context or screenshots about the feature request here.
```

Substitute `{project_name}` from the Phase 0 project profile.

### Tier B: Existing Issue Template Enhancement

**If issue templates already exist** (Tier B), read the existing templates and check for completeness:
- Bug report: Does it have YAML frontmatter, description, steps to reproduce, expected/actual behavior, and environment sections?
- Feature request: Does it have YAML frontmatter, problem statement, proposed solution, and alternatives sections?

If any sections are missing, suggest additions using the Tier B enhancement format. Do not overwrite existing content.

Present both templates (or enhancement suggestions) for user review before writing.

---

## Step 6.4 — Pull Request Template

Generate a single PR template at `.github/PULL_REQUEST_TEMPLATE.md`.

Generate with the following structure:

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Refactoring (no functional changes)
- [ ] Other (describe below)

## Checklist
- [ ] I have performed a self-review of my code
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] I have updated the documentation accordingly

## Related Issues
Closes #{issue_number}
```

### Tier B: Existing PR Template Enhancement

**If a PR template already exists** (Tier B), read the existing template and check for completeness:
- Does it have a description section?
- Does it have a type of change section with checkboxes?
- Does it have a checklist section?
- Does it have a related issues section?

If any sections are missing, suggest additions using the Tier B enhancement format.

Present the template (or enhancement suggestions) for user review before writing.

---

## Step 6.5 — CI Workflow Generation

Generate a CI workflow at `.github/workflows/ci.yml` tailored to the project's detected language and tooling. The workflow MUST be derived from the Phase 0 project profile — do not guess or assume. Inspect the profile for: primary language, package manager, test framework, build system, and any linting configuration detected in Phase 4.

### Workflow Structure

The generated workflow should follow this skeleton:

```yaml
name: CI

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      # Language-specific setup step
      # Install dependencies step
      # Lint step (if linter configured)
      # Build step (if build command exists)
      # Test step
```

### Language-Specific Configuration

Select the appropriate steps based on the Phase 0 project profile:

**Node.js** (detected via `package.json`):
```yaml
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
      - run: npm ci
      # If eslint/biome configured (detected in Phase 4):
      - run: npm run lint
      # If build script exists in package.json:
      - run: npm run build
      - run: npm test
```

**Python** (detected via `pyproject.toml`, `setup.py`, `requirements.txt`):
```yaml
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt
      # Or if pyproject.toml with build backend: pip install -e ".[dev]"
      # If ruff/flake8/pylint configured:
      - run: ruff check .
      # If pytest configured:
      - run: pytest
```

**Rust** (detected via `Cargo.toml`):
```yaml
      - uses: dtolnay/rust-toolchain@stable
      # If clippy configured:
      - run: cargo clippy -- -D warnings
      - run: cargo build
      - run: cargo test
```

**Go** (detected via `go.mod`):
```yaml
      - uses: actions/setup-go@v5
        with:
          go-version: '1.21'
      # If golangci-lint configured:
      - run: golangci-lint run
      - run: go build ./...
      - run: go test ./...
```

**Other languages or no detectable build system**: Generate a minimal workflow with comments indicating where the user should customize:

```yaml
      # TODO: Add language setup step appropriate for your project
      # TODO: Add dependency installation step
      # TODO: Add build step
      # TODO: Add test step
      - run: echo "CI workflow needs customization for this project"
```

### Tier B: Existing CI Workflow Enhancement

**If a CI workflow already exists** (Tier B), read the existing workflow and check for coverage:
- Does it have a lint step? (If a linter was detected in Phase 4 but the workflow lacks a lint step, suggest adding one.)
- Does it have a build step?
- Does it have a test step?
- Does it trigger on both push and pull_request?

If any steps or triggers are missing, suggest enhancements using the Tier B format rather than generating a replacement workflow.

Present the workflow (or enhancement suggestions) for user review before writing.

---

## Step 6.6 — .gitignore Completeness Review

Review the existing `.gitignore` (or create one if absent) for completeness across four required categories. The goal is to ensure the repository excludes all common artifacts that should not be tracked.

### Required Categories

**1. OS Files**
- `.DS_Store`
- `Thumbs.db`
- `Desktop.ini`
- `._*` (macOS resource forks)

**2. IDE / Editor Files**
- `.idea/`
- `.vscode/`
- `*.swp`
- `*.swo`
- `*~`
- `.project`
- `.classpath`
- `.settings/`
- `*.sublime-project`
- `*.sublime-workspace`

**3. Language-Specific Artifacts** (derived from Phase 0 project profile)

Select the appropriate entries based on the detected language:

| Language | Required Entries |
|----------|-----------------|
| JavaScript/TypeScript | `node_modules/`, `dist/`, `build/`, `.next/`, `coverage/`, `*.tsbuildinfo` |
| Python | `__pycache__/`, `*.pyc`, `*.pyo`, `*.egg-info/`, `dist/`, `build/`, `.eggs/`, `*.egg`, `.pytest_cache/`, `.mypy_cache/`, `.ruff_cache/`, `venv/`, `.venv/` |
| Rust | `target/`, `Cargo.lock` (for libraries only — keep for binaries) |
| Go | `vendor/` (if not using modules) |
| Java | `*.class`, `target/`, `build/`, `.gradle/`, `*.jar`, `*.war` |
| Ruby | `vendor/bundle/`, `.bundle/`, `coverage/`, `*.gem` |
| .NET | `bin/`, `obj/`, `*.suo`, `*.user` |

**4. Environment Files**
- `.env`
- `.env.local`
- `.env.*.local`
- `.env.development`
- `.env.production`

### Review Process

1. **If `.gitignore` does not exist**: Generate a complete `.gitignore` containing all entries from the four categories relevant to the project's detected language. Present the full file for user review.

2. **If `.gitignore` exists**: Read the existing file and compare against the four categories.
   - **Identify missing entries**: For each required entry not found in the existing `.gitignore`, add it to the "missing entries" list.
   - **Preserve all existing entries**: Never remove or modify existing entries.
   - **Present missing entries as additions**: Show the entries that should be appended to the existing file.

Format the review as:

```
### .gitignore Completeness Review

**Existing entries**: {N} entries found
**Missing entries**: {N} entries recommended

| Category | Missing Entries |
|----------|----------------|
| OS Files | {list or "Complete"} |
| IDE / Editor | {list or "Complete"} |
| Language-Specific | {list or "Complete"} |
| Environment Files | {list or "Complete"} |

--- BEGIN SUGGESTED ADDITIONS (append to .gitignore) ---
# OS Files
{missing OS entries}

# IDE / Editor
{missing IDE entries}

# Language-Specific
{missing language entries}

# Environment
{missing env entries}
--- END SUGGESTED ADDITIONS ---
```

Present the additions for user review before writing. Only append approved entries to the existing `.gitignore`; never modify or remove existing content.

---

## Step 6.7 — GitHub Identity Guidance & CODEOWNERS

This step has two sub-steps: identity guidance (informational) and CODEOWNERS generation (produces a file).

### Step 6.7a — GitHub Identity Guidance

Present a comparison table of personal account vs. organization for GitHub hosting:

```
### GitHub Identity Options

| Option | Best For | Pros | Cons |
|--------|----------|------|------|
| Personal account | Solo projects, hobby tools | Simple setup, no extra steps | Tied to your personal identity, harder to transfer |
| Organization | Team projects, branded tools, community-driven | Separate identity, team management, transfer-friendly | Must create via web UI (cannot be automated) |
```

After presenting the table, provide a recommendation based on `state.user_context.audience`:

| Audience | Recommendation |
|----------|----------------|
| Solo/hobby project | Personal account (simpler, adequate for solo work) |
| Team/internal tool going public | Organization (enables team collaboration from day one) |
| Community project seeking contributors | Organization (separate identity encourages community ownership) |
| Library/framework for developers | Organization (professional appearance, easier to transfer maintainership) |

**If `state.user_context.audience` is set**, present the tailored recommendation:

> Based on your audience ("{audience}"), we recommend: **{recommendation}**.

**If `state.user_context.audience` is not set**, present both options without a recommendation and note:

> "Set your audience in Phase 0 to get a tailored recommendation."

**If the user chooses organization**: Explain that GitHub organization creation is a manual step — it cannot be automated via CLI or API. Organizations must be created at `https://github.com/organizations/new`. Note that oss-prep can automate everything else (repo creation, settings, labels, etc.) via `gh` CLI once the org exists. This information is relevant for Phase 10 (Launch Automation).

This sub-step is **informational only** — it does not produce findings or write files. The user's choice (if they make one) is noted for Phase 10 context but is not stored in state (Phase 10 will collect the definitive repo owner input before dispatch).

### Step 6.7b — CODEOWNERS Generation

Generate a `.github/CODEOWNERS` file that establishes default code review ownership.

#### Owner Detection Fallback Chain

Detect the repository owner using the following fallback chain (per PRD OQ-6). Try each step in order, stopping at the first successful detection:

1. **Git remote URL**: Parse `git remote -v` to extract the owner. For `git@github.com:org/repo.git` or `https://github.com/org/repo.git`, the owner is `org`. For personal repos, the owner is the username.
2. **`gh api user`**: If no remote is configured, use `gh api user` to get the authenticated GitHub user's login.
3. **Prompt**: If neither is available (no remote, `gh` not authenticated), ask the user for their GitHub username or org name.

#### File Generation

Generate the CODEOWNERS file with the detected owner:

```
# Default code owners for all files
* @{owner}
```

#### Three-Tier File Handling

Apply the existing three-tier file handling rule from Step 6.2 to `.github/CODEOWNERS`:

| Tier | Condition | Action |
|------|-----------|--------|
| **A — Generate** | No `.github/CODEOWNERS` exists | Generate the file with `* @{owner}` and present for user review before writing. |
| **B — Enhance** | `.github/CODEOWNERS` exists but the `*` default rule is missing | Suggest adding `* @{owner}` as a default rule. Present the suggestion for user review. |
| **C — Review Only** | `.github/CODEOWNERS` exists and already has a `*` rule | Report "No changes needed." |

Present the generated or suggested CODEOWNERS content for user review before writing. The generated file is added to the infrastructure inventory (Step 6.1) and included in the files-to-stage list for the Phase 6 commit.

---

## Step 6.8 — Phase Summary and Gate

After all generation and review steps have completed, present the Phase 6 summary:

```
## Phase 6 Summary — GitHub Repository Setup & CI/CD

### Category Summary

| Category | Status | Count | Top Severity | Effort |
|----------|--------|-------|-------------|--------|
| Issue Templates | {Clean/Findings} | {N} | {HIGH/MEDIUM/LOW/—} | {Auto-fix/Quick fix/Decision needed/—} |
| PR Template | {Clean/Findings} | {N} | {HIGH/MEDIUM/LOW/—} | {effort or —} |
| CI/CD Workflow | {Clean/Findings} | {N} | {HIGH/MEDIUM/LOW/—} | {effort or —} |
| .gitignore Coverage | {Clean/Findings} | {N} | {HIGH/MEDIUM/LOW/—} | {effort or —} |
| CODEOWNERS | {Clean/Findings} | {N} | {HIGH/MEDIUM/LOW/—} | {effort or —} |

**Files generated (new)**: {N} ({list filenames})
**Files enhanced (existing)**: {N} ({list filenames})
**Files with no changes needed**: {N} ({list filenames})
**Files skipped by user**: {N} ({list filenames})
**.gitignore entries added**: {N}

### Infrastructure Status

| # | File | Action Taken | Status |
|---|------|-------------|--------|
| 1 | .github/ISSUE_TEMPLATE/bug_report.md | {Generated/Enhanced/No changes/Skipped} | {Approved/Skipped} |
| 2 | .github/ISSUE_TEMPLATE/feature_request.md | {Generated/Enhanced/No changes/Skipped} | {Approved/Skipped} |
| 3 | .github/PULL_REQUEST_TEMPLATE.md | {Generated/Enhanced/No changes/Skipped} | {Approved/Skipped} |
| 4 | .github/workflows/ci.yml | {Generated/Enhanced/No changes/Skipped} | {Approved/Skipped} |
| 5 | .gitignore | {Generated/Enhanced/No changes/Skipped} | {Approved/Skipped} |
| 6 | .github/CODEOWNERS | {Generated/Enhanced/No changes/Skipped} | {Approved/Skipped} |

### Findings
{List any findings generated during this phase — e.g., unrecognized language for CI workflow, missing build/test commands}

**Findings**: {total} total ({high} high, {medium} medium, {low} low)
```

Then present the user approval gate:

> "Phase 6 (GitHub Repository Setup & CI/CD) complete. Choose one:
> - **Approve and continue** — Accept findings and move to Phase 7 (Naming, Trademark & Identity Review)
> - **Review details** — Show the full infrastructure status and all findings
> - **Request changes** — Re-generate or re-review specific files
> - **Skip** — Mark Phase 6 as skipped and move on"

**Do NOT advance to Phase 7 until the user explicitly responds.**

---

## State Update (Step 6.9)

After Phase 6 is approved, update `.oss-prep/state.json`:

- Set `phase` to `7`
- Add phase-level findings to `phase_findings["6"]` with counts and status
- Update cumulative `findings` totals (add Phase 6 findings to running totals from Phases 1–5)
- Append `6` to `phases_completed`

Expected state shape after Phase 6:

```json
{
  "phase": 7,
  "project_root": "{absolute path}",
  "prep_branch": "oss-prep/ready",
  "project_profile": {
    "language": "{from Phase 0}",
    "framework": "{from Phase 0}",
    "package_manager": "{from Phase 0}",
    "build_system": "{from Phase 0}",
    "test_framework": "{from Phase 0}"
  },
  "findings": {
    "total": "{cumulative total from Phases 1 + 2 + 3 + 4 + 5 + 6}",
    "critical": "{cumulative critical}",
    "high": "{cumulative high}",
    "medium": "{cumulative medium}",
    "low": "{cumulative low}"
  },
  "phases_completed": [0, 1, 2, 3, 4, 5, 6],
  "history_flattened": false
}
```

Announce:
> "Phase 6 (GitHub Repository Setup & CI/CD) complete. Moving to Phase 7 — Naming, Trademark & Identity Review."

Wait for user approval before beginning Phase 7 (per the Phase-Gating Interaction Model).
