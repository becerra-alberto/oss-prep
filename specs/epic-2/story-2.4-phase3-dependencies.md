---
id: "2.4"
epic: 2
title: "Extract Phase 3: Dependencies to phases/03-dependencies.md (with License Fix)"
status: done
source_prd: "tasks/prd-oss-prep-v2.md"
priority: critical
estimation: large
depends_on: ["1.1"]
---

# Story 2.4 — Extract Phase 3: Dependencies to phases/03-dependencies.md (with License Fix)

## User Story

As a developer preparing a repo for open-source release, I want the dependency audit phase extracted into a self-contained file with a license selection preamble so that license compatibility analysis works correctly without depending on the Phase 5 license selection that happens later in the pipeline.

## Technical Context

Phase 3 content lives between the `<!-- PHASE_3_START -->` and `<!-- PHASE_3_END -->` markers in SKILL.md (approximately lines 1125-1453). It contains 8 steps:

- **Step 3.1 -- Manifest Detection**: Glob-based discovery of package manifests and lock files across 10 ecosystems (Node.js, Python, Rust, Go, Ruby, Java/Maven/Gradle, PHP, .NET, Elixir, Swift) with monorepo support. Includes skip rules for build artifact directories (node_modules/, vendor/, .build/, _build/, target/, dist/).
- **Step 3.2 -- Dependency Inventory Table Generation**: Per-manifest parsing with 5-column table (Package Name, Version, License, Direct/Transitive, Flags). License extraction methods documented per ecosystem (Node.js, Python, Rust, Go, Ruby, PHP, Java/Gradle/.NET/Elixir/Swift) with graceful degradation when toolchains are missing.
- **Step 3.3 -- License Compatibility Checking**: 12-row x 7-column compatibility matrix (dependency license vs project license), 4-level severity classification (CRITICAL for incompatible, HIGH for unknown, MEDIUM for weak-copyleft, LOW for compatible).
- **Step 3.4 -- Private/Internal Dependency Detection**: Detection heuristics for scoped packages on private registries (Node.js .npmrc/.yarnrc), local path references (file:, path dependencies across 4 ecosystems), private git repository references (git+ssh://, git@github.com), and private registry configurations (.npmrc, .yarnrc.yml, pip.conf, Cargo config). All private dependency findings are CRITICAL.
- **Step 3.5 -- Opportunistic Vulnerability Checking**: Tool detection (npm, yarn, pip-audit, cargo-audit, bundle-audit) with JSON-parsed output, informational classification.
- **Step 3.6 -- Finding Report Format**: `D3-{N}` template with license-specific fields (License, Project License, Compatibility, Explanation). Remediation options: replace dependency, remove dependency, change project license, contact author, accept risk.
- **Step 3.7 -- Consolidate and Present Findings**: Combine license + private + vulnerability findings, severity sorting, phase summary format with ecosystem breakdown, user approval gate with 4 options (Approve/Review details/Request changes/Skip).
- **Step 3.8 -- Update STATE**: State block update template with cumulative findings from Phases 1+2+3.

**BUG FIX (FR-21, AC-2.4.2)**: A new **Step 3.0 -- License Context** preamble must be added BEFORE Step 3.1. This fixes the design bug where Phase 3's license compatibility checking (Step 3.3) references "the project's own license" but the license is only selected in Phase 5. The preamble:

1. Checks if a LICENSE file exists in the repository root
2. If YES: reads the file, identifies the license type (matches against MIT, Apache-2.0, GPL-3.0, BSD-2-Clause, BSD-3-Clause, MPL-2.0, ISC, Unlicense templates)
3. If NO: presents the license selection menu (identical to the v1 Phase 5 menu: MIT (default), Apache-2.0, GPL-3.0, BSD-2-Clause, BSD-3-Clause, MPL-2.0, ISC, Unlicense) and records the user's choice

The selected/detected license is recorded as `state.license_choice` for downstream use by Phase 5 (which will read it from state instead of re-prompting).

**Important architectural note**: Per DD-4 and the PRD Technical Considerations section, the sub-agent cannot interact with the user. Therefore, the license check/prompt in Step 3.0 must be documented as an orchestrator-side pre-check. The orchestrator checks for the LICENSE file and handles the prompt BEFORE dispatching the Phase 3 sub-agent, then passes the chosen license as an input to the sub-agent.

## Acceptance Criteria

### AC1: Phase file structure

- **Given** the current SKILL.md with Phase 3 content between `<!-- PHASE_3_START -->` and `<!-- PHASE_3_END -->`
- **When** the phase is extracted to `phases/03-dependencies.md`
- **Then** the file starts with a header block containing:
  - Phase: 3
  - Name: Dependency Audit
  - Inputs: project_root, project_profile, state (from Phases 0-2), license_choice (from Step 3.0 or state)
  - Outputs: dependency inventory tables, findings list with counts by severity, state update with cumulative finding counts and license_choice

### AC2: License selection preamble added (Bug Fix)

- **Given** the extracted phase file
- **When** Step 3.0 is reviewed
- **Then** it contains a "License Context" preamble that:
  - (a) Documents that the orchestrator checks for a LICENSE file at project root before dispatching the sub-agent
  - (b) If LICENSE exists: orchestrator reads and identifies the license type, passes it as input
  - (c) If LICENSE does not exist: orchestrator presents the license selection menu to the user and passes the choice as input
  - (d) The license selection menu matches v1 exactly: MIT (default), Apache-2.0, GPL-3.0, BSD-2-Clause, BSD-3-Clause, MPL-2.0, ISC, Unlicense
  - (e) The selected/detected license is recorded as a state update (`license_choice`) for Phase 5

### AC3: Self-contained execution steps

- **Given** a sub-agent that reads `phases/03-dependencies.md` and receives the license_choice input
- **When** it executes the phase
- **Then** it can perform all steps (3.1 through 3.8) without referencing any other file, including:
  - Manifest detection across 10 ecosystems with monorepo support
  - Dependency inventory table generation with per-ecosystem license extraction
  - License compatibility checking against the provided license_choice
  - Private/internal dependency detection with all heuristic categories
  - Opportunistic vulnerability checking
  - Finding consolidation and presentation

### AC4: Full compatibility matrix preserved

- **Given** the extracted phase file
- **When** Step 3.3 is reviewed
- **Then** the complete 12-row x 7-column compatibility matrix is present with all entries (MIT, ISC, BSD-2, BSD-3, Apache-2.0, LGPL-2.1, LGPL-3.0, MPL-2.0, GPL-2.0, GPL-3.0, AGPL-3.0, Unlicense/CC0, Unknown) checked against all project licenses

### AC5: All ecosystem detection preserved

- **Given** the extracted phase file
- **When** Step 3.1 is reviewed
- **Then** manifest and lock file glob patterns are present for all 10 ecosystems:
  - Node.js (npm/yarn/pnpm): package.json, package-lock.json, yarn.lock, pnpm-lock.yaml
  - Python: requirements.txt, requirements/*.txt, Pipfile, pyproject.toml, Pipfile.lock, poetry.lock
  - Rust: Cargo.toml, Cargo.lock
  - Go: go.mod, go.sum
  - Ruby: Gemfile, Gemfile.lock
  - Java/Maven/Gradle: pom.xml, build.gradle, build.gradle.kts
  - PHP: composer.json, composer.lock
  - .NET: *.csproj, *.fsproj, packages.config
  - Elixir: mix.exs, mix.lock
  - Swift: Package.swift, Package.resolved

### AC6: Private dependency detection preserved

- **Given** the extracted phase file
- **When** Step 3.4 is reviewed
- **Then** all 4 detection heuristic categories are present:
  - Scoped packages on private registries (Node.js .npmrc/.yarnrc inspection)
  - Local path references (file: protocol, path deps in Cargo.toml, pyproject.toml, go.mod replace)
  - Private git repository references (git+ssh://, git@github.com, embedded auth tokens)
  - Private registry configurations (.npmrc, .yarnrc.yml, pip.conf, Cargo config)

### AC7: License compatibility uses provided input

- **Given** the extracted phase file
- **When** Step 3.3 is reviewed
- **Then** it references the license_choice input (from Step 3.0 or state) as the project license for compatibility checking, NOT "Phase 0" or "detected in Phase 0" or any assumption about Phase 5

### AC8: User gate documented

- **Given** the extracted phase file
- **When** the user gate section is reviewed
- **Then** it contains the Phase 3-specific approval prompt with 4 options:
  - Approve and continue (to Phase 4)
  - Review details (full dependency inventory and findings)
  - Request changes (re-analyze ecosystems or adjust)
  - Skip

### AC9: I/O declaration

- **Given** the extracted phase file
- **When** checked against extraction rules
- **Then** it declares:
  - **Inputs**: project_root, project_profile, state (from Phases 0-2), license_choice (from orchestrator pre-check or state)
  - **Outputs**: dependency inventory tables (per-ecosystem), findings list (D3-1 through D3-N), finding counts by severity, state update (phase: 4, cumulative findings from Phases 1+2+3, phases_completed adds 3, license_choice)

### AC10: Validation

- **Given** the completed phase file
- **When** checked against all 5 extraction rules from CLAUDE.md
- **Then** it satisfies each rule:
  1. Self-contained: all steps, compatibility matrix, detection heuristics, and presentation formats are inline
  2. Declares I/O: Inputs and Outputs sections present in header
  3. References shared patterns: N/A for Phase 3 (no secret/PII pattern references needed)
  4. Includes user gate: 4-option approval prompt documented
  5. Starts with header block: phase number, name, inputs, outputs

## Test Definition

### Structural Tests

- File exists at `phases/03-dependencies.md`
- Contains required sections: header block (with Phase, Name, Inputs, Outputs), Steps (3.0 through 3.8), Finding Format, User Gate
- Header block declares Phase: 3, Name: Dependency Audit
- Contains Step 3.0 -- License Context preamble (the bug fix)
- Step 3.0 documents the license selection menu with all 8 options (MIT, Apache-2.0, GPL-3.0, BSD-2-Clause, BSD-3-Clause, MPL-2.0, ISC, Unlicense)
- Step 3.0 documents orchestrator-side handling (not sub-agent interaction)
- Contains the full 12x7 compatibility matrix
- Contains manifest glob patterns for all 10 ecosystems
- Contains license extraction methods for Node.js, Python, Rust, Go, Ruby, PHP, Java/Gradle/.NET/Elixir/Swift
- Contains all 4 private dependency detection heuristic categories
- Contains vulnerability checking tool detection commands (npm, yarn, pip-audit, cargo-audit, bundle-audit)
- Contains the `D3-{N}` finding format template
- Contains 5 remediation options for license findings
- Does NOT reference `patterns/secrets.md` or `patterns/pii.md` (not needed for Phase 3)
- Header Inputs include `license_choice`

### Content Tests

- Build artifact skip list present (node_modules/, vendor/, .build/, _build/, target/, dist/)
- Graceful degradation rule documented for missing toolchains
- All severity levels for license findings documented (CRITICAL/HIGH/MEDIUM/LOW)
- Private dependency finding format includes: Package, Reference Type, Reference Value, Impact, Remediation
- Vulnerability checking classified as informational
- Phase summary format includes ecosystem breakdown, total dependencies, license extraction rate

## Files to Create/Modify

- `phases/03-dependencies.md` -- extracted Phase 3 content with license selection preamble (create)
