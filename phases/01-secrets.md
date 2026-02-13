# Phase 1 — Secrets & Credentials Audit

- **Phase**: 1
- **Name**: Secrets & Credentials Audit
- **Inputs**: `project_root`, `project_profile` (from state), `patterns/secrets.md`
- **Outputs**: findings list (S1-1 through S1-N), finding counts by severity, remediated files (if Apply remediations chosen), state update (`phase: 2`, cumulative findings, `phases_completed` adds `1`)

---

Phase 1 scans both the current working tree and full git history for secrets, credentials, API keys, tokens, passwords, and private keys. It classifies each finding by severity using pattern confidence and entropy heuristics, proposes surgical remediations, and presents everything for user approval before any changes are made.

## Step 1.1 — Dispatch Parallel Sub-Agents

Launch **two sub-agents simultaneously** via the Task tool (both with `model: "opus"`):

- **Sub-agent A — Working Tree Scan**: Scans all tracked files in the current working tree using Grep with the pattern library.
- **Sub-agent B — Git History Scan**: Scans the full git history for secrets that were committed and later removed.

Provide each sub-agent with:
- The current STATE block
- The `project_root` path
- The full pattern library (read `patterns/secrets.md` and include its contents in the sub-agent prompt)
- Instructions to report findings in the standard format (see Step 1.4)
- The Grounding Requirement — every finding must include file path + line number (Sub-agent A) or commit hash + file path (Sub-agent B)

Wait for **both sub-agents to complete** before proceeding to consolidation.

### Sub-Agent A — Working Tree Scan Instructions

For each pattern category in the pattern library, run a Grep search across all tracked files. For each match:
1. Record the file path and line number.
2. Extract the matched value (the credential/secret portion, not the entire line).
3. Classify the severity using the rules in Step 1.3.
4. Skip binary files and files matching: `*.png`, `*.jpg`, `*.gif`, `*.ico`, `*.woff`, `*.woff2`, `*.ttf`, `*.eot`, `*.mp4`, `*.mp3`, `*.zip`, `*.tar.gz`, `*.jar`, `*.pyc`, `*.so`, `*.dylib`, `*.dll`.

For `.env` files specifically: scan for ALL `KEY=value` pairs where the value is non-empty, not a comment, and not an obvious placeholder.

### Sub-Agent B — Git History Scan Instructions

Run the following to extract diffs from the entire history:
```bash
git log -p --all --diff-filter=D -- .
```
This shows content from deleted files. Additionally, run:
```bash
git log -p --all -S "PATTERN" -- .
```
for the highest-priority patterns (AWS keys, GitHub tokens, PEM headers, database URIs) to find secrets that were added and then modified or removed.

For each match:
1. Record the commit hash, author, date, and file path.
2. Extract the matched value.
3. Classify the severity using the rules in Step 1.3.
4. Note whether the secret still exists in the current working tree or was only in history.

## Step 1.2 — Secret Pattern Library

Read `patterns/secrets.md` for the complete 11-category secret detection pattern library.

The pattern library covers: AWS Credentials, GCP Credentials, Azure Credentials, GitHub Tokens, Generic API Keys and Tokens, Database Connection Strings, Private Keys (PEM Format), JWT & OAuth, SMTP Credentials, .env File Contents, and Vendor-Specific Tokens.

## Step 1.3 — Severity Classification

Classify each finding using a combination of pattern confidence and Shannon entropy of the matched value.

### Entropy Calculation

For each matched value (the credential portion, not the key name), compute Shannon entropy:

```
H = -Σ (p(c) × log₂(p(c))) for each unique character c in the value
```

Where `p(c)` is the frequency of character `c` divided by the total length.

Entropy thresholds (bits per character):
- **High entropy**: H > 3.5 — likely a real credential
- **Moderate entropy**: 2.0 < H ≤ 3.5 — possibly real, possibly structured
- **Low entropy**: H ≤ 2.0 — likely a placeholder or dummy value

### Classification Rules

| Severity | Criteria |
|----------|----------|
| **CRITICAL** | Confirmed credential pattern (AWS key, PEM private key, GitHub token with valid prefix) AND high entropy (H > 3.5). OR any PEM-format private key (regardless of entropy). |
| **HIGH** | Pattern match in a non-example context (file is not in `test/`, `tests/`, `spec/`, `examples/`, `docs/` and filename does not contain `example`, `sample`, `mock`, `fixture`, `dummy`, `test`) AND moderate-to-high entropy (H > 2.0). |
| **MEDIUM** | Pattern match but low entropy (H ≤ 2.0), OR value matches known placeholder patterns: `YOUR_*_HERE`, `xxx`, `changeme`, `TODO`, `FIXME`, `placeholder`, `replace_me`, `insert_*_here`, `<REDACTED>`, `dummy`, `fake`, `test`. |
| **LOW** | Pattern match in an example/documentation file (README, docs/, examples/), OR value is an obvious dummy (e.g., `password`, `secret`, `12345`, `abcdef`), OR the match is in a code comment explaining a pattern rather than setting a value. |

### Special Cases

- **Encrypted private keys** (`BEGIN ENCRYPTED PRIVATE KEY`): Classify as MEDIUM (encrypted, lower risk but still worth noting).
- **Git history-only findings**: If the secret no longer exists in the working tree but was found in git history, maintain the severity classification but add a note: "Found in git history only — will be eliminated by Phase 8 (History Flatten)."
- **`.env.example` files**: Always classify as LOW — these files are intentionally committed with placeholder values.
- **Lock files** (`package-lock.json`, `yarn.lock`, `Cargo.lock`, etc.): Skip entirely — these contain integrity hashes, not secrets.

## Step 1.4 — Finding Report Format

Each finding must be reported in this format:

```
### Finding S1-{N}: {brief description}

- **Severity**: {CRITICAL|HIGH|MEDIUM|LOW}
- **Category**: {pattern category from Step 1.2}
- **Location**: {file_path}:{line_number} (working tree) or commit {hash} in {file_path} (history)
- **Matched Pattern**: {the regex that matched}
- **Matched Value**: {the value, partially redacted — show first 4 and last 4 chars, mask middle with asterisks}
- **Entropy**: {H value, rounded to 2 decimal places} bits/char
- **Context**: {1-2 lines of surrounding code for context}
- **Remediation**: {proposed fix — see Step 1.5}
```

Number findings sequentially as `S1-1`, `S1-2`, etc. (S1 = Secrets Phase 1).

**Value redaction rule**: Always partially redact matched values. For values ≤8 characters, show only first 2 and last 2 characters. For values >8 characters, show first 4 and last 4 characters. Replace middle characters with asterisks. Example: `ghp_abc1****xyz9`.

## Step 1.5 — Remediation Proposals

For each finding, propose a **surgical remediation** — never propose deleting entire files. Match the remediation type to the finding:

### Hardcoded Credential in Source Code
Propose replacing the hardcoded value with an environment variable reference appropriate to the project's language:
- **JavaScript/TypeScript**: `process.env.VARIABLE_NAME`
- **Python**: `os.environ['VARIABLE_NAME']` or `os.getenv('VARIABLE_NAME')`
- **Ruby**: `ENV['VARIABLE_NAME']`
- **Go**: `os.Getenv("VARIABLE_NAME")`
- **Rust**: `std::env::var("VARIABLE_NAME")`
- **Java**: `System.getenv("VARIABLE_NAME")`
- **PHP**: `getenv('VARIABLE_NAME')`
- **Shell**: `$VARIABLE_NAME`

Include a suggested environment variable name derived from the key name (e.g., `api_key = "abc"` → `API_KEY`).

### `.env` File with Real Credentials
1. Add `.env` (and variants like `.env.local`, `.env.production`) to `.gitignore` if not already present.
2. Create a `.env.example` file with the same keys but placeholder values (e.g., `DATABASE_URL=your_database_url_here`).
3. Redact the real values in the committed `.env` file or remove it from tracking entirely.

### Private Key Files
1. Add the key file path to `.gitignore`.
2. Remove the file from git tracking (`git rm --cached {path}`).
3. Note: Do NOT delete the file from the filesystem — just stop tracking it.

### Git History-Only Findings
No immediate remediation in the working tree is needed. Note that:
- Phase 8 (History Flatten) will eliminate these findings by squashing all history into a single commit.
- If the user chooses NOT to flatten history, recommend running `git filter-repo` or `BFG Repo-Cleaner` to remove specific secrets from history.

### Config Files with Embedded Secrets
1. Extract secret values to environment variables.
2. Update the config file to read from environment variables.
3. Add a comment in the config file noting the required environment variable.

## Step 1.6 — Opportunistic Tool Detection

Before running the built-in scan, check if additional security scanning tools are available:

```bash
command -v trufflehog 2>/dev/null && echo "trufflehog available" || echo "trufflehog not found"
command -v gitleaks 2>/dev/null && echo "gitleaks available" || echo "gitleaks not found"
```

### If `trufflehog` is available:
Run it as a supplementary scan:
```bash
trufflehog filesystem --directory=. --no-update --json 2>/dev/null
trufflehog git file://. --no-update --json 2>/dev/null
```
Parse the JSON output and merge any new findings (not already caught by built-in patterns) into the results. Mark these findings with "Source: trufflehog" in the report.

### If `gitleaks` is available:
Run it as a supplementary scan:
```bash
gitleaks detect --source=. --report-format=json --report-path=/tmp/gitleaks-report.json 2>/dev/null
```
Parse the JSON output and merge any new findings into the results. Mark these findings with "Source: gitleaks" in the report.

### If neither tool is available:
Proceed with only the built-in pattern scan. Do NOT warn the user or suggest installing these tools — the built-in scan is sufficient. Simply note in the phase summary: "Scanned using built-in pattern library."

## Step 1.7 — Consolidate and Present Findings

After both sub-agents complete, consolidate all findings:

1. **Deduplicate**: If both the working-tree scan and history scan found the same secret (same value in the same file), keep only the working-tree finding and add a note that it also appears in history.
2. **Sort by severity**: CRITICAL first, then HIGH, MEDIUM, LOW.
3. **Number sequentially**: Assign finding IDs S1-1 through S1-N.

Present the **Phase Summary** (per the Phase-Gating Interaction Model):

```
## Phase 1 Summary — Secrets & Credentials Audit

**Scan method**: {Built-in pattern library | Built-in + trufflehog | Built-in + gitleaks | Built-in + trufflehog + gitleaks}

**Findings**: {total} total ({critical} critical, {high} high, {medium} medium, {low} low)
- Working tree: {N} findings
- Git history only: {N} findings

### Key Highlights
1. {Most critical finding — brief description}
2. {Second most critical finding}
3. {Third most critical finding}
{...up to 5 highlights}

### Proposed Actions
- {N} environment variable replacements
- {N} .gitignore additions
- {N} files to remove from tracking
- {N} history-only findings (resolved by Phase 8)
```

Then present the user approval gate:
> "Phase 1 (Secrets Audit) complete. Choose one:
> - **Approve and continue** — Accept findings and move to Phase 2 (PII Audit)
> - **Review details** — Show all findings with full details
> - **Apply remediations** — Apply the proposed fixes now (will ask for confirmation on each)
> - **Request changes** — Re-scan specific patterns or adjust severity classifications
> - **Skip** — Mark Phase 1 as skipped and move on"

**Do NOT advance to Phase 2 until the user explicitly responds.**

> **Note**: The orchestrator presents this gate after the sub-agent returns its findings. The sub-agent should return consolidated findings and the phase summary to the orchestrator, which then presents them to the user and handles the gate interaction.

## Step 1.8 — Apply Remediations (If Approved)

If the user chooses "Apply remediations", present each remediation individually and ask for approval before applying:

1. Show the specific change (old code → new code) for each finding.
2. Wait for user approval on each change.
3. Apply approved changes using the Edit tool.
4. After all approved changes are applied, run a quick re-scan to verify no regressions were introduced.
5. Present a summary of what was changed.

## Step 1.9 — Update STATE

After Phase 1 is complete (whether findings were remediated or not), update the STATE block:

```
STATE:
  phase: 2
  project_root: {absolute path}
  prep_branch: oss-prep/ready
  project_profile:
    language: {from Phase 0}
    framework: {from Phase 0}
    package_manager: {from Phase 0}
    build_system: {from Phase 0}
    test_framework: {from Phase 0}
  findings:
    total: {cumulative total}
    critical: {cumulative critical}
    high: {cumulative high}
    medium: {cumulative medium}
    low: {cumulative low}
  phases_completed: [0, 1]
  history_flattened: false
```

> **Note**: The state update is an orchestrator responsibility. The orchestrator also sets `phase_findings["1"]` with per-phase counts and `status: "completed"` (or `"skipped"`). This phase file documents the expected state change for reference.

Announce:
> "Phase 1 (Secrets & Credentials Audit) complete. Moving to Phase 2 — PII Audit."

Wait for user approval before beginning Phase 2 (per the Phase-Gating Interaction Model).
