---
id: "2.2"
epic: 2
title: "Phase 2 — PII Audit"
status: pending
source_prd: "tasks/prd-oss-prep.md"
priority: high
estimation: medium
depends_on: ["1.2"]
---

# Story 2.2 — Phase 2: PII Audit

## User Story

As a developer preparing to open-source a private repo, I want the tool to find personally identifiable information in the codebase and git history, so that I do not expose personal data (emails, names, internal identifiers) to the public.

## Technical Context

This story adds the Phase 2 section to `SKILL.md`. Phase 2 mirrors the structure of Phase 1 (Secrets Audit) but targets PII rather than credentials. It runs immediately after Phase 1 and reuses the same sub-agent parallelization pattern.

**Approach**:

1. **Sub-agent parallelization (FR-53)**: Phase 2 dispatches three sub-agents simultaneously:
   - **Sub-agent A** — scans the current working tree for PII patterns using Grep with targeted regex.
   - **Sub-agent B** — scans git history using `git log -p --all` with PII-focused pattern searches.
   - **Sub-agent C** — inspects git author/committer metadata across all commits for personal email addresses.

2. **PII pattern library**: SKILL.md defines patterns for:
   - **Email addresses**: RFC 5322 simplified pattern, with special attention to personal provider domains (gmail.com, yahoo.com, hotmail.com, outlook.com, icloud.com, protonmail.com) and corporate domains that reveal internal identity.
   - **Phone numbers**: North American (`(XXX) XXX-XXXX`, `XXX-XXX-XXXX`, `+1XXXXXXXXXX`) and international (`+XX XXXXXXXXXX`) formats.
   - **Physical/mailing addresses**: Street address patterns (number + street name + city/state/zip).
   - **IP addresses (FR-14 exclusions)**: IPv4 addresses, excluding: localhost (`127.0.0.1`), private ranges (`10.x.x.x`, `172.16-31.x.x`, `192.168.x.x`), and RFC 5737 documentation ranges (`192.0.2.x`, `198.51.100.x`, `203.0.113.x`). Also excludes IPv6 loopback (`::1`) and link-local (`fe80::`).
   - **SSNs**: US format `XXX-XX-XXXX` with context-awareness to avoid matching dates or other hyphenated number patterns.
   - **Credit card numbers**: Visa, Mastercard, Amex, Discover prefix patterns with Luhn validation where feasible.
   - **Internal employee IDs**: Badge numbers, internal usernames in comments (e.g., `// TODO(jsmith):`), Jira ticket references (`PROJ-XXXX`), Slack channel references (`#internal-channel`).
   - **Hardcoded personal names**: Names in TODO/FIXME comments, test data, fixture files, database seeds, and file header attributions.

3. **Public/generic PII allowlist (FR-14)**: The skill defines an allowlist of values that match PII patterns but are not sensitive:
   - `example@example.com`, `user@example.com`, `test@test.com`, `noreply@github.com`
   - `127.0.0.1`, `0.0.0.0`, `localhost`, `::1`
   - RFC 5737 documentation IPs: `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`
   - `000-00-0000` (placeholder SSN)
   - Common test card numbers (e.g., Stripe test cards `4242424242424242`)
   - Names like "John Doe", "Jane Doe", "Alice", "Bob" in clearly test/example contexts

4. **Git author/committer email check (FR-13)**: Sub-agent C runs `git log --format='%ae%n%ce' --all | sort -u` to collect all unique author and committer emails. Personal emails (non-noreply, non-generic) are flagged with a recommendation to use `username@users.noreply.github.com` or a project-specific email address. The skill explains how to configure this with `git config user.email`.

5. **Remediation proposals (FR-15)**: For each finding:
   - Replace personal email with a generic/noreply address.
   - Replace hardcoded names with generic placeholders in test data.
   - Redact or anonymize addresses, phone numbers, and IDs.
   - For git-history-only findings, note that history flatten (Phase 8) will eliminate them.
   - For git author emails, provide `git config` command and note that history flatten resolves historical attribution.

6. **User approval gate**: All findings and proposed remediations are presented. No changes are applied without explicit approval. State block is updated with Phase 2 findings and `2` added to `phases_completed`.

## Acceptance Criteria

### AC1: Working-Tree PII Detection

- **Given** a repository containing: a personal email address in a config file, a phone number in a test fixture, a public IP address in a hardcoded endpoint, and a name in a TODO comment (`// TODO(john.smith): refactor this`)
- **When** Phase 2 runs the working-tree scan sub-agent
- **Then** all four PII types are detected with correct file paths, line numbers, and pattern categories

### AC2: Public/Generic PII Allowlist Filtering

- **Given** a repository containing `example@example.com` in a README, `127.0.0.1` in a development config, `192.0.2.1` in a documentation example, and `4242424242424242` in a Stripe test file
- **When** Phase 2 scans these files
- **Then** none of these values are flagged as PII findings (they are filtered by the allowlist)

### AC3: Git Author Email Flagging

- **Given** a repository with commits authored by `developer@gmail.com` and `alice@company-internal.com`
- **When** Phase 2 runs the git author metadata sub-agent
- **Then** both emails are flagged with a recommendation to switch to a noreply GitHub address, and the skill provides the `git config user.email` command for remediation

### AC4: Git History PII Detection

- **Given** a repository where a file previously contained a hardcoded SSN (`123-45-6789`) that was committed and later removed
- **When** Phase 2 runs the git-history scan sub-agent
- **Then** the finding includes the commit hash, author, date, file path, and the matched SSN pattern, and notes that history flatten (Phase 8) will eliminate it

### AC5: Remediation Proposals and User Approval Gate

- **Given** Phase 2 has completed scanning and presents its summary
- **When** the user reviews the findings
- **Then** each finding has a specific remediation proposal (not generic), no changes are applied without explicit user approval, and the state block is updated with Phase 2 cumulative findings and `2` added to `phases_completed`

## Test Definition

### Unit Tests

- **Pattern coverage**: Run `/oss-prep` Phase 2 on a test repository seeded with one instance of each PII category (personal email, phone number, physical address, public IP, SSN, credit card number, employee ID in comment, hardcoded name in test data). Verify all categories produce findings.
- **Allowlist filtering**: Seed a repo with only allowlisted values (`example@example.com`, `127.0.0.1`, `192.0.2.1`, `4242424242424242`). Verify Phase 2 produces zero findings for these values.
- **IP exclusion ranges**: Include `10.0.0.5` (private), `172.16.0.1` (private), `192.168.1.1` (private), and `8.8.8.8` (public) in a config file. Verify only `8.8.8.8` is flagged.

### Integration/E2E Tests

- **Full Phase 2 end-to-end**: Create a test repository with: (1) a personal email in `src/utils.py`, (2) a TODO comment with a real name, (3) a phone number in `tests/fixtures/users.json`, and (4) commits authored by a personal gmail address. Run `/oss-prep` through Phase 2 and verify: all findings detected, git author email flagged, remediation proposals are specific and surgical, and no changes applied without approval.
- **Sub-agent parallelism**: Verify Phase 2 dispatches at least three sub-agents (working-tree, git-history, git-author-metadata) and all complete before findings are consolidated.
- **Sequential execution after Phase 1**: Verify Phase 2 only runs after Phase 1 completes and the user approves the phase transition.

## Files to Create/Modify

- `skills/oss-prep/SKILL.md` -- add Phase 2 section with PII pattern definitions, allowlist, git author check instructions, sub-agent dispatch instructions, remediation proposal templates, and user approval gate instructions (modify)
