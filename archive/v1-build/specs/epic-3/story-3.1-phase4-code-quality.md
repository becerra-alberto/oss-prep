---
id: "3.1"
epic: 3
title: "Phase 4 — Code Architecture & Quality Review"
status: pending
source_prd: "tasks/prd-oss-prep.md"
priority: high
estimation: medium
depends_on: ["1.2"]
---

# Story 3.1 — Phase 4 — Code Architecture & Quality Review

## User Story
As a developer preparing to open-source a private repo, I want the tool to review my code's architecture, build health, test coverage, and quality concerns so that the public codebase meets professional open-source standards before release.

## Technical Context
This story adds the Phase 4 section to `SKILL.md`. Phase 4 is the first quality-focused phase (after the security/compliance phases 1-3) and shifts from "is this safe to publish?" to "is this ready to publish well?". The implementation is instructional markdown that tells Claude how to conduct a multi-stream analysis of the codebase.

Key design decisions for this phase:

1. **Sub-agent parallelization** — Phase 4 has five largely independent analysis streams (architecture summary, coding standards, build verification, test verification, code quality flagging). The SKILL.md instructions should direct Claude to run architecture summary, coding standards check, and code quality flagging as parallel sub-agents via the Task tool (all using `model: "opus"`). Build and test verification should run sequentially after the architecture scan completes (since knowing the build/test commands depends on understanding the project structure).

2. **Non-blocking failures** — Build failures and test failures are reported but do NOT block subsequent phases. The instructions must explicitly state this, matching FR-23 and FR-24. The findings are recorded in the state block and appear in the final report, but the phase gate still allows the user to proceed.

3. **Architecture summary scope** — The high-level architecture summary (FR-21) should cover directory structure (top 2-3 levels), module boundaries (how code is organized), entry points (main files, CLI entry points, server start files), and key abstractions (major classes, interfaces, types). This is descriptive, not prescriptive — it summarizes what exists rather than recommending changes.

4. **Quality flagging categories** — FR-25 defines specific categories: dead code (unreachable functions, unused exports), TODO/FIXME/HACK comments that reference internal context (e.g., "TODO: ask @john about this", "HACK: workaround for internal-tool-v2"), commented-out code blocks (more than 3 consecutive commented lines), and hardcoded configuration values (URLs, ports, file paths that should be environment variables). Each finding must include file path and line number per the grounding requirement.

5. **Coding standards detection** — FR-22 checks for the presence (not correctness) of: formatting configuration (.prettierrc, .editorconfig, rustfmt.toml, etc.), linting configuration (.eslintrc, pylintrc, clippy.toml, etc.), type checking configuration (tsconfig.json, mypy.ini, etc.), and build scripts (Makefile, package.json scripts, build.gradle, etc.). Missing configurations are flagged as suggestions, not errors.

## Acceptance Criteria

### AC1: Architecture Summary Covers Required Elements
- **Given** Phase 4 is reached on a repository with identifiable structure
- **When** the architecture analysis sub-agent executes
- **Then** the phase produces a summary covering: directory structure (top 2-3 levels with descriptions), module boundaries, entry points (main files, CLI commands, server start), and key abstractions, all grounded in actual file paths found via Glob/Read

### AC2: Coding Standards Detection Reports Configuration Presence
- **Given** Phase 4 is reached on a repository
- **When** the coding standards sub-agent executes
- **Then** it reports the presence or absence of: formatting config (e.g., .prettierrc, .editorconfig), linting config (e.g., .eslintrc, pylintrc), type checking config (e.g., tsconfig.json, mypy.ini), and build scripts (e.g., Makefile, package.json scripts), with missing items flagged as LOW severity suggestions

### AC3: Build Verification Runs Detected Build Command Without Blocking
- **Given** Phase 4 is reached on a repository with a detectable build command (e.g., `npm run build` from package.json, `cargo build` from Cargo.toml)
- **When** the build verification step executes
- **Then** it runs the build command via Bash, reports the exit code and relevant output, records build failure as a MEDIUM severity finding if applicable, and does NOT prevent the user from proceeding to Phase 5

### AC4: Test Verification Runs Detected Test Command and Reports Results
- **Given** Phase 4 is reached on a repository with a detectable test command (e.g., `npm test`, `pytest`, `cargo test`)
- **When** the test verification step executes
- **Then** it runs the test command via Bash, reports pass/fail counts and any failures, records test failures as MEDIUM severity findings, and does NOT prevent the user from proceeding to Phase 5

### AC5: Code Quality Flagging Identifies All Required Categories
- **Given** Phase 4 is reached on a repository containing TODO comments with internal references, commented-out code blocks, and hardcoded configuration values
- **When** the code quality sub-agent executes
- **Then** it identifies and reports: dead code indicators (unused exports, unreachable functions), TODO/FIXME/HACK comments referencing internal context (names, tools, tickets), commented-out code blocks (3+ consecutive commented lines), and hardcoded config values (URLs, ports, paths), with each finding including the file path and line number

### AC6: Phase Summary and Gate Follow Standard Pattern
- **Given** all Phase 4 analysis streams have completed
- **When** the phase presents its summary to the user
- **Then** it shows: finding counts by severity, key highlights from each analysis stream (architecture, standards, build, tests, quality), and waits for user approval before proceeding to Phase 5, following the phase-gating interaction model defined in Story 1.1

## Test Definition

### Unit Tests
- Read `SKILL.md` and verify the Phase 4 section exists with references to FR-21 through FR-25
- Verify the section instructs spawning sub-agents for architecture, coding standards, and quality flagging in parallel
- Verify the section specifies build and test failures as non-blocking (explicitly stated)
- Verify the section lists all code quality flagging categories (dead code, TODO/FIXME/HACK with internal context, commented-out code, hardcoded config)
- Verify the section references the phase-gating model for summary and user approval

### Integration/E2E Tests (if applicable)
- Run `/oss-prep` on a Node.js repository with a failing test suite and verify Phase 4 reports the test failures but allows proceeding to Phase 5
- Run `/oss-prep` on a Python repository with TODO comments containing internal team names (e.g., "TODO: @alice from platform-team") and verify Phase 4 flags them with file paths and line numbers
- Run `/oss-prep` on a repository with no linting or formatting configuration and verify Phase 4 reports the absence as LOW severity suggestions

## Files to Create/Modify
- `skills/oss-prep/SKILL.md` — Add Phase 4 section covering architecture summary, coding standards check, build verification, test verification, and code quality flagging with sub-agent parallelization instructions (modify)
