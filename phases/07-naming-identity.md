# Phase 7 — Naming, Trademark & Identity Review

- **Phase**: 7
- **Name**: Naming, Trademark & Identity Review
- **Inputs**: `state.project_root`, `state.project_profile` (language, framework, package_manager), `state.phases_completed`, `state.findings`, package manifest paths detected during execution
- **Outputs**: findings list (N7-1 through N7-N) with registry availability results, identity leak findings, and telemetry findings; state updates (`phase_findings` for phase 7, cumulative `findings` totals, `phases_completed` adds `7`, `phase` advances to `8`)

---

Phase 7 is the final analysis phase before the destructive operations in Phase 8 (History Flatten). It focuses on identity — ensuring the public-facing project does not inadvertently expose its private origins, conflict with existing public packages, or ship undisclosed telemetry. It covers package name availability checking (FR-37), internal identity leak scanning (FR-38), telemetry and analytics detection (FR-39), and remediation suggestions with severity classification (FR-40).

**No sub-agent parallelization** is needed for this phase. The name availability check uses `curl` HTTP API calls and `gh` CLI checks (which are fast and deterministic), and identity/telemetry scanning uses Grep (which is fast). Running these sequentially in the main thread is simpler and avoids unnecessary overhead.

## Step 7.1 — Package Name Availability Check (FR-37)

Determine the project's published package name(s) and check availability on the relevant registries.

### 7.1.1 — Detect Package Manifests

Use Glob to check for the following manifest files in the project root:

| Manifest File | Registry | Name Field |
|---------------|----------|------------|
| `package.json` | npm (npmjs.com) | `name` |
| `pyproject.toml` | PyPI (pypi.org) | `[project].name` or `[tool.poetry].name` |
| `setup.py` / `setup.cfg` | PyPI (pypi.org) | `name` argument / `[metadata].name` |
| `Cargo.toml` | crates.io | `[package].name` |
| `*.gemspec` / `Gemfile` | RubyGems (rubygems.org) | `spec.name` |
| `go.mod` | Go modules (pkg.go.dev) | module path |

For each detected manifest:
1. Read the file and extract the package name from the appropriate field.
2. Record the manifest type, registry, and extracted name.

If **no package manifest exists**, use the repository directory name (basename of `project_root`) as the candidate name and check it against npm, PyPI, and crates.io (the three most common registries).

### 7.1.2 — Check Name Availability on Registries

For each package name / registry pair identified above, use direct HTTP API calls via `curl` to check if the name is already taken. Each API returns an unambiguous HTTP status code: **200 = taken**, **404 = available**.

**Registry API Calls**:

```bash
# npm — 200=taken, 404=available
curl -s -o /dev/null -w "%{http_code}" "https://registry.npmjs.org/{name}"

# PyPI — 200=taken, 404=available
curl -s -o /dev/null -w "%{http_code}" "https://pypi.org/pypi/{name}/json"

# crates.io — 200=taken, 404=available (requires User-Agent header)
curl -s -o /dev/null -w "%{http_code}" -H "User-Agent: oss-prep" "https://crates.io/api/v1/crates/{name}"

# RubyGems — 200=taken, 404=available
curl -s -o /dev/null -w "%{http_code}" "https://rubygems.org/api/v1/gems/{name}.json"

# Go modules — 200=taken, 404=available
curl -s -o /dev/null -w "%{http_code}" "https://proxy.golang.org/{module}/@latest"
```

**GitHub Namespace Checks** (FR-28):

Use the `gh` CLI to check GitHub user/org and repo availability:

```bash
# GitHub user/org — 200=exists, 404=available
gh api /users/{name} 2>/dev/null

# GitHub repo — 200=exists, 404=available
gh api /repos/{owner}/{repo} 2>/dev/null
```

The GitHub user/org check verifies whether the desired namespace owner exists. The repo check verifies whether the specific `owner/repo` combination is taken. Both are relevant for Phase 10 (Launch Automation) planning.

**Domain Availability Check** (FR-29):

Use RDAP (Registration Data Access Protocol) to check `.com` domain availability:

```bash
# .com domain — 200=registered, 404=available
curl -s -o /dev/null -w "%{http_code}" "https://rdap.verisign.com/com/v1/domain/{name}.com"
```

> **Note**: This covers `.com` domains only. Other TLDs (`.dev`, `.io`, `.org`) use different RDAP servers. `.com` is checked as the most common starting point; additional TLDs can be checked manually if needed.

**Excluded Checks** (NG-10): Twitter/X (requires paid API access) and Mastodon (federated architecture with no central registry) are **not checked**. These platforms cannot be reliably queried via free, deterministic API calls.

For each check, record one of:
- **Available**: HTTP 404 — no existing package/namespace/domain found.
- **Taken** / **Registered**: HTTP 200 — an existing package, namespace, or domain registration was found.
- **Could not verify**: `curl` or `gh` command failed (timeout, DNS error, non-200/404 status code, authentication error).

### 7.1.3 — Classify Name Availability Findings

| Result | Severity | Effort Tag | Finding |
|--------|----------|------------|---------|
| Name is taken on a registry | MEDIUM | `[Decision needed]` | "Package name `{name}` is already taken on {registry}. Consider renaming if you intend to publish to this registry." |
| GitHub user/org exists | — | — | Informational — the namespace exists but the repo name may still be available. No finding generated unless the repo is also taken. |
| GitHub repo exists | MEDIUM | `[Decision needed]` | "Repository `{owner}/{repo}` already exists on GitHub. Consider an alternative repo name or org." |
| Domain is registered | MEDIUM | `[Decision needed]` | "Domain `{name}.com` is already registered. Consider alternative TLDs (`.dev`, `.io`) or a different name." |
| Name/namespace could not be verified | MEDIUM | `[Quick fix]` | "Could not verify availability for `{name}` on {platform} — manual check recommended." |
| Name is available | — | — | No finding generated (positive result, noted in summary) |

Number findings sequentially as `N7-1`, `N7-2`, etc. (N7 = Naming Phase 7). Each finding uses the format: `N7-{N} [{effort}] ({SEVERITY}): {description}`. See SKILL.md for the canonical effort tag definitions and structured finding format.

### 7.1.4 — Graceful Degradation

If any `curl` or `gh` command fails during registry, GitHub, or domain checks:

**`curl` failure modes**:
- **Timeout / DNS error**: The `curl` command exits with a non-zero exit code before returning an HTTP status. Record as "Could not verify."
- **Unexpected HTTP status** (not 200 or 404): The registry returned an unexpected response (e.g., 403 rate-limited, 500 server error, 301 redirect). Record as "Could not verify."

**`gh api` failure modes**:
- **Not authenticated**: `gh` is not logged in or the token is expired. Record as "Could not verify — GitHub CLI not authenticated."
- **Rate limited**: GitHub API returned 403 or 429. Record as "Could not verify — GitHub API rate limited."
- **Network error**: `gh` command exits with a non-zero exit code. Record as "Could not verify."

For each failure:
1. Record the finding as "Could not verify availability for `{name}` on {platform} — manual check recommended" with MEDIUM severity and effort tag `[Quick fix]`.
2. Continue with the remaining checks — do **not** block the phase on individual failures.
3. Include a note in the phase summary indicating which platforms could not be verified.

## Step 7.2 — Internal Identity Leak Scanning (FR-38)

Scan the entire working tree for references that reveal the project's private/internal origins. These are references that should not appear in a public repository.

### 7.2.1 — Identity Leak Pattern Library

Scan for the following categories using Grep across all tracked files. Exclude binary files and directories matching: `node_modules`, `vendor`, `.git`, `dist`, `build`, `__pycache__`, `*.pyc`, `*.min.js`, `*.min.css`.

**Category 1 — Internal URLs (CRITICAL)**

Search for URL patterns that reference internal infrastructure:

| Pattern | Regex | Severity |
|---------|-------|----------|
| Internal subdomains | `https?://[a-zA-Z0-9._-]+\.(internal\|corp\|local\|intranet\|private\|staging\|dev)\.[a-zA-Z0-9.-]+` | CRITICAL |
| Internal hostnames (no TLD) | `https?://[a-zA-Z0-9-]+(\.internal\|\.corp\|\.local)\b` | CRITICAL |
| VPN/private network URLs | `https?://(vpn\|intranet\|wiki\|dashboard\|portal\|admin)\.[a-zA-Z0-9.-]+` | CRITICAL |
| Private IP in URLs | `https?://(10\.\d{1,3}\.\d{1,3}\.\d{1,3}\|172\.(1[6-9]\|2\d\|3[01])\.\d{1,3}\.\d{1,3}\|192\.168\.\d{1,3}\.\d{1,3})` | CRITICAL |

**Category 2 — Jira / Confluence / Project Tracker Links (MEDIUM)**

| Pattern | Regex | Severity |
|---------|-------|----------|
| Jira issue links | `https?://[a-zA-Z0-9.-]+\.(atlassian\.net\|jira\.[a-zA-Z0-9.-]+)/browse/[A-Z]+-\d+` | MEDIUM |
| Jira board/project links | `https?://[a-zA-Z0-9.-]+\.(atlassian\.net\|jira\.[a-zA-Z0-9.-]+)/(projects\|boards\|issues)` | MEDIUM |
| Confluence links | `https?://[a-zA-Z0-9.-]+\.(atlassian\.net\|confluence\.[a-zA-Z0-9.-]+)/(display\|wiki\|spaces)` | MEDIUM |
| Linear issue links | `https?://linear\.app/[a-zA-Z0-9-]+/issue/[A-Z]+-\d+` | MEDIUM |
| Shorthand issue refs in comments | `(TODO\|FIXME\|HACK\|XXX):?\s*[A-Z]{2,10}-\d{1,6}\b` | MEDIUM |

**Category 3 — Slack / Internal Communication References (MEDIUM)**

| Pattern | Regex | Severity |
|---------|-------|----------|
| Slack workspace URLs | `https?://[a-zA-Z0-9-]+\.slack\.com/(archives\|channels\|messages)` | MEDIUM |
| Slack channel references | `#[a-z][a-z0-9_-]{2,}-(team\|internal\|private\|dev\|eng\|ops\|infra)\b` | MEDIUM |
| Teams/Discord links | `https?://(teams\.microsoft\.com\|discord\.(gg\|com))/[a-zA-Z0-9/]+` | MEDIUM |

**Category 4 — Company / Team Name References (HIGH)**

This category requires context from Phase 0. Before scanning, determine potential company/team identifiers:

1. Check git remote URLs for organization names: `git remote -v` — extract the org/owner from GitHub/GitLab/Bitbucket URLs.
2. Check package manifest files for organization scopes (e.g., `@company/` in package.json, org name in Python package namespace).
3. Check existing LICENSE or NOTICE files for company names in copyright lines.

Once company/team identifiers are collected, scan for:

| Pattern | What to Search | Severity |
|---------|---------------|----------|
| Company name in code comments | Grep for the identified company/org name in `*.{js,ts,py,rb,go,rs,java,kt,swift,c,cpp,h}` files | HIGH |
| Company name in configs | Grep for the company/org name in `*.{json,yaml,yml,toml,xml,ini,cfg,env.example}` files | HIGH |
| Team name references | Grep for patterns like `{company}-team`, `team-{name}`, or `@{company}` in all text files | HIGH |
| Internal tool names | Grep for known internal tool/service names if identifiable from configs or imports | HIGH |

**Important**: Only flag matches that are clearly internal references. Generic terms that happen to match a company name (e.g., "apple" in a fruit-related project) should be manually reviewed, not automatically flagged. When in doubt, flag with a note: "Verify this is an internal reference."

### 7.2.2 — Classify Identity Leak Findings

For each match found:
1. Record the **file path** and **line number**.
2. Record the **matched content** (the specific text that matched).
3. Assign severity per the tables above.
4. Assign an **effort tag** based on the finding's nature (see guidance below).
5. Generate a specific **remediation suggestion**:

| Category | Effort Tag | Remediation |
|----------|------------|-------------|
| Internal URLs | `[Quick fix]` | "Remove or replace with a placeholder URL (e.g., `https://example.com`). If this URL is needed for local development, move it to an environment variable or `.env.example` file." |
| Jira/Confluence links | `[Quick fix]` | "Remove the tracker reference. Replace with a generic description of the issue or link to a public issue tracker once available." |
| Slack/Teams references | `[Quick fix]` | "Remove the internal channel reference. Replace with a public communication channel (e.g., GitHub Discussions link) if applicable." |
| Company/team names in comments | `[Quick fix]` | "Generalize the reference. Replace `{company} team` with `the maintainers` or `the development team`. Remove company name from code comments." |
| Company/team names in config | `[Quick fix]` | "Replace with a generic name or the intended public project/org name." |
| Identity references found **only in git history** (not in working tree) | `[Deferred -> Phase 8]` | "Will be resolved by Phase 8 (History Flatten). This reference exists in git history but not in the current working tree." |

**Deferred Finding Format**: Internal identity references found **only in git history** (not in the current working tree) MUST:
- Use effort tag `[Deferred -> Phase 8]`
- Include `deferred_to: 8` in the structured finding output
- Note "Will be resolved by Phase 8 (History Flatten)" in the remediation
- These findings cannot be resolved by editing files — they exist only in historical commits and require the Phase 8 flatten to eliminate

The sub-agent structured output format for each finding includes the `deferred_to` field (integer or null). For deferred findings, set `deferred_to: 8`. For all other findings, set `deferred_to: null`.

Number findings sequentially continuing from Step 7.1: `N7-{next}`, `N7-{next+1}`, etc.

## Step 7.3 — Telemetry and Analytics Detection (FR-39)

Scan for code that collects or transmits usage data. Telemetry is not inherently bad — the goal is to ensure it is disclosed or intentionally removed before public release.

### 7.3.1 — Known Analytics SDK Detection (HIGH Confidence)

Search for imports, requires, or package references of known analytics/tracking libraries. Use Grep to search source files (`*.{js,ts,jsx,tsx,py,rb,go,rs,java,kt,swift}`) and package manifests.

**JavaScript / TypeScript SDKs**:

| SDK | Import/Require Patterns | npm Package Names |
|-----|------------------------|-------------------|
| Segment | `@segment/analytics-next`, `analytics-node`, `@segment/analytics-node` | `@segment/analytics-next`, `analytics-node` |
| Mixpanel | `mixpanel`, `mixpanel-browser` | `mixpanel`, `mixpanel-browser` |
| Amplitude | `@amplitude/analytics-browser`, `@amplitude/analytics-node`, `amplitude-js` | `@amplitude/analytics-browser`, `amplitude-js` |
| Google Analytics | `react-ga`, `react-ga4`, `ga-4-react`, `gtag.js`, `analytics.js` | `react-ga`, `react-ga4` |
| Heap | `heap-api`, `@heap/heap-node` | `heap-api` |
| PostHog | `posthog-js`, `posthog-node` | `posthog-js`, `posthog-node` |
| Matomo | `@datapunt/matomo-tracker-react`, `matomo-tracker` | `matomo-tracker` |
| LaunchDarkly | `launchdarkly-js-client-sdk`, `launchdarkly-node-server-sdk` | `launchdarkly-js-client-sdk` |
| Datadog RUM | `@datadog/browser-rum`, `dd-trace` | `@datadog/browser-rum`, `dd-trace` |
| Sentry | `@sentry/browser`, `@sentry/node`, `@sentry/react` | `@sentry/browser`, `@sentry/node` |
| Fullstory | `@fullstory/browser` | `@fullstory/browser` |
| LogRocket | `logrocket` | `logrocket` |
| Hotjar | `react-hotjar`, `@hotjar/browser` | `react-hotjar` |

**Python SDKs**:

| SDK | Import Patterns | PyPI Package Names |
|-----|----------------|-------------------|
| Segment | `import analytics`, `from analytics import` | `analytics-python` |
| Mixpanel | `import mixpanel`, `from mixpanel import` | `mixpanel` |
| Amplitude | `from amplitude import` | `amplitude-analytics` |
| Sentry | `import sentry_sdk` | `sentry-sdk` |
| PostHog | `from posthog import` | `posthog` |
| Datadog | `from ddtrace import`, `import datadog` | `ddtrace`, `datadog` |

Also check package manifests (`package.json` dependencies/devDependencies, `pyproject.toml` dependencies, `requirements*.txt`, `Cargo.toml` dependencies, `Gemfile`, `go.mod`) for any of the above package names.

Each confirmed SDK match is a **HIGH** severity finding.

### 7.3.2 — Custom Telemetry Indicator Detection (MEDIUM Confidence)

Search for patterns that suggest custom/homegrown tracking code. These have a higher false-positive rate, so findings are classified as MEDIUM severity.

**Function/Method Name Patterns** — Use Grep to search for definitions (not just calls) of:

| Pattern | Regex |
|---------|-------|
| Event tracking functions | `(function\|def\|fn\|func)\s+(trackEvent\|track_event\|sendAnalytics\|send_analytics\|reportUsage\|report_usage\|logEvent\|log_event\|captureEvent\|capture_event\|recordMetric\|record_metric)\b` |
| Telemetry class/module definitions | `(class\|module\|struct)\s+(Telemetry\|Analytics\|Tracking\|UsageReporter\|MetricsCollector)\b` |

**Telemetry Config Patterns**:

| Pattern | Regex |
|---------|-------|
| Telemetry config references | `(telemetry\|analytics\|tracking\|metrics)[_.]?(enabled\|disabled\|endpoint\|url\|key\|id\|token)\b` |

**Outbound Data Transmission Patterns** — Search for HTTP calls to hardcoded non-public URLs that suggest phone-home behavior:

| Pattern | Regex | Notes |
|---------|-------|-------|
| Hardcoded tracking endpoints | `(fetch\|axios\|requests\.(get\|post)\|http\.(Get\|Post)\|HttpClient)\s*\(?\s*['"\x60]https?://[^'"\x60\s]+/(track\|collect\|analytics\|telemetry\|metrics\|events\|beacon\|report)` | Matches HTTP calls to tracking-like endpoints |
| Pixel/beacon patterns | `new\s+Image\(\)\.src\s*=\|navigator\.sendBeacon\(` | Common browser tracking techniques |

**Important**: Custom telemetry detection has a higher false-positive rate. For each match, include a note: "This may be a false positive — review the surrounding code to confirm whether this is actual telemetry/tracking behavior."

### 7.3.3 — Classify Telemetry Findings

For each telemetry match:
1. Record the **file path** and **line number**.
2. Record the **matched content**.
3. Assign severity:
   - **HIGH** for known analytics SDK imports/dependencies.
   - **MEDIUM** for custom telemetry indicators (higher false-positive rate).
4. Assign an **effort tag**: all telemetry findings use `[Decision needed]` because the user must choose between disclosing or removing the telemetry.
5. Generate a remediation suggestion:

| Finding Type | Effort Tag | Remediation |
|-------------|------------|-------------|
| Known analytics SDK in dependencies | `[Decision needed]` | "This project uses {SDK name} for analytics/tracking. Before public release, choose one: (a) **Disclose** — Add a 'Telemetry' section to README documenting what data is collected, where it is sent, and how users can opt out. (b) **Remove** — Remove the SDK and all references to it." |
| Known analytics SDK import in code | `[Decision needed]` | "Source file `{path}` imports {SDK name}. Ensure this is covered by a telemetry disclosure in README, or remove the import and associated tracking code." |
| Custom telemetry function | `[Decision needed]` | "Function `{name}` in `{path}` appears to implement custom tracking. Review whether this collects user data. If so, disclose in README or remove." |
| Outbound tracking endpoint | `[Decision needed]` | "HTTP call to a tracking-like endpoint in `{path}`. Review whether this transmits user data. If so, disclose in README or remove." |

Number findings continuing from the previous steps: `N7-{next}`, etc.

## Step 7.4 — Remediation Categories (FR-40)

All Phase 7 findings map to one of four remediation categories. Present these categories in the phase summary to help the user decide how to address each finding:

| Category | When to Use | Action |
|----------|-------------|--------|
| **Rename** | Package name conflicts on registries | Change the package name in the manifest file and update all internal references. |
| **Remove** | Internal identity leaks (URLs, tracker links, company names) and unwanted telemetry | Delete or replace the offending content with generic alternatives. Provide the specific file, line, and suggested replacement text. |
| **Disclose** | Intentional telemetry/analytics the user wants to keep | Add a "Telemetry" section to README.md documenting: what data is collected, where it is sent, how to opt out. Provide a template for this section. |
| **Acknowledge** | Findings the user reviews and decides are acceptable | User explicitly marks the finding as reviewed and acceptable. Record in the findings log as "Acknowledged — {reason}". |

### Telemetry Disclosure Template

When suggesting the "Disclose" remediation for telemetry findings, offer this template for the user's README:

```markdown
## Telemetry

This project collects anonymous usage data to help improve the software. The following data is collected:

- {describe what is collected}
- {describe what is collected}

Data is sent to {service/endpoint}.

### Opting Out

To disable telemetry, {describe how to opt out — e.g., set an environment variable, toggle a config flag, or remove the SDK}.
```

## Step 7.5 — Consolidate and Present Findings

After completing all analysis (name availability, identity leaks, telemetry), consolidate findings:

1. **Combine** all findings from Steps 7.1, 7.2, and 7.3.
2. **Sort by severity**: CRITICAL first, then HIGH, MEDIUM.
3. **Number sequentially**: Confirm finding IDs are N7-1 through N7-N.

### Namespace Availability Report (FR-30)

Present all registry, GitHub, and domain check results in a single consolidated table:

```
| Platform | Name | Status | Action |
|----------|------|--------|--------|
| npm | {name} | Available / Taken / Could not verify | Reserve with `npm init` / Consider alternative name / Manual check needed |
| PyPI | {name} | Available / Taken / Could not verify | Reserve with `twine` / Consider alternative name / Manual check needed |
| crates.io | {name} | Available / Taken / Could not verify | Reserve with `cargo publish` / Consider alternative name / Manual check needed |
| RubyGems | {name} | Available / Taken / Could not verify | Reserve with `gem push` / Consider alternative name / Manual check needed |
| Go modules | {module} | Available / Taken / Could not verify | Publish module / Consider alternative path / Manual check needed |
| GitHub user | {name} | Available / Taken / Could not verify | Can create org at github.com/organizations/new / Namespace exists / Manual check needed |
| GitHub repo | {owner}/{repo} | Available / Taken / Could not verify | Will be created in Phase 10 / Consider alternative name / Manual check needed |
| {name}.com | -- | Available / Registered / Could not verify | Can register domain / Consider .dev or .io / Manual check needed |
```

The **Status** column uses exactly one of: `Available`, `Taken`, `Registered`, or `Could not verify`.

Present the **Phase Summary** (per the Phase-Gating Interaction Model):

```
## Phase 7 Summary — Naming, Trademark & Identity Review

### Category Summary

| Category | Status | Count | Top Severity | Effort |
|----------|--------|-------|-------------|--------|
| Registry Availability | {Clean/Findings} | {N} | {MEDIUM/—} | {Decision needed/Quick fix/—} |
| GitHub Namespace | {Clean/Findings} | {N} | {MEDIUM/—} | {effort or —} |
| Domain Availability | {Clean/Findings} | {N} | {MEDIUM/—} | {effort or —} |
| Internal Identity Leaks | {Clean/Findings} | {N} | {CRITICAL/HIGH/MEDIUM/—} | {effort or —} |
| Telemetry/Analytics | {Clean/Findings} | {N} | {HIGH/MEDIUM/—} | {effort or —} |

**Package names checked**: {N} name(s) across {N} registries
**Name availability**: {N} available, {N} taken, {N} could not verify
**Identity leak scan**: {N} files scanned, {N} matches found
**Telemetry detection**: {N} known SDKs found, {N} custom telemetry indicators found
**Deferred to Phase 8**: {N} findings (identity references found only in git history)

**Findings**: {total} total ({critical} critical, {high} high, {medium} medium)

### Key Highlights
1. {Most critical finding — brief description}
2. {Second most critical finding}
3. {Third most critical finding}
{...up to 5 highlights}

### Findings by Category

| Category | Count | Severities |
|----------|-------|-----------|
| Registry name conflicts | {N} | {breakdown} |
| GitHub namespace conflicts | {N} | {breakdown} |
| Domain availability | {N} | {breakdown} |
| Internal identity leaks | {N} | {breakdown} |
| Telemetry / analytics | {N} | {breakdown} |

### Remediation Summary
- **Rename**: {N} findings suggest renaming
- **Remove**: {N} findings suggest removing internal references
- **Disclose**: {N} findings suggest adding telemetry disclosure
- **Acknowledge**: {N} findings available for acknowledgment
- **Deferred**: {N} findings deferred to Phase 8 (history-only references)
```

### Effort Classification Guidance (Phase 7)

- **`[Auto-fix]`**: Rare in Phase 7 — naming decisions inherently require human judgment. May apply to removing a single, unambiguous telemetry endpoint reference.
- **`[Quick fix]`**: Removing a single internal URL, Jira link, Slack reference, or company name from a code comment. Verifying name availability manually on a platform where the API check failed.
- **`[Decision needed]`**: Package name conflicts on registries requiring a rename decision, choosing between disclosing or removing telemetry, resolving ambiguous identity references that could be internal or public.
- **`[Deferred -> Phase 8]`**: Internal identity references found only in git history (not in the current working tree). These cannot be fixed by editing files — they require the Phase 8 history flatten to eliminate. The structured finding output includes `deferred_to: 8`.

Then present the user approval gate:
> "Phase 7 (Naming, Trademark & Identity Review) complete. Choose one:
> - **Approve and continue** — Accept findings and move to Phase 8 (History Flatten)
> - **Review details** — Show the full findings with file paths, line numbers, and remediation suggestions
> - **Request changes** — Re-scan specific categories or adjust severity classifications
> - **Skip** — Mark Phase 7 as skipped and move on"

**Do NOT advance to Phase 8 until the user explicitly responds.**

> **Note**: The orchestrator presents this gate after the sub-agent returns its findings. The sub-agent should return consolidated findings and the phase summary to the orchestrator, which then presents them to the user and handles the gate interaction.

## Step 7.6 — Update STATE

After Phase 7 is complete, update `.oss-prep/state.json`:

- Set `phase` to `8`
- Add `7` to `phases_completed` array
- Update `phase_findings["7"]` with this phase's finding counts and `status: "completed"`
- Update cumulative `findings` totals (add Phase 7 counts to existing totals from Phases 1-6)

Expected state shape after Phase 7:

```
{
  "phase": 8,
  "project_root": "{absolute path}",
  "prep_branch": "oss-prep/ready",
  "project_profile": {
    "language": "{from Phase 0}",
    "framework": "{from Phase 0}",
    "package_manager": "{from Phase 0}",
    "build_system": "{from Phase 0}",
    "test_framework": "{from Phase 0}"
  },
  "findings": {
    "total": "{cumulative total from Phases 1 + 2 + 3 + 4 + 5 + 6 + 7}",
    "critical": "{cumulative critical}",
    "high": "{cumulative high}",
    "medium": "{cumulative medium}",
    "low": "{cumulative low}"
  },
  "phases_completed": [0, 1, 2, 3, 4, 5, 6, 7],
  "history_flattened": false,
  "phase_findings": {
    "7": {
      "total": "{phase 7 total}",
      "critical": "{phase 7 critical}",
      "high": "{phase 7 high}",
      "medium": "{phase 7 medium}",
      "low": "{phase 7 low}",
      "status": "completed"
    }
  }
}
```

Announce:
> "Phase 7 (Naming, Trademark & Identity Review) complete. Moving to Phase 8 — History Flatten."

Wait for user approval before beginning Phase 8 (per the Phase-Gating Interaction Model).
