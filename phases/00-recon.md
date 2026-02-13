# Phase 0 — Reconnaissance

- **Phase**: 0
- **Name**: Reconnaissance
- **Inputs**: git repository (working directory) — no prior state required
- **Outputs**: project_profile (language, framework, package_manager, build_system, test_framework), prep_branch name, anomaly report, initial STATE block with all fields populated, finding counts initialized to 0, phases_completed set to [0], history_flattened set to false

---

## Purpose

Phase 0 is the entry point for every `/oss-prep` run. It detects the project, creates a working branch, builds a comprehensive profile, checks for anomalies, and presents everything for user confirmation before any audit work begins.

Phase 0 is unique in that it **initializes** state rather than reading it. Its only input is the git repository itself. Its outputs are the most foundational artifacts: the prep branch, the project profile, and the initial state.

---

## Steps

### Step 0.1 — Detect Project Root

1. Run `git rev-parse --show-toplevel` to determine the repository root. Store this as `project_root`.
2. Run `git rev-parse --show-superproject-working-tree` to check if this repo is a git submodule.
   - **If it returns a non-empty value**: This is a submodule. Warn the user:
     > "This repository appears to be a git submodule inside `{superproject_path}`. The audit will run on this submodule only — not the parent repository. Do you want to proceed?"
   - Wait for explicit user confirmation before continuing. If the user wants to audit the parent instead, instruct them to re-run `/oss-prep` from the parent repo root.
   - **If it returns empty**: This is a standalone repository. Proceed without warning.
3. Change the working directory to `project_root` for all subsequent operations.

### Step 0.2 — Preparation Branch Management

1. Check if the `oss-prep/ready` branch already exists:
   ```bash
   git branch --list oss-prep/ready
   ```
2. **If the branch exists**, ask the user:
   > "An existing `oss-prep/ready` branch was found. Choose one:
   > - **Resume** — Keep existing changes and continue where you left off
   > - **Reset** — Delete the branch and start fresh from current HEAD"
   - If **Resume**: check out the existing branch (`git checkout oss-prep/ready`).
   - If **Reset**: delete the branch (`git branch -D oss-prep/ready`), then create and check out a new one from current HEAD.
3. **If the branch does not exist**, create and check out a new branch:
   ```bash
   git checkout -b oss-prep/ready
   ```
4. Confirm to the user which branch is now active and what HEAD it points to.

### Step 0.3 — Build Project Profile

Inspect the repository to build a comprehensive project profile. Use `git ls-files` (not filesystem traversal) to respect `.gitignore`. For each category, detect what is present and mark undetectable fields as `"Not detected"`.

#### Languages
- Run `git ls-files` and count files by extension to determine primary and secondary languages.
- Map common extensions: `.py` → Python, `.js`/`.jsx` → JavaScript, `.ts`/`.tsx` → TypeScript, `.rs` → Rust, `.go` → Go, `.rb` → Ruby, `.java` → Java, `.c`/`.h` → C, `.cpp`/`.hpp` → C++, `.cs` → C#, `.swift` → Swift, `.kt` → Kotlin, `.php` → PHP, `.sh` → Shell.
- Rank languages by file count. Report the top 1-3 as primary languages.

#### Frameworks
- Detect frameworks by inspecting manifest/config file contents:
  - **JavaScript/TypeScript**: Check `package.json` `dependencies` and `devDependencies` for `next`, `react`, `vue`, `angular`, `express`, `fastify`, `nestjs`, `svelte`, `nuxt`, `remix`, `astro`, `electron`.
  - **Python**: Check `requirements.txt`, `pyproject.toml`, or `setup.py` for `django`, `flask`, `fastapi`, `streamlit`, `pytorch`, `tensorflow`.
  - **Ruby**: Check `Gemfile` for `rails`, `sinatra`.
  - **Rust**: Check `Cargo.toml` dependencies for `actix`, `axum`, `rocket`, `tokio`, `warp`.
  - **Go**: Check `go.mod` for common framework modules.
  - **Java/Kotlin**: Check `build.gradle` or `pom.xml` for `spring`, `quarkus`, `micronaut`.
  - **PHP**: Check `composer.json` for `laravel`, `symfony`.
- Report detected frameworks or `"Not detected"` if none are recognized.

#### Package Managers
- Detect by manifest and lock file presence:
  - `package.json` + `package-lock.json` → npm
  - `package.json` + `yarn.lock` → Yarn
  - `package.json` + `pnpm-lock.yaml` → pnpm
  - `package.json` + `bun.lockb` or `bun.lock` → Bun
  - `Cargo.toml` + `Cargo.lock` → Cargo
  - `go.mod` + `go.sum` → Go Modules
  - `pyproject.toml` or `setup.py` + `requirements.txt` → pip / Poetry / PDM (check `pyproject.toml` `[build-system]` to distinguish)
  - `Gemfile` + `Gemfile.lock` → Bundler
  - `pom.xml` → Maven
  - `build.gradle` or `build.gradle.kts` → Gradle
  - `composer.json` + `composer.lock` → Composer

#### Build System
- Detect build systems and scripts:
  - `Makefile` → Make
  - `package.json` with `scripts` → npm/yarn/pnpm scripts (list the script names)
  - `build.gradle` / `build.gradle.kts` → Gradle
  - `CMakeLists.txt` → CMake
  - `Dockerfile` / `docker-compose.yml` → Docker
  - `justfile` → Just
  - `Taskfile.yml` → Task
  - `Earthfile` → Earthly
  - `Makefile.toml` → cargo-make

#### Test Framework
- Detect test frameworks by configuration files and test directories:
  - `jest.config.*` or `jest` key in `package.json` → Jest
  - `vitest.config.*` → Vitest
  - `cypress.config.*` or `cypress/` directory → Cypress
  - `playwright.config.*` → Playwright
  - `.mocharc.*` → Mocha
  - `pytest.ini`, `pyproject.toml` with `[tool.pytest]`, or `conftest.py` → pytest
  - `tox.ini` → tox
  - `spec/` directory with `Gemfile` containing `rspec` → RSpec
  - `*_test.go` files → Go testing
  - `tests/` or `test/` directories → generic test presence
- Report the specific framework(s) detected, or `"Not detected"`.

#### Metrics
Gather the following numerical metrics:
```bash
# Total tracked file count
git ls-files | wc -l

# Total lines of code (tracked files only)
git ls-files | xargs wc -l 2>/dev/null | tail -1

# Total commit count
git rev-list --count HEAD

# Top-level directory structure
ls -d */
```

#### CI/CD
- Check for CI/CD configuration presence:
  - `.github/workflows/` → GitHub Actions (list workflow file names)
  - `.gitlab-ci.yml` → GitLab CI
  - `Jenkinsfile` → Jenkins
  - `.circleci/` → CircleCI
  - `.travis.yml` → Travis CI
  - `azure-pipelines.yml` → Azure Pipelines
  - `bitbucket-pipelines.yml` → Bitbucket Pipelines
  - `.buildkite/` → Buildkite
- Report specific CI system(s) found, or `"Not detected"`.

### Step 0.4 — Anomaly Detection

Scan for repository anomalies that may complicate the open-source release. Report each anomaly with enough detail for the user to assess risk.

#### Submodules
```bash
git submodule status
```
- If any submodules exist, list each with its path, current commit, and remote URL.
- Note that submodule contents are NOT audited by this run — each submodule should be audited independently if it will be included in the release.

#### Large Binary Files (>1MB)
```bash
git ls-files -z | xargs -0 -I{} sh -c 'size=$(wc -c < "{}"); if [ "$size" -gt 1048576 ]; then echo "$(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes") {}"; fi'
```
- List each file >1MB with its path and human-readable size.
- Note: These files will bloat the repository and should likely be removed or moved to Git LFS before public release.

#### Symlinks
```bash
git ls-files -s | awk '$1 == "120000" {print $4}'
```
- List each symlink with its path and target.
- Note: Symlinks can break on different platforms and should be reviewed for portability.

#### Non-Standard Permissions
```bash
git ls-files -s | awk '$1 ~ /^100755/ {print $4}'
```
- List files with executable permission bits set.
- Flag any files that are not shell scripts, binaries, or known executables as potentially having non-standard permissions.

### Step 0.5 — Present Profile and Confirm

Present the complete project profile and anomaly report to the user in this format:

```
## Project Profile — {repo name}

| Field              | Value                              |
|--------------------|------------------------------------|
| Project Root       | {project_root}                     |
| Prep Branch        | oss-prep/ready                     |
| Language(s)        | {detected languages}               |
| Framework(s)       | {detected frameworks}              |
| Package Manager(s) | {detected package managers}        |
| Build System       | {detected build system}            |
| Test Framework     | {detected test framework}          |
| Total Files        | {N}                                |
| Total LOC          | {N}                                |
| Total Commits      | {N}                                |
| CI/CD              | {detected CI/CD system(s)}         |

### Top-Level Structure
{directory listing}

### Anomalies
- **Submodules**: {count} found {details or "None"}
- **Large files (>1MB)**: {count} found {details or "None"}
- **Symlinks**: {count} found {details or "None"}
- **Non-standard permissions**: {count} found {details or "None"}
```

Then ask the user:

> "Does this profile look accurate? You can:
> - **Confirm** — Accept and proceed to Phase 1 (Secrets Audit)
> - **Correct** — Fix any misdetections (e.g., wrong framework, missing language)
> - **Add context** — Provide additional information the profile missed"

If the user provides corrections, update the profile accordingly and re-present until confirmed.

### Step 0.6 — Update STATE and Complete Phase

Once the user confirms the profile, update the STATE block:

```
STATE:
  schema_version: 1
  phase: 1
  project_root: {absolute path}
  prep_branch: oss-prep/ready
  started_at: {ISO 8601 timestamp}
  project_profile:
    language: {confirmed language(s)}
    framework: {confirmed framework(s) or "none"}
    package_manager: {confirmed package manager(s) or "none"}
    build_system: {confirmed build system or "none"}
    test_framework: {confirmed test framework(s) or "none"}
  findings:
    total: 0
    critical: 0
    high: 0
    medium: 0
    low: 0
  phases_completed: [0]
  phase_findings:
    "0":
      total: 0
      critical: 0
      high: 0
      medium: 0
      low: 0
      status: "completed"
  license_choice: ""
  readiness_rating: ""
  history_flattened: false
  phase_failures: {}
```

> **Note**: The state update is an orchestrator responsibility. The orchestrator also sets `phase_findings["0"]` with per-phase counts and `status: "completed"` (or `"skipped"`). This phase file documents the expected state change for reference.

Phase 0 is now complete. Announce:

> "Phase 0 (Reconnaissance) complete. Project profile confirmed. Moving to Phase 1 — Secrets & Credentials Audit."

Wait for the user's explicit approval before beginning Phase 1 (per the Phase-Gating Interaction Model).

---

## Finding Format

Phase 0 does not produce security findings. Its output is the anomaly report presented in Step 0.5, formatted as:

```
### Anomalies
- **Submodules**: {count} found {details or "None"}
- **Large files (>1MB)**: {count} found {details or "None"}
- **Symlinks**: {count} found {details or "None"}
- **Non-standard permissions**: {count} found {details or "None"}
```

Each anomaly entry includes the count and, when non-zero, a list of affected paths with relevant details (commit hash and remote URL for submodules, human-readable size for large files, target for symlinks, file type note for permissions).

---

## User Gate

Phase 0 uses a unique confirmation prompt (different from the standard 4-option gate used in later phases):

> "Does this profile look accurate? You can:
> - **Confirm** — Accept and proceed to Phase 1 (Secrets Audit)
> - **Correct** — Fix any misdetections (e.g., wrong framework, missing language)
> - **Add context** — Provide additional information the profile missed"

**Orchestrator note (DD-4):** The sub-agent does NOT present this gate directly. Instead, the sub-agent returns the completed profile and anomaly report to the orchestrator, and the orchestrator presents this confirmation prompt to the user. This ensures the orchestrator maintains control of user interaction flow.
