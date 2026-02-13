# Phase 4 — Code Architecture & Quality Review

- **Phase**: 4
- **Name**: Code Architecture & Quality Review
- **Inputs**: project_root, project_profile (language, framework, package_manager, build_system, test_framework from state)
- **Outputs**: architecture summary (directory structure, module boundaries, entry points, key abstractions), findings list (Q4-1 through Q4-N), finding counts by severity, build status (passed/failed/skipped), test status (passed/failed/skipped with counts), state update (phase: 5, cumulative findings from Phases 1+2+3+4, phases_completed adds 4)

---

## Purpose

Phase 4 shifts from "is this safe to publish?" (security/compliance in Phases 1-3) to "is this ready to publish well?" (quality and professionalism). It conducts a multi-stream analysis covering architecture summary, coding standards detection, build verification, test verification, and code quality flagging. Build and test failures are **non-blocking** — they are reported but do NOT prevent the user from proceeding to Phase 5.

Phase 4 does not reference `patterns/secrets.md` or `patterns/pii.md` — those are Phase 1/2 concerns. It uses no shared pattern libraries.

---

## Steps

### Step 4.1 — Dispatch Parallel Sub-Agents (Stream 1)

Launch **three sub-agents simultaneously** via the Task tool (all with `model: "opus"`):

- **Sub-agent A — Architecture Summary**: Produces a high-level architecture summary of the codebase.
- **Sub-agent B — Coding Standards Detection**: Checks for the presence of formatting, linting, type checking, and build script configuration.
- **Sub-agent C — Code Quality Flagging**: Identifies dead code, TODO/FIXME/HACK comments with internal context, commented-out code blocks, and hardcoded configuration values.

Provide each sub-agent with:
- The current STATE block (including `project_profile`)
- The `project_root` path
- Clear instructions about what to scan (copy the relevant sub-section below into the sub-agent prompt)
- The Grounding Requirement — every finding must include file path and line number

Wait for **all three sub-agents to complete** before proceeding to Step 4.2 (build and test verification depend on understanding the project structure from Sub-agent A's results).

#### Sub-Agent A — Architecture Summary Instructions

Produce a descriptive (not prescriptive) summary of the codebase architecture. This summarizes what exists rather than recommending changes. Cover the following elements, grounding every claim in actual file paths found via Glob and Read:

**1. Directory Structure (Top 2-3 Levels)**
- Run `ls` or Glob at the project root to enumerate top-level directories and files.
- For each significant directory, describe its purpose (e.g., `src/` — application source code, `tests/` — test suite, `docs/` — documentation).
- Go 2-3 levels deep for directories that represent important module boundaries.
- Ignore build artifact directories: `node_modules/`, `dist/`, `target/`, `__pycache__/`, `vendor/`, `.build/`, `_build/`.

**2. Module Boundaries**
- Identify how code is organized into logical modules, packages, or components.
- Note the separation pattern used: flat structure, feature-based directories, layered architecture (controllers/services/models), monorepo with packages, etc.
- Reference specific directory paths and key files that define boundaries.

**3. Entry Points**
- Identify the main entry point(s) of the application:
  - **CLI entry points**: Files referenced in `package.json` `bin` field, `setup.py`/`pyproject.toml` `[project.scripts]`, `Cargo.toml` `[[bin]]`, or files with `if __name__ == "__main__"` / `func main()` patterns.
  - **Server start files**: Files that boot an HTTP server (look for `app.listen`, `uvicorn.run`, `http.ListenAndServe`, `rocket::ignite`, etc.).
  - **Library entry points**: `index.js`/`index.ts`, `__init__.py`, `lib.rs`, `mod.go` files that export the public API.
- List each entry point with its file path and a brief description of what it does.

**4. Key Abstractions**
- Identify the major classes, interfaces, types, or data structures that define the project's domain model.
- Look for files with common abstraction indicators: `types.ts`, `models/`, `interfaces/`, `schemas/`, `entities/`, trait definitions, abstract classes.
- List up to 10 key abstractions with file paths and one-line descriptions.
- Do NOT attempt to catalog every class or function — focus on the architectural backbone.

Format the output as a structured summary under the heading "Architecture Summary".

#### Sub-Agent B — Coding Standards Detection Instructions

Check for the **presence** (not correctness) of coding standards tooling configuration. For each category, search for the listed configuration files using Glob. Report whether each category is configured or missing.

**1. Formatting Configuration**
Search for:
- `.prettierrc`, `.prettierrc.*`, `prettier.config.*` (Prettier)
- `.editorconfig` (EditorConfig)
- `rustfmt.toml`, `.rustfmt.toml` (rustfmt)
- `pyproject.toml` with `[tool.black]` or `[tool.yapf]` sections (Black, YAPF)
- `.clang-format` (clang-format)
- `biome.json`, `biome.jsonc` (Biome)
- `deno.json` or `deno.jsonc` with `fmt` key (Deno)

**2. Linting Configuration**
Search for:
- `.eslintrc`, `.eslintrc.*`, `eslint.config.*` (ESLint)
- `biome.json`, `biome.jsonc` with lint rules (Biome)
- `pylintrc`, `.pylintrc`, `pyproject.toml` with `[tool.pylint]` (Pylint)
- `pyproject.toml` with `[tool.ruff]` or `ruff.toml` (Ruff)
- `pyproject.toml` with `[tool.flake8]` or `.flake8` (Flake8)
- `clippy.toml`, `.clippy.toml` (Clippy)
- `.golangci.yml`, `.golangci.yaml` (golangci-lint)
- `.rubocop.yml` (RuboCop)

**3. Type Checking Configuration**
Search for:
- `tsconfig.json`, `tsconfig.*.json` (TypeScript)
- `jsconfig.json` (JavaScript with type checking)
- `mypy.ini`, `.mypy.ini`, `pyproject.toml` with `[tool.mypy]` (mypy)
- `pyrightconfig.json`, `pyproject.toml` with `[tool.pyright]` (Pyright)

**4. Build Scripts**
Search for:
- `Makefile` (Make)
- `package.json` with `scripts` section (npm/yarn/pnpm scripts — list the available script names)
- `build.gradle`, `build.gradle.kts` (Gradle)
- `CMakeLists.txt` (CMake)
- `justfile` (Just)
- `Taskfile.yml` (Task)

For each category, report:
- **Present**: List the specific configuration file(s) found with their paths.
- **Missing**: Flag as a LOW severity suggestion. Recommend adding the standard configuration for the project's primary language/framework.

Format findings as:
```
### Finding Q4-{N}: Missing {category} configuration

- **Severity**: LOW
- **Category**: Coding Standards
- **Detail**: No {specific tool} configuration found. Consider adding {recommended config file} for consistent {formatting|linting|type checking|build automation}.
```

#### Sub-Agent C — Code Quality Flagging Instructions

Scan the codebase for code quality concerns across the following categories. For each finding, include the file path and line number. Skip files in build artifact directories: `node_modules/`, `dist/`, `target/`, `__pycache__/`, `vendor/`, `.build/`, `_build/`.

**1. Dead Code Indicators**
- Search for functions/methods that are defined but never called within the project (use Grep to find definitions and then search for call sites).
- Search for unused exports (exported symbols that are never imported elsewhere in the project).
- Focus on the project's primary language and look for common patterns:
  - JavaScript/TypeScript: `export function/const/class` without corresponding `import` elsewhere
  - Python: `def` functions in modules that are never imported
  - Rust: `pub fn` that are never used (look for `#[allow(dead_code)]` annotations as indicators)
- **Note**: Dead code analysis is heuristic-based and may produce false positives. Report findings as MEDIUM severity and note the uncertainty.

**2. TODO/FIXME/HACK Comments with Internal Context**
- Search using Grep for patterns: `(?i)(TODO|FIXME|HACK|XXX)\b`
- For each match, check if it references internal context:
  - Personal names: `TODO(jsmith)`, `FIXME John:`, `HACK per Alice's suggestion`
  - Internal tools or systems: `TODO: update when internal-tool-v2 ships`, `FIXME: workaround for internal-deploy-system`
  - Internal ticket references: `TODO: PROJ-1234`, `FIXME: see JIRA-567`
  - Team or department names: `HACK: platform-team asked for this`, `TODO: backend team to review`
- Report each as a finding with:
  - **Severity**: MEDIUM (if it contains internal names, tools, or tickets) or LOW (if it's a generic TODO without internal references)
  - The file path, line number, and the full TODO/FIXME/HACK line content

**3. Commented-Out Code Blocks**
- Search for blocks of **3 or more consecutive commented lines** that appear to be code rather than documentation.
- Detection heuristics:
  - Lines starting with `//` or `#` followed by code-like patterns (variable assignments, function calls, control flow statements, import/require statements)
  - Multi-line comment blocks (`/* ... */` or `""" ... """`) containing code-like patterns
- **Exclude**:
  - License headers (typically at the top of files with words like "copyright", "license", "permission")
  - JSDoc/docstring comments (starting with `/**`, `///`, or `"""`/`'''` followed by description text)
  - Configuration comments in config files (e.g., commented-out options in `.eslintrc`)
- Report each as:
  - **Severity**: LOW
  - Include the file path, starting line number, and first 2-3 lines of the commented block as context

**4. Hardcoded Configuration Values**
- Search for patterns that suggest hardcoded values which should be environment variables or configuration:
  - **URLs**: `http://` or `https://` strings in source code (not in documentation, README, or config files that are meant to hold URLs). Focus on URLs that look like API endpoints, database hosts, or service URLs — not documentation links.
  - **Ports**: Hardcoded port numbers in `listen`, `bind`, `connect`, or server configuration calls (e.g., `:3000`, `:8080`, `:5432`). Exclude ports in documentation and comments.
  - **File paths**: Absolute file paths (starting with `/` or drive letters like `C:\`) in source code that are not part of the project's own directory structure.
  - **Magic numbers**: Focus on numbers that appear to be configuration rather than logic (timeout values, retry counts, size limits). Only flag these if they appear in contexts where they clearly should be configurable.
- Report each as:
  - **Severity**: LOW (for most hardcoded values) or MEDIUM (for URLs or paths that look like they point to internal/production infrastructure)
  - Include the file path, line number, the hardcoded value, and a suggestion to extract to an environment variable or config file

### Step 4.2 — Build and Test Verification (Stream 2 — Sequential)

After the parallel sub-agents from Step 4.1 complete, run build verification and test verification **sequentially**. These run after the architecture scan because knowing the build/test commands depends on understanding the project structure.

#### Build Verification

1. Detect the build command from the project profile and manifest inspection:
   - **Node.js**: Check `package.json` `scripts` for `build`, `compile`, or `dist` scripts → run `npm run build` (or `yarn build` / `pnpm build` matching the detected package manager)
   - **Python**: Check for `setup.py` → `python setup.py build`, or `pyproject.toml` with build backend → `pip install -e .` or `python -m build`
   - **Rust**: `cargo build`
   - **Go**: `go build ./...`
   - **Java/Gradle**: `./gradlew build` or `mvn package`
   - **TypeScript**: Check for `tsconfig.json` + `tsc` in scripts → `npx tsc --noEmit` (type check only)

2. If a build command is detected, run it via Bash with a **5-minute timeout**.

3. Record the result:
   - **Success**: Note "Build passed" — no finding generated.
   - **Failure**: Generate a finding:
     ```
     ### Finding Q4-{N}: Build failure detected

     - **Severity**: MEDIUM
     - **Category**: Build Verification
     - **Command**: {the command that was run}
     - **Exit Code**: {exit code}
     - **Error Output**: {relevant error output, truncated to 50 lines}
     - **Note**: Build failures are non-blocking — this finding is reported for awareness but does not prevent proceeding to Phase 5.
     ```

4. If **no build command is detected**, note "No build command detected — build verification skipped" and do not generate a finding.

**CRITICAL: Build failures do NOT block subsequent phases.** The finding is recorded and appears in the final report, but the phase gate still allows the user to proceed.

#### Test Verification

1. Detect the test command from the project profile and manifest inspection:
   - **Node.js**: Check `package.json` `scripts` for `test` script → run `npm test` (or `yarn test` / `pnpm test`)
   - **Python**: Check for `pytest.ini`, `conftest.py`, or `pyproject.toml` with `[tool.pytest]` → `pytest`; or `tox.ini` → `tox`
   - **Rust**: `cargo test`
   - **Go**: `go test ./...`
   - **Java/Gradle**: `./gradlew test` or `mvn test`
   - **Ruby**: Check for `Rakefile` with test task → `bundle exec rake test`; or `spec/` directory → `bundle exec rspec`

2. If a test command is detected, run it via Bash with a **10-minute timeout**.

3. Record the result:
   - **Success**: Note "Tests passed" with pass/fail counts if available — no finding generated.
   - **Failure**: Generate a finding:
     ```
     ### Finding Q4-{N}: Test failures detected

     - **Severity**: MEDIUM
     - **Category**: Test Verification
     - **Command**: {the command that was run}
     - **Exit Code**: {exit code}
     - **Summary**: {X passed, Y failed, Z skipped — if parseable from output}
     - **Failed Tests**: {list of failed test names, truncated to 20 entries}
     - **Note**: Test failures are non-blocking — this finding is reported for awareness but does not prevent proceeding to Phase 5.
     ```

4. If **no test command is detected**, note "No test command detected — test verification skipped" and do not generate a finding.

**CRITICAL: Test failures do NOT block subsequent phases.** The finding is recorded and appears in the final report, but the phase gate still allows the user to proceed.

### Step 4.3 — Consolidate and Present Findings

After all analysis streams complete (three parallel sub-agents + sequential build/test), consolidate all Phase 4 findings:

1. **Merge** findings from all five streams: architecture summary (informational, no findings unless issues detected), coding standards detection, code quality flagging, build verification, and test verification.
2. **Sort by severity**: MEDIUM first, then LOW (Phase 4 findings are typically MEDIUM or LOW).
3. **Number sequentially**: Assign finding IDs Q4-1 through Q4-N (Q4 = Quality Phase 4).

Present the **Phase Summary** (per the Phase-Gating Interaction Model):

```
## Phase 4 Summary — Code Architecture & Quality Review

### Architecture Summary
{High-level summary from Sub-agent A — directory structure, module boundaries, entry points, key abstractions. Keep this concise — 10-15 lines max in the summary view.}

### Coding Standards
- Formatting: {Present (tool name) | Missing}
- Linting: {Present (tool name) | Missing}
- Type checking: {Present (tool name) | Missing}
- Build scripts: {Present (tool name) | Missing}

### Build Verification
{Passed | Failed (with brief error summary) | Skipped (no build command detected)}

### Test Verification
{Passed (X tests) | Failed (X passed, Y failed) | Skipped (no test command detected)}

### Code Quality
- Dead code indicators: {N} findings
- TODO/FIXME/HACK with internal context: {N} findings
- Commented-out code blocks: {N} findings
- Hardcoded configuration values: {N} findings

**Findings**: {total} total ({medium} medium, {low} low)
```

### Step 4.4 — Update STATE

After Phase 4 is complete, update the STATE block:

```
STATE:
  phase: 5
  project_root: {absolute path}
  prep_branch: oss-prep/ready
  project_profile:
    language: {from Phase 0}
    framework: {from Phase 0}
    package_manager: {from Phase 0}
    build_system: {from Phase 0}
    test_framework: {from Phase 0}
  findings:
    total: {cumulative total from Phases 1 + 2 + 3 + 4}
    critical: {cumulative critical}
    high: {cumulative high}
    medium: {cumulative medium}
    low: {cumulative low}
  phases_completed: [0, 1, 2, 3, 4]
  history_flattened: false
```

> **Note**: The state update is an orchestrator responsibility. The orchestrator also sets `phase_findings["4"]` with per-phase counts and `status: "completed"` (or `"skipped"`). This phase file documents the expected state change for reference.

Announce:
> "Phase 4 (Code Architecture & Quality Review) complete. Moving to Phase 5 — Documentation Generation."

Wait for user approval before beginning Phase 5 (per the Phase-Gating Interaction Model).

---

## Finding Format

Phase 4 findings use the `Q4-{N}` format (Q4 = Quality Phase 4), numbered sequentially across all streams.

### Coding Standards Missing-Config Finding

```
### Finding Q4-{N}: Missing {category} configuration

- **Severity**: LOW
- **Category**: Coding Standards
- **Detail**: No {specific tool} configuration found. Consider adding {recommended config file} for consistent {formatting|linting|type checking|build automation}.
```

### Build Failure Finding

```
### Finding Q4-{N}: Build failure detected

- **Severity**: MEDIUM
- **Category**: Build Verification
- **Command**: {the command that was run}
- **Exit Code**: {exit code}
- **Error Output**: {relevant error output, truncated to 50 lines}
- **Note**: Build failures are non-blocking — this finding is reported for awareness but does not prevent proceeding to Phase 5.
```

### Test Failure Finding

```
### Finding Q4-{N}: Test failures detected

- **Severity**: MEDIUM
- **Category**: Test Verification
- **Command**: {the command that was run}
- **Exit Code**: {exit code}
- **Summary**: {X passed, Y failed, Z skipped — if parseable from output}
- **Failed Tests**: {list of failed test names, truncated to 20 entries}
- **Note**: Test failures are non-blocking — this finding is reported for awareness but does not prevent proceeding to Phase 5.
```

### Code Quality Finding

```
### Finding Q4-{N}: {brief description}

- **Severity**: {MEDIUM|LOW}
- **Category**: {Dead Code | TODO/FIXME/HACK | Commented-Out Code | Hardcoded Config}
- **Location**: {file_path}:{line_number}
- **Detail**: {description of the quality concern}
- **Suggestion**: {recommended action}
```

---

## User Gate

> "Phase 4 (Code Architecture & Quality Review) complete. Choose one:
> - **Approve and continue** — Accept findings and move to Phase 5 (Documentation Generation)
> - **Review details** — Show the full architecture summary and all findings
> - **Request changes** — Re-run specific analysis streams or adjust findings
> - **Skip** — Mark Phase 4 as skipped and move on"

**Do NOT advance to Phase 5 until the user explicitly responds.**

The phase summary presented before this gate includes:
- **Architecture Summary** (concise 10-15 line overview)
- **Coding Standards** (4 categories: formatting, linting, type checking, build scripts — each marked Present or Missing)
- **Build Verification** status (Passed / Failed / Skipped)
- **Test Verification** status (Passed with counts / Failed with counts / Skipped)
- **Code Quality** counts by category (dead code, TODO/FIXME/HACK, commented-out code, hardcoded config)
