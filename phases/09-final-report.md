# Phase 9 — Final Readiness Report

- **Phase**: 9
- **Name**: Final Readiness Report
- **Inputs**: `state.project_root`, `state.prep_branch`, `state.project_profile` (language, framework), `state.phases_completed` (array of completed phase numbers), `state.phase_findings` (per-phase finding counts with severity breakdowns), `state.findings` (cumulative totals: total, critical, high, medium, low), `state.history_flattened` (boolean), `state.deferred_actions` (deferred findings with resolution status), `.oss-prep/phase-{1..8}-summary.json` files (per-phase structured findings with effort tags)
- **Outputs**: report file (`{project_root}/oss-prep-report-{YYYY-MM-DD}.md`), `state.readiness_rating` (Ready / Ready with Caveats / Not Ready), state update with `phases_completed: [0,1,2,3,4,5,6,7,8,9]`

---

## Purpose

Phase 9 is the culmination of the entire OSS Prep skill. It does **not** perform new scanning or make code changes. Instead, it synthesizes findings from all prior phases (0–8) into a single, comprehensive readiness report that gives the user full confidence — or clear warnings — about the repository's safety for public release.

Phase 9 is unique among phases in several ways:
1. It performs NO new scanning or code changes — it is purely a synthesis/aggregation phase.
2. It READS the most state of any phase: the full cumulative state with all per-phase finding counts, completed phases, history flattened flag, and all prior phase summaries.
3. It WRITES a file to disk (the report markdown file) using the Write tool.
4. It is the final phase of the standard audit and preparation workflow.
5. Its readiness rating logic determines the final verdict of the entire skill.

Phase 9 has six components:
1. Report file generation
2. Risk matrix table
3. Summary with readiness rating
4. Per-phase detail sections
5. Launch checklist
6. Final user-facing presentation

---

## Steps

### Step 9.1 — Report File Generation

Generate the report filename using the current date:

```bash
date +%Y-%m-%d
```

The report file is written to:
```
{project_root}/oss-prep-report-{YYYY-MM-DD}.md
```

Use the **Write tool** to create this file — do not just display it in the conversation. The file must be a complete, standalone markdown document that renders correctly outside of the conversation.

Begin the report with a header:

```markdown
# OSS Readiness Report — {repo name}

**Generated**: {YYYY-MM-DD}
**Project root**: {project_root}
**Preparation branch**: {prep_branch}
**Primary language**: {language}
**Framework**: {framework}

---
```

---

### Step 9.2 — Risk Matrix Table

The risk matrix is the centerpiece of the report. Build a markdown table with one row per finding from Phases 0–8.

**Columns**:

| Phase | Category | Severity | Effort | Finding | Status |
|-------|----------|----------|--------|---------|--------|
| {0–8} | {secrets, PII, license, dependency, code-quality, documentation, ci-cd, naming, history} | {critical, high, medium, low} | {Auto-fix, Quick fix, Decision needed, Deferred} | {one-line description of the finding} | {Resolved, Accepted, Outstanding} |

The **Effort** column is populated from the effort tag assigned to each finding in its source phase. For deferred findings, the Status reflects whether Phase 8 resolved them ("Resolved") or they remain outstanding.

**Status definitions**:
- **Resolved** — The skill remediated this finding during execution (e.g., removed a secret, added a LICENSE file, flattened history).
- **Accepted** — The user acknowledged this finding but chose not to fix it (e.g., declined a suggestion, skipped a phase).
- **Outstanding** — The finding remains unaddressed. No remediation was performed and the user did not explicitly accept it.

**Sorting**: Sort rows by severity (critical first, then high, medium, low), then by phase number within each severity level. The Effort column inherits the original effort tag from the source phase.

**If zero findings exist across all phases**, write:
```markdown
## Risk Matrix

No findings were recorded across any phase. The repository scan was clean.
```

### Data Source: Phase Summary Files

Read `.oss-prep/phase-{1..8}-summary.json` files for per-phase finding details including effort tags and deferred action status. These files are the **canonical source** for detailed finding data — they preserve accurate finding counts, effort tags, and deferred action status even after context compaction.

The Phase 9 sub-agent receives the summary file paths (not the file contents) from the orchestrator and reads them directly from disk. For each phase summary file:
1. Parse the JSON to extract the `findings` array.
2. For each finding, read `id`, `severity`, `effort`, `summary`, `file`, `line`, and `deferred_to`.
3. Use the `effort` field to populate the Effort column in the risk matrix.
4. For findings with `deferred_to` set, check `state.deferred_actions` to determine if they were resolved by Phase 8.

If a summary file is missing for a phase (e.g., the phase was skipped or the file failed to write), fall back to the aggregate counts from `state.phase_findings` for that phase and note "Detail unavailable" in the finding description.

### Deferred Action Status Reporting

For findings that were deferred to Phase 8 (`deferred_to: 8`):
- If `state.deferred_actions` shows the item with `status: "resolved"`: report as **Resolved** in the risk matrix.
- If `state.deferred_actions` shows the item without resolution: report as **Outstanding** in the risk matrix.
- If `state.history_flattened` is `true` and no deferred action status is recorded: assume resolved (the flatten eliminated all history-based findings).
- If `state.history_flattened` is `false`: report all deferred items as **Outstanding** — the history was not flattened, so history-based findings persist.

Cross-reference the summary file data with the cumulative STATE block and any per-phase summaries from the orchestrator context. When summary files and state disagree, prefer the summary file data (it has the full finding detail).

---

### Step 9.3 — Summary with Readiness Rating

After the risk matrix, add a summary section with the overall readiness rating.

**Readiness rating logic**:

| Rating | Criteria |
|--------|----------|
| **Ready** | Zero outstanding critical or high findings. Zero outstanding findings of any severity, or only accepted low-severity items remain. |
| **Ready with Caveats** | Zero outstanding critical findings, but some high or medium findings remain outstanding or accepted. |
| **Not Ready** | Any outstanding critical findings, OR history was not flattened AND secrets or PII were found in git history during Phases 1–2. |

**Format the summary as**:

```markdown
## Summary

**Overall Readiness**: {Ready / Ready with Caveats / Not Ready}

| Metric | Count |
|--------|-------|
| Total findings | {N} |
| Critical | {N} |
| High | {N} |
| Medium | {N} |
| Low | {N} |

| Status | Count |
|--------|-------|
| Resolved | {N} |
| Accepted | {N} |
| Outstanding | {N} |

{If "Ready with Caveats", list each caveat as a bullet point here.}
{If "Not Ready", list each outstanding critical finding or unflattened-history risk here.}
```

---

### Step 9.4 — Per-Phase Detail Sections

Each phase (0 through 8) gets its own section in the report. For each phase, include:

1. **What was checked** — A brief description of the phase's scope (1–2 sentences).
2. **What was found** — The number of findings and a brief description of the most notable ones. If zero findings, state "No issues found."
3. **What was remediated** — What actions were taken (files modified, entries added, configurations generated, etc.). If nothing was remediated, state "No remediation actions taken."
4. **What remains outstanding** — Findings that were not resolved or were accepted without remediation. If nothing remains, state "All findings resolved."
5. **Skipped phases** — If a phase was skipped, note it as skipped and include the reason if one was given by the user.

**Format each phase section as**:

```markdown
## Phase {N} — {Phase Name}

**Scope**: {what was checked}

**Findings**: {N} total ({breakdown by severity if any})

**Actions taken**:
- {action 1}
- {action 2}
- ...

**Outstanding**:
- {finding 1 — severity, description}
- ...

{Or: "All findings resolved." / "No issues found." / "Phase skipped{: reason}"}
```

Use the following phase names:
- Phase 0: Reconnaissance
- Phase 1: Secrets & Credentials Audit
- Phase 2: PII Audit
- Phase 3: Dependency Audit
- Phase 4: Code Architecture & Quality Review
- Phase 5: Documentation Generation
- Phase 6: GitHub Repository Setup & CI/CD
- Phase 7: Naming, Trademark & Identity Review
- Phase 8: History Flatten

---

### Step 9.5 — Launch Checklist

Add a launch checklist section at the end of the report. These are post-report manual steps for the user — the skill does **not** execute them.

```markdown
## Launch Checklist

The following steps are manual actions to complete after reviewing this report:

- [ ] Create GitHub repository (or confirm it exists)
- [ ] Push preparation branch to remote
- [ ] Set repository visibility to public
- [ ] Verify CI/CD pipeline runs successfully
- [ ] Add collaborators or teams
- [ ] Create initial release or tag
- [ ] Announce the project
```

---

### Step 9.6 — Final User-Facing Presentation

After writing the report file to disk, present a summary to the user **in the conversation**. The tone and content must match the readiness rating:

**If "Ready"**:
> Your repository is ready for public release. All findings have been resolved and no outstanding issues remain.
>
> Full report written to: `{project_root}/oss-prep-report-{YYYY-MM-DD}.md`

**If "Ready with Caveats"**:
> Your repository is ready for public release, with some caveats to be aware of:
> - {caveat 1}
> - {caveat 2}
> - ...
>
> These items are documented in the full report. Review them before publishing to ensure you're comfortable with the remaining risk.
>
> Full report written to: `{project_root}/oss-prep-report-{YYYY-MM-DD}.md`

**If "Not Ready"**:
> **Warning: Your repository is not yet ready for public release.**
>
> The following critical issues must be resolved before publishing:
> - {outstanding critical finding 1}
> - {outstanding critical finding 2}
> - ...
>
> Strongly recommend resolving these issues before making the repository public. Re-run the affected phases after remediation.
>
> Full report written to: `{project_root}/oss-prep-report-{YYYY-MM-DD}.md`

---

## Step 9.7 — Update STATE

After Phase 9 is complete, update the STATE block:

```
STATE:
  project_root: {absolute path}
  prep_branch: oss-prep/ready
  project_profile:
    language: {from Phase 0}
    framework: {from Phase 0}
    package_manager: {from Phase 0}
    build_system: {from Phase 0}
    test_framework: {from Phase 0}
  findings:
    total: {cumulative total from all phases}
    critical: {cumulative critical}
    high: {cumulative high}
    medium: {cumulative medium}
    low: {cumulative low}
  phases_completed: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  history_flattened: {true|false}
  readiness_rating: {Ready|Ready with Caveats|Not Ready}
```

The sub-agent adds 9 to `phases_completed` and sets `readiness_rating`, but does NOT set `phase` to a terminal value. After Phase 9 completes, control returns to the orchestrator, which may offer optional next steps. The orchestrator handles the final `phase` state transition based on whether the user continues to Phase 10 or stops.

---

## Finding Format

Phase 9 does not produce new findings. It aggregates and classifies all findings from Phases 0–8 into the risk matrix (Step 9.2) using three status labels:

- **Resolved** — The skill remediated this finding during execution (e.g., removed a secret, added a LICENSE file, flattened history).
- **Accepted** — The user acknowledged this finding but chose not to fix it (e.g., declined a suggestion, skipped a phase).
- **Outstanding** — The finding remains unaddressed. No remediation was performed and the user did not explicitly accept it.

Each finding row in the risk matrix uses the format:

| Phase | Category | Severity | Effort | Finding | Status |
|-------|----------|----------|--------|---------|--------|

Categories: secrets, PII, license, dependency, code-quality, documentation, ci-cd, naming, history.
Severities: critical, high, medium, low.
Effort tags: `[Auto-fix]`, `[Quick fix]`, `[Decision needed]`, `[Deferred -> Phase N]`. Effort tags are inherited from the source phase — they are not redefined in Phase 9. See SKILL.md for the canonical effort tag definitions.

### Effort Classification Note (Phase 9)

Phase 9 does not classify new findings. It inherits effort tags from prior phases. The Effort column in the risk matrix shows the original tag from the source phase. For deferred findings resolved by Phase 8, the effort tag remains as originally assigned (e.g., `Deferred`) while the Status column reflects the resolution.

---

## User Gate

### Phase Summary Template

Present the summary using this template:

```
### Phase 9 Summary — Final Readiness Report

### Category Summary (Per-Phase Rollup)

| Category | Status | Count | Top Severity | Effort |
|----------|--------|-------|-------------|--------|
| Secrets (Phase 1) | {Clean/Findings} | {N} | {CRITICAL/HIGH/MEDIUM/LOW/—} | {effort or —} |
| PII (Phase 2) | {Clean/Findings} | {N} | {severity or —} | {effort or —} |
| Dependencies (Phase 3) | {Clean/Findings} | {N} | {severity or —} | {effort or —} |
| Code Quality (Phase 4) | {Clean/Findings} | {N} | {severity or —} | {effort or —} |
| Documentation (Phase 5) | {Clean/Findings} | {N} | {severity or —} | {effort or —} |
| GitHub Setup (Phase 6) | {Clean/Findings} | {N} | {severity or —} | {effort or —} |
| Naming (Phase 7) | {Clean/Findings} | {N} | {severity or —} | {effort or —} |
| History (Phase 8) | {Clean/Findings} | {N} | {severity or —} | {effort or —} |

**Readiness rating**: {Ready / Ready with Caveats / Not Ready}
**Report file**: `{project_root}/oss-prep-report-{YYYY-MM-DD}.md`
**Total findings across all phases**: {N} ({critical} critical, {high} high, {medium} medium, {low} low)
**Resolved**: {N} | **Accepted**: {N} | **Outstanding**: {N}
**Deferred actions**: {N} total, {N} resolved by Phase 8, {N} outstanding

### Key Highlights
1. {Most important outcome — e.g., "Repository rated Ready — all findings resolved across 9 phases"}
2. {Second highlight — e.g., "Risk matrix contains 14 findings, all resolved"}
3. {Third highlight — e.g., "History flattened, secrets and PII eliminated from git history"}
{...up to 5 highlights}
```

> "Phase 9 (Final Readiness Report) complete. The OSS Prep process is finished."

After presenting the summary, the sub-agent returns its output to the orchestrator for final disposition.

**Orchestrator note:** The sub-agent generates the report file, computes the readiness rating, and returns the rating plus key summary to the orchestrator. The orchestrator then presents the appropriate message to the user and handles any post-Phase-9 decisions. The sub-agent does NOT present the final user-facing message directly — it returns the data needed for the orchestrator to do so.
