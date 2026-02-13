---
id: "1.1"
epic: 1
title: "SKILL.md Skeleton with Frontmatter, State Tracking & Phase Orchestration"
status: pending
source_prd: "tasks/prd-oss-prep.md"
priority: critical
estimation: medium
depends_on: []
---

# Story 1.1 — SKILL.md Skeleton with Frontmatter, State Tracking & Phase Orchestration

## User Story
As a developer invoking `/oss-prep`, I want the skill to have a well-defined skeleton with state tracking, phase gating, and sub-agent orchestration so that every subsequent phase can be added incrementally without rearchitecting the skill.

## Technical Context
This story creates the foundational `SKILL.md` file for the oss-prep skill. Since this is a Claude Code skill (not executable code), the "implementation" is writing instructional markdown that tells Claude how to behave when the skill is invoked. The file must include:

1. **Frontmatter block** — Standard Claude Code skill metadata (`name`, `description`, `user_invocable`, `argument_hint`) so the skill appears as `/oss-prep` in the command palette.
2. **State tracking block definition** — A restateable STATE block format (similar to the changelog skill pattern) that survives autocompaction. The block must capture: current phase (0-9), project root path, preparation branch name, project profile summary, cumulative findings by severity, list of completed phases, and history-flattened flag.
3. **Phase-gating interaction model** — Instructions defining the loop: enter phase, execute analysis, present summary (counts by severity, key highlights), wait for user approval gate before advancing. This section also defines progressive disclosure: summaries show counts only, details available on request, final report contains everything.
4. **Sub-agent strategy section** — Instructions that all sub-agents spawned via the Task tool MUST use `model: "opus"`. Defines when parallelization is appropriate (within-phase independent work streams) and when it is not (cross-phase dependencies).
5. **Grounding requirement** — An explicit instruction that every finding must reference actual code artifacts (file paths, line numbers, commit hashes, grep matches). The skill must NEVER fabricate or hallucinate findings. If a pattern search returns no results, report zero findings — do not invent plausible-sounding ones.
6. **Phase table of contents** — A numbered list of all 10 phases (0-9) with one-line descriptions, serving as a roadmap. Individual phase sections will be added by subsequent stories.

The file structure should place the state tracking and orchestration instructions at the top (so they are read first and set behavioral expectations), followed by the phase TOC, followed by placeholder markers where each phase section will be inserted.

## Acceptance Criteria

### AC1: Skill Frontmatter Is Valid and Discoverable
- **Given** the SKILL.md file is created at `skills/oss-prep/SKILL.md`
- **When** Claude Code loads the skill directory
- **Then** the frontmatter contains `name: oss-prep`, a description referencing open-source preparation, `user_invocable: true`, and `argument_hint` with usage guidance (e.g., "Run from the root of any git repository")

### AC2: State Block Definition Covers All Required Fields
- **Given** the skill is read by Claude Code
- **When** it reaches the state tracking section
- **Then** the STATE block template includes all seven fields: `phase` (0-9), `project_root` (absolute path), `prep_branch` (branch name), `project_profile` (language, framework, package_manager, build_system, test_framework), `findings` (total, critical, high, medium, low counts), `phases_completed` (list), and `history_flattened` (boolean), with clear instructions to restate this block after every phase transition to survive autocompaction

### AC3: Phase-Gating Interaction Model Is Defined
- **Given** the skill is executing a phase
- **When** the phase completes its analysis
- **Then** the instructions require: (a) presenting a summary with finding counts by severity and key highlights, (b) asking the user to approve, review details, request changes, or skip, (c) not advancing to the next phase until the user responds, and (d) supporting progressive disclosure where detailed findings are shown only on request

### AC4: Sub-Agent Strategy Enforces Opus Model
- **Given** the skill needs to spawn sub-agents via the Task tool
- **When** Claude reads the sub-agent strategy section
- **Then** it finds explicit instructions that all Task tool invocations MUST use `model: "opus"`, with guidance on when to parallelize (independent work within a phase) and when to run sequentially (cross-phase dependencies)

### AC5: Grounding Requirement Prevents Hallucinated Findings
- **Given** the skill is performing any audit phase
- **When** Claude generates findings
- **Then** the grounding requirement section explicitly states that every finding must include concrete references (file paths, line numbers, commit hashes, or tool output) and that reporting zero findings is always preferable to fabricating plausible-sounding ones

## Test Definition

### Unit Tests
- Read the created `skills/oss-prep/SKILL.md` and verify the frontmatter parses correctly with all required fields (`name`, `description`, `user_invocable`, `argument_hint`)
- Verify the STATE block template contains all seven required fields with example values
- Verify the phase-gating section includes the four required behaviors (summary, approval gate, no auto-advance, progressive disclosure)
- Verify the sub-agent section mentions `model: "opus"` explicitly
- Verify the grounding section contains anti-hallucination language

### Integration/E2E Tests (if applicable)
- Invoke `/oss-prep` from a test git repository and verify the skill activates, displays the phase roadmap, and initializes the STATE block with phase 0 and empty findings
- Verify that the skill does not attempt to execute any phase content yet (since phases are not implemented in this story), but instead indicates that Phase 0 is the next step

## Files to Create/Modify
- `skills/oss-prep/SKILL.md` — Create the initial skill file with frontmatter, state tracking block definition, phase-gating model, sub-agent strategy, grounding requirement, and phase table of contents with placeholder markers for each phase (create)
