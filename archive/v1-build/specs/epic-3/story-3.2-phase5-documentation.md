---
id: "3.2"
epic: 3
title: "Phase 5 — Documentation Generation"
status: pending
source_prd: "tasks/prd-oss-prep.md"
priority: high
estimation: large
depends_on: ["1.2"]
---

# Story 3.2 — Phase 5 — Documentation Generation

## User Story
As a developer preparing to open-source a private repo, I want the tool to audit my existing documentation, generate missing standard files, and sanitize any internal references so that the repository presents a complete, professional, contributor-friendly documentation suite from day one.

## Technical Context
This story adds the Phase 5 section to `SKILL.md`. Phase 5 is the most generative phase in the skill — it transitions from auditing (finding problems) to creating (producing documentation artifacts). This requires careful instructions around preserving existing content, presenting drafts for review, and never overwriting user work.

Key design decisions for this phase:

1. **Documentation completeness matrix** — FR-26 requires checking seven files: README.md, LICENSE, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md, and CLAUDE.md. The instructions should first build a completeness matrix (exists? / empty? / has internal references?) before generating anything. This matrix is presented to the user as the initial Phase 5 summary.

2. **Existing-file preservation** — FR-28 and the PRD's AC-4.5 are emphatic: existing documentation files are preserved and enhanced, never overwritten. The SKILL.md instructions must define a three-tier approach: (a) if the file does not exist, generate a full draft; (b) if the file exists but is incomplete, suggest additions as clearly-marked enhancement blocks; (c) if the file exists and is complete, review it for internal references only. Enhancement suggestions are presented as diffs/additions, not replacements.

3. **README.md generation template** — FR-29 specifies required sections: project name/description, badges (build status, license, version), installation, usage, configuration, contributing reference, license reference. The instructions should tell Claude to infer content from the project profile gathered in Phase 0 (language, framework, package manager) and from code inspection (entry points, CLI commands from Phase 4). The generated README must be tailored, not generic boilerplate.

4. **CLAUDE.md sanitization** — FR-30 is specific to CLAUDE.md. If one exists, it likely contains internal development instructions that reference private infrastructure, internal tools, or team-specific conventions. The instructions should direct Claude to: keep all project-relevant development instructions (build commands, architecture notes, coding conventions), remove internal references (private API endpoints, internal tool names, employee names, internal URLs), and flag any ambiguous references for user review.

5. **License selection menu** — FR-31 and DD-3 define the license interaction. If no LICENSE file exists, the instructions must present a numbered menu: (1) MIT (default), (2) Apache-2.0, (3) GPL-3.0, (4) BSD-2-Clause, (5) BSD-3-Clause, (6) MPL-2.0, (7) ISC, (8) Unlicense. The user MUST explicitly confirm their choice — the skill must never auto-select a license. If a LICENSE file exists, verify it is a recognized OSS license and that the copyright holder name is appropriate for public release (not an internal team name or corporate entity the user wants to anonymize).

6. **Sub-agent parallelization** — Multiple documentation files can be drafted simultaneously. The instructions should direct Claude to spawn parallel sub-agents (via Task tool, `model: "opus"`) for: README.md generation, CONTRIBUTING.md generation, CODE_OF_CONDUCT.md generation, and SECURITY.md generation. LICENSE requires user interaction (menu selection) and runs in the main thread. CHANGELOG.md generation may depend on git history analysis and runs after license selection. CLAUDE.md sanitization runs as a separate sub-agent if the file exists.

7. **User review gate** — FR-27 requires all generated content to be presented for user review before writing. The instructions should define a review loop: present each generated/enhanced file's content, ask the user to approve, request edits, or reject. Only approved content is written to disk.

## Acceptance Criteria

### AC1: Documentation Completeness Matrix Is Generated
- **Given** Phase 5 is reached on any repository
- **When** the phase begins execution
- **Then** it produces a completeness matrix showing the status of all seven documentation files (README.md, LICENSE, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md, CLAUDE.md) with columns for: exists (yes/no), has content (yes/no/partial), and contains internal references (yes/no/not checked)

### AC2: Missing Files Are Generated with Project-Tailored Content
- **Given** Phase 5 is reached on a repository missing CONTRIBUTING.md, CODE_OF_CONDUCT.md, and SECURITY.md
- **When** the documentation generation sub-agents execute
- **Then** each missing file is drafted with content tailored to the project's language, framework, and structure (e.g., CONTRIBUTING.md references the project's actual build and test commands), and each draft is presented to the user for review before writing

### AC3: Existing Files Are Enhanced Without Overwriting
- **Given** Phase 5 is reached on a repository with an existing but incomplete README.md (e.g., missing installation or usage sections)
- **When** the README enhancement logic executes
- **Then** it suggests specific additions (new sections, expanded content) presented as clearly-marked enhancement blocks rather than replacing the entire file, and the user is asked to approve each suggestion before it is applied

### AC4: README.md Includes All Required Sections
- **Given** Phase 5 generates a new README.md (or enhances an existing one)
- **When** the README content is produced
- **Then** it includes sections for: project name and description, badges (build status, license, version), installation instructions appropriate to the detected package manager, usage examples, configuration, a reference to CONTRIBUTING.md, and a reference to the LICENSE file

### AC5: CLAUDE.md Is Sanitized While Preserving Development Instructions
- **Given** Phase 5 is reached on a repository with an existing CLAUDE.md containing internal references (e.g., "Deploy to staging.internal.acme.com", "Ask @dave in #platform-team on Slack")
- **When** the CLAUDE.md sanitization sub-agent executes
- **Then** it preserves project-relevant development instructions (build commands, architecture notes, coding conventions), removes or redacts internal references (private endpoints, internal tool names, employee names, Slack channels), flags ambiguous references for user review, and presents the sanitized version for approval before writing

### AC6: License Selection Menu Requires Explicit User Confirmation
- **Given** Phase 5 is reached on a repository with no LICENSE file
- **When** the license selection step executes
- **Then** it presents a numbered menu of license options (MIT as default, Apache-2.0, GPL-3.0, BSD-2-Clause, BSD-3-Clause, MPL-2.0, ISC, Unlicense), waits for the user to explicitly select and confirm a license, and only then generates the LICENSE file with the correct full license text and appropriate copyright holder information

### AC7: All Generated Content Requires User Review Before Writing
- **Given** Phase 5 has generated or enhanced one or more documentation files
- **When** the generated content is ready
- **Then** each file's content is presented to the user for review, and the file is only written to disk after the user explicitly approves it, with the option to request edits or reject the draft

## Test Definition

### Unit Tests
- Read `SKILL.md` and verify the Phase 5 section exists with references to FR-26 through FR-31
- Verify the section defines the documentation completeness matrix with all seven files listed
- Verify the section contains the existing-file preservation rule (enhance, never overwrite)
- Verify the README template includes all required sections (name, badges, install, usage, config, contributing ref, license ref)
- Verify the CLAUDE.md sanitization instructions distinguish between project-relevant and internal content
- Verify the license selection menu lists all eight license options with MIT as the default
- Verify the section instructs sub-agent parallelization for independent documentation generation tasks
- Verify the section requires user review and approval before writing any generated file

### Integration/E2E Tests (if applicable)
- Run `/oss-prep` on a repository with no documentation files at all and verify Phase 5 generates drafts for README.md, LICENSE (after menu selection), CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, and CHANGELOG.md, presenting each for review
- Run `/oss-prep` on a repository with an existing README.md missing a "Usage" section and verify Phase 5 suggests adding the section without replacing the existing content
- Run `/oss-prep` on a repository with a CLAUDE.md containing `internal.company.com` URLs and verify Phase 5 flags and removes them while preserving build instructions
- Run `/oss-prep` on a repository with an existing MIT LICENSE file and verify Phase 5 validates it as a recognized OSS license and checks the copyright holder name

## Files to Create/Modify
- `skills/oss-prep/SKILL.md` — Add Phase 5 section covering documentation completeness check, file generation with project-tailored content, existing-file enhancement rules, README template, CLAUDE.md sanitization, license selection menu, sub-agent parallelization, and user review gates (modify)
