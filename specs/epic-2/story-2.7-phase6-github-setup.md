---
id: "2.7"
epic: 2
title: "Extract Phase 6: GitHub Repository Setup & CI/CD"
status: done
source_prd: "tasks/prd-oss-prep-v2.md"
priority: high
estimation: medium
depends_on: ["1.1"]
---

# Story 2.7 — Extract Phase 6: GitHub Repository Setup & CI/CD

## User Story
As a developer preparing a repo for open-source release, I want the GitHub repository setup and CI/CD scaffolding phase extracted into a self-contained phase file so that issue templates, PR templates, CI workflows, and .gitignore completeness are handled in a dedicated sub-agent context.

## Technical Context
Phase 6 content lives in SKILL.md between the `<!-- PHASE_6_START -->` and `<!-- PHASE_6_END -->` markers (approximately lines 2173-2608). It covers Steps 6.1 through 6.8: infrastructure inventory, existing-file handling rule, issue template generation, PR template generation, CI workflow generation, .gitignore completeness review, phase summary/gate, and state update.

The extracted file must be self-contained per the CLAUDE.md extraction rules: header block, declared I/O, execution steps, finding format, and user gate.

Phase 6 is a straightforward extraction with no bug fixes required. The CI workflow generation is the most complex step, with language-specific templates for Node.js, Python, Rust, Go, and a generic fallback. All templates must be preserved verbatim.

### Key content to extract:
- Step 6.1: Infrastructure inventory (5 files: bug_report.md, feature_request.md, PULL_REQUEST_TEMPLATE.md, ci.yml, .gitignore)
- Step 6.2: Existing-file handling rule (same three-tier approach as Phase 5: Generate / Enhance / Review Only)
- Step 6.3: Issue templates generation (bug report and feature request with YAML frontmatter)
- Step 6.4: PR template generation (description, type of change, checklist, related issues)
- Step 6.5: CI workflow generation (language-specific: Node.js, Python, Rust, Go, generic fallback)
- Step 6.6: .gitignore completeness review (4 categories: OS, IDE, language-specific, environment)
- Step 6.7: Phase summary and gate
- Step 6.8: State update

### Content to preserve verbatim:
- Infrastructure inventory table format
- Three-tier file handling table
- Bug report template (full markdown with YAML frontmatter)
- Feature request template (full markdown with YAML frontmatter)
- PR template (full markdown with checkboxes)
- CI workflow YAML skeleton and all language-specific variants (Node.js, Python, Rust, Go, generic)
- .gitignore required categories table (OS files, IDE/editor, language-specific per 7 languages, environment files)
- Enhancement suggestion format
- Phase summary template with infrastructure status table

## Acceptance Criteria

### AC1: Phase file structure follows extraction rules
- **Given** the CLAUDE.md extraction rules requiring header block, I/O declarations, steps, finding format, and user gate
- **When** Phase 6 is extracted to `phases/06-github-setup.md`
- **Then** the file starts with a header block containing: phase number (6), phase name (GitHub Repository Setup & CI/CD), inputs list, and outputs list

### AC2: Inputs and outputs are explicitly declared
- **Given** Phase 6 reads project profile from state and creates files under `.github/` and modifies `.gitignore`
- **When** the I/O declarations are written
- **Then** inputs include: `state.project_root`, `state.project_profile` (language, framework, package_manager, build_system, test_framework), `state.phases_completed`, and `state.findings`
- **And** outputs include: files created/modified (`.github/ISSUE_TEMPLATE/bug_report.md`, `.github/ISSUE_TEMPLATE/feature_request.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/workflows/ci.yml`, `.gitignore`), state updates (phase_findings for phase 6, cumulative findings totals, phases_completed updated)

### AC3: Issue templates are preserved with full structure
- **Given** the v1 Phase 6 defines bug report and feature request templates with YAML frontmatter
- **When** the templates are extracted
- **Then** the bug report template includes: YAML frontmatter (name, description, labels, assignees), Description, Steps to Reproduce, Expected Behavior, Actual Behavior, Environment (with language-specific runtime version), Additional Context
- **And** the feature request template includes: YAML frontmatter (name, description, labels, assignees), Problem Statement, Proposed Solution, Alternatives Considered, Additional Context
- **And** both templates use `{project_name}` substitution from project profile
- **And** Tier B enhancement instructions are included for existing templates

### AC4: PR template is preserved with full structure
- **Given** the v1 Phase 6 defines a PR template with checkboxes
- **When** the PR template is extracted
- **Then** it includes: Description, Type of Change (6 checkbox options), Checklist (4 items), Related Issues
- **And** Tier B enhancement instructions are included for existing PR templates

### AC5: CI workflow generation covers all language variants
- **Given** the v1 Phase 6 provides language-specific CI workflow templates
- **When** the CI workflow generation step is extracted
- **Then** it includes the YAML skeleton structure and all four language-specific variants: Node.js (setup-node, npm ci, lint, build, test), Python (setup-python, pip install, ruff, pytest), Rust (rust-toolchain, clippy, cargo build, cargo test), Go (setup-go, golangci-lint, go build, go test)
- **And** a generic fallback with TODO comments is included
- **And** CI workflow generation is explicitly tied to project profile detection (not guessing)
- **And** Tier B enhancement instructions check for lint/build/test steps and push/PR triggers

### AC6: .gitignore completeness review covers all categories
- **Given** the v1 Phase 6 reviews .gitignore across four categories
- **When** the .gitignore step is extracted
- **Then** all four categories are preserved: OS files (4 entries), IDE/Editor (10 entries), Language-Specific (7 language tables: JS/TS, Python, Rust, Go, Java, Ruby, .NET), Environment files (5 entries)
- **And** the review process distinguishes between creating a new .gitignore and appending to an existing one
- **And** the review presentation format is preserved (existing/missing counts, category table, suggested additions block)
- **And** the rule "never remove or modify existing entries" is stated

### AC7: Three-tier file handling rule is preserved
- **Given** the existing-file preservation approach applies to all infrastructure files
- **When** the phase is extracted
- **Then** the three-tier table is preserved: Tier A (Generate), Tier B (Enhance), Tier C (Review Only)
- **And** the enhancement suggestion format is preserved

### AC8: User gate prompt is included
- **Given** extraction rule 4 requires each phase file to include its user gate
- **When** the phase is extracted
- **Then** the file includes the Phase 6 approval gate: "Phase 6 (GitHub Repository Setup & CI/CD) complete. Choose one: Approve and continue / Review details / Request changes / Skip"
- **And** the gate specifies the next phase: Phase 7 (Naming, Trademark & Identity Review)

### AC9: Finding format is included
- **Given** Phase 6 can generate findings (e.g., unrecognized language for CI, missing build/test commands)
- **When** the phase is extracted
- **Then** a finding format section is included for Phase 6 findings using the ID prefix `GH6-{N}` (GH6 = GitHub Setup Phase 6), numbered sequentially (GH6-1, GH6-2, etc.)
- **And** the phase summary template is preserved with the infrastructure status table (5 rows for the 5 infrastructure files)

### AC10: Self-contained execution
- **Given** a sub-agent receives only this phase file, the current state, and the project root
- **When** the sub-agent reads `phases/06-github-setup.md`
- **Then** it contains all information needed to execute Phase 6 without referencing SKILL.md or any other phase file
- **And** no shared pattern libraries are referenced (Phase 6 does not use secrets.md or pii.md)

## Test Definition

### Structural Tests
- File exists at `phases/06-github-setup.md`
- File begins with a header block containing: Phase number (6), Phase name (GitHub Repository Setup & CI/CD), Inputs section, Outputs section
- File contains all step numbers: 6.1 through 6.7 (6.8 state update is documented as expected state change)
- File contains bug report template with YAML frontmatter
- File contains feature request template with YAML frontmatter
- File contains PR template with checkbox items
- File contains CI workflow YAML with `on: push/pull_request` trigger structure
- File contains all four language-specific CI variants (Node.js, Python, Rust, Go)
- File contains .gitignore category table with all four categories
- File contains the user gate prompt with all four options
- File contains the finding ID convention `GH6-{N}` or `GH6-1`
- File does NOT contain content from other phases

### Content Verification Tests
- Bug report template has sections: Description, Steps to Reproduce, Expected Behavior, Actual Behavior, Environment, Additional Context
- Feature request template has sections: Problem Statement, Proposed Solution, Alternatives Considered, Additional Context
- PR template has sections: Description, Type of Change (checkboxes), Checklist (checkboxes), Related Issues
- CI workflow Node.js variant references: actions/setup-node@v4, npm ci, npm run lint, npm run build, npm test
- CI workflow Python variant references: actions/setup-python@v5, pip install, ruff check, pytest
- CI workflow Rust variant references: dtolnay/rust-toolchain@stable, cargo clippy, cargo build, cargo test
- CI workflow Go variant references: actions/setup-go@v5, golangci-lint run, go build, go test
- .gitignore OS files category includes: .DS_Store, Thumbs.db, Desktop.ini, ._*
- .gitignore environment category includes: .env, .env.local, .env.*.local

## Files to Create/Modify
- `phases/06-github-setup.md` -- extracted Phase 6 content (create)
