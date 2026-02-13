---
id: "2.1"
epic: 2
title: "Phase 1 — Secrets & Credentials Audit"
status: pending
source_prd: "tasks/prd-oss-prep.md"
priority: critical
estimation: large
depends_on: ["1.2"]
---

# Story 2.1 — Phase 1: Secrets & Credentials Audit

## User Story

As a developer preparing to open-source a private repo, I want the tool to find all secrets (API keys, tokens, passwords, private keys) in both the current codebase and git history, so that I do not accidentally expose credentials when the repo goes public.

## Technical Context

This story adds the Phase 1 section to `SKILL.md`. Phase 1 is the first security-critical phase and runs immediately after Phase 0 (Reconnaissance). All "code" is instructional markdown that tells Claude Code how to conduct the secrets audit.

**Approach**:

1. **Sub-agent parallelization (FR-53)**: Phase 1 dispatches two sub-agents simultaneously via the Task tool:
   - **Sub-agent A** — scans the current working tree using Grep with regex patterns for each secret category.
   - **Sub-agent B** — scans git history using `git log -p --all` piped through targeted pattern searches to find secrets that were committed and later removed.

2. **Pattern library**: SKILL.md defines an exhaustive pattern list covering: AWS access key IDs (`AKIA[0-9A-Z]{16}`), AWS secret keys, GCP service account JSON keys, Azure subscription keys, GitHub personal access tokens (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`), generic API key/token patterns (`[Aa]pi[_-]?[Kk]ey`, `[Aa]pi[_-]?[Tt]oken`, `[Ss]ecret[_-]?[Kk]ey`), database connection strings (`mongodb://`, `postgres://`, `mysql://`, `redis://`), private keys (PEM headers for RSA, DSA, EC, Ed25519, and OpenSSH format), JWT signing secrets, OAuth client secrets, SMTP credentials (`smtp://`, password fields near SMTP config), and `.env` file contents (any `KEY=value` pair in files matching `.env*`).

3. **Severity classification (FR-8)**: Each finding is classified using a combination of pattern confidence and entropy heuristics:
   - CRITICAL — confirmed credential pattern with high Shannon entropy (>3.5 bits/char for the value portion), or PEM-format private key.
   - HIGH — pattern match in a non-example context (not in test fixtures named `example`, not in documentation), moderate entropy.
   - MEDIUM — pattern match but low entropy or in a context suggesting a placeholder (e.g., `YOUR_API_KEY_HERE`, `xxx`, `changeme`).
   - LOW — pattern match in an example file, documentation, or with obvious dummy values.

4. **Remediation proposals (FR-9, FR-58)**: For each finding, the skill proposes surgical remediation rather than file deletion:
   - Replace hardcoded value with an environment variable reference (`process.env.X`, `os.environ['X']`).
   - Add the file to `.gitignore` (for `.env` files and similar).
   - Create a `.env.example` with placeholder values.
   - Redact the value in-place (replace with `<REDACTED>` or placeholder).
   - For git-history-only findings, note that history flatten (Phase 8) will eliminate them.

5. **Opportunistic tool detection**: If `trufflehog` or `gitleaks` is found on PATH, the skill instructs Claude to run it as a supplementary scan and merge its results, but never fails if these tools are absent.

6. **User approval gate (FR-10)**: All findings and proposed remediations are presented to the user. No changes are applied until the user explicitly approves.

7. **State update**: After Phase 1 completes, the running state block is updated with findings counts by severity and `phases_completed` gains `1`.

## Acceptance Criteria

### AC1: Comprehensive Working-Tree Secret Detection

- **Given** a repository with secrets embedded in source files (e.g., an AWS access key in a config file, a database connection string in a Python module, a PEM private key in a `.pem` file, and an API token in a `.env` file)
- **When** Phase 1 runs the working-tree scan sub-agent
- **Then** all four secret types are detected, each with the correct file path, line number, matched pattern category, and a severity classification of HIGH or CRITICAL

### AC2: Git History Secret Detection

- **Given** a repository where a secret (e.g., a GitHub personal access token `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`) was committed in an earlier commit and subsequently removed
- **When** Phase 1 runs the git-history scan sub-agent
- **Then** the finding includes the commit hash, author, date, file path, and the matched secret pattern, and is classified at the appropriate severity level

### AC3: Severity Classification with Entropy Heuristics

- **Given** a repository containing: (a) a real AWS secret key with high entropy, (b) a placeholder string `YOUR_API_KEY_HERE` matching an API key pattern, and (c) an example connection string `mongodb://user:password@localhost:27017/test` in a README
- **When** Phase 1 classifies these findings
- **Then** finding (a) is CRITICAL, finding (b) is MEDIUM, and finding (c) is LOW

### AC4: Surgical Remediation Proposals

- **Given** Phase 1 has detected a hardcoded database connection string in `src/config.py` and a `.env` file containing real credentials
- **When** the skill presents remediation proposals
- **Then** the proposal for the connection string suggests replacing it with an environment variable reference (e.g., `os.environ['DATABASE_URL']`), and the proposal for the `.env` file suggests adding `.env` to `.gitignore` and creating a `.env.example` with placeholder values. No file deletion is proposed (FR-58).

### AC5: User Approval Gate and State Update

- **Given** Phase 1 has completed scanning and presents its summary (findings count by severity, key highlights)
- **When** the user reviews the findings
- **Then** no remediation changes are applied until the user explicitly approves, and the state block is updated with `phase: 1`, the cumulative findings counts, and `1` added to `phases_completed`

## Test Definition

### Unit Tests

- **Pattern coverage**: Run `/oss-prep` on a test repository seeded with one instance of each secret category (AWS key, GCP key, Azure key, GitHub token, generic API key, database URI, PEM private key, JWT secret, OAuth secret, SMTP credential, `.env` content). Verify that all 11 categories produce at least one finding.
- **Entropy classification**: Seed a repo with a high-entropy random string assigned to `API_KEY=` and a low-entropy placeholder `API_KEY=changeme`. Verify the high-entropy finding is CRITICAL or HIGH and the low-entropy finding is MEDIUM or LOW.
- **False positive resilience**: Include a file with the text `AKIA` in a code comment that is not followed by 16 alphanumeric characters. Verify it does not produce a finding (or is classified LOW at most).

### Integration/E2E Tests

- **Full Phase 1 end-to-end**: Create a test repository with: (1) a `.env` file containing `DATABASE_URL=postgres://user:pass@prod.db:5432/app`, (2) an AWS key in `config/aws.js`, and (3) a GitHub token committed and then deleted in a prior commit. Run `/oss-prep` through Phase 1 and verify: all three are detected, severity classifications are reasonable, remediation proposals are surgical (no file deletions), and no changes are applied without user approval.
- **Opportunistic tool integration**: On a machine with `gitleaks` installed, run Phase 1 and verify the skill detects and uses it. On a machine without it, verify Phase 1 completes successfully using only built-in scanning.
- **Sub-agent parallelism**: Verify that Phase 1 dispatches at least two sub-agents (working-tree and git-history) and that both complete before the findings are consolidated and presented.

## Files to Create/Modify

- `skills/oss-prep/SKILL.md` -- add Phase 1 section with secret pattern definitions, sub-agent dispatch instructions, severity classification rules, remediation proposal templates, and user approval gate instructions (modify)
