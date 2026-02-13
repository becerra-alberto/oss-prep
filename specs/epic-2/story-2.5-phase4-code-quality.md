---
id: "2.5"
epic: 2
title: "Extract Phase 4: Code Quality to phases/04-code-quality.md"
status: done
source_prd: "tasks/prd-oss-prep-v2.md"
priority: high
estimation: medium
depends_on: ["1.1"]
---

# Story 2.5 — Extract Phase 4: Code Quality to phases/04-code-quality.md

## User Story

As a developer preparing a repo for open-source release, I want the code quality review phase extracted into a self-contained file so that a sub-agent can execute architecture analysis, coding standards checks, build/test verification, and quality flagging in its own context without loading the monolith.

## Technical Context

Phase 4 content lives between the `<!-- PHASE_4_START -->` and `<!-- PHASE_4_END -->` markers in SKILL.md (approximately lines 1455-1749). Phase 4 shifts from security/compliance auditing (Phases 1-3) to quality and professionalism assessment. It uses a two-stream approach:

**Stream 1 -- Parallel Sub-Agents (Step 4.1)**: Three sub-agents launched simultaneously:

- **Sub-agent A -- Architecture Summary**: Produces a descriptive (not prescriptive) codebase summary covering:
  1. Directory structure (top 2-3 levels, ignoring build artifacts)
  2. Module boundaries (flat, feature-based, layered, monorepo patterns)
  3. Entry points (CLI entry points via manifest bin fields, server start files, library entry points)
  4. Key abstractions (up to 10 major classes/interfaces/types/data structures)

- **Sub-agent B -- Coding Standards Detection**: Checks PRESENCE (not correctness) of tooling configuration across 4 categories:
  1. Formatting: Prettier, EditorConfig, rustfmt, Black/YAPF, clang-format, Biome, Deno fmt
  2. Linting: ESLint, Biome, Pylint, Ruff, Flake8, Clippy, golangci-lint, RuboCop
  3. Type checking: TypeScript (tsconfig), jsconfig, mypy, Pyright
  4. Build scripts: Makefile, package.json scripts, Gradle, CMake, Just, Task
  - Missing categories reported as LOW severity findings with specific recommendations

- **Sub-agent C -- Code Quality Flagging**: Scans for 4 quality concern categories:
  1. Dead code indicators (unused functions/exports, language-specific heuristics, MEDIUM severity)
  2. TODO/FIXME/HACK comments with internal context (names, tools, tickets, teams; MEDIUM for internal refs, LOW for generic)
  3. Commented-out code blocks (3+ consecutive commented lines with code patterns; LOW severity; excludes license headers, JSDoc, config comments)
  4. Hardcoded configuration values (URLs, ports, absolute file paths, magic numbers; LOW or MEDIUM for internal/production infrastructure)

**Stream 2 -- Sequential Build/Test (Step 4.2)**: Runs after Stream 1 completes because knowing build/test commands depends on project structure understanding:

- **Build Verification**: Detect build command per ecosystem (Node.js npm/yarn/pnpm, Python setup.py/pyproject.toml, Rust cargo, Go, Java/Gradle, TypeScript tsc). Run with 5-minute timeout. Success = no finding; Failure = MEDIUM finding (non-blocking).
- **Test Verification**: Detect test command per ecosystem (Node.js npm/yarn/pnpm test, Python pytest/tox, Rust cargo test, Go go test, Java/Gradle, Ruby rspec/rake). Run with 10-minute timeout. Success = no finding; Failure = MEDIUM finding (non-blocking).

Both build and test failures are explicitly **non-blocking** -- they appear as findings but do NOT prevent the user from proceeding.

Phase 4 does not reference `patterns/secrets.md` or `patterns/pii.md` (those are Phase 1/2 concerns). It does not need shared pattern libraries.

## Acceptance Criteria

### AC1: Phase file structure

- **Given** the current SKILL.md with Phase 4 content between `<!-- PHASE_4_START -->` and `<!-- PHASE_4_END -->`
- **When** the phase is extracted to `phases/04-code-quality.md`
- **Then** the file starts with a header block containing:
  - Phase: 4
  - Name: Code Architecture & Quality Review
  - Inputs: project_root, project_profile (from state)
  - Outputs: architecture summary, findings list (Q4-1 through Q4-N) with counts by severity, build status, test status, state update with cumulative finding counts

### AC2: Self-contained execution steps

- **Given** a sub-agent that reads only `phases/04-code-quality.md`
- **When** it executes the phase
- **Then** it can perform all steps (4.1 through 4.4) without referencing any other file, including:
  - Parallel sub-agent dispatch for 3 quality streams (architecture, standards, quality flags)
  - Sequential build and test verification with specific commands per ecosystem
  - Finding consolidation from all 5 streams
  - Phase summary presentation

### AC3: Parallel sub-agent instructions complete

- **Given** the extracted phase file
- **When** Step 4.1 is reviewed
- **Then** it contains complete, self-contained instructions for all 3 sub-agents:
  - Sub-agent A: directory structure analysis (2-3 levels), module boundary identification, entry point detection (CLI/server/library with specific file/field patterns), key abstractions (up to 10)
  - Sub-agent B: all configuration file paths for 4 categories (formatting: 7 tool families, linting: 8 tool families, type checking: 4 tool families, build scripts: 6 tool families)
  - Sub-agent C: all 4 quality concern categories with detection heuristics, inclusion/exclusion rules, and severity assignments

### AC4: Build and test timeouts preserved

- **Given** the extracted phase file
- **When** Step 4.2 is reviewed
- **Then** it specifies:
  - Build timeout: 5 minutes
  - Test timeout: 10 minutes
  - Both failures are explicitly documented as non-blocking (MEDIUM severity, do not prevent proceeding)

### AC5: Build/test command detection per ecosystem preserved

- **Given** the extracted phase file
- **When** Step 4.2 is reviewed
- **Then** build and test command detection is present for all ecosystems:
  - Build: Node.js (npm/yarn/pnpm run build), Python (setup.py build, pip install -e ., python -m build), Rust (cargo build), Go (go build ./...), Java/Gradle (gradlew build, mvn package), TypeScript (npx tsc --noEmit)
  - Test: Node.js (npm/yarn/pnpm test), Python (pytest, tox), Rust (cargo test), Go (go test ./...), Java/Gradle (gradlew test, mvn test), Ruby (bundle exec rake test, bundle exec rspec)

### AC6: Finding format preserved

- **Given** the extracted phase file
- **When** the finding format section is reviewed
- **Then** it contains:
  - `Q4-{N}` finding ID format
  - The coding standards missing-config finding format with severity LOW and recommendation
  - The build/test failure finding format with command, exit code, error output (truncated to 50 lines for build, 20 failed test names for test), and non-blocking note
  - The code quality finding format with file path, line number, and severity

### AC7: User gate documented

- **Given** the extracted phase file
- **When** the user gate section is reviewed
- **Then** it contains the Phase 4-specific approval prompt with 4 options:
  - Approve and continue (to Phase 5)
  - Review details (full architecture summary and all findings)
  - Request changes (re-run specific analysis streams or adjust)
  - Skip
- **And** the phase summary format includes: Architecture Summary (concise), Coding Standards (4 categories present/missing), Build Verification status, Test Verification status, Code Quality counts by category

### AC8: I/O declaration

- **Given** the extracted phase file
- **When** checked against extraction rules
- **Then** it declares:
  - **Inputs**: project_root, project_profile (language, framework, package_manager, build_system, test_framework from state)
  - **Outputs**: architecture summary (directory structure, module boundaries, entry points, key abstractions), findings list (Q4-1 through Q4-N), finding counts by severity, build status (passed/failed/skipped), test status (passed/failed/skipped with counts), state update (phase: 5, cumulative findings from Phases 1+2+3+4, phases_completed adds 4)

### AC9: Validation

- **Given** the completed phase file
- **When** checked against all 5 extraction rules from CLAUDE.md
- **Then** it satisfies each rule:
  1. Self-contained: all sub-agent instructions, build/test detection rules, finding formats, and presentation formats are inline
  2. Declares I/O: Inputs and Outputs sections present in header
  3. References shared patterns: N/A for Phase 4 (no secret/PII pattern references needed)
  4. Includes user gate: 4-option approval prompt documented
  5. Starts with header block: phase number, name, inputs, outputs

## Test Definition

### Structural Tests

- File exists at `phases/04-code-quality.md`
- Contains required sections: header block (with Phase, Name, Inputs, Outputs), Steps (4.1 through 4.4), Finding Format, User Gate
- Header block declares Phase: 4, Name: Code Architecture & Quality Review
- Contains complete Sub-agent A instructions (directory structure, module boundaries, entry points, key abstractions)
- Contains complete Sub-agent B instructions (formatting, linting, type checking, build scripts with all config file paths)
- Contains complete Sub-agent C instructions (dead code, TODO/FIXME/HACK, commented-out blocks, hardcoded config)
- Contains build verification with 5-minute timeout
- Contains test verification with 10-minute timeout
- Contains "non-blocking" declaration for both build and test failures
- Contains build command detection for 6 ecosystems (Node.js, Python, Rust, Go, Java/Gradle, TypeScript)
- Contains test command detection for 6 ecosystems (Node.js, Python, Rust, Go, Java/Gradle, Ruby)
- Contains the `Q4-{N}` finding format template
- Contains the phase summary format (Architecture Summary, Coding Standards, Build, Test, Code Quality)
- Does NOT reference `patterns/secrets.md` or `patterns/pii.md`

### Content Tests

- Sub-agent A: build artifact directories to ignore listed (node_modules/, dist/, target/, __pycache__, vendor/, .build/, _build/)
- Sub-agent B: all formatting tools listed (Prettier, EditorConfig, rustfmt, Black/YAPF, clang-format, Biome, Deno)
- Sub-agent B: all linting tools listed (ESLint, Biome, Pylint, Ruff, Flake8, Clippy, golangci-lint, RuboCop)
- Sub-agent C: dead code heuristics per language (JS/TS, Python, Rust)
- Sub-agent C: TODO/FIXME/HACK with internal context detection (names, tools, tickets, teams)
- Sub-agent C: commented-out code exclusions (license headers, JSDoc, config comments)
- Sub-agent C: hardcoded values include URLs, ports, absolute paths, magic numbers
- Build/test failure finding format includes command, exit code, truncated output, non-blocking note

## Files to Create/Modify

- `phases/04-code-quality.md` -- extracted Phase 4 content (create)
