# Phase 8 — History Flatten

| Field | Value |
|-------|-------|
| Phase | 8 |
| Name | History Flatten |
| Priority | Critical — most destructive operation in the skill |
| Sub-Agent Calls | 2 (assessment + execution), with orchestrator gate between them |

## Inputs

| Source | Fields |
|--------|--------|
| State | `state.project_root`, `state.prep_branch`, `state.phases_completed`, `state.findings`, `state.phase_findings` (specifically phases 1 and 2 findings for the assessment) |
| Pattern Libraries | `patterns/secrets.md` (post-flatten secret verification), `patterns/pii.md` (post-flatten PII verification) |

## Outputs

| Output | Description |
|--------|-------------|
| `state.history_flattened` | Boolean — `true` if flatten executed, `false` if declined or dry-run |
| `state.phase_findings["8"]` | Phase 8 finding counts and status |
| `state.findings` | Updated cumulative finding totals (if post-flatten scan finds issues) |
| `state.phases_completed` | Appended with `8` |
| Backup ref `refs/oss-prep/pre-flatten` | Created before any destructive operation (if flatten executed) |
| Modified `oss-prep/ready` branch | Single orphan commit (if flatten executed) |

---

## Two Sub-Agent Dispatch Architecture

Phase 8 is unique because it has a mid-phase user gate (the "type flatten" confirmation) that is intentionally stronger than standard inter-phase gates. This splits execution into two sub-agent calls with an orchestrator gate between them.

### Sub-Agent Call 1 — Assessment (Steps 8.1–8.2)

The first sub-agent runs the history assessment and pre-flatten checklist. It returns the assessment data and checklist to the orchestrator. No destructive operations occur in this call.

**Steps included**: 8.1 (History Assessment), 8.2 (Pre-Flatten Checklist)

### Orchestrator Gate — Confirmation (Step 8.3)

The orchestrator presents the confirmation gate (Step 8.3) to the user. This is NOT executed by a sub-agent — it is the orchestrator's responsibility because it requires direct user interaction.

The user responds with one of:
- **`flatten`** — Proceed to Sub-Agent Call 2
- **`skip`** or any other response — Orchestrator handles the decline path (Step 8.6) itself
- **`dry-run`** — Orchestrator triggers the dry-run path (see Dry-Run Mode section)

### Sub-Agent Call 2 — Execution (Steps 8.4–8.5)

If the user confirms with "flatten", the orchestrator dispatches a second sub-agent to execute the flatten and run post-flatten verification. This sub-agent receives the assessment data from Call 1 (specifically the commit message choice from the orchestrator gate).

**Steps included**: 8.4 (Execute Flatten), 8.5 (Post-Flatten Verification Scan)

### Steps Handled by Orchestrator

The following steps are NOT dispatched to sub-agents:
- **Step 8.3** (Confirmation Gate) — requires direct user interaction
- **Step 8.6** (Decline Path) — handled after user declines
- **Step 8.7** (Phase Summary) — orchestrator consolidates results from both calls
- **Step 8.8** (State Update) — orchestrator updates persistent state

---

## Step 8.0 — Deferred Action Awareness

> **Sub-Agent Call 1**

Before beginning the history assessment, read `state.deferred_actions` from the state to understand what findings from earlier phases (1, 2, and 7) have been deferred to this phase. These are findings related to secrets, PII, or identity references found **only in git history** that cannot be resolved by editing files — they require the history flatten to eliminate.

If `state.deferred_actions` is non-empty, include a summary in the assessment output:

```
### Deferred Actions Pending

{N} deferred actions from phases 1, 2, and 7 will be resolved by this flatten:
- {deferred_action_1 summary} (from Phase {N})
- {deferred_action_2 summary} (from Phase {N})
- ...

These items were flagged as [Deferred -> Phase 8] in their source phases because they exist only in git history.
```

If `state.deferred_actions` is empty or absent, note: "No deferred actions pending from prior phases."

---

## Step 8.1 — History Assessment

> **Sub-Agent Call 1**

Gather the following data from the repository and present it as a structured assessment:

1. **Total commit count**:
```bash
git rev-list --count HEAD
```

2. **Unique contributor count**:
```bash
git log --format='%aN <%aE>' | sort -u | wc -l
```

3. **Date range** (earliest to latest commit):
```bash
git log --format='%ai' --reverse | head -1   # earliest
git log --format='%ai' -1                      # latest
```

4. **List of branches**:
```bash
git branch -a
```

5. **List of tags**:
```bash
git tag -l
```

6. **Secrets found in history**: Reference the cumulative secrets count from the Phase 1 findings in the STATE block (`findings` from Phase 1). Report this as: "{N} secrets/credentials detected during Phase 1 (Secrets & Credentials Audit), including those found in git history."

7. **PII found in history**: Reference the cumulative PII count from the Phase 2 findings in the STATE block (`findings` from Phase 2). Report this as: "{N} PII items detected during Phase 2 (PII Audit), including those found in git history."

8. **Large files in history** (>1MB): Run:
```bash
git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | awk '/^blob/ && $3 > 1048576 {print $3, $4}' | sort -rn
```
Report the count and list each file with its size.

Present all of this as a formatted assessment:

```
### History Assessment

| Metric | Value |
|--------|-------|
| Total commits | {N} |
| Unique contributors | {N} |
| Date range | {earliest} → {latest} |
| Branches | {N} ({list}) |
| Tags | {N} ({list or "none"}) |
| Secrets found (Phase 1) | {N} |
| PII found (Phase 2) | {N} |
| Large files (>1MB) | {N} |

{If large files found, list them:}
**Large files in history:**
- {filename} — {size in MB}
- ...
```

---

## Step 8.2 — Pre-Flatten Checklist

> **Sub-Agent Call 1**

After presenting the history assessment, present the pre-flatten checklist as a clearly formatted, scannable list. Do NOT bury this information in a paragraph.

```
### What Will Be Permanently Lost

If you proceed with the history flatten, the following will be **permanently and irreversibly** destroyed:

- [ ] **All commit history** — {N} commits will be replaced by a single commit
- [ ] **Tags reachable from `oss-prep/ready`** — {list each reachable tag by name, or "no reachable tags to remove"} (tags not reachable from the preparation branch are preserved)
- [ ] **All branch references on `oss-prep/ready`** — the preparation branch will point to a single orphan commit
- [ ] **Git blame attribution** — all lines will show a single author and date
- [ ] **All code will appear as authored in a single commit** — individual contribution history will not be visible

Your original branch (e.g., `main` or `master`) is **not affected** — only the `oss-prep/ready` preparation branch will be flattened.
```

**Return to orchestrator**: After completing Steps 8.1 and 8.2, Sub-Agent Call 1 returns the assessment table and checklist data to the orchestrator for presentation in the confirmation gate.

---

## Step 8.3 — Confirmation Gate

> **Orchestrator responsibility — NOT executed by a sub-agent**

Present the confirmation gate. This gate is intentionally stronger than the standard phase approval gates used elsewhere in this skill.

> "This operation is **irreversible**. Once the history is flattened, it cannot be undone — all {N} commits, tags, and blame attribution on the `oss-prep/ready` branch will be permanently replaced by a single commit.
>
> A backup of the current branch state will be saved to `refs/oss-prep/pre-flatten`. If you need to restore, run:
> ```bash
> git checkout -B oss-prep/ready refs/oss-prep/pre-flatten
> ```
>
> To confirm, type **`flatten`** (the word, not just 'y' or 'yes').
>
> To preview what would change without executing, type **`dry-run`**.
>
> To decline, type **`skip`** or any other response."

**Confirmation rules:**
- The user must type exactly `flatten` (case-insensitive) to proceed.
- Responses of `y`, `yes`, `ok`, `sure`, or any other input do **NOT** trigger the flatten — they are treated as a decline.
- If the response is `dry-run` (case-insensitive), proceed to the **Dry-Run Mode** section.
- If the response is ambiguous or negative, proceed to **Step 8.6 — Decline Path**.
- If the user confirms with `flatten`, proceed to **Step 8.4 — Execute Flatten**.

---

## Step 8.4 — Execute Flatten (Orphan Branch Procedure)

> **Sub-Agent Call 2**

**Only execute this step if the user typed `flatten` in Step 8.3.**

Before creating the commit, the orchestrator will have asked the user:
> "The default commit message is: **'Initial public release'**. Would you like to customize it? (Press Enter to use the default, or type your preferred message.)"

The chosen commit message is passed to this sub-agent.

### 8.4.1 — Check for Uncommitted Changes

Before any destructive operation, check for uncommitted changes:

```bash
git status --porcelain
```

**If output is non-empty**: REFUSE to proceed. Report:
> "**Cannot flatten**: Uncommitted changes detected in the working tree. The flatten operation requires a clean working tree to proceed safely.
>
> Uncommitted changes found:
> {list output of git status --porcelain}
>
> Run `git stash` to save your changes, then re-run Phase 8."

Do NOT silently proceed with uncommitted changes. Return to the orchestrator with a failure status.

### 8.4.2 — Create Backup Reference

Before any destructive git operation, create a backup of the current branch state:

```bash
git update-ref refs/oss-prep/pre-flatten oss-prep/ready
```

Verify the backup was created:
```bash
git rev-parse refs/oss-prep/pre-flatten
```

If the backup ref creation fails, STOP and report the error. Do not proceed with the flatten.

### 8.4.3 — Create Orphan Branch

```bash
git checkout --orphan oss-prep/flatten-temp
```

### 8.4.4 — Stage and Commit

```bash
git add -A
git commit -m "{commit message — default: 'Initial public release'}"
```

### 8.4.5 — Replace Preparation Branch

Force-update the preparation branch to point to this commit:

```bash
git branch -M oss-prep/flatten-temp oss-prep/ready
```

Verify the branch has exactly one commit:

```bash
git rev-list --count HEAD
```

This must return `1`. If it does not, report an error and stop — do not proceed to verification.

### 8.4.6 — Remove Reachable Tags

Remove only tags that were reachable from the preparation branch (they reference commits that no longer exist on this branch):

```bash
git tag --merged oss-prep/ready | xargs -r git tag -d
```

After successful execution, announce:
> "History flattened successfully. The `oss-prep/ready` branch now contains a single commit. Running post-flatten verification scan..."

---

## Step 8.5 — Post-Flatten Verification Scan

> **Sub-Agent Call 2**

After flattening, re-run the secret and PII detection scans against the current working tree and the single commit to verify no sensitive data survived into the clean state.

### 8.5.1 — Secret Scan

Apply the secret detection patterns from **`patterns/secrets.md`** against all files in the current working tree. Use the Grep tool to scan for each pattern category defined in the shared library. Do NOT redefine the patterns — read `patterns/secrets.md` for the complete pattern set.

### 8.5.2 — PII Scan

Apply the PII detection patterns from **`patterns/pii.md`** against all files in the current working tree. Use the Grep tool to scan for each pattern category defined in the shared library. Do NOT redefine the patterns — read `patterns/pii.md` for the complete pattern set.

Apply the PII allowlist below to filter false positives.

#### PII Allowlist (duplicated from Phase 2 for sub-agent self-containment)

The following values match PII patterns but are **not sensitive** and should be **excluded from findings**:

##### Allowlisted Email Addresses
- `example@example.com`
- `user@example.com`
- `test@test.com`
- `test@example.com`
- `admin@example.com`
- `noreply@github.com`
- `noreply@example.com`
- `*@users.noreply.github.com` (any GitHub noreply address)
- `github-actions@github.com`
- `dependabot[bot]@users.noreply.github.com`
- Any email at the `example.com`, `example.org`, `example.net`, or `test.com` domains

##### Allowlisted IP Addresses
- `127.0.0.1` (localhost)
- `0.0.0.0` (unspecified)
- `localhost`
- `::1` (IPv6 loopback)
- `fe80::*` (IPv6 link-local)
- `10.*.*.*` (private range)
- `172.16-31.*.*` (private range)
- `192.168.*.*` (private range)
- `192.0.2.*` (RFC 5737 documentation, TEST-NET-1)
- `198.51.100.*` (RFC 5737 documentation, TEST-NET-2)
- `203.0.113.*` (RFC 5737 documentation, TEST-NET-3)

**Note**: The IPv4 regex in `patterns/pii.md` already excludes most of these ranges. This allowlist serves as a secondary filter for any edge cases.

##### Allowlisted SSNs
- `000-00-0000` (placeholder)
- `123-45-6789` (common test SSN — still flag in non-test contexts but note it is a well-known test value)

##### Allowlisted Credit Card Numbers
- `4242424242424242` (Stripe test Visa)
- `4000056655665556` (Stripe test Visa debit)
- `5555555555554444` (Stripe test Mastercard)
- `378282246310005` (Stripe test Amex)
- `6011111111111117` (Stripe test Discover)
- `4111111111111111` (generic test Visa)
- Any card number in a file explicitly named `*test*`, `*mock*`, `*fixture*`, `*fake*`, `*stripe*test*` where the surrounding context clearly indicates test usage

##### Allowlisted Names
- "John Doe", "Jane Doe" (standard placeholder names)
- "Alice", "Bob", "Charlie", "Dave", "Eve", "Mallory" (cryptography/protocol placeholder names)
- "Foo Bar", "Test User", "Example User", "Admin User"
- Names appearing in `LICENSE` files (these are intentional copyright attributions)

##### Allowlisting Rules
1. Allowlist matches are **case-insensitive** for email domains and names.
2. Allowlist matches require **exact value match** for IPs, SSNs, and credit card numbers.
3. When a value is allowlisted, it is completely excluded from findings — it does not appear even as LOW severity.
4. If an allowlisted value appears in an unexpected context (e.g., a test SSN in a production config), flag it as MEDIUM with a note explaining why it was partially allowlisted.

### 8.5.3 — Single-Commit Diff Scan

Also scan the content of the single commit's diff:

```bash
git show --format= --diff-filter=A HEAD
```

Apply both the `patterns/secrets.md` secret patterns and `patterns/pii.md` PII patterns to this output. Apply the PII allowlist above to filter false positives.

### 8.5.4 — Verification Result

**Expected result**: Zero findings. If this is the case, announce:
> "Post-flatten verification complete. No secrets or PII detected in the flattened repository. Clean state confirmed."

**If findings are detected**: Report them as **CRITICAL** issues:
> "**CRITICAL**: Post-flatten verification found {N} issue(s) that survived into the flattened repository. These MUST be resolved before proceeding to Phase 9."

List each finding in the standard finding report format:

```
**HF8-{N}** [{effort}] (CRITICAL): {description}
- **File**: {file path}
- **Line**: {line number}
- **Pattern**: {pattern category from patterns/secrets.md or patterns/pii.md}
- **Matched value**: {redacted excerpt showing context}
- **Recommendation**: {specific remediation action}
```

Where `{effort}` is one of the effort tags defined in SKILL.md. See SKILL.md for the canonical effort tag definitions and structured finding format. Post-flatten residual findings are typically `[Decision needed]` since they indicate the flatten did not fully sanitize the repository.

Require the user to remediate before continuing. After remediation, re-run the verification scan. Do NOT proceed to Phase 9 until the scan is clean.

### 8.5.5 — Deferred Action Resolution Verification

After the post-flatten verification scan, check each item in `state.deferred_actions` to determine if the flatten resolved it:

1. For each deferred action, verify the referenced content no longer exists in the flattened repository's single commit or working tree.
2. Build a `deferred_resolved` list containing the IDs of all deferred actions that were resolved by the flatten.
3. Return the `deferred_resolved` list alongside the regular findings so the orchestrator can update `state.deferred_actions` entries with `status: "resolved"`.

If the flatten was executed and the post-flatten scan is clean, all deferred actions related to git history should be resolved. Report:

```
### Deferred Action Resolution

{N} of {M} deferred actions resolved by flatten:
- {action_id}: Resolved — reference no longer exists in flattened history
- ...

{If any remain unresolved:}
{K} deferred actions still outstanding:
- {action_id}: Still present in working tree — requires manual remediation
```

---

## Step 8.6 — Decline Path

> **Orchestrator responsibility**

If the user declines to flatten (any response other than `flatten` or `dry-run` in Step 8.3), do the following:

1. **Acknowledge the decision**:
> "Understood — history will not be flattened. Your full commit history will be preserved on the `oss-prep/ready` branch."

2. **Present alternative selective history rewriting commands** that the user can run manually:

```
### Alternative: Selective History Rewriting

If you want to surgically remove specific sensitive data from history without
a full flatten, consider these `git filter-repo` commands:

**Remove a specific file from all history:**
```bash
git filter-repo --invert-paths --path path/to/secret-file.env
```

**Remove files matching a pattern:**
```bash
git filter-repo --invert-paths --path-glob '*.pem'
git filter-repo --invert-paths --path-glob '**/.env*'
```

**Replace a specific string (e.g., an API key) across all history:**
```bash
git filter-repo --replace-text <(echo 'AKIAIOSFODNN7EXAMPLE==>REDACTED')
```

**Remove all files larger than a threshold:**
```bash
git filter-repo --strip-blobs-bigger-than 1M
```

Note: `git filter-repo` requires installation (`pip install git-filter-repo`).
After running any of these commands, re-run Phase 1 and Phase 2 scans to verify.
```

3. **Explain the risks of proceeding without flattening**:
> "**Risk warning**: Without flattening, secrets and PII that were committed and later removed may still be accessible in git history. Anyone who clones the public repository can run `git log -p` to view old diffs. Even if sensitive data was removed from the working tree during Phases 1-2, it may still exist in historical commits. The Phase 9 final report will reflect this as a risk item."

4. **Record the decision** — the STATE block will be updated in Step 8.8 with `history_flattened: false`.

5. **Proceed to Phase 9** — do not block progress. The final report (Phase 9) will include a risk warning about the unflattened history.

---

## Dry-Run Mode

> **Orchestrator responsibility — triggered when user types `dry-run` in Step 8.3**

The dry-run mode executes the assessment (Steps 8.1-8.2) and reports what the flatten would do, without performing any destructive operations.

If Steps 8.1-8.2 have already been executed by Sub-Agent Call 1, the orchestrator reuses those results. No additional sub-agent call is needed for dry-run.

### Dry-Run Report

Present the following to the user:

```
### Dry-Run: History Flatten Preview

**Commits that would be removed**: {N} commits (replaced by 1 clean commit)
**Tags that would be deleted**: {list tags from `git tag --merged oss-prep/ready`, or "none"}
**Backup ref that would be created**: `refs/oss-prep/pre-flatten` → {current SHA of oss-prep/ready}
**Branches affected**: Only `oss-prep/ready` — all other branches are preserved

No destructive operations were performed. This was a dry-run.
```

After presenting the dry-run report:
- Set `state.history_flattened` to `false`
- Proceed to **Step 8.7 — Phase Summary** (summarizing the dry-run)
- The user may re-enter Phase 8 to perform the actual flatten if desired

---

## Step 8.7 — Consolidate and Present Phase Summary

> **Orchestrator responsibility**

Present the Phase 8 summary using the standard format:

```
## Phase 8 Summary — History Flatten

### Category Summary

| Category | Status | Count | Top Severity | Effort |
|----------|--------|-------|-------------|--------|
| Pre-Flatten Assessment | {Clean/Findings} | {N} | {CRITICAL/HIGH/MEDIUM/LOW/—} | {effort or —} |
| Post-Flatten Secrets Verification | {Clean/Findings} | {N} | {CRITICAL/—} | {effort or —} |
| Post-Flatten PII Verification | {Clean/Findings} | {N} | {CRITICAL/—} | {effort or —} |
| Deferred Action Resolution | {Clean/Findings} | {N} | {—} | {effort or —} |

**History assessed**: {N} commits, {N} contributors, date range {earliest} → {latest}
**Tags found**: {N} ({list or "none"})
**Large files in history**: {N} files over 1MB
**Decision**: {Flattened / Declined / Dry-Run}
{If flattened:} **Post-flatten verification**: {Clean — 0 findings / {N} findings resolved}
{If flattened:} **Deferred actions resolved**: {N} of {M}
{If declined:} **Risk level**: Elevated — secrets/PII may remain in git history

**Findings**: {total} total ({critical} critical, {high} high, {medium} medium)

### Key Highlights
1. {Most important outcome — e.g., "History flattened: 247 commits consolidated into 1 clean commit"}
2. {Second highlight — e.g., "Post-flatten scan confirmed zero secrets or PII in clean state"}
3. {Third highlight — e.g., "12 tags removed from flattened branch"}
{...up to 5 highlights}
```

### Effort Classification Guidance (Phase 8)

- **`[Auto-fix]`**: The flatten operation itself (once the user confirms with `flatten`). The skill executes the orphan branch creation, staging, and commit automatically.
- **`[Quick fix]`**: Post-flatten verification findings that can be resolved by removing a single file or line (should be zero after a clean flatten).
- **`[Decision needed]`**: Post-flatten scan finds residual secrets or PII that survived into the flattened state — the user must decide how to remediate. Also applies when choosing between flatten, dry-run, and skip.

Then present the user approval gate:
> "Phase 8 (History Flatten) complete. Choose one:
> - **Approve and continue** — Accept results and move to Phase 9 (Final Readiness Report)
> - **Review details** — Show the full history assessment and flatten details
> - **Skip** — Mark Phase 8 as skipped and move on"

**Do NOT advance to Phase 9 until the user explicitly responds.**

---

## Step 8.8 — Update STATE

> **Orchestrator responsibility — documented as expected state changes**

After Phase 8 is complete and the user approves, update the STATE:

| Field | Value |
|-------|-------|
| `phase` | `9` |
| `history_flattened` | `true` if flattened, `false` if declined or dry-run |
| `phases_completed` | Append `8` |
| `phase_findings["8"]` | `{ total, critical, high, medium, low, status: "completed" }` |
| `findings` | Updated cumulative totals (add Phase 8 findings to running totals) |

Announce:
> "Phase 8 (History Flatten) complete. Moving to Phase 9 — Final Readiness Report."

Wait for user approval before beginning Phase 9 (per the Phase-Gating Interaction Model).
