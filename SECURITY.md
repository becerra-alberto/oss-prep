# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |

## Reporting a Vulnerability

If you discover a security vulnerability in oss-prep, please report it responsibly.

### How to Report

1. **Do not** open a public issue for security vulnerabilities.
2. Use [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) feature on this repository.
3. Alternatively, email the maintainers directly (see the repository's maintainer contact information).

### What to Include

- A description of the vulnerability
- Steps to reproduce the issue
- The potential impact
- Any suggested fixes (if you have them)

### What to Expect

- **Acknowledgment**: Within 48 hours of your report
- **Status updates**: At least once per week while the issue is being investigated
- **Resolution target**: Within 90 days of the initial report
- **Credit**: You will be credited in the security advisory (unless you prefer to remain anonymous)

## Scope

### In Scope

- The oss-prep skill code (phase files, pattern libraries, orchestrator, state schema)
- Regex patterns that could cause ReDoS (catastrophic backtracking)
- Logic issues that could cause false negatives (missing real secrets or PII)

### Out of Scope

- Third-party services or tools invoked by oss-prep (e.g., `npm audit`, `trufflehog`)
- The Claude Code runtime environment itself
- Social engineering attacks
- Denial of service testing
