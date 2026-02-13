---
id: "2.3"
epic: 2
title: "Phase 3 — Dependency Audit"
status: pending
source_prd: "tasks/prd-oss-prep.md"
priority: high
estimation: large
depends_on: ["1.2"]
---

# Story 2.3 — Phase 3: Dependency Audit

## User Story

As a developer preparing to open-source a private repo, I want the tool to inventory all dependencies, verify their license compatibility with my chosen license, and flag any private or internal packages, so that I do not violate license terms or expose internal infrastructure when publishing.

## Technical Context

This story adds the Phase 3 section to `SKILL.md`. Phase 3 shifts from pattern-based scanning (Phases 1-2) to structured manifest parsing and license analysis. It operates on the working tree only (dependencies are not meaningfully auditable in git history).

**Approach**:

1. **Comprehensive manifest detection (FR-16)**: SKILL.md instructs Claude to search for all recognized package manifests using Glob. The full detection list:

   | Ecosystem | Manifest Files | Lock Files |
   |-----------|---------------|------------|
   | Node.js (npm/yarn/pnpm) | `package.json` | `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` |
   | Python (pip/pipenv/poetry) | `requirements.txt`, `requirements/*.txt`, `Pipfile`, `pyproject.toml` | `Pipfile.lock`, `poetry.lock` |
   | Rust (cargo) | `Cargo.toml` | `Cargo.lock` |
   | Go | `go.mod` | `go.sum` |
   | Ruby (bundler) | `Gemfile` | `Gemfile.lock` |
   | Java (Maven/Gradle) | `pom.xml`, `build.gradle`, `build.gradle.kts` | (no standard lock file) |
   | PHP (Composer) | `composer.json` | `composer.lock` |
   | .NET (NuGet) | `*.csproj`, `*.fsproj`, `packages.config` | (no standard lock file) |
   | Elixir (Mix) | `mix.exs` | `mix.lock` |
   | Swift (SPM) | `Package.swift` | `Package.resolved` |

   The skill uses Glob patterns (e.g., `**/package.json`, `**/Cargo.toml`) to find manifests at any depth, supporting monorepo structures where multiple manifests exist.

2. **Dependency inventory table (FR-17)**: For each detected manifest, the skill instructs Claude to parse it and produce a table with columns:
   - **Package Name**: The dependency identifier.
   - **Version**: Pinned version or version range from the manifest.
   - **License**: Extracted from lock files (e.g., npm lock files contain license metadata), from the package itself if installed locally (e.g., `node_modules/pkg/package.json`), or marked as "Unknown" if not determinable.
   - **Direct/Transitive**: "Direct" if listed in the manifest, "Transitive" if only appearing in lock files.
   - **Flags**: Any concerns (private registry, incompatible license, deprecated, etc.).

3. **License compatibility checking (FR-18)**: The skill defines a compatibility matrix based on the project's LICENSE file (detected in Phase 0 or selected by the user). Key rules:
   - **MIT/ISC/BSD projects**: Incompatible with GPL-2.0, GPL-3.0, AGPL dependencies (copyleft cannot be included in permissive-licensed projects without the entire project becoming copyleft).
   - **Apache-2.0 projects**: Incompatible with GPL-2.0-only (but compatible with GPL-3.0), incompatible with AGPL.
   - **GPL projects**: Generally compatible with permissive licenses; incompatible with AGPL unless the project is also AGPL.
   - **Unknown licenses**: Flagged as HIGH severity (risk cannot be assessed).
   - Severity ratings: CRITICAL for clearly incompatible licenses, HIGH for unknown licenses, MEDIUM for weak-copyleft (LGPL, MPL) that may require special handling, LOW for fully compatible licenses (informational).

4. **Private/internal dependency detection (FR-19)**: The skill defines detection heuristics:
   - Scoped packages matching internal patterns: `@company/*`, `@internal/*`, or any scope that does not resolve to a public registry.
   - Dependencies using `file:` or `link:` protocols (local path references).
   - Dependencies pointing to private git repositories (e.g., `git+ssh://`, private GitHub URLs).
   - Dependencies from private registries (`.npmrc` or `.yarnrc` with non-default registry URLs, `pip.conf` with private index URLs).
   - All private dependency findings are classified as CRITICAL because they will break for external contributors.

5. **Opportunistic vulnerability checking (FR-20)**: The skill checks if ecosystem-specific audit tools are available on PATH and runs them if found:
   - `npm audit` or `yarn audit` for Node.js projects.
   - `pip-audit` for Python projects.
   - `cargo audit` for Rust projects.
   - `bundle audit` for Ruby projects.
   - Results are included in the findings but classified as informational (the tool is not a security scanner per NG-3).
   - If no audit tool is available, the skill notes this gracefully and does not fail.

6. **Graceful degradation (FR-57)**: For unrecognized project types or ecosystems where license extraction is not feasible (e.g., Java/Gradle without local dependency cache), the skill reports what it could determine and clearly states what it could not, rather than guessing or failing.

7. **User approval gate**: Findings are presented in the dependency inventory table format. CRITICAL and HIGH findings are highlighted. The user can acknowledge, remediate (remove/replace dependencies), or accept the risk. State block is updated with Phase 3 findings and `3` added to `phases_completed`.

## Acceptance Criteria

### AC1: Comprehensive Manifest Detection

- **Given** a monorepo containing a `package.json` at the root, a `requirements.txt` in a `backend/` subdirectory, and a `Cargo.toml` in a `cli/` subdirectory
- **When** Phase 3 runs manifest detection
- **Then** all three manifests are discovered and each ecosystem is identified correctly (Node.js, Python, Rust)

### AC2: Dependency Inventory Table Generation

- **Given** a Node.js project with a `package.json` listing 5 direct dependencies and a `package-lock.json` containing those 5 plus 20 transitive dependencies
- **When** Phase 3 parses the manifests
- **Then** a dependency inventory table is produced listing all 25 dependencies with package name, version, license (where determinable), and direct/transitive classification

### AC3: License Compatibility Flagging

- **Given** an MIT-licensed project that depends on a package with a GPL-3.0 license and another package with an Apache-2.0 license
- **When** Phase 3 performs license compatibility checking
- **Then** the GPL-3.0 dependency is flagged as CRITICAL (incompatible with MIT), the Apache-2.0 dependency is marked as compatible (LOW/informational), and the finding explains why the GPL-3.0 dependency is problematic

### AC4: Private/Internal Dependency Detection

- **Given** a `package.json` that includes: `"@acme-corp/internal-utils": "^1.0.0"` (scoped to a private registry), `"local-lib": "file:../local-lib"` (file protocol), and `"lodash": "^4.17.21"` (public npm package)
- **When** Phase 3 scans for private dependencies
- **Then** `@acme-corp/internal-utils` is flagged as CRITICAL (private registry scope), `local-lib` is flagged as CRITICAL (file protocol), and `lodash` is not flagged

### AC5: Graceful Handling and State Update

- **Given** a project with a `go.mod` file but no Go toolchain installed locally (so `go list -m all` cannot run), and Phase 3 completes its analysis
- **When** the skill attempts dependency analysis for the Go ecosystem
- **Then** the skill reports what it could extract from `go.mod` directly (module name, direct dependencies listed in the file), clearly states it could not resolve transitive dependencies or licenses without the Go toolchain, and the state block is updated with Phase 3 findings and `3` added to `phases_completed`

## Test Definition

### Unit Tests

- **Manifest detection breadth**: Create a test repository with at least one manifest file for each of the 10 listed ecosystems. Run Phase 3 and verify all are detected and listed.
- **License compatibility matrix**: Create a test repo with an MIT license and a `package.json` depending on packages with MIT, Apache-2.0, GPL-3.0, LGPL-2.1, and an unknown license. Verify: MIT is LOW, Apache-2.0 is LOW, GPL-3.0 is CRITICAL, LGPL-2.1 is MEDIUM, Unknown is HIGH.
- **Private dependency detection**: Create a `package.json` with `file:` protocol deps, `@internal/*` scoped packages, and standard public packages. Verify only the private/internal ones are flagged as CRITICAL.

### Integration/E2E Tests

- **Full Phase 3 end-to-end**: Create a Node.js test repository with `package.json`, `package-lock.json`, a mix of permissively-licensed and GPL-licensed dependencies, one `@company/private-pkg` dependency, and `npm audit` available. Run `/oss-prep` through Phase 3 and verify: complete inventory table generated, GPL dependency flagged as CRITICAL, private package flagged as CRITICAL, `npm audit` results included, and no changes applied without user approval.
- **Monorepo handling**: Create a repository with `package.json` at root and `backend/requirements.txt`. Verify Phase 3 discovers and audits both, producing separate inventory sections for each ecosystem.
- **Missing toolchain graceful degradation**: Create a repo with a `Cargo.toml` but no Rust toolchain installed. Verify Phase 3 extracts what it can from `Cargo.toml` directly and does not error out.

## Files to Create/Modify

- `skills/oss-prep/SKILL.md` -- add Phase 3 section with manifest detection list, dependency inventory table format, license compatibility matrix, private dependency detection heuristics, opportunistic vulnerability checking instructions, and user approval gate instructions (modify)
