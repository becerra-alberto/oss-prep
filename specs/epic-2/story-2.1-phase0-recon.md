---
id: "2.1"
epic: 2
title: "Extract Phase 0: Reconnaissance to phases/00-recon.md"
status: done
source_prd: "tasks/prd-oss-prep-v2.md"
priority: critical
estimation: medium
depends_on: ["1.1"]
---

# Story 2.1 — Extract Phase 0: Reconnaissance to phases/00-recon.md

## User Story

As a developer preparing a repo for open-source release, I want the reconnaissance phase extracted into a self-contained file so that a sub-agent can execute project detection, branch creation, and profile building without loading the entire 3,484-line monolith into context.

## Technical Context

Phase 0 content lives between the `<!-- PHASE_0_START -->` and `<!-- PHASE_0_END -->` markers in SKILL.md (approximately lines 154-379). It contains 6 steps:

- **Step 0.1 -- Detect Project Root**: `git rev-parse --show-toplevel`, submodule detection, working directory setup.
- **Step 0.2 -- Preparation Branch Management**: Check for existing `oss-prep/ready` branch, offer resume/reset, create and checkout new branch.
- **Step 0.3 -- Build Project Profile**: Language detection (file extension counting via `git ls-files`), framework detection (manifest inspection), package manager detection, build system detection, test framework detection, metrics gathering, CI/CD detection. Each sub-category has detailed detection heuristics with specific file patterns and config keys.
- **Step 0.4 -- Anomaly Detection**: Submodule enumeration, large binary files (>1MB), symlinks, non-standard permissions.
- **Step 0.5 -- Present Profile and Confirm**: Formatted profile table, anomaly report, user confirmation gate with Confirm/Correct/Add context options.
- **Step 0.6 -- Update STATE and Complete Phase**: STATE block initialization with all fields populated, phase completion announcement.

The extracted phase file must be fully self-contained -- a sub-agent reading only `phases/00-recon.md` must be able to execute all 6 steps without any other file. Phase 0 does not reference `patterns/secrets.md` or `patterns/pii.md` (those are Phase 1/2 concerns).

Phase 0 is unique in that it initializes state rather than reading it. Its only input is the git repository itself. Its outputs are the most foundational artifacts: the prep branch, the project profile, and the initial state.

The user gate for Phase 0 is the profile confirmation prompt (Step 0.5), which differs from the standard 4-option gate used in later phases -- it offers Confirm/Correct/Add context instead. Per DD-4, the sub-agent does NOT present this gate; it returns the profile and the orchestrator presents the gate.

## Acceptance Criteria

### AC1: Phase file structure

- **Given** the current SKILL.md with Phase 0 content between `<!-- PHASE_0_START -->` and `<!-- PHASE_0_END -->`
- **When** the phase is extracted to `phases/00-recon.md`
- **Then** the file starts with a header block containing:
  - Phase: 0
  - Name: Reconnaissance
  - Inputs: git repository (working directory)
  - Outputs: project_profile (all fields), prep_branch name, initial state, anomaly report

### AC2: Self-contained execution steps

- **Given** a sub-agent that reads only `phases/00-recon.md`
- **When** it executes the phase
- **Then** it can perform all 6 steps (0.1 through 0.6) without referencing any other file, including:
  - Project root detection with submodule check
  - Branch creation/resume logic
  - Full project profile building (languages, frameworks, package managers, build systems, test frameworks, metrics, CI/CD)
  - Anomaly detection (submodules, large files, symlinks, permissions)
  - Profile presentation format
  - State initialization

### AC3: All detection heuristics preserved

- **Given** the extracted phase file
- **When** compared against the SKILL.md Phase 0 content
- **Then** every detection heuristic is preserved verbatim:
  - All 14 language extension mappings (.py, .js, .jsx, .ts, .tsx, .rs, .go, .rb, .java, .c, .h, .cpp, .hpp, .cs, .swift, .kt, .php, .sh)
  - All framework detection rules per ecosystem (JS/TS, Python, Ruby, Rust, Go, Java/Kotlin, PHP)
  - All package manager detection rules (11 entries with manifest + lock file combinations)
  - All build system detection rules (9 entries)
  - All test framework detection rules (10+ entries)
  - All CI/CD detection rules (8 entries)
  - All anomaly detection commands (submodules, large files, symlinks, permissions)

### AC4: User gate documented

- **Given** the extracted phase file
- **When** the user gate section is reviewed
- **Then** it contains the Phase 0-specific confirmation prompt:
  - "Does this profile look accurate? You can: Confirm / Correct / Add context"
  - With a note that the orchestrator presents this gate after the sub-agent returns (per DD-4)

### AC5: I/O declaration

- **Given** the extracted phase file
- **When** checked against extraction rules
- **Then** it declares:
  - **Inputs**: git repository (working directory), no prior state required
  - **Outputs**: project_profile (language, framework, package_manager, build_system, test_framework), prep_branch, anomaly report, initial STATE block with all fields populated, finding counts initialized to 0, phases_completed set to [0], history_flattened set to false

### AC6: Validation

- **Given** the completed phase file
- **When** checked against all 5 extraction rules from CLAUDE.md
- **Then** it satisfies each rule:
  1. Self-contained: all steps, detection heuristics, and output formats are inline
  2. Declares I/O: Inputs and Outputs sections present in header
  3. References shared patterns: N/A for Phase 0 (no pattern references needed)
  4. Includes user gate: profile confirmation prompt documented
  5. Starts with header block: phase number, name, inputs, outputs

## Test Definition

### Structural Tests

- File exists at `phases/00-recon.md`
- Contains required sections: header block (with Phase, Name, Inputs, Outputs), Steps (0.1 through 0.6), Finding Format (anomaly presentation), User Gate
- Header block declares Phase: 0, Name: Reconnaissance
- Contains `git rev-parse --show-toplevel` command (Step 0.1)
- Contains `git checkout -b oss-prep/ready` command (Step 0.2)
- Contains `git ls-files` command for language detection (Step 0.3)
- Contains large file detection command with 1MB threshold (Step 0.4)
- Contains the profile presentation table format (Step 0.5)
- Contains STATE block initialization template (Step 0.6)
- Does NOT contain inline regex patterns from Phase 1 or Phase 2
- Does NOT reference `patterns/secrets.md` or `patterns/pii.md` (not needed for Phase 0)

### Content Tests

- All 14+ language extension mappings are present
- All framework detection rules per ecosystem are present
- All 11 package manager detection entries are present
- All build system detection entries are present
- All test framework detection entries are present
- All CI/CD detection entries are present
- Anomaly detection covers: submodules, large files (>1MB), symlinks, non-standard permissions

## Files to Create/Modify

- `phases/00-recon.md` -- extracted Phase 0 content (create)
