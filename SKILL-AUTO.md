---
name: oss-prep-auto
description: "Run the full oss-prep pipeline autonomously — no user gates, deterministic decisions, risk-aware phase emphasis, scored readiness summary."
user-invocable: true
argument-hint: "Run from the root of any git repository you want to prepare for open-source release (fully automatic)"
---

Full-auto orchestrator for `/oss-prep-auto`. Runs all 10 phases plus remediation passes without user interaction. Phase logic lives in `phases/00-recon.md` through `phases/09-final-report.md` (same files as interactive mode). This file manages state, sequencing, autonomous decisions, risk assessment, sub-agent dispatch with emphasis injection, scoring, and the HITL summary.

---

## Startup Validation (with ADP Auto-Resolves)

Run these checks in order. Unlike interactive mode, certain gates auto-resolve per the Autonomous Decision Protocol.

1. **Git repository**: Run `git rev-parse --is-inside-work-tree`. If it fails: ABORT. Print "This directory is not inside a git repository. Run `/oss-prep-auto` from the root of a git repo."
2. **Shallow clone**: Run `git rev-parse --is-shallow-repository`. If `true`: ABORT. Print "This is a shallow clone. History-based scans require full history. Run `git fetch --unshallow` first."
3. **Git version**: Run `git --version`, parse the version number. If < 2.20: ABORT. Print "Git version {version} is too old. oss-prep requires Git >= 2.20. Please upgrade."
4. **Uncommitted changes (ADP-1)**: Run `git status --porcelain`. If non-empty: run `git stash` automatically. Log decision to auto-decisions.json: `{ "adp": 1, "gate": "Uncommitted changes", "resolution": "git stash", "detail": "{stash ref}" }`.

## State Initialization

If `.oss-prep/state.json` exists:
- **ADP-2**: Always delete `.oss-prep/` directory and reinitialize (clean idempotent run). Log: `{ "adp": 2, "gate": "Resume vs Reset", "resolution": "Reset — clean idempotent run" }`.

Create `.oss-prep/` directory. Initialize state from `state-schema.json` defaults with:
- `started_at`: current ISO 8601 timestamp
- `project_root`: output of `git rev-parse --show-toplevel`
- `auto_mode`: `true`
- `auto_decisions_path`: `.oss-prep/auto-decisions.json`
- `auto_run_started_at`: current ISO 8601 timestamp

Write initial state using atomic write (tmp → validate → rename). Initialize `.oss-prep/auto-decisions.json` as an empty array `[]`.

## Preparation Branch

Check if `oss-prep/ready` branch exists:
- **If exists (ADP-4)**: Delete it (`git branch -D oss-prep/ready`) and recreate from HEAD. Log: `{ "adp": 4, "gate": "Existing prep branch", "resolution": "Delete + recreate from HEAD" }`.
- **If not**: Create it from HEAD.

Switch to the prep branch: `git checkout oss-prep/ready`.

---

## Phase 0: Reconnaissance

Dispatch sub-agent for Phase 0 using standard dispatch template (see Sub-Agent Dispatch below), with AUTO MODE INSTRUCTIONS injected.

After Phase 0 returns:
- **ADP-5**: Auto-confirm the detected project profile. Log: `{ "adp": 5, "gate": "Profile confirmation", "resolution": "Auto-confirmed detected profile" }`.
- **ADP-8**: Auto-approve Phase 0 gate. Log: `{ "adp": 8, "gate": "Phase 0 approval", "resolution": "Auto-approved" }`.
- Commit and update state per standard commit flow.

---

## Risk Assessment & Golden Path

This runs **inline in the orchestrator** (no sub-agent) immediately after Phase 0 completes. Read the project profile from state and inspect the file inventory to classify the project archetype.

### Archetype Classification

Evaluate these archetypes in order (highest-risk first). Assign the **first match**:

**1. Monorepo / Multi-Project** (`highest` risk)
- Signal: Multiple package manifests (`package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Gemfile`) in different subdirectories, OR workspace config files (`pnpm-workspace.yaml`, `lerna.json`, `nx.json`, `Cargo workspace`, `go.work`)
- Detection: `glob **/package.json`, `glob **/Cargo.toml`, etc. — if >=2 manifests in different directories, or any workspace config exists

**2. Infrastructure / DevOps** (`highest` risk)
- Signal: Terraform files (`.tf`), Ansible (`playbook*.yml`, `inventory`), Kubernetes (`k8s/`, `helm/`, `*.yaml` with `apiVersion`), Pulumi, CloudFormation, or cloud SDK deps (`aws-sdk`, `@google-cloud/*`, `azure-*`)
- Detection: `glob **/*.tf`, `glob **/playbook*.yml`, `glob **/k8s/**`, check deps for cloud SDKs

**3. API Service / Backend** (`high` risk)
- Signal: Web framework (Express, FastAPI, Django, Rails, Spring, Gin, Actix) AND database deps (`pg`, `mysql2`, `mongoose`, `prisma`, `sqlalchemy`, `diesel`, `typeorm`) AND/OR auth libs (`passport`, `jwt`, `oauth`, `bcrypt`)
- Detection: Check framework in project profile + grep deps for DB/auth packages

**4. Web Application** (`medium` risk)
- Signal: Web framework detected but NO database deps
- Detection: Framework in profile but no DB deps found

**5. Data / ML Pipeline** (`medium` risk)
- Signal: Python + ML deps (`torch`, `tensorflow`, `scikit-learn`, `pandas`, `numpy`, `transformers`, `keras`) OR `.ipynb` files
- Detection: Check deps + `glob **/*.ipynb`

**6. Mobile App** (`medium` risk)
- Signal: Swift/Kotlin project files, React Native (`react-native` dep), Flutter (`pubspec.yaml`), Xcode project (`.xcodeproj`), Android (`AndroidManifest.xml`)
- Detection: `glob **/*.xcodeproj`, `glob **/AndroidManifest.xml`, `glob **/pubspec.yaml`, check deps

**7. CLI Tool / Library** (`lower` risk)
- Signal: No web framework, no database deps, no `.env` file in root, has `bin` or `main` entry point
- Detection: Absence of above signals + check for bin/main config

**8. Static Site / Docs** (`lowest` risk)
- Signal: Hugo (`hugo.toml`/`config.toml`), Jekyll (`_config.yml` + `_posts/`), Gatsby (`gatsby-config.*`), Docusaurus (`docusaurus.config.*`), MkDocs (`mkdocs.yml`), VitePress (`docs/.vitepress/`)
- Detection: `glob` for config files of static site generators

**Fallback**: If no archetype matches, classify as **CLI Tool / Library** (`lower` risk).

### Phase Emphasis Matrix

Based on the classified archetype, assign emphasis levels to each phase:

| Phase | CLI/Lib | Static | Web App | API Svc | Infra | Mobile | Data/ML | Monorepo |
|-------|---------|--------|---------|---------|-------|--------|---------|----------|
| 1-Secrets | standard | light | deep | **maximum** | **maximum** | deep | standard | **maximum** |
| 2-PII | light | light | standard | deep | standard | standard | **maximum** | deep |
| 3-Deps | standard | light | standard | deep | standard | standard | deep | **maximum** |
| 4-Quality | standard | light | standard | standard | standard | standard | standard | deep |
| 5-Docs | standard | standard | standard | standard | deep | standard | deep | deep |
| 6-GitHub | standard | standard | standard | standard | deep | standard | standard | deep |
| 7-Naming | standard | light | deep | deep | **maximum** | deep | standard | **maximum** |
| 8-Flatten | standard | skip-elig | deep | **maximum** | **maximum** | deep | deep | **maximum** |

### Focus Areas by Archetype (injected into sub-agent prompts for `deep`/`maximum` phases)

**API Service / Backend**:
- Phase 1 (maximum): Database connection strings, JWT secrets, API keys in config files, OAuth client secrets, SMTP credentials, session secrets, encryption keys
- Phase 2 (deep): User data in test fixtures, email addresses in seed data, PII in API response examples
- Phase 3 (deep): License compatibility of ORM/DB drivers, auth middleware licenses, transitive dependency audit
- Phase 7 (deep): Internal API endpoint names, company-specific route prefixes, internal service discovery URLs

**Infrastructure / DevOps**:
- Phase 1 (maximum): Cloud credentials (AWS_ACCESS_KEY, GCP service account JSON, Azure tenant secrets), SSH keys, TLS certificates, Vault tokens, Terraform state secrets, Ansible vault passwords
- Phase 5 (deep): Deployment prerequisites, infrastructure dependencies, required environment variables documentation
- Phase 6 (deep): CI/CD pipeline secrets, deployment workflow security, environment-specific configs
- Phase 7 (maximum): Cloud account IDs, internal DNS names, VPC/subnet references, internal registry URLs, org-specific resource naming
- Phase 8 (maximum): Historical cloud credentials, rotated keys in old commits, infrastructure state files

**Web Application**:
- Phase 1 (deep): Frontend API keys, analytics tokens, third-party service credentials, OAuth configs
- Phase 7 (deep): Brand assets, analytics tracking IDs, internal URLs in frontend code, company domains in CORS configs

**Data / ML Pipeline**:
- Phase 2 (maximum): Training data with PII, model outputs containing personal info, dataset paths with usernames, notebook outputs with sensitive data
- Phase 3 (deep): ML framework licenses, dataset licenses, model weight licenses, pre-trained model attribution
- Phase 5 (deep): Model documentation, dataset documentation, reproducibility instructions

**Mobile App**:
- Phase 1 (deep): Keystore passwords, signing configs, API keys in build configs, push notification secrets
- Phase 7 (deep): Bundle identifiers, app store metadata, internal analytics endpoints, crash reporting DSNs

**Monorepo / Multi-Project**:
- Phase 1 (maximum): Cross-package secret leakage, shared config files with credentials, per-package .env files
- Phase 3 (maximum): Per-package dependency audit, workspace-level dependency conflicts, internal package references
- Phase 7 (maximum): Internal package names, cross-references between packages, org-scoped package names, internal registry references
- Phase 8 (maximum): Per-package history assessment, cross-package secret exposure in history

### Red Flags

Auto-generate red flags from detected signals. Each red flag is grounded in an actual project artifact:

- If `pg`, `mysql2`, `mongoose`, or other DB deps found: "Database dependency detected ({dep}) — scan for DATABASE_URL, connection strings"
- If `.env` file exists: ".env file present — verify .gitignore coverage, scan for committed .env variants"
- If `docker-compose.yml` exists: "Docker Compose found — check for hardcoded credentials in service definitions"
- If `Dockerfile` exists: "Dockerfile found — check for ARG/ENV secrets, base image credentials"
- If AWS/GCP/Azure deps found: "Cloud SDK dependency ({dep}) — scan for cloud credentials, account IDs"
- If `jwt`, `passport`, `oauth` deps found: "Auth library ({dep}) — scan for hardcoded secrets, token signing keys"
- If `.ipynb` files found: "Jupyter notebooks detected — scan cell outputs for PII, credentials, sensitive data"
- If `terraform.tfstate` found: "Terraform state file detected — CRITICAL: likely contains secrets"
- If `*.pem`, `*.key` files found: "Private key files detected — verify .gitignore coverage"
- If `Makefile` with deploy targets found: "Deployment automation detected — scan for hardcoded hosts, credentials"

### Output

Write `.oss-prep/risk-profile.json`:
```json
{
  "archetype": "{archetype name}",
  "risk_level": "{lowest|lower|medium|high|highest}",
  "phase_emphasis": {
    "1": "{emphasis}",
    "2": "{emphasis}",
    "3": "{emphasis}",
    "4": "{emphasis}",
    "5": "{emphasis}",
    "6": "{emphasis}",
    "7": "{emphasis}",
    "8": "{emphasis}"
  },
  "focus_areas": {
    "{phase_number}": ["focus area 1", "focus area 2"]
  },
  "red_flags": [
    { "signal": "{what was detected}", "concern": "{what to scan for}" }
  ],
  "golden_path_note": "Brief summary of the risk profile and key areas of concern for this archetype."
}
```

Update state: `risk_profile_generated: true`. Commit `.oss-prep/risk-profile.json` and `.oss-prep/state.json`.

---

## License Pre-Selection (ADP-6 / ADP-7)

Before dispatching Phase 3, determine the license:

1. If a LICENSE file already exists at project root, use the detected license.
2. If no LICENSE file exists: scan dependencies for copyleft licenses (GPL, LGPL, AGPL, MPL).
   - If copyleft deps found: select `GPL-3.0`. Log ADP-6: `{ "adp": 6, "gate": "License selection", "resolution": "GPL-3.0 (copyleft deps detected)", "detail": "{dep list}", "hitl_flag": true }`.
   - If no copyleft deps: select `MIT`. Log ADP-6: `{ "adp": 6, "gate": "License selection", "resolution": "MIT (default, no copyleft deps)", "hitl_flag": true }`.
3. Store in `state.license_choice`.

The same logic applies at ADP-7 (Phase 5 fallback) if `state.license_choice` is still empty.

---

## Phases 1-7: Audit Phases

For each phase 1 through 7, in order:

### Sub-Agent Dispatch (with Emphasis Injection)

Read the risk profile from `.oss-prep/risk-profile.json`. For each phase, dispatch with the standard prompt template PLUS:

1. **AUTO MODE INSTRUCTIONS** block
2. **Risk Profile** block with archetype, emphasis level, focus areas, and red flags

See Sub-Agent Dispatch Template below for the full prompt structure.

### Post-Dispatch

- **ADP-8**: Auto-approve each phase gate. Log: `{ "adp": 8, "gate": "Phase {N} approval", "resolution": "Auto-approved" }`. If the phase reports any CRITICAL findings, add `"hitl_flag": true` to the log entry.
- **ADP-13**: Do NOT auto-remediate secrets/PII findings. The sub-agent reports only; source modifications are deferred to the human. Log: `{ "adp": 13, "gate": "Phase {N} remediations", "resolution": "Deferred to human (report only)", "hitl_flag": {true if CRITICAL > 0} }`.
- Commit and update state per standard commit flow.

### Phase-Specific Overrides

**Phase 3**: Append `License choice: {state.license_choice}` to sub-agent prompt.
**Phase 5**: Append `License choice: {state.license_choice}` to sub-agent prompt. ADP-9: auto-approve all generated doc files. Log: `{ "adp": 9, "gate": "Phase 5 per-file doc review", "resolution": "Approved all generated files" }`.
**Phase 6**: ADP-10: auto-approve all generated infra files. Log: `{ "adp": 10, "gate": "Phase 6 per-file infra review", "resolution": "Approved all generated files" }`.

---

## Phase 8: History Flatten

Phase 8 uses the two-dispatch pattern from SKILL.md, but with autonomous gates:

**Dispatch 1 — Assessment**: Sub-agent reads `phases/08-history-flatten.md` and executes assessment + pre-flatten checklist. Append AUTO MODE INSTRUCTIONS and Risk Profile to prompt.

**ADP-11**: Auto-confirm flatten. Create backup ref first: `git tag oss-prep/pre-flatten HEAD`. Log: `{ "adp": 11, "gate": "Phase 8 flatten confirm", "resolution": "Auto-confirmed (backup ref: oss-prep/pre-flatten)", "hitl_flag": true }`.

**ADP-12**: Use default commit message "Initial public release". Log: `{ "adp": 12, "gate": "Phase 8 commit message", "resolution": "Default: Initial public release" }`.

**Dispatch 2 — Execution**: Sub-agent executes flatten with the confirmed commit message. Append AUTO MODE INSTRUCTIONS and Risk Profile to prompt. Pass commit message: "Initial public release".

After Dispatch 2 returns:
- Update state: `history_flattened: true`
- ADP-8: Auto-approve Phase 8 gate.
- Commit and update state.

---

## Phase 9: Final Report

Dispatch sub-agent for Phase 9 with AUTO MODE INSTRUCTIONS and Risk Profile injected.

After Phase 9 returns:
- ADP-8: Auto-approve Phase 9 gate.
- Commit and update state.

---

## Phase 5R: Documentation Remediation

After Phase 9, dispatch sub-agent for Phase 5 again with this modified prompt:

```
You are executing Phase 5R (Documentation Remediation) of oss-prep-auto.

Read the phase file at: {skill_dir}/phases/05-documentation.md

This is a REMEDIATION pass. The initial Phase 5 audit has already run and findings were captured in the Phase 9 report. Your task is to FIX outstanding documentation issues — generate missing files, update incomplete docs, add missing sections.

{AUTO MODE INSTRUCTIONS}
{Risk Profile block}

Current state: {state JSON}
Project root: {project_root}
License choice: {state.license_choice}

Write all files immediately. Do not pause for review.
Report: finding counts, actions taken, files to stage.
```

ADP-9: Auto-approve all generated files. Commit with message: `oss-prep-auto: phase 5R complete -- documentation remediation`.

---

## Phase 6R: GitHub Infra Remediation

Dispatch sub-agent for Phase 6 again with this modified prompt:

```
You are executing Phase 6R (GitHub Infra Remediation) of oss-prep-auto.

Read the phase file at: {skill_dir}/phases/06-github-setup.md

This is a REMEDIATION pass. The initial Phase 6 audit has already run. Your task is to FIX outstanding GitHub infrastructure issues — generate missing templates, update CI/CD configs, fix .gitignore gaps.

{AUTO MODE INSTRUCTIONS}
{Risk Profile block}

Current state: {state JSON}
Project root: {project_root}

Write all files immediately. Do not pause for review.
Report: finding counts, actions taken, files to stage.
```

ADP-10: Auto-approve all generated files. Commit with message: `oss-prep-auto: phase 6R complete -- github infra remediation`.

---

## ADP-14: Phase 10 Launch

Always skip Phase 10 (public launch). Log: `{ "adp": 14, "gate": "Phase 10 launch", "resolution": "Skipped (too irreversible for auto mode)", "hitl_flag": true }`.

## ADP-15: Remediation Menu

Skip the interactive remediation menu. Log: `{ "adp": 15, "gate": "Remediation menu", "resolution": "Skipped (all phases already ran)" }`.

---

## HITL Summary & Scoring

After all phases and remediation passes complete, compute the readiness score and generate the summary.

### Scoring Algorithm (0-100, deduction-based)

1. **Start at 100**.
2. **Deduct per outstanding finding** (findings NOT auto-remediated):
   - CRITICAL: -25 each (no cap)
   - HIGH: -10 each (cap at 40 total deduction)
   - MEDIUM: -3 each (cap at 15 total deduction)
   - LOW: -1 each (cap at 5 total deduction)
3. **Auto-remediated finding weights**:
   - CRITICAL auto-remediated: 0.5x weight (so -12.5 each)
   - HIGH auto-remediated: 0.25x weight (so -2.5 each)
   - MEDIUM/LOW auto-remediated: 0x weight (no deduction)
4. **Archetype risk multiplier** (applied to total deductions before subtracting from 100):
   - lowest: 1.0x
   - lower: 1.0x
   - medium: 1.2x
   - high: 1.5x
   - highest: 2.0x
5. **Unresolved red flags**: -5 each (NOT subject to risk multiplier)
6. **Hard overrides** (force score interpretation regardless of number):
   - Any outstanding CRITICAL finding → rating is "Not Ready" regardless of score
   - History not flattened AND secrets/PII findings in history → rating is "Not Ready"

### Rating Thresholds

| Score | Rating |
|-------|--------|
| 90-100 | Ready |
| 70-89 | Ready with Caveats |
| 0-69 | Not Ready |

### Compute Readiness

To determine outstanding vs auto-remediated findings:
- Phases 5R and 6R remediated their respective phase findings. Findings originally reported in Phases 5 and 6 that were resolved by the remediation pass count as auto-remediated.
- Phase 8 flatten eliminates all history-based findings from Phases 1 and 2 (those count as auto-remediated if history was flattened).
- All other findings are outstanding (Phases 1-4, 7 working-tree findings remain).

Calculate the score, apply the rating thresholds, check hard overrides, and store in state: `auto_score`, `readiness_rating`.

### Terminal Output

Print a box-drawing formatted summary:

```
╔══════════════════════════════════════════════════════════╗
║                  OSS-PREP AUTO SUMMARY                  ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  Project: {project_name}                                 ║
║  Archetype: {archetype} ({risk_level} risk)              ║
║  Score: {score}/100 — {rating}                           ║
║  Duration: {duration}                                    ║
║                                                          ║
╠══════════════════════════════════════════════════════════╣
║  AUTONOMOUS DECISIONS                                    ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  ADP | Gate                  | Resolution                ║
║  ----+------------------------+------------------------  ║
║  {For each ADP decision logged, one row}                 ║
║  Decisions requiring review marked with [!]              ║
║                                                          ║
╠══════════════════════════════════════════════════════════╣
║  PHASE RESULTS                                           ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  Phase | Name              | C | H | M | L | Status     ║
║  ------+-------------------+---+---+---+---+----------- ║
║  {For each phase 0-9 plus 5R and 6R, one row}           ║
║                                                          ║
╠══════════════════════════════════════════════════════════╣
║  SCORE BREAKDOWN                                         ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  Base score: 100                                         ║
║  {Itemized deductions with severity and source}          ║
║  Risk multiplier: {multiplier}x ({risk_level})           ║
║  Red flag deductions: {count} x -5 = -{total}            ║
║  Final score: {score}                                    ║
║  Hard overrides: {any that applied, or "None"}           ║
║                                                          ║
╠══════════════════════════════════════════════════════════╣
║  OUTSTANDING ITEMS                                       ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  CRITICAL ({count}):                                     ║
║    - {finding summary with file:line}                    ║
║  HIGH ({count}):                                         ║
║    - {finding summary}                                   ║
║  MEDIUM ({count}):                                       ║
║    - {finding summary}                                   ║
║  LOW ({count}):                                          ║
║    - {finding summary}                                   ║
║                                                          ║
╠══════════════════════════════════════════════════════════╣
║  NEXT STEPS                                              ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  1. Review items marked [!] in the decisions table       ║
║  2. Address outstanding CRITICAL/HIGH findings manually  ║
║  3. When ready, create public repo and push:             ║
║     git remote add public <url>                          ║
║     git push public oss-prep/ready:main                  ║
║                                                          ║
║  Files:                                                  ║
║    Report: .oss-prep/readiness-report.md                 ║
║    Risk Profile: .oss-prep/risk-profile.json             ║
║    Decisions: .oss-prep/auto-decisions.json              ║
║    Summary: {project_root}/oss-prep-auto-summary-{date}.md  ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
```

### Disk File

Write the same content (without box-drawing, as clean markdown) to `{project_root}/oss-prep-auto-summary-{YYYY-MM-DD}.md`.

### Final State Update

Update state atomically:
- `auto_score`: computed score
- `readiness_rating`: computed rating
- `auto_run_completed_at`: current ISO 8601 timestamp
- `phase`: 10

Commit: `oss-prep-auto: run complete -- score {score}/100 ({rating})`.

---

## Sub-Agent Dispatch Template

For every phase sub-agent dispatch, use this prompt structure:

```
You are executing Phase {N} ({Name}) of the oss-prep skill.

Read the phase file at: {skill_dir}/phases/{NN}-{slug}.md

--- AUTO MODE INSTRUCTIONS ---
This is a FULLY AUTONOMOUS run. Do NOT pause for user input at any point.
- Do NOT present approval gates or ask for confirmation.
- Write all output files immediately without review prompts.
- If a decision point arises, choose the safer/more conservative option.
- If you encounter an error, log it and continue with remaining checks.
- Report findings but do NOT modify source code to remediate secrets/PII (report only).
--- END AUTO MODE ---

--- RISK PROFILE ---
Archetype: {archetype}
Risk Level: {risk_level}
Phase {N} Emphasis: {emphasis level for this phase}
Focus Areas: {focus areas for this phase, or "Standard scan" if none}
Red Flags: {red flags relevant to this phase, or "None"}
--- END RISK PROFILE ---

Current state:
{state JSON}

Project root: {project_root}

Grounding Requirement:
Every finding you report MUST be grounded in actual code artifacts. Each finding must include at least one of: file path and line number, commit hash, grep/glob match output, or tool output. Zero findings is a valid result — do not invent findings. Never report a file path without verifying it exists, never report a line number without reading that line, never report a commit hash without retrieving it from git. If uncertain, classify as MEDIUM and note the uncertainty. Prefer false negatives over false positives.

Execute all steps in the phase file. When complete, report:
1. Finding counts: {total, critical, high, medium, low}
2. Key highlights: 3-5 most important findings or actions
3. Actions taken: files created, modified, or deleted
4. Files to stage: explicit list of file paths to commit
```

All sub-agents dispatched with `model: "opus"` via the Task tool with `subagent_type: "general-purpose"`.

---

## Commit Flow

After each phase (and remediation pass):

1. Stage only phase-specific output files and `.oss-prep/state.json`: `git add -- .oss-prep/state.json {file1} {file2} ...`
2. **NEVER** use `git add -A`, `git add .`, or any unscoped staging.
3. Commit message format: `oss-prep-auto: phase {N} complete -- {phase-name}`
4. If the sub-agent reports no files to stage, stage only `.oss-prep/state.json`.

## State Update Flow

After each successful commit:
1. Add N to `phases_completed`
2. Update `findings` with new cumulative counts
3. Store per-phase counts in `phase_findings`
4. Set `phase` to N+1
5. Write state using atomic write pattern (tmp → validate → rename)

---

## Sub-Agent Failure Handling

Same as SKILL.md:
1. **Retry once** with simplified prompt.
2. If retry fails, **execute in main context** with warning.
3. Log failure in `phase_failures`.

---

## Grounding Requirement

Same as SKILL.md — every finding must be grounded in actual code artifacts. Zero findings is valid. Prefer false negatives over false positives.

---

## Sub-Agent Model Policy

All sub-agents spawned via the Task tool MUST use `model: "opus"`. Never use `sonnet` or `haiku`.

---

## Autonomous Decision Protocol Reference

| ADP | Gate | Resolution | HITL Flag |
|-----|------|-----------|-----------|
| 1 | Uncommitted changes | `git stash` automatically | No |
| 2 | Resume vs Reset | Always reset (clean idempotent run) | No |
| 3 | Submodule warning | Proceed with audit | No |
| 4 | Existing prep branch | Delete + recreate from HEAD | No |
| 5 | Profile confirmation | Auto-confirm detected profile | No |
| 6 | License selection | MIT default; GPL-3.0 if copyleft deps | **Yes** |
| 7 | License fallback | Same as ADP-6 | **Yes** |
| 8 | Phase approval gates | Auto-approve unconditionally | If CRITICAL > 0 |
| 9 | Phase 5 per-file doc review | Approve all generated files | No |
| 10 | Phase 6 per-file infra review | Approve all generated files | No |
| 11 | Phase 8 flatten confirm | Auto-confirm (backup ref created) | **Yes** |
| 12 | Phase 8 commit message | Default: "Initial public release" | No |
| 13 | Phase 1/2 remediations | Defer to human (report only) | If CRITICAL > 0 |
| 14 | Phase 10 launch | Always skip (too irreversible) | **Yes** |
| 15 | Remediation menu | Skip (all phases already ran) | No |

---

## Phase Sequence

```
0 → [Risk Assessment] → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 5R → 6R → [HITL Summary]
```

Phase 5R and 6R run after Phase 9 so the report captures the honest audit baseline first.
