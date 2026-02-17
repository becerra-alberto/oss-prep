# Phase 10 — Launch Automation

| Field | Value |
|-------|-------|
| Phase | 10 |
| Name | Launch Automation |
| Priority | Critical — creates a public repository and pushes code to GitHub |
| Sub-Agent Calls | 2 (assessment + execution), with orchestrator gate between them |

## Inputs

| Source | Fields |
|--------|--------|
| State | `state.project_root`, `state.prep_branch`, `state.phases_completed`, `state.readiness_rating`, `state.project_profile`, `state.findings`, `state.history_flattened` |
| Pre-Dispatch Inputs (from orchestrator) | `repo_owner` (string — personal account or org name), `repo_name` (string — repository name), `visibility` (string — "public"), `version` (string — e.g., "v0.1.0" or "v1.0.0"), `funding_channels` (array — subset of ["github_sponsors", "open_collective", "ko_fi"] or empty) |
| Phase Summary Files | `.oss-prep/phase-7-summary.json` (namespace availability data for repo name pre-population) |

## Outputs

| Output | Description |
|--------|-------------|
| `state.github_repo_url` | URL of the created repository (e.g., `https://github.com/{owner}/{repo}`) |
| `state.phase` | Set to `11` (all phases including Phase 10 complete) |
| `state.phases_completed` | Appended with `10` |
| `state.phase_findings["10"]` | Phase 10 finding counts and status |
| `.github/FUNDING.yml` | Created if funding channels were selected |
| Updated `README.md` | Badge URLs fixed with actual `{owner}/{repo}` |
| GitHub release | Initial release at the specified version |

---

## Two Sub-Agent Dispatch Architecture

Phase 10 follows the same two-dispatch pattern as Phase 8 (History Flatten). It is the most consequential phase in the skill because it creates a public repository and pushes code to GitHub. Its safety model is at least as rigorous as Phase 8's flatten gate.

### Sub-Agent Call 1 — Assessment (Steps 10.1–10.2)

The first sub-agent runs a pre-launch readiness check and presents a summary of what will happen. No GitHub repository creation or code push occurs in this call.

**Steps included**: 10.1 (Pre-Launch Readiness Check), 10.2 (Pre-Launch Summary)

### Orchestrator Gate — Confirmation (Step 10.3)

The orchestrator presents the safety confirmation gate to the user. This is NOT executed by a sub-agent — it is the orchestrator's responsibility because it requires direct user interaction.

The user responds with one of:
- **`launch`** — Proceed to Sub-Agent Call 2
- **Any other response** — Orchestrator handles the decline path (Step 10.6) itself

### Sub-Agent Call 2 — Execution (Steps 10.4–10.5)

If the user confirms with "launch", the orchestrator dispatches a second sub-agent to execute all GitHub operations. This sub-agent receives the pre-dispatch inputs and assessment data from Call 1.

**Steps included**: 10.4 (Execute Launch), 10.5 (Post-Launch Verification)

### Steps Handled by Orchestrator

The following steps are NOT dispatched to sub-agents:
- **Pre-Dispatch Input Collection** — collects repo owner, repo name, visibility, version, and funding channels from the user before any sub-agent dispatch
- **Branch Handling** — checks current branch and offers merge to `main` if on `oss-prep/ready` (before Dispatch 2)
- **Step 10.3** (Confirmation Gate) — requires direct user interaction with typed `launch` confirmation
- **Step 10.6** (Decline Path) — handled after user declines
- **Step 10.7** (Phase Summary) — orchestrator consolidates results from both calls
- **Step 10.8** (State Update) — orchestrator updates persistent state

---

## Pre-Dispatch Input Collection

> **Orchestrator responsibility — NOT executed by a sub-agent**

Before dispatching Sub-Agent Call 1, the orchestrator collects five inputs from the user. These are passed as structured data in both dispatch prompts. Per DD-4, sub-agents cannot interact with users, so all interactive inputs must be resolved here.

### Input 1 — Repo Owner

Ask the user whether to create the repository under their personal GitHub account or an organization:

> "Where should the repository be created?
> (a) Personal account (your GitHub username)
> (b) An organization"

If the user selects an organization, prompt for the org name and validate it exists:

```bash
gh api /orgs/{org_name} 2>/dev/null
```

- If the API returns 200: the org exists. Proceed.
- If the API returns 404: warn "Organization `{org_name}` was not found on GitHub. Please verify the name or create the organization first at https://github.com/organizations/plan." Ask again.
- If the API fails (network error, auth error): warn "Could not verify organization `{org_name}`. Proceeding with this name — if it doesn't exist, the repo creation will fail."

If the user selects personal account, use `gh api /user` to retrieve the authenticated username:

```bash
gh api /user --jq '.login'
```

### Input 2 — Repo Name

Pre-populate the suggested repo name using the best available source:

1. **Phase 7 namespace data**: If `.oss-prep/phase-7-summary.json` exists, check its findings for GitHub repo availability results. If a repo name was checked and found available in Phase 7, suggest that name.
2. **Project directory name**: Otherwise, use the basename of `state.project_root` as the default suggestion.

Present the suggestion:

> "Repository name: `{suggested_name}`
> Press Enter to accept, or type a different name."

Validate the chosen name:
- Must match `^[a-zA-Z0-9._-]+$` (GitHub repo name rules)
- Must not exceed 100 characters

### Input 3 — Visibility

Confirm public visibility with an explicit warning:

> "This will create a **PUBLIC** repository. All code, commit history, and issues will be visible to everyone on the internet.
>
> Confirm public visibility? (yes/no)"

If the user declines, explain: "Phase 10 only supports public repository creation (the purpose of oss-prep is to prepare for open-source release). If you need a private repository, create it manually using `gh repo create --private`." Proceed to the decline path (Step 10.6).

### Input 4 — Version

Suggest a version based on the readiness rating from Phase 9:

| Readiness Rating | Suggested Version | Reasoning |
|-----------------|-------------------|-----------|
| Ready | v1.0.0 | Project passed all checks — suitable for a stable release |
| Ready with Caveats | v0.1.0 | Some caveats remain — an initial pre-release signals work-in-progress |
| Not Ready | v0.1.0 | Significant issues remain — pre-release is appropriate |

Present the suggestion:

> "Initial release version: `{suggested_version}` (based on readiness rating: {readiness_rating})
> Press Enter to accept, or type a different version (e.g., v0.1.0, v1.0.0, v2.0.0)."

### Input 5 — Funding Channels

Ask if the user wants to set up funding:

> "Would you like to add funding information? This creates a `.github/FUNDING.yml` file that GitHub displays as a 'Sponsor' button.
>
> (a) GitHub Sponsors
> (b) Open Collective
> (c) Ko-fi
> (d) No funding — skip this step
>
> You can select multiple options (e.g., 'a, c')."

For each selected channel, collect the required identifier:
- **GitHub Sponsors**: GitHub username (default: the repo owner)
- **Open Collective**: Open Collective project slug
- **Ko-fi**: Ko-fi username

If "No funding" is selected, `funding_channels` is an empty array.

---

## Step 10.1 — Pre-Launch Readiness Check

> **Sub-Agent Call 1**

Verify all prerequisites for a successful launch:

### 10.1.1 — `gh` CLI Authentication

```bash
gh auth status
```

If not authenticated: report "CRITICAL: `gh` CLI is not authenticated. Run `gh auth login` before proceeding." Return to orchestrator with failure status.

### 10.1.2 — State Prerequisites

Verify the following state conditions:
- `state.phases_completed` contains all phases 0-9 (all standard phases complete)
- `state.readiness_rating` is set (not empty string)
- `state.phase` equals 10 (Phase 10 is the current phase to execute)

If any condition fails, report the specific failure and return to the orchestrator.

### 10.1.3 — Branch Verification

Check the current branch:

```bash
git branch --show-current
```

Report the current branch name. The orchestrator uses this to determine branch handling (see "Steps Handled by Orchestrator" above and the orchestrator's branch handling logic).

### 10.1.4 — Repository Name Conflict Check

Using the pre-dispatch inputs (`repo_owner` and `repo_name`), verify the repository doesn't already exist:

```bash
gh api /repos/{owner}/{repo} 2>/dev/null
```

- If 200: "WARNING: Repository `{owner}/{repo}` already exists on GitHub. Creating this repo will fail."
- If 404: "Repository name `{owner}/{repo}` is available."
- If error: "Could not verify repository availability. Proceeding — the creation step will report any conflicts."

---

## Step 10.2 — Pre-Launch Summary

> **Sub-Agent Call 1**

Present a comprehensive summary of what will happen if the user confirms:

```
### Pre-Launch Summary

| Action | Details |
|--------|---------|
| Repository | {owner}/{repo} |
| Visibility | PUBLIC |
| Description | {from project_profile or "No description set"} |
| Version | {version} |
| Branch to push | {current branch} |
| History | {if history_flattened: "Flattened (single commit)" else "{N} commits"} |
| Funding | {funding channels list or "None"} |
| Readiness rating | {readiness_rating} |

### What Will Happen

1. Create a **public** GitHub repository at `{owner}/{repo}`
2. Push the current branch to GitHub as the default branch
3. Configure repository settings (discussions, issues, squash merge, etc.)
4. Create standard issue labels
{5. Generate `.github/FUNDING.yml` (if funding selected)}
5. Create initial release `{version}` with changelog notes
6. Fix badge URLs in README with actual `{owner}/{repo}`

### What Will NOT Happen (requires manual steps after launch)

See the "What Phase 10 Cannot Automate" section below.
```

**Return to orchestrator**: After completing Steps 10.1 and 10.2, Sub-Agent Call 1 returns the readiness check results and pre-launch summary to the orchestrator for presentation in the confirmation gate.

---

## Step 10.3 — Confirmation Gate

> **Orchestrator responsibility — NOT executed by a sub-agent**

Present the confirmation gate. This gate follows the same safety model as Phase 8's "type `flatten`" gate.

> "This will create a **PUBLIC** repository at `{owner}/{repo}` and push all code. This action cannot be fully undone — the repository will be publicly visible immediately.
>
> **What will happen:**
> - A public repository will be created at `https://github.com/{owner}/{repo}`
> - All code on the current branch will be pushed
> - Repository settings, labels, and an initial release will be configured
> - The repository will be immediately visible to everyone on the internet
>
> To confirm, type **`launch`** (the word, not just 'y' or 'yes').
>
> To decline, type anything else."

**Confirmation rules:**
- The user must type exactly `launch` (case-insensitive) to proceed.
- Responses of `y`, `yes`, `ok`, `sure`, or any other input do **NOT** trigger the launch — they are treated as a decline.
- If the user confirms with `launch`, proceed to **Branch Handling** (orchestrator) then **Step 10.4**.
- If the user declines, proceed to **Step 10.6 — Decline Path**.

---

## Branch Handling

> **Orchestrator responsibility — executed AFTER the user types `launch` and BEFORE dispatching Sub-Agent Call 2**

Check the current branch (from the assessment in Step 10.1.3) and handle accordingly:

### Case A: On `oss-prep/ready`

Offer to merge to `main` first:

> "You're currently on the `oss-prep/ready` branch. **Recommended**: Merge to `main` first so that `main` becomes the default branch on GitHub.
>
> (a) Merge `oss-prep/ready` into `main` and push `main` (Recommended)
> (b) Push `oss-prep/ready` as-is (it will become the default branch on GitHub)"

If the user accepts the merge:

```bash
git checkout main
git merge oss-prep/ready --no-edit
```

Update the branch name passed to Dispatch 2 to `main`.

### Case B: On `main`

No action needed. Push `main` directly. Proceed to Dispatch 2.

### Case C: On any other branch

Warn the user:

> "You're currently on branch `{branch_name}`, which is neither `main` nor `oss-prep/ready`.
>
> (a) Push `{branch_name}` as-is (it will become the default branch on GitHub)
> (b) Switch to `main` and merge `{branch_name}` into `main` first
> (c) Cancel — go back to the decline path"

Handle accordingly based on the user's choice.

---

## Step 10.4 — Execute Launch

> **Sub-Agent Call 2**

**Only execute this step if the user typed `launch` in Step 10.3 and branch handling is complete.**

The sub-agent receives the pre-dispatch inputs, the branch to push, and the project description as structured data from the orchestrator.

### 10.4.1 — Create GitHub Repository

```bash
gh repo create {owner}/{repo} --public --description "{description}" --source . --push
```

Where:
- `{owner}/{repo}` is from the pre-dispatch inputs
- `{description}` is derived from the project's README first line, `package.json` description, or `state.project_profile` language/framework summary. If no description is available, use "Open-source release prepared with oss-prep."
- `--source .` sets the current directory as the source
- `--push` pushes the current branch to the new remote

If the command fails, report the error and return to the orchestrator with failure status. Common failures:
- Authentication expired: "Run `gh auth login` to re-authenticate."
- Repo already exists: "Repository `{owner}/{repo}` already exists. Choose a different name."
- Org permissions: "You don't have permission to create repositories in the `{owner}` organization."

### 10.4.2 — Configure Repository Settings

```bash
gh repo edit {owner}/{repo} \
  --enable-discussions \
  --enable-issues \
  --enable-squash-merge \
  --delete-branch-on-merge \
  --add-topic "open-source"
```

Add topics based on `state.project_profile`:
- If `language` is detected: add it as a topic (lowercased)
- If `framework` is detected: add it as a topic (lowercased)

Enable security features:

```bash
gh api -X PUT /repos/{owner}/{repo}/vulnerability-alerts
gh api -X PUT /repos/{owner}/{repo}/code-scanning/default-setup \
  --field state=configured 2>/dev/null || true
```

> **Note**: Secret scanning and push protection are enabled by default on public repositories as of 2024. The vulnerability alerts API call enables Dependabot alerts. The code scanning setup may fail on free plans — this is expected and non-blocking.

### 10.4.3 — Create Standard Labels

Create the six standard labels using `gh label create`. Each label is created individually to handle partial failures gracefully:

```bash
gh label create "good first issue" --description "Good for newcomers" --color "7057ff" --repo {owner}/{repo} 2>/dev/null || true
gh label create "help wanted" --description "Extra attention is needed" --color "008672" --repo {owner}/{repo} 2>/dev/null || true
gh label create "documentation" --description "Improvements or additions to documentation" --color "0075ca" --repo {owner}/{repo} 2>/dev/null || true
gh label create "bug" --description "Something isn't working" --color "d73a4a" --repo {owner}/{repo} 2>/dev/null || true
gh label create "enhancement" --description "New feature or request" --color "a2eeef" --repo {owner}/{repo} 2>/dev/null || true
gh label create "question" --description "Further information is requested" --color "d876e3" --repo {owner}/{repo} 2>/dev/null || true
```

> **Note**: Some of these labels (like `bug`, `documentation`, `enhancement`) may already exist as GitHub defaults. The `|| true` ensures creation doesn't fail if the label already exists.

### 10.4.4 — Generate FUNDING.yml

If `funding_channels` is non-empty, create `.github/FUNDING.yml`:

```bash
mkdir -p .github
```

Write the file using the Write tool. The content depends on the selected channels:

```yaml
# Funding information for this project
# See: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/displaying-a-sponsor-button-in-your-repository

github: [{github_sponsors_username}]      # Only if GitHub Sponsors selected
open_collective: {oc_slug}                 # Only if Open Collective selected
ko_fi: {kofi_username}                     # Only if Ko-fi selected
```

Include only the lines for selected channels. After writing:

```bash
git add .github/FUNDING.yml
git commit -m "chore: add funding configuration"
git push
```

If `funding_channels` is empty, skip this step entirely.

### 10.4.5 — Create Initial Release

Check if a `CHANGELOG.md` exists:

```bash
test -f CHANGELOG.md && echo "exists" || echo "missing"
```

Create the release:

```bash
# If CHANGELOG.md exists:
gh release create {version} --title "{version}" --notes-file CHANGELOG.md --repo {owner}/{repo}

# If CHANGELOG.md does not exist:
gh release create {version} --title "{version}" --generate-notes --repo {owner}/{repo}
```

### 10.4.6 — Badge Fixup in README

Scan the README for badge placeholder tokens and replace them with the actual `{owner}/{repo}`:

Common badge URL patterns to fix:

| Badge Type | Placeholder Pattern | Replacement |
|-----------|-------------------|-------------|
| CI Status | `{owner}/{repo}` or `OWNER/REPO` in workflow badge URLs | Actual `{owner}/{repo}` |
| License | `shields.io/github/license/{owner}/{repo}` placeholders | Actual `{owner}/{repo}` |
| Issues | `shields.io/github/issues/{owner}/{repo}` placeholders | Actual `{owner}/{repo}` |
| Version | `shields.io/github/v/release/{owner}/{repo}` placeholders | Actual `{owner}/{repo}` |

Use the Read tool to read `README.md`, then use the Edit tool to replace any placeholder patterns:

1. Search for `OWNER/REPO`, `{owner}/{repo}`, `your-username/your-repo`, or similar placeholder patterns
2. Replace with the actual `{owner}/{repo}` values
3. If no placeholders are found, skip this step (no modification needed)

After making changes:

```bash
git add README.md
git commit -m "chore: fix badge URLs with actual repository path"
git push
```

### 10.4.7 — Store GitHub Repo URL

Record the repository URL for state persistence:

```
github_repo_url: https://github.com/{owner}/{repo}
```

Return this value to the orchestrator for state update.

---

## Step 10.5 — Post-Launch Verification

> **Sub-Agent Call 2**

After all creation steps, verify the launch succeeded:

### 10.5.1 — Repository Exists

```bash
gh repo view {owner}/{repo} --json name,url,visibility,description
```

Verify the output shows `visibility: "PUBLIC"`.

### 10.5.2 — Release Exists

```bash
gh release view {version} --repo {owner}/{repo} --json tagName,name
```

Verify the release was created with the correct tag.

### 10.5.3 — Verification Result

**Expected result**: Repository exists, is public, and release is present.

> "Post-launch verification complete:
> - Repository: https://github.com/{owner}/{repo} (PUBLIC)
> - Release: {version} created successfully
> - Labels: {N} standard labels configured
> - Settings: discussions, issues, squash merge enabled
> {- Funding: .github/FUNDING.yml created (if applicable)}
>
> Your repository is live!"

If any verification fails, report the specific failure but do not block completion — the repository may still be functional even if a minor setting didn't apply.

**Return to orchestrator**: Sub-Agent Call 2 returns the execution results, verification status, and `github_repo_url` to the orchestrator.

---

## Step 10.6 — Decline Path

> **Orchestrator responsibility**

If the user declines to launch (any response other than `launch` in Step 10.3, or declining the visibility confirmation in the pre-dispatch inputs), do the following:

1. **Acknowledge the decision**:
> "Understood — no repository was created. You can launch manually at any time using the checklist in your readiness report, or re-run Phase 10 later."

2. **Set phase to 11** — all phases are done (launch was skipped). This ensures the skill terminates without blocking on a never-executed Phase 10.

3. **Do not block progress** — the skill completes normally with the launch skipped.

---

## Step 10.7 — Consolidate and Present Phase Summary

> **Orchestrator responsibility**

Present the Phase 10 summary using the standard format:

```
## Phase 10 Summary — Launch Automation

| Action | Status |
|--------|--------|
| Repository creation | {Created at https://github.com/{owner}/{repo} / Declined} |
| Repository settings | {Configured / Skipped} |
| Standard labels | {Created ({N} labels) / Skipped} |
| FUNDING.yml | {Created / Not selected / Skipped} |
| Initial release | {Created ({version}) / Skipped} |
| Badge fixup | {Updated / No placeholders found / Skipped} |

**Decision**: {Launched / Declined}
{If launched:} **Repository URL**: https://github.com/{owner}/{repo}
{If launched:} **Release**: {version}
{If declined:} The project is ready for manual launch using the checklist in the readiness report.

**Findings**: 0 total (Phase 10 is an automation phase — it does not produce audit findings)
```

### Effort Classification Guidance (Phase 10)

Phase 10 does not produce traditional audit findings. All operations are automated. If any step fails, it is reported as an execution error, not a finding.

---

## Step 10.8 — Update STATE

> **Orchestrator responsibility — documented as expected state changes**

After Phase 10 is complete (whether launched or declined) and the user approves the summary:

| Field | Value |
|-------|-------|
| `phase` | `11` |
| `github_repo_url` | `https://github.com/{owner}/{repo}` if launched, `""` if declined |
| `phases_completed` | Append `10` |
| `phase_findings["10"]` | `{ total: 0, critical: 0, high: 0, medium: 0, low: 0, status: "completed" }` |
| `findings` | Unchanged (Phase 10 does not produce audit findings) |

If declined, `phase_findings["10"]` status is `"skipped"` instead of `"completed"`.

Announce:
> "Phase 10 (Launch Automation) complete. OSS Prep is finished!"

---

## What Phase 10 Cannot Automate

The following items require manual action because they cannot be automated via the GitHub API or CLI:

1. **GitHub organization creation** — Organizations must be created through the GitHub web UI at https://github.com/organizations/plan. The API does not support creating organizations. Phase 10 can create repos within an existing org, but cannot create the org itself.

2. **GitHub Sponsors enrollment** — Enrolling in GitHub Sponsors requires bank account information, tax details, and identity verification that must be completed through the GitHub web UI at https://github.com/sponsors. Phase 10 can add `github:` to `FUNDING.yml`, but the sponsor button will not appear until enrollment is complete.

3. **Social preview image upload** — The repository's social preview image (shown when the repo link is shared on social media) must be uploaded through the GitHub web UI at Settings > Social preview. The API endpoint for this requires a binary image upload with specific dimensions (1280x640px recommended) that cannot be reliably automated in a CLI workflow.

4. **Custom domain configuration** — If the project will have a documentation site with a custom domain (e.g., via GitHub Pages), domain registration, DNS configuration, and the GitHub Pages custom domain setting must be configured manually. Domain registration is an external service, and DNS propagation requires human verification.

---

## Post-Launch Recommended Actions

After Phase 10 completes, the user should consider:

1. **Set up branch protection** on `main` (Settings > Branches > Branch protection rules)
2. **Configure GitHub Actions secrets** if CI/CD workflows need API keys or tokens
3. **Upload a social preview image** (see "Cannot Automate" above)
4. **Announce the launch** on relevant channels (social media, forums, mailing lists)
5. **Enroll in GitHub Sponsors** if funding was configured (see "Cannot Automate" above)
