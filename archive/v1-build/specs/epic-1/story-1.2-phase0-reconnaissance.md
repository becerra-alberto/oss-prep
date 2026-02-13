---
id: "1.2"
epic: 1
title: "Phase 0 — Reconnaissance"
status: pending
source_prd: "tasks/prd-oss-prep.md"
priority: critical
estimation: medium
depends_on: ["1.1"]
---

# Story 1.2 — Phase 0 — Reconnaissance

## User Story
As a developer invoking `/oss-prep` on any git repository, I want the skill to automatically detect the project root, create a preparation branch, build a comprehensive project profile, and present it for my confirmation so that all subsequent audit phases operate on accurate project context.

## Technical Context
This story adds the Phase 0 section to the existing `SKILL.md` skeleton created in story 1.1. Phase 0 is the reconnaissance phase — the entry point for every `/oss-prep` run. Since this is a Claude Code skill (instructional markdown, not executable code), the implementation consists of detailed instructions telling Claude what commands to run, what to inspect, and how to present results.

Key implementation details:

1. **Project root detection** — Use `git rev-parse --show-toplevel` to find the repo root. Then check if the repo is a submodule by inspecting `git rev-parse --show-superproject-working-tree` — if it returns a value, warn the user that they are inside a submodule and confirm they want to proceed on this repo specifically (not the parent).

2. **Preparation branch management** — Check if `oss-prep/ready` branch already exists (`git branch --list oss-prep/ready`). If it exists, ask the user: "Resume existing preparation (keep changes) or Reset (start fresh)?". If resetting, delete and recreate. If creating new, branch from current HEAD. Switch to the prep branch for all subsequent work.

3. **Project profile building** — This is the most substantial part. The skill must use a combination of file inspection and tool detection to build the profile:
   - **Languages**: Use `git ls-files` piped through extension counting, or inspect for signature files (`.py`, `.js`, `.ts`, `.rs`, `.go`, `.rb`, `.java`, etc.)
   - **Frameworks**: Detect by manifest contents (e.g., `next` in package.json deps = Next.js, `django` in requirements.txt = Django)
   - **Package managers**: Detect by manifest file presence (`package.json`/`yarn.lock`/`pnpm-lock.yaml`, `Cargo.toml`, `go.mod`, `pyproject.toml`/`requirements.txt`, `Gemfile`, `pom.xml`, `build.gradle`, `composer.json`)
   - **Build system**: Detect build scripts (`Makefile`, `package.json` scripts, `build.gradle`, `CMakeLists.txt`, etc.)
   - **Test framework**: Detect test directories and config files (`jest.config.*`, `pytest.ini`, `vitest.config.*`, etc.)
   - **Metrics**: File count (`git ls-files | wc -l`), LOC (sum via `wc -l`), commit count (`git rev-list --count HEAD`), directory structure (top-level dirs)
   - **CI/CD**: Check for `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/`, `.travis.yml`, `azure-pipelines.yml`

4. **Anomaly detection** — Detect and report:
   - Submodules: `git submodule status`
   - Large binaries: `git ls-files` with size check for files >1MB
   - Symlinks: `find` with `-type l` or `git ls-files` checking for symlinks
   - Non-standard permissions: `git ls-files -s` checking for executable bits on non-script files

5. **Profile presentation** — Present the profile in a structured format and ask the user to confirm accuracy, correct any misdetections, or add context. After confirmation, update the STATE block with the project profile and mark Phase 0 as complete.

The instructions must be repo-agnostic — they should work on any git repository regardless of language, framework, or structure. For unrecognized project types, the profile should note "Unknown" for undetectable fields and proceed gracefully.

## Acceptance Criteria

### AC1: Project Root Detection and Submodule Warning
- **Given** the user invokes `/oss-prep` from any directory within a git repository
- **When** Phase 0 begins execution
- **Then** the skill detects the project root via `git rev-parse --show-toplevel`, checks for submodule status via `git rev-parse --show-superproject-working-tree`, and if inside a submodule, warns the user with a clear message explaining that submodule contents are audited independently and asks for confirmation to proceed

### AC2: Preparation Branch Created or Resumed
- **Given** Phase 0 has detected the project root
- **When** the skill checks for the `oss-prep/ready` branch
- **Then** if the branch does not exist, it is created from current HEAD and checked out; if the branch already exists, the user is asked whether to resume (keep existing changes) or reset (delete and recreate from current HEAD); and in either case the skill confirms which branch is now active

### AC3: Project Profile Is Comprehensive and Accurate
- **Given** the skill is building the project profile
- **When** it inspects the repository using git commands, file inspection, and manifest parsing
- **Then** the profile includes all required fields: primary language(s), framework(s), package manager(s), build system, test framework, directory structure (top-level), total file count, total lines of code, commit count, and CI/CD presence (with specific CI system identified); and undetectable fields are marked "Not detected" rather than guessed

### AC4: Anomalies Are Detected and Reported
- **Given** the skill is performing reconnaissance
- **When** it checks for repository anomalies
- **Then** it detects and reports: submodules (with paths), large binary files >1MB (with paths and sizes), symlinks (with paths and targets), and non-standard file permissions; and each anomaly includes enough detail for the user to assess risk

### AC5: Profile Presented for User Confirmation and STATE Updated
- **Given** the project profile and anomaly report are complete
- **When** the skill presents them to the user
- **Then** the profile is displayed in a structured, readable format; the user is asked to confirm accuracy, correct misdetections, or add context; and upon confirmation the STATE block is updated with phase: 1, project_root, prep_branch, project_profile summary, findings initialized to zero, and phases_completed: [0]

## Test Definition

### Unit Tests
- Verify the Phase 0 section exists in SKILL.md with instructions for all five subsections (root detection, branch management, profile building, anomaly detection, profile presentation)
- Verify the instructions reference `git rev-parse --show-toplevel` for root detection
- Verify the instructions reference `git rev-parse --show-superproject-working-tree` for submodule detection
- Verify the instructions include logic for both creating a new `oss-prep/ready` branch and resuming an existing one
- Verify the project profile field list matches all items from FR-3 (languages, frameworks, package managers, build system, test framework, directory structure, file count, LOC, commit count, CI/CD)
- Verify anomaly detection covers all four categories from FR-4 (submodules, large binaries >1MB, symlinks, non-standard permissions)

### Integration/E2E Tests (if applicable)
- Run `/oss-prep` on a small test git repository (e.g., a Node.js project with `package.json`, a few source files, and a `jest.config.js`) and verify:
  - The project root is correctly identified
  - The `oss-prep/ready` branch is created and checked out
  - The profile correctly identifies Node.js, the package manager, Jest as the test framework, and the file/LOC/commit counts
  - The profile is presented in a readable format and the user is prompted for confirmation
  - After confirmation, the STATE block shows phase: 1 and phases_completed: [0]
- Run `/oss-prep` on a Python project with `pyproject.toml` and `pytest` to verify repo-agnostic detection works across languages
- Run `/oss-prep` inside a git submodule and verify the submodule warning is displayed

## Files to Create/Modify
- `skills/oss-prep/SKILL.md` — Add Phase 0: Reconnaissance section with instructions for project root detection, preparation branch management, project profile building, anomaly detection, and profile presentation with user confirmation gate (modify)
