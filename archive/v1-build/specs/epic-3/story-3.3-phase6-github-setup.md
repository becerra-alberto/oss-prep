---
id: "3.3"
epic: 3
title: "Phase 6 — GitHub Repository Setup & CI/CD"
status: pending
source_prd: "tasks/prd-oss-prep.md"
priority: medium
estimation: medium
depends_on: ["1.2"]
---

# Story 3.3 — Phase 6 — GitHub Repository Setup & CI/CD

## User Story
As a developer preparing to open-source a private repo, I want the tool to generate GitHub issue templates, PR templates, a CI/CD workflow, and a comprehensive .gitignore so that the repository has professional community infrastructure and automated quality checks from the first public commit.

## Technical Context
This story adds the Phase 6 section to `SKILL.md`. Phase 6 shifts from content quality (documentation in Phase 5) to repository infrastructure — the scaffolding that enables community participation and automated quality gates. All generated files live under `.github/` or at the repo root (`.gitignore`).

Key design decisions for this phase:

1. **Issue templates** — FR-32 requires generating `.github/ISSUE_TEMPLATE/bug_report.md` and `.github/ISSUE_TEMPLATE/feature_request.md`. The instructions should direct Claude to use GitHub's standard template format with YAML frontmatter (`name`, `description`, `labels`, `assignees`) and markdown body sections. Bug reports should include: description, steps to reproduce, expected behavior, actual behavior, environment info. Feature requests should include: problem statement, proposed solution, alternatives considered. Templates should reference the project name from the Phase 0 profile.

2. **PR template** — FR-33 requires generating `.github/PULL_REQUEST_TEMPLATE.md`. The template should include: description of changes, type of change (bug fix, feature, breaking change, docs), checklist (tests added, docs updated, self-reviewed), and related issues. This is a single file, not a directory of templates.

3. **CI workflow generation** — FR-34 requires a `.github/workflows/ci.yml` appropriate to the detected language and test framework. The instructions must direct Claude to inspect the project profile from Phase 0 to determine: the correct base image (e.g., `node:18`, `python:3.11`, `rust:latest`), the package install command (e.g., `npm ci`, `pip install -r requirements.txt`), the lint command (if a linter is configured, detected in Phase 4), the build command, and the test command. The workflow should trigger on `push` to main/master and on `pull_request`. If the project uses multiple languages or has no detectable build system, generate a minimal workflow with a comment indicating where the user should customize.

4. **.gitignore completeness** — FR-35 requires reviewing the existing `.gitignore` (or creating one if absent) for completeness. The instructions should define four categories of required entries: OS files (`.DS_Store`, `Thumbs.db`, `Desktop.ini`), IDE files (`.idea/`, `.vscode/`, `*.swp`, `*.swo`, `.project`, `.classpath`), language-specific artifacts (detected from Phase 0 profile — e.g., `node_modules/` for Node.js, `__pycache__/` and `*.pyc` for Python, `target/` for Rust, `bin/` and `obj/` for .NET), and environment files (`.env`, `.env.local`, `.env.*.local`). Existing entries must be preserved; only missing entries are suggested as additions.

5. **Existing file handling** — If any of these files already exist, the instructions should direct Claude to review them for completeness and suggest additions rather than overwriting. For `.gitignore`, this means appending missing entries. For CI workflows, if one already exists, review it for coverage (lint, build, test steps) and suggest enhancements.

6. **User review gate** — FR-36 mandates that all generated files are presented for user review before writing. The instructions should define the same review loop as Phase 5: present content, ask for approval/edits/rejection, write only on approval.

7. **Directory creation** — The `.github/ISSUE_TEMPLATE/` directory may not exist. Instructions should note that the Write tool will create intermediate directories, but the phase should verify the path structure before writing.

## Acceptance Criteria

### AC1: Issue Templates Are Generated with Standard Format
- **Given** Phase 6 is reached on a repository without `.github/ISSUE_TEMPLATE/` files
- **When** the issue template generation executes
- **Then** it generates `bug_report.md` and `feature_request.md` in `.github/ISSUE_TEMPLATE/`, each with YAML frontmatter (name, description, labels) and appropriate markdown body sections (bug: steps to reproduce, expected/actual behavior, environment; feature: problem, proposed solution, alternatives), and presents both for user review before writing

### AC2: PR Template Is Generated with Checklist
- **Given** Phase 6 is reached on a repository without `.github/PULL_REQUEST_TEMPLATE.md`
- **When** the PR template generation executes
- **Then** it generates a PR template with sections for: description of changes, type of change, checklist items (tests, docs, self-review), and related issues, and presents it for user review before writing

### AC3: CI Workflow Is Language-Appropriate
- **Given** Phase 6 is reached on a Node.js repository (detected via `package.json` in Phase 0) with `jest` as the test framework
- **When** the CI workflow generation executes
- **Then** it generates `.github/workflows/ci.yml` with: `node` base image, `npm ci` install step, lint step (if eslint configured), `npm run build` build step (if build script exists), `npm test` test step, triggers on push to main and pull_request, and presents the workflow for user review before writing

### AC4: .gitignore Is Reviewed and Enhanced
- **Given** Phase 6 is reached on a Python repository with an existing `.gitignore` that contains `__pycache__/` but is missing `.env` and `.DS_Store`
- **When** the .gitignore review executes
- **Then** it identifies the missing entries (`.env`, `.DS_Store`, and other required entries from the four categories), suggests them as additions to the existing file (preserving all current entries), and presents the enhanced .gitignore for user review before writing

### AC5: Existing Files Are Enhanced Rather Than Overwritten
- **Given** Phase 6 is reached on a repository with an existing `.github/workflows/ci.yml` that has build and test steps but no lint step
- **When** the CI workflow review executes
- **Then** it suggests adding a lint step to the existing workflow rather than generating a replacement workflow, and presents the suggestion for user review

### AC6: Phase Summary and Gate Follow Standard Pattern
- **Given** all Phase 6 generation and review steps have completed
- **When** the phase presents its summary to the user
- **Then** it shows: count of files generated (new), count of files enhanced (existing), count of .gitignore entries added, and waits for user approval before proceeding to Phase 7, following the phase-gating interaction model

## Test Definition

### Unit Tests
- Read `SKILL.md` and verify the Phase 6 section exists with references to FR-32 through FR-36
- Verify the section specifies bug_report.md and feature_request.md templates with YAML frontmatter format
- Verify the section specifies PR template with description, type of change, and checklist sections
- Verify the CI workflow generation references the Phase 0 project profile for language detection
- Verify the .gitignore review covers all four categories (OS, IDE, language-specific, env files)
- Verify the section requires user review and approval before writing any generated file
- Verify the section specifies preservation of existing files (enhance, not overwrite)

### Integration/E2E Tests (if applicable)
- Run `/oss-prep` on a repository with no `.github/` directory and verify Phase 6 generates all four file types (bug report template, feature request template, PR template, CI workflow) plus .gitignore review
- Run `/oss-prep` on a Rust repository and verify the CI workflow uses `rust` image, `cargo build`, and `cargo test` commands
- Run `/oss-prep` on a repository with an existing `.gitignore` and verify Phase 6 only suggests additions, preserving all existing entries
- Run `/oss-prep` on a repository with existing issue templates and verify Phase 6 reviews them for completeness rather than regenerating

## Files to Create/Modify
- `skills/oss-prep/SKILL.md` — Add Phase 6 section covering GitHub issue templates, PR template, CI workflow generation, .gitignore completeness review, existing-file enhancement rules, and user review gates (modify)
