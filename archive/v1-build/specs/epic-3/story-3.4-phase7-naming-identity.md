---
id: "3.4"
epic: 3
title: "Phase 7 — Naming, Trademark & Identity Review"
status: pending
source_prd: "tasks/prd-oss-prep.md"
priority: medium
estimation: medium
depends_on: ["1.2"]
---

# Story 3.4 — Phase 7 — Naming, Trademark & Identity Review

## User Story
As a developer preparing to open-source a private repo, I want the tool to verify my project name is available on package registries, scan for internal identity leaks, and detect telemetry/analytics code so that the public repository has no naming conflicts, no internal company references, and full transparency about any data collection.

## Technical Context
This story adds the Phase 7 section to `SKILL.md`. Phase 7 is the last analysis phase before the destructive operations in Phase 8 (history flatten). It focuses on identity — making sure the public-facing project does not inadvertently expose its private origins or conflict with existing public projects.

Key design decisions for this phase:

1. **Package name availability checking** — FR-37 requires checking name availability on relevant registries. The instructions should direct Claude to: (a) inspect the package manifest to determine the project's published name (e.g., `name` field in `package.json`, `[package].name` in `Cargo.toml`, `[project].name` in `pyproject.toml`), (b) determine which registry to check based on manifest type (npm for package.json, PyPI for pyproject.toml/setup.py, crates.io for Cargo.toml, RubyGems for Gemfile/.gemspec, Go modules registry for go.mod), (c) use WebSearch to query the registry for name conflicts (e.g., search "npmjs.com package {name}", "pypi.org project {name}"). If no package manifest exists, check the repository/directory name against major registries. Results are best-effort — network failures degrade gracefully with "Could not verify availability" rather than blocking.

2. **Internal identity leak scanning** — FR-38 defines specific categories to scan for: company names, team names, internal tool names, internal URLs (patterns like `*.internal.company.com`, `*.corp.company.com`, `*.local`, intranet URLs), Jira/Confluence links (patterns like `jira.company.com/browse/PROJ-123`, `confluence.company.com/display/`), and Slack channel references (patterns like `#team-channel`, `slack.com/archives/`). The instructions should direct Claude to use Grep with targeted patterns across the entire working tree, excluding binary files and node_modules/vendor directories. Findings are classified: CRITICAL for URLs that would expose internal infrastructure, HIGH for company/team names in code comments, MEDIUM for references in documentation (which may be intentional).

3. **Telemetry and analytics detection** — FR-39 requires detecting phone-home code. The instructions should define two tiers of detection: (a) known SDK detection — search for imports/requires of known analytics libraries (Segment, Mixpanel, Amplitude, Google Analytics, Heap, PostHog, Matomo, LaunchDarkly, Datadog RUM, Sentry), including their npm package names, Python module names, and common import patterns; (b) custom telemetry indicators — search for patterns suggesting custom tracking: HTTP calls to hardcoded non-public URLs, fetch/axios/requests calls with internal-looking endpoints, event tracking function definitions (e.g., `trackEvent`, `sendAnalytics`, `reportUsage`). Known SDK detection is HIGH confidence; custom telemetry detection is MEDIUM confidence (higher false-positive rate). The instructions should note that telemetry is not necessarily bad — the remediation is disclosure (add a "Telemetry" section to README) or removal, per the user's choice.

4. **Remediation suggestions** — FR-40 requires four categories of remediation: (a) rename project (if name conflicts exist on registries), (b) remove internal references (for identity leaks — provide the specific file, line, and suggested replacement), (c) add telemetry disclosure (suggest a README section documenting what data is collected and how to opt out), (d) acknowledge (for findings the user reviews and decides are acceptable). Each finding should be presented with a concrete remediation suggestion, not just a flag.

5. **Severity classification** — Name conflicts are MEDIUM (informational — the user may not intend to publish to that registry). Internal URL leaks are CRITICAL (they expose infrastructure). Company/team name references are HIGH. Telemetry findings are HIGH (they require disclosure or removal). Slack/Jira references are MEDIUM (they leak internal processes but not infrastructure).

6. **No sub-agent parallelization needed** — Unlike Phases 4 and 5, Phase 7's analysis streams are lightweight and sequential. The name availability check uses WebSearch (which has rate considerations), identity scanning uses Grep (fast), and telemetry detection uses Grep (fast). Running these sequentially in the main thread is simpler and avoids unnecessary sub-agent overhead.

## Acceptance Criteria

### AC1: Package Name Availability Is Checked on Relevant Registries
- **Given** Phase 7 is reached on a repository with a `package.json` containing `"name": "my-cool-lib"`
- **When** the name availability check executes
- **Then** it uses WebSearch to check if `my-cool-lib` exists on npm, reports whether the name is available or taken, and if taken, suggests considering a rename with the finding classified as MEDIUM severity

### AC2: Registry Selection Matches Detected Package Manifests
- **Given** Phase 7 is reached on a repository with both `pyproject.toml` and `package.json` (e.g., a full-stack project)
- **When** the name availability check executes
- **Then** it checks both PyPI (for the Python package name) and npm (for the Node.js package name), reporting availability for each registry separately

### AC3: Internal Identity Leaks Are Detected and Classified
- **Given** Phase 7 is reached on a repository containing: a code comment "// Deployed on staging.internal.acme.com", a README reference to "the Acme Platform Team", and a config file with `jira_url: "https://acme.atlassian.net/browse/PLAT-"`
- **When** the identity leak scan executes
- **Then** it reports all three findings with: file path and line number, the matched content, severity classification (CRITICAL for the internal URL, HIGH for the team name, MEDIUM for the Jira reference), and a specific remediation suggestion for each (remove URL, generalize team name, remove Jira reference)

### AC4: Telemetry and Analytics Code Is Detected
- **Given** Phase 7 is reached on a repository with `import Analytics from '@segment/analytics-next'` in a source file and a custom `trackEvent()` function definition
- **When** the telemetry detection scan executes
- **Then** it reports both findings: the Segment SDK import as HIGH severity (known analytics SDK), the custom trackEvent function as MEDIUM severity (potential custom telemetry), and suggests remediation options: add a "Telemetry" disclosure section to README, or remove the tracking code

### AC5: Graceful Degradation When WebSearch Fails
- **Given** Phase 7 is reached on a repository with a `package.json`
- **When** the WebSearch for npm name availability fails or returns inconclusive results
- **Then** the finding is recorded as "Could not verify name availability on npm — manual check recommended" with MEDIUM severity, and the phase continues without blocking

### AC6: Phase Summary Presents Findings with Remediation Options
- **Given** all Phase 7 analysis has completed with findings across naming, identity, and telemetry categories
- **When** the phase presents its summary to the user
- **Then** it shows: findings grouped by category (naming, identity leaks, telemetry), each with severity and specific remediation suggestion, total finding counts by severity, and waits for user approval before proceeding to Phase 8, following the phase-gating interaction model

## Test Definition

### Unit Tests
- Read `SKILL.md` and verify the Phase 7 section exists with references to FR-37 through FR-40
- Verify the section maps package manifest types to their corresponding registries (package.json to npm, pyproject.toml to PyPI, Cargo.toml to crates.io)
- Verify the section defines internal identity leak patterns (internal URLs, Jira/Confluence links, Slack references, company/team names)
- Verify the section lists known analytics SDKs to detect (Segment, Mixpanel, Amplitude, Google Analytics, and others)
- Verify the section defines custom telemetry detection patterns (trackEvent, sendAnalytics, hardcoded non-public URLs)
- Verify the section specifies four remediation categories (rename, remove, disclose, acknowledge)
- Verify the section specifies graceful degradation for WebSearch failures

### Integration/E2E Tests (if applicable)
- Run `/oss-prep` on a Node.js repository with a common npm package name and verify Phase 7 reports name availability status from WebSearch
- Run `/oss-prep` on a repository with `*.internal.company.com` URLs in config files and verify Phase 7 flags them as CRITICAL identity leaks with file paths and line numbers
- Run `/oss-prep` on a repository with Mixpanel SDK imports and verify Phase 7 detects and reports the telemetry finding with disclosure/removal remediation options
- Run `/oss-prep` on a repository with no package manifest and verify Phase 7 checks the directory name against registries and handles the absence gracefully

## Files to Create/Modify
- `skills/oss-prep/SKILL.md` — Add Phase 7 section covering package name availability checking, internal identity leak scanning, telemetry/analytics detection, and remediation suggestions with severity classification (modify)
