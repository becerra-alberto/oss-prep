# Phase 9 — Final Readiness Report

- **Phase**: 9
- **Name**: Final Readiness Report
- **Inputs**: `state.project_root`, `state.prep_branch`, `state.project_profile` (language, framework), `state.phases_completed` (array of completed phase numbers), `state.phase_findings` (per-phase finding counts with severity breakdowns), `state.findings` (cumulative totals: total, critical, high, medium, low), `state.history_flattened` (boolean), per-phase summaries from orchestrator context
- **Outputs**: report file (`{project_root}/oss-prep-report-{YYYY-MM-DD}.md`), `state.readiness_rating` (Ready / Ready with Caveats / Not Ready), terminal state update with `phases_completed: [0,1,2,3,4,5,6,7,8,9]`

---

## Purpose

Phase 9 is the culmination of the entire OSS Prep skill. It does **not** perform new scanning or make code changes. Instead, it synthesizes findings from all prior phases (0–8) into a single, comprehensive readiness report that gives the user full confidence — or clear warnings — about the repository's safety for public release.

Phase 9 is unique among phases in several ways:
1. It performs NO new scanning or code changes — it is purely a synthesis/aggregation phase.
2. It READS the most state of any phase: the full cumulative state with all per-phase finding counts, completed phases, history flattened flag, and all prior phase summaries.
3. It WRITES a file to disk (the report markdown file) using the Write tool.
4. It is the TERMINAL phase — no further phases follow.
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

| Phase | Category | Severity | Finding | Status |
|-------|----------|----------|---------|--------|
| {0–8} | {secrets, PII, license, dependency, code-quality, documentation, ci-cd, naming, history} | {critical, high, medium, low} | {one-line description of the finding} | {Resolved, Accepted, Outstanding} |

**Status definitions**:
- **Resolved** — The skill remediated this finding during execution (e.g., removed a secret, added a LICENSE file, flattened history).
- **Accepted** — The user acknowledged this finding but chose not to fix it (e.g., declined a suggestion, skipped a phase).
- **Outstanding** — The finding remains unaddressed. No remediation was performed and the user did not explicitly accept it.

**Sorting**: Sort rows by severity (critical first, then high, medium, low), then by phase number within each severity level.

**If zero findings exist across all phases**, write:
```markdown
## Risk Matrix

No findings were recorded across any phase. The repository scan was clean.
```

Gather all findings from the cumulative STATE block and from the per-phase summaries presented during the session. Cross-reference what was remediated, what the user accepted, and what remains open.

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

## Step 9.7 — Update STATE (Terminal)

After Phase 9 is complete, update the STATE block to its terminal state:

```
STATE:
  phase: 9
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

This is the **terminal state** of the skill. Phase 9 is the final phase — there is no Phase 10.

---

## Finding Format

Phase 9 does not produce new findings. It aggregates and classifies all findings from Phases 0–8 into the risk matrix (Step 9.2) using three status labels:

- **Resolved** — The skill remediated this finding during execution (e.g., removed a secret, added a LICENSE file, flattened history).
- **Accepted** — The user acknowledged this finding but chose not to fix it (e.g., declined a suggestion, skipped a phase).
- **Outstanding** — The finding remains unaddressed. No remediation was performed and the user did not explicitly accept it.

Each finding row in the risk matrix uses the format:

| Phase | Category | Severity | Finding | Status |
|-------|----------|----------|---------|--------|

Categories: secrets, PII, license, dependency, code-quality, documentation, ci-cd, naming, history.
Severities: critical, high, medium, low.

---

## User Gate

### Phase Summary Template

Present the summary using this template:

```
### Phase 9 Summary — Final Readiness Report

**Readiness rating**: {Ready / Ready with Caveats / Not Ready}
**Report file**: `{project_root}/oss-prep-report-{YYYY-MM-DD}.md`
**Total findings across all phases**: {N} ({critical} critical, {high} high, {medium} medium, {low} low)
**Resolved**: {N} | **Accepted**: {N} | **Outstanding**: {N}

### Key Highlights
1. {Most important outcome — e.g., "Repository rated Ready — all findings resolved across 9 phases"}
2. {Second highlight — e.g., "Risk matrix contains 14 findings, all resolved"}
3. {Third highlight — e.g., "History flattened, secrets and PII eliminated from git history"}
{...up to 5 highlights}
```

> "Phase 9 (Final Readiness Report) complete. The OSS Prep process is finished."

**This is the final phase. No further phases or user approval gates follow.**

**Orchestrator note:** The sub-agent generates the report file, computes the readiness rating, and returns the rating plus key summary to the orchestrator. The orchestrator then presents the appropriate final message (from Step 9.6) to the user based on the rating. The sub-agent does NOT present the final user-facing message directly — it returns the data needed for the orchestrator to do so.
