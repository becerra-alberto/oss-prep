# Phase 3 — Dependency Audit

- **Phase**: 3
- **Name**: Dependency Audit
- **Inputs**: project_root, project_profile, state (from Phases 0-2), license_choice (from orchestrator pre-check or state)
- **Outputs**: dependency inventory tables (per-ecosystem), findings list (D3-1 through D3-N), finding counts by severity, state update (phase: 4, cumulative findings from Phases 1+2+3, phases_completed adds 3, license_choice)

---

Phase 3 inventories all project dependencies across all detected ecosystems, checks license compatibility against the project's chosen license, flags private or internal packages that would break for external contributors, and opportunistically runs ecosystem audit tools for known vulnerabilities. Unlike Phases 1-2 (pattern-based scanning), Phase 3 performs structured manifest parsing and license analysis on the working tree only — dependencies are not meaningfully auditable in git history.

---

## Step 3.0 — License Context (Orchestrator Pre-Check)

> **Architectural note (DD-4)**: The sub-agent cannot interact with the user. Therefore, the license check and prompt described below are handled by the **orchestrator** BEFORE dispatching the Phase 3 sub-agent. The orchestrator passes the resolved `license_choice` as an input to the sub-agent.

The orchestrator performs the following before dispatching the Phase 3 sub-agent:

### 1. Check for existing LICENSE file

The orchestrator checks if a `LICENSE` file exists at the project root (`{project_root}/LICENSE`).

### 2a. If LICENSE exists — Identify the license type

Read the LICENSE file and identify the license type by matching against standard license templates:

- **MIT** — contains "Permission is hereby granted, free of charge" and "The above copyright notice and this permission notice"
- **Apache-2.0** — contains "Apache License" and "Version 2.0"
- **GPL-3.0** — contains "GNU GENERAL PUBLIC LICENSE" and "Version 3"
- **BSD-2-Clause** — contains "Redistribution and use in source and binary forms" with exactly 2 conditions
- **BSD-3-Clause** — contains "Redistribution and use in source and binary forms" with 3 conditions (including non-endorsement)
- **MPL-2.0** — contains "Mozilla Public License Version 2.0"
- **ISC** — contains "Permission to use, copy, modify, and/or distribute this software"
- **Unlicense** — contains "This is free and unencumbered software released into the public domain"

If the license is recognized, record it as `license_choice` and pass it to the sub-agent.

If the license is **not recognized**, record `license_choice` as `"Unknown"` and note this for Phase 5 to handle.

### 2b. If LICENSE does not exist — Present license selection menu

Present the following numbered menu to the user. **The user MUST explicitly select and confirm a license — never auto-select.**

```
No LICENSE file found. A license choice is needed for dependency compatibility analysis.
Please select a license for your project:

  1. MIT (default — permissive, minimal restrictions)
  2. Apache-2.0 (permissive, includes patent grant)
  3. GPL-3.0 (strong copyleft, requires derivative works to be GPL-3.0)
  4. BSD-2-Clause (permissive, minimal restrictions)
  5. BSD-3-Clause (permissive, adds non-endorsement clause)
  6. MPL-2.0 (weak copyleft, file-level copyleft)
  7. ISC (permissive, functionally equivalent to MIT)
  8. Unlicense (public domain dedication)

Enter a number (1-8):
```

Record the user's selection as `license_choice` and pass it to the sub-agent.

### 3. State update

The selected or detected license is recorded as `state.license_choice` for downstream use by Phase 5 (which reads it from state instead of re-prompting).

---

## Step 3.1 — Manifest Detection

Use Glob to discover all package manifests and lock files across the repository, including nested directories (monorepo support). Search for the following patterns:

| Ecosystem | Manifest Glob Patterns | Lock File Glob Patterns |
|-----------|----------------------|------------------------|
| Node.js (npm/yarn/pnpm) | `**/package.json` | `**/package-lock.json`, `**/yarn.lock`, `**/pnpm-lock.yaml` |
| Python (pip/pipenv/poetry) | `**/requirements.txt`, `**/requirements/*.txt`, `**/Pipfile`, `**/pyproject.toml` | `**/Pipfile.lock`, `**/poetry.lock` |
| Rust (cargo) | `**/Cargo.toml` | `**/Cargo.lock` |
| Go | `**/go.mod` | `**/go.sum` |
| Ruby (bundler) | `**/Gemfile` | `**/Gemfile.lock` |
| Java (Maven/Gradle) | `**/pom.xml`, `**/build.gradle`, `**/build.gradle.kts` | (no standard lock file) |
| PHP (Composer) | `**/composer.json` | `**/composer.lock` |
| .NET (NuGet) | `**/*.csproj`, `**/*.fsproj`, `**/packages.config` | (no standard lock file) |
| Elixir (Mix) | `**/mix.exs` | `**/mix.lock` |
| Swift (SPM) | `**/Package.swift` | `**/Package.resolved` |

For each discovered manifest:
1. Record the file path and ecosystem type.
2. Note whether a corresponding lock file exists alongside it.
3. Group manifests by ecosystem for processing in Step 3.2.

**Skip** manifests found inside `node_modules/`, `vendor/`, `.build/`, `_build/`, `target/`, `dist/`, or other build artifact directories — these are transitive copies, not project manifests.

Present the manifest discovery results to the user before proceeding:

```
### Detected Package Manifests

| # | Ecosystem | Manifest Path | Lock File |
|---|-----------|--------------|-----------|
| 1 | {ecosystem} | {path} | {lock file path or "None"} |
| 2 | ... | ... | ... |
```

---

## Step 3.2 — Dependency Inventory Table Generation

For each detected manifest, parse it and produce a dependency inventory table. The table must have the following columns:

| Column | Description |
|--------|-------------|
| **Package Name** | The dependency identifier (e.g., `lodash`, `requests`, `serde`) |
| **Version** | Pinned version or version range from the manifest (e.g., `^4.17.21`, `>=3.8`, `1.0.0`) |
| **License** | The declared license (see license extraction methods below), or `"Unknown"` if not determinable |
| **Direct/Transitive** | `"Direct"` if listed in the manifest, `"Transitive"` if only appearing in lock files |
| **Flags** | Any concerns: private registry, incompatible license, deprecated, unknown license, etc. (empty if none) |

### License Extraction Methods (by ecosystem)

Use the following methods in priority order for each ecosystem. Fall back to the next method if the previous one is unavailable:

**Node.js**:
1. Read the `license` field from each dependency's entry in `node_modules/{pkg}/package.json` (if `node_modules` exists).
2. Parse `package-lock.json` — v2/v3 lockfiles include license metadata in the `packages` section.
3. If neither is available, mark license as `"Unknown"`.

**Python**:
1. If `pip` is available, run `pip show {package}` for each direct dependency and read the `License` field.
2. Parse `pyproject.toml` for `[project.license]` or `[tool.poetry.dependencies]` metadata.
3. If neither is available, mark license as `"Unknown"`.

**Rust**:
1. If `cargo` is available, run `cargo metadata --format-version=1` and parse the `license` field from the `packages` array.
2. Read `Cargo.toml` `[dependencies]` directly for package names and versions (license will be `"Unknown"` without cargo metadata).

**Go**:
1. If `go` is available, run `go list -m -json all` and check for license files in the module cache.
2. Read `go.mod` directly for module names and versions (license will be `"Unknown"` without the Go toolchain).

**Ruby**:
1. If `bundle` is available, run `bundle show --paths` and check each gem's `.gemspec` for `license` or `licenses` fields.
2. Parse `Gemfile.lock` for dependency names and versions (license will be `"Unknown"` without bundler inspection).

**PHP**:
1. Parse `composer.lock` — it includes `license` fields for each package.
2. Parse `composer.json` for direct dependency names and versions.

**Java/Gradle/.NET/Elixir/Swift**:
1. Parse the manifest for dependency names and versions.
2. License information is typically not available without running the build system's dependency resolution. Mark as `"Unknown"` and note this in the output.

**Graceful degradation rule**: If an ecosystem's toolchain is not installed locally, extract what is possible from the manifest and lock files directly. Clearly state what could not be determined and why (e.g., "Go toolchain not available — transitive dependencies and licenses could not be resolved"). Never fail or error out — always produce a partial inventory with clear notes about gaps.

---

## Step 3.3 — License Compatibility Checking

After building the dependency inventory, check each dependency's license against the project's license (`license_choice` input provided by the orchestrator from Step 3.0 or state).

### Compatibility Matrix

Use the following matrix to determine compatibility. The **Project License** (columns) is checked against each **Dependency License** (rows):

| Dependency ↓ / Project → | MIT | ISC | BSD-2/3 | Apache-2.0 | GPL-2.0 | GPL-3.0 | AGPL-3.0 |
|--------------------------|-----|-----|---------|------------|---------|---------|----------|
| MIT | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| ISC | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| BSD-2-Clause | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| BSD-3-Clause | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Apache-2.0 | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| LGPL-2.1 | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ | ✅ |
| LGPL-3.0 | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ |
| MPL-2.0 | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ |
| GPL-2.0 | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| GPL-3.0 | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| AGPL-3.0 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Unlicense / CC0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Unknown | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |

Legend:
- ✅ Compatible — LOW severity (informational)
- ⚠️ Requires attention — MEDIUM severity (weak-copyleft or unknown; may require special handling)
- ❌ Incompatible — CRITICAL severity (copyleft dependency in a more-permissive project)

### Severity Classification for License Findings

| Severity | Criteria |
|----------|----------|
| **CRITICAL** | Dependency license is clearly incompatible with the project license (❌ in the matrix). The project would be in violation of the dependency's license terms if published as-is. |
| **HIGH** | Dependency license is `"Unknown"` — risk cannot be assessed. The dependency may be proprietary, custom-licensed, or simply missing metadata. |
| **MEDIUM** | Dependency uses a weak-copyleft license (LGPL, MPL) that is conditionally compatible (⚠️ in the matrix). These licenses allow usage in permissive projects under specific conditions (e.g., dynamic linking for LGPL, file-level copyleft for MPL) but require the developer to understand and comply with those conditions. |
| **LOW** | Dependency license is fully compatible (✅ in the matrix). Included for completeness in the inventory but not flagged as an issue. |

---

## Step 3.4 — Private/Internal Dependency Detection

Scan all discovered manifests for dependencies that reference private or internal resources. These will break for external contributors and must be resolved before open-source release. All private dependency findings are classified as **CRITICAL**.

### Detection Heuristics

**Scoped packages on private registries (Node.js)**:
1. Check for `.npmrc` or `.yarnrc` / `.yarnrc.yml` files that define non-default registry URLs.
2. Scan `package.json` for scoped packages (`@scope/package`) and cross-reference with any custom registry configuration.
3. Flag scoped packages that do not resolve to the default npm registry (`https://registry.npmjs.org`).

**Local path references**:
- `file:` protocol dependencies (e.g., `"my-lib": "file:../my-lib"` in `package.json`)
- `path` dependencies in `Cargo.toml` (e.g., `my-crate = { path = "../my-crate" }`)
- `path` dependencies in `pyproject.toml` or `requirements.txt` (e.g., `-e ../local-pkg` or `my-pkg @ file:///local/path`)
- Relative path references in `go.mod` `replace` directives

**Private git repository references**:
- `git+ssh://` URLs in any manifest
- `git@github.com:{org}/{private-repo}` URLs
- GitHub URLs pointing to repositories that are likely private (heuristic: the URL contains organization names, not well-known open-source orgs)
- `git+https://` URLs with authentication tokens embedded

**Private registry configurations**:
- `.npmrc` with `registry=` pointing to a non-default URL (e.g., Artifactory, Nexus, GitHub Packages private feed)
- `.yarnrc.yml` with `npmRegistryServer:` pointing to a non-default URL
- `pip.conf` or `pip.ini` with `index-url` or `extra-index-url` pointing to private PyPI mirrors
- `~/.cargo/config.toml` with `[registries]` sections (note: this is a user-level config, so just check for `Cargo.toml` dependencies that specify `registry = "my-private-registry"`)

### Finding Format for Private Dependencies

```
### Finding D3-{N}: Private dependency detected — {package name}

- **Severity**: CRITICAL
- **Category**: Private/Internal Dependency
- **Location**: {manifest file path}
- **Package**: {package name}
- **Reference Type**: {scoped/private registry | file: protocol | git+ssh | private git URL | private registry config}
- **Reference Value**: {the URL, path, or scope reference}
- **Impact**: External contributors will not be able to install this dependency
- **Remediation**: {see remediation options below}
```

### Remediation Options for Private Dependencies

1. **Publish to a public registry**: If the dependency is owned by the project maintainers, publish it to the ecosystem's public registry (npm, PyPI, crates.io, etc.).
2. **Vendor/inline the dependency**: Copy the dependency source into the project repository if its license permits.
3. **Replace with a public alternative**: Find an equivalent public package that provides the same functionality.
4. **Remove the dependency**: If the functionality is non-essential, remove the dependency and the code that uses it.
5. **Convert to optional**: Make the dependency optional/feature-gated so the project works without it but gains extra functionality when it's available.

---

## Step 3.5 — Opportunistic Vulnerability Checking

Before building the inventory, check if ecosystem-specific audit tools are available on PATH. If found, run them and include results as informational findings.

```bash
# Node.js
command -v npm 2>/dev/null && echo "npm available" || echo "npm not found"
command -v yarn 2>/dev/null && echo "yarn available" || echo "yarn not found"

# Python
command -v pip-audit 2>/dev/null && echo "pip-audit available" || echo "pip-audit not found"

# Rust
command -v cargo-audit 2>/dev/null && echo "cargo-audit available" || echo "cargo-audit not found"

# Ruby
command -v bundle-audit 2>/dev/null && echo "bundle-audit available" || echo "bundle-audit not found"
```

### If `npm` is available (and a `package-lock.json` exists):
```bash
npm audit --json 2>/dev/null
```
Parse the JSON output for vulnerability counts by severity.

### If `yarn` is available (and a `yarn.lock` exists):
```bash
yarn audit --json 2>/dev/null
```

### If `pip-audit` is available:
```bash
pip-audit --format=json 2>/dev/null
```

### If `cargo-audit` is available (and a `Cargo.lock` exists):
```bash
cargo audit --json 2>/dev/null
```

### If `bundle-audit` is available (and a `Gemfile.lock` exists):
```bash
bundle-audit check --format=json 2>/dev/null
```

**Classification**: All vulnerability audit findings are classified as **informational** — this skill is not a security scanner (per the grounding requirement). Include vulnerability counts and summaries in the phase report but do not promote them to CRITICAL/HIGH unless the vulnerability is directly related to a dependency that also has license or private-registry issues.

**If no audit tool is available**: Proceed without vulnerability checking. Do not warn the user or suggest installing tools. Simply note in the phase summary: "No ecosystem audit tools available on PATH — vulnerability check skipped."

---

## Step 3.6 — Finding Report Format

Each license or private dependency finding must be reported in this format:

```
### Finding D3-{N}: {brief description}

- **Severity**: {CRITICAL|HIGH|MEDIUM|LOW}
- **Category**: {License Incompatibility | Unknown License | Weak-Copyleft License | Private/Internal Dependency}
- **Location**: {manifest file path}
- **Package**: {package name} @ {version}
- **License**: {detected license or "Unknown"}
- **Project License**: {the project's own license from license_choice}
- **Compatibility**: {Compatible | Incompatible | Requires Attention | Unknown}
- **Explanation**: {why this is flagged — e.g., "GPL-3.0 is a strong copyleft license that requires the entire project to be released under GPL-3.0, which is incompatible with your MIT license"}
- **Remediation**: {proposed fix}
```

Number findings sequentially as `D3-1`, `D3-2`, etc. (D3 = Dependencies Phase 3).

### Remediation Options for License Findings

1. **Replace the dependency**: Find an alternative package with a compatible license.
2. **Remove the dependency**: If the functionality is non-essential.
3. **Change the project license**: If the project can adopt a more permissive or copyleft license to accommodate the dependency (note: this affects all users of the project).
4. **Contact the dependency author**: Request a dual-license or license exception (for borderline cases).
5. **Accept the risk**: Acknowledge the incompatibility with a documented rationale (for MEDIUM/weak-copyleft cases where the usage pattern may be compliant).

---

## Step 3.7 — Consolidate and Present Findings

After completing all analysis, consolidate findings:

1. **Combine** license compatibility findings, private dependency findings, and vulnerability audit results.
2. **Sort by severity**: CRITICAL first, then HIGH, MEDIUM, LOW.
3. **Number sequentially**: Assign finding IDs D3-1 through D3-N.

Present the **Phase Summary** (per the Phase-Gating Interaction Model):

```
## Phase 3 Summary — Dependency Audit

**Ecosystems detected**: {list of ecosystems and manifest counts}
**Total dependencies inventoried**: {N} ({N} direct, {N} transitive)
**License extraction rate**: {N}% of dependencies had determinable licenses
**Vulnerability audit**: {tool used and result summary, or "skipped — no audit tool available"}

**Findings**: {total} total ({critical} critical, {high} high, {medium} medium, {low} low)

### Key Highlights
1. {Most critical finding — brief description}
2. {Second most critical finding}
3. {Third most critical finding}
{...up to 5 highlights}

### Finding Breakdown
- License incompatibilities: {N} findings
- Unknown licenses: {N} findings
- Weak-copyleft (requires attention): {N} findings
- Private/internal dependencies: {N} findings
- Vulnerability advisories: {N} (informational)
```

---

## User Gate

> "Phase 3 (Dependency Audit) complete. Choose one:
> - **Approve and continue** — Accept findings and move to Phase 4 (Code Architecture & Quality Review)
> - **Review details** — Show the full dependency inventory table and all findings
> - **Request changes** — Re-analyze specific ecosystems or adjust severity classifications
> - **Skip** — Mark Phase 3 as skipped and move on"

**Do NOT advance to Phase 4 until the user explicitly responds.**

---

## Step 3.8 — Update STATE

After Phase 3 is complete, update the STATE block:

```
STATE:
  phase: 4
  project_root: {absolute path}
  prep_branch: oss-prep/ready
  project_profile:
    language: {from Phase 0}
    framework: {from Phase 0}
    package_manager: {from Phase 0}
    build_system: {from Phase 0}
    test_framework: {from Phase 0}
  findings:
    total: {cumulative total from Phases 1 + 2 + 3}
    critical: {cumulative critical}
    high: {cumulative high}
    medium: {cumulative medium}
    low: {cumulative low}
  phases_completed: [0, 1, 2, 3]
  license_choice: {from Step 3.0}
  history_flattened: false
```

> **Note**: The state update is an orchestrator responsibility. The orchestrator also sets `phase_findings["3"]` with per-phase counts and `status: "completed"` (or `"skipped"`). This phase file documents the expected state change for reference.

Announce:
> "Phase 3 (Dependency Audit) complete. Moving to Phase 4 — Code Architecture & Quality Review."

Wait for user approval before beginning Phase 4 (per the Phase-Gating Interaction Model).
