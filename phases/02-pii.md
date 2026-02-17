# Phase 2 — PII Audit

---

- **Phase**: 2
- **Name**: PII Audit
- **Inputs**: project_root, project_profile, state (from Phases 0-1), patterns/pii.md
- **Outputs**: findings list (P2-1 through P2-N), finding counts by severity, remediated files (if Apply remediations chosen), git config changes (if author email remediation approved), state update (phase: 3, cumulative findings from Phases 1+2, phases_completed adds 2)

---

Phase 2 scans both the current working tree and full git history for personally identifiable information (PII) — email addresses, phone numbers, physical addresses, IP addresses, SSNs, credit card numbers, internal employee identifiers, and hardcoded personal names. It also inspects git author/committer metadata for personal email addresses. Findings are classified by severity, filtered against a public/generic PII allowlist, and presented with surgical remediation proposals for user approval.

## Step 2.1 — Dispatch Parallel Sub-Agents

Launch **three sub-agents simultaneously** via the Task tool (all with `model: "opus"`):

- **Sub-agent A — Working Tree PII Scan**: Scans all tracked files in the current working tree using Grep with the PII pattern library.
- **Sub-agent B — Git History PII Scan**: Scans the full git history for PII that was committed and later removed or modified.
- **Sub-agent C — Git Author/Committer Email Audit**: Inspects all unique author and committer email addresses across all commits.

Provide each sub-agent with:
- The current STATE block
- The `project_root` path
- The full PII pattern library — read `patterns/pii.md` for the complete 8-category PII detection pattern library and include its contents in the sub-agent prompt
- The PII allowlist (copy the allowlist section from Step 2.3 below into the sub-agent prompt)
- Instructions to report findings in the standard format (see Step 2.5)
- The Grounding Requirement — every finding must include file path + line number (Sub-agent A), commit hash + file path (Sub-agent B), or email address + recommendation (Sub-agent C)

Wait for **all three sub-agents to complete** before proceeding to consolidation.

### Sub-Agent A — Working Tree PII Scan Instructions

Read `patterns/pii.md` for the complete 8-category PII detection pattern library. For each pattern category, run a Grep search across all tracked files. For each match:
1. Record the file path and line number.
2. Extract the matched value (the PII portion, not the entire line).
3. Check the match against the PII allowlist — if allowlisted, skip it.
4. Classify the severity using the rules in Step 2.4.
5. Skip binary files and files matching: `*.png`, `*.jpg`, `*.gif`, `*.ico`, `*.woff`, `*.woff2`, `*.ttf`, `*.eot`, `*.mp4`, `*.mp3`, `*.zip`, `*.tar.gz`, `*.jar`, `*.pyc`, `*.so`, `*.dylib`, `*.dll`.
6. Skip lock files: `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Cargo.lock`, `Gemfile.lock`, `composer.lock`, `go.sum`, `bun.lockb`, `bun.lock`.

### Sub-Agent B — Git History PII Scan Instructions

Run the following to extract diffs from the entire history:
```bash
git log -p --all --diff-filter=D -- .
```
This shows content from deleted files. Additionally, run:
```bash
git log -p --all -S "PATTERN" -- .
```
for the highest-priority PII patterns (personal emails, SSNs, credit card numbers, phone numbers) to find PII that was added and then modified or removed.

For each match:
1. Record the commit hash, author, date, and file path.
2. Extract the matched value.
3. Check the match against the PII allowlist — if allowlisted, skip it.
4. Classify the severity using the rules in Step 2.4.
5. Note whether the PII still exists in the current working tree or was only in history.

### Sub-Agent C — Git Author/Committer Email Audit Instructions

Run the following to collect all unique author and committer emails:
```bash
git log --format='%ae%n%ce' --all | sort -u
```

For each unique email address:
1. Check if it is a GitHub noreply address (matches `*@users.noreply.github.com`) — if so, skip it (this is already the recommended format).
2. Check if it is a generic/bot address (matches patterns like `noreply@*`, `bot@*`, `github-actions@*`, `dependabot@*`) — if so, skip it.
3. For all remaining emails, flag them as personal email addresses that will be visible in the public git history.
4. Categorize flagged emails:
   - **Personal provider emails**: Addresses at `gmail.com`, `yahoo.com`, `hotmail.com`, `outlook.com`, `icloud.com`, `protonmail.com`, `aol.com`, `mail.com`, `zoho.com` — these directly expose personal identity.
   - **Corporate/internal emails**: Addresses at company domains — these reveal organizational affiliation and internal identity.
5. For each flagged email, recommend switching to `username@users.noreply.github.com` and provide the configuration command:
   ```bash
   git config user.email "username@users.noreply.github.com"
   ```
6. Note that historical author emails will be eliminated by Phase 8 (History Flatten) if the user chooses to flatten. If the user opts not to flatten, recommend `git filter-repo --mailmap` to rewrite author emails.

## Step 2.2 — PII Pattern Library

Read `patterns/pii.md` for the complete 8-category PII detection pattern library. The pattern library includes:

1. **Email Addresses** — General email and personal provider email patterns
2. **Phone Numbers** — North American (parenthesized, dashed, E.164) and international formats
3. **Physical/Mailing Addresses** — US street address and city/state/zip patterns
4. **IP Addresses** — IPv4 (public only, excluding private/documentation ranges) with IPv6 notes
5. **Social Security Numbers** — US SSN format with context-awareness guidance
6. **Credit Card Numbers** — Visa, Mastercard, Amex, Discover with Luhn validation guidance
7. **Internal Employee Identifiers** — TODO/FIXME names, Jira tickets, Slack channels, badge/employee IDs
8. **Hardcoded Personal Names** — Names in TODO/FIXME, file headers, and test data

The pattern library also includes severity guidance and special cases for classification. All sub-agents must use these patterns for detection — do not define inline patterns.

## Step 2.3 — PII Allowlist

The following values match PII patterns but are **not sensitive** and should be **excluded from findings**:

### Allowlisted Email Addresses
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

### Allowlisted IP Addresses
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

### Allowlisted SSNs
- `000-00-0000` (placeholder)
- `123-45-6789` (common test SSN — still flag in non-test contexts but note it is a well-known test value)

### Allowlisted Credit Card Numbers
- `4242424242424242` (Stripe test Visa)
- `4000056655665556` (Stripe test Visa debit)
- `5555555555554444` (Stripe test Mastercard)
- `378282246310005` (Stripe test Amex)
- `6011111111111117` (Stripe test Discover)
- `4111111111111111` (generic test Visa)
- Any card number in a file explicitly named `*test*`, `*mock*`, `*fixture*`, `*fake*`, `*stripe*test*` where the surrounding context clearly indicates test usage

### Allowlisted Names
- "John Doe", "Jane Doe" (standard placeholder names)
- "Alice", "Bob", "Charlie", "Dave", "Eve", "Mallory" (cryptography/protocol placeholder names)
- "Foo Bar", "Test User", "Example User", "Admin User"
- Names appearing in `LICENSE` files (these are intentional copyright attributions)

### Allowlisting Rules
1. Allowlist matches are **case-insensitive** for email domains and names.
2. Allowlist matches require **exact value match** for IPs, SSNs, and credit card numbers.
3. When a value is allowlisted, it is completely excluded from findings — it does not appear even as LOW severity.
4. If an allowlisted value appears in an unexpected context (e.g., a test SSN in a production config), flag it as MEDIUM with a note explaining why it was partially allowlisted.

## Step 2.4 — Severity Classification

Classify each PII finding using the following rules:

| Severity | Criteria |
|----------|----------|
| **CRITICAL** | SSN, credit card number (passing Luhn), or combination of full name + address/phone/email that constitutes a complete identity profile. Any PII that could enable identity theft. |
| **HIGH** | Personal email address (at personal provider domain) in source code or config. Phone number with area code. Physical/mailing address. Public IP address in production config. Employee ID or badge number. |
| **MEDIUM** | Email address at corporate/internal domain (reveals affiliation but not necessarily personal). TODO/FIXME comments with usernames. Jira ticket references in source code. Slack channel references. Names in file headers or test data that might be real people. Git author emails (flagged by Sub-agent C). |
| **LOW** | Names in test data that appear fictional but are not in the allowlist. IP addresses in non-production config (development, staging). Jira references in changelogs. Phone numbers that may be fake/test numbers (e.g., 555-xxxx area code). Credit card numbers failing Luhn validation. |

### Special Cases

- **Git history-only findings**: Maintain the severity classification but add a note: "Found in git history only — will be eliminated by Phase 8 (History Flatten)."
- **Test/example files**: Findings in directories like `test/`, `tests/`, `spec/`, `examples/`, `docs/` or files named `*example*`, `*sample*`, `*mock*`, `*fixture*`, `*test*` are downgraded by one severity level (e.g., HIGH → MEDIUM), unless they contain SSNs or credit card numbers (which remain at their original severity).
- **Comments vs. code**: PII in code comments (not TODO/FIXME with names) is downgraded by one severity level compared to PII in executable code or config values.
- **License files**: Names in `LICENSE`, `LICENSE.md`, `LICENSE.txt` files are always skipped — these are intentional copyright attributions and should not be flagged.

## Step 2.5 — Finding Report Format

Each finding must be reported in this format:

```
### Finding P2-{N}: {brief description}

- **Severity**: {CRITICAL|HIGH|MEDIUM|LOW}
- **Category**: {pattern category from patterns/pii.md}
- **Location**: {file_path}:{line_number} (working tree) or commit {hash} in {file_path} (history) or git author metadata (for Sub-agent C findings)
- **Matched Pattern**: {the regex or check that matched}
- **Matched Value**: {the value, partially redacted — see redaction rules below}
- **Context**: {1-2 lines of surrounding code for context}
- **Remediation**: {proposed fix — see Step 2.6}
```

Number findings sequentially as `P2-1`, `P2-2`, etc. (P2 = PII Phase 2).

**Value redaction rules**:
- **Email addresses**: Show domain only — `****@gmail.com`
- **Phone numbers**: Mask middle digits — `(555) ***-4567`
- **SSNs**: Mask first 5 digits — `***-**-6789`
- **Credit card numbers**: Show last 4 digits only — `****-****-****-4242`
- **Physical addresses**: Show city/state only — `****, San Francisco, CA ****`
- **IP addresses**: Show full IP (IPs are infrastructure data, not personal; redaction would hinder debugging)
- **Names**: Show full name (names in code are already semi-public within the codebase context; redacting would make findings unactionable)
- **Employee IDs**: Mask all but last 2 characters — `****78`

## Step 2.6 — Remediation Proposals

For each finding, propose a **surgical remediation** tailored to the PII type and context:

### Personal Email Addresses in Source Code
1. Replace with a generic/noreply address: `noreply@example.com`, `support@projectname.com`, or an environment variable.
2. If the email is used for notifications/alerts, extract to an environment variable appropriate to the language (following the same convention as Phase 1 Step 1.5).
3. If the email is in a comment or documentation, replace with `user@example.com` or remove entirely.

### Git Author/Committer Emails
1. Configure the local repo to use a noreply address going forward:
   ```bash
   git config user.email "username@users.noreply.github.com"
   ```
2. For historical commits, note that Phase 8 (History Flatten) will eliminate all historical author metadata if the user chooses to flatten.
3. If the user opts not to flatten, recommend creating a `.mailmap` file and using `git filter-repo --mailmap .mailmap` to rewrite historical author emails.

### Phone Numbers
1. Replace with a placeholder: `+1 (555) 000-0000` or `PHONE_PLACEHOLDER`.
2. If used in test data, replace with a clearly fake number using the 555 area code (reserved for fictional use in North America).
3. If used in production code, extract to an environment variable.

### Physical/Mailing Addresses
1. Replace with a generic placeholder: `123 Example Street, Anytown, ST 00000`.
2. If in test/fixture data, replace with clearly fictional address data.
3. If in production code (e.g., business address for API calls), extract to environment variable or config.

### Public IP Addresses
1. Replace hardcoded IPs with hostnames or environment variables where possible.
2. If in configuration, extract to environment variable.
3. If in documentation/examples, replace with RFC 5737 documentation range IPs: `192.0.2.1`, `198.51.100.1`, or `203.0.113.1`.

### SSNs and Credit Card Numbers
1. **Immediately redact** from source code — replace with clearly fake values.
2. SSN replacement: `000-00-0000` (the standard placeholder).
3. Credit card replacement: `4242424242424242` (Stripe test card) or `4111111111111111` (generic test Visa).
4. If in test data, ensure the test still passes with the fake value, or use a test-framework-specific mechanism to generate test data.

### Internal Employee Identifiers (TODO/FIXME names, Jira references, Slack channels)
1. **TODO/FIXME with names**: Remove the name — change `TODO(jsmith): refactor` to `TODO: refactor`.
2. **Jira ticket references**: Remove or generalize — change `// See PROJ-1234 for details` to `// See issue tracker for details` or remove the comment entirely.
3. **Slack channel references**: Remove or generalize — change `// Ask in #internal-backend` to `// Ask the backend team`.
4. **Employee IDs in code/config**: Replace with placeholders or remove.

### Hardcoded Personal Names
1. **Test data/fixtures**: Replace with obviously fictional names: "Alice Example", "Bob Test", "Test User 1".
2. **File headers/attributions**: Remove author attributions or replace with project name: `// Maintained by the ProjectName contributors`.
3. **Database seeds**: Replace with fictional names and note in the seed file that names are placeholders.
4. **Comments**: Remove the personal name or replace with a role: `// Per the security team's recommendation` instead of `// Per John's recommendation`.

### Git History-Only Findings
No immediate remediation in the working tree is needed. Note that:
- Phase 8 (History Flatten) will eliminate these findings by squashing all history into a single commit.
- If the user chooses NOT to flatten history, recommend running `git filter-repo` to remove specific PII from history.

## Step 2.7 — Consolidate and Present Findings

After all three sub-agents complete, consolidate all findings:

1. **Merge**: Combine findings from Sub-agent A (working tree), Sub-agent B (git history), and Sub-agent C (git author metadata).
2. **Deduplicate**: If both the working-tree scan and history scan found the same PII (same value in the same file), keep only the working-tree finding and add a note that it also appears in history.
3. **Apply allowlist**: Remove any remaining allowlisted values that may have slipped through sub-agent filtering.
4. **Sort by severity**: CRITICAL first, then HIGH, MEDIUM, LOW.
5. **Number sequentially**: Assign finding IDs P2-1 through P2-N.

Present the **Phase Summary** (per the Phase-Gating Interaction Model):

```
## Phase 2 Summary — PII Audit

**Findings**: {total} total ({critical} critical, {high} high, {medium} medium, {low} low)
- Working tree: {N} findings
- Git history only: {N} findings
- Git author metadata: {N} email(s) flagged

### Key Highlights
1. {Most critical finding — brief description}
2. {Second most critical finding}
3. {Third most critical finding}
{...up to 5 highlights}

### PII Categories Detected
- Email addresses: {N} findings
- Phone numbers: {N} findings
- Physical addresses: {N} findings
- IP addresses: {N} findings
- SSNs: {N} findings
- Credit card numbers: {N} findings
- Internal identifiers: {N} findings
- Hardcoded names: {N} findings

### Proposed Actions
- {N} value replacements with placeholders/env vars
- {N} test data anonymizations
- {N} comment/attribution removals
- {N} git config changes recommended
- {N} history-only findings (resolved by Phase 8)
```

## User Gate

> "Phase 2 (PII Audit) complete. Choose one:
> - **Approve and continue** — Accept findings and move to Phase 3 (Dependency Audit)
> - **Review details** — Show all findings with full details
> - **Apply remediations** — Apply the proposed fixes now (will ask for confirmation on each)
> - **Request changes** — Re-scan specific patterns or adjust severity classifications
> - **Skip** — Mark Phase 2 as skipped and move on"

**Do NOT advance to Phase 3 until the user explicitly responds.**

## Step 2.8 — Apply Remediations (If Approved)

If the user chooses "Apply remediations", present each remediation individually and ask for approval before applying:

1. Show the specific change (old code → new code) for each finding.
2. Wait for user approval on each change.
3. Apply approved changes using the Edit tool.
4. For git config changes (author email), run the `git config` command only after user approval.
5. After all approved changes are applied, run a quick re-scan of modified files to verify no regressions were introduced and no new PII was accidentally added.
6. Present a summary of what was changed.

## Step 2.9 — Update STATE

After Phase 2 is complete (whether findings were remediated or not), update the STATE block:

```
STATE:
  phase: 3
  project_root: {absolute path}
  prep_branch: oss-prep/ready
  project_profile:
    language: {from Phase 0}
    framework: {from Phase 0}
    package_manager: {from Phase 0}
    build_system: {from Phase 0}
    test_framework: {from Phase 0}
  findings:
    total: {cumulative total from Phases 1 + 2}
    critical: {cumulative critical}
    high: {cumulative high}
    medium: {cumulative medium}
    low: {cumulative low}
  phases_completed: [0, 1, 2]
  history_flattened: false
```

> **Note**: The state update is an orchestrator responsibility. The orchestrator also sets `phase_findings["2"]` with per-phase counts and `status: "completed"` (or `"skipped"`). This phase file documents the expected state change for reference.

Announce:
> "Phase 2 (PII Audit) complete. Moving to Phase 3 — Dependency Audit."

Wait for user approval before beginning Phase 3 (per the Phase-Gating Interaction Model).
