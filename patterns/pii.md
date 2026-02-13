# PII Detection Pattern Library

## Consumers

This pattern library is referenced by:
- **Phase 2** (PII Audit) — primary scan
- **Phase 8** (History Flatten) — post-flatten verification scan

## Modification Policy

Any changes to patterns in this file must be reflected across all consumer phases. Do not duplicate or redefine these patterns in phase files — always reference this file by path.

---

## Pattern Categories

Scan for the following PII pattern categories. Each category includes one or more regex patterns and notes on expected false positive behavior.

#### Email Addresses
| Pattern | Regex | Notes |
|---------|-------|-------|
| General email | `[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}` | RFC 5322 simplified; filter against allowlist |
| Personal provider email | `[a-zA-Z0-9._%+\-]+@(gmail\.com\|yahoo\.com\|hotmail\.com\|outlook\.com\|icloud\.com\|protonmail\.com\|aol\.com\|mail\.com\|zoho\.com)` | Higher severity — directly identifies a person |

#### Phone Numbers
| Pattern | Regex | Notes |
|---------|-------|-------|
| North American (parenthesized) | `\(\d{3}\)\s?\d{3}[.\-]\d{4}` | Format: `(555) 123-4567` |
| North American (dashed) | `\b\d{3}[.\-]\d{3}[.\-]\d{4}\b` | Format: `555-123-4567` or `555.123.4567` |
| North American (E.164) | `\+1\d{10}\b` | Format: `+15551234567` |
| International (E.164) | `\+\d{1,3}\s?\d{4,14}\b` | Format: `+44 7911123456`; may produce false positives with version numbers |

#### Physical/Mailing Addresses
| Pattern | Regex | Notes |
|---------|-------|-------|
| US street address | `\b\d{1,5}\s+[A-Z][a-zA-Z]+(\s+[A-Z][a-zA-Z]+)*\s+(St\|Street\|Ave\|Avenue\|Blvd\|Boulevard\|Dr\|Drive\|Ln\|Lane\|Rd\|Road\|Ct\|Court\|Pl\|Place\|Way\|Pkwy\|Parkway\|Cir\|Circle)\b` | Requires number + street name + suffix; high false-positive rate in code comments |
| US city/state/zip | `[A-Z][a-zA-Z\s]+,\s*[A-Z]{2}\s+\d{5}(-\d{4})?` | Format: `City, ST 12345` or `City, ST 12345-6789` |

#### IP Addresses
| Pattern | Regex | Notes |
|---------|-------|-------|
| IPv4 (public only) | `\b(?!127\.0\.0\.1)(?!10\.\d{1,3}\.\d{1,3}\.\d{1,3})(?!172\.(1[6-9]\|2\d\|3[01])\.\d{1,3}\.\d{1,3})(?!192\.168\.\d{1,3}\.\d{1,3})(?!192\.0\.2\.\d{1,3})(?!198\.51\.100\.\d{1,3})(?!203\.0\.113\.\d{1,3})(?!0\.0\.0\.0)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b` | Excludes localhost, private ranges (10.x, 172.16-31.x, 192.168.x), and RFC 5737 documentation ranges (192.0.2.x, 198.51.100.x, 203.0.113.x) |

**Note on IPv6**: Skip IPv6 loopback (`::1`) and link-local (`fe80::`) addresses. Flag any other non-documentation IPv6 addresses found in source code.

#### Social Security Numbers (US)
| Pattern | Regex | Notes |
|---------|-------|-------|
| SSN format | `\b(?!000\|666\|9\d{2})\d{3}-(?!00)\d{2}-(?!0000)\d{4}\b` | US SSN format `XXX-XX-XXXX`; excludes invalid prefixes (000, 666, 900-999) and zero groups; filter against allowlist for `000-00-0000` |

**Context-awareness**: SSN patterns can match dates in `YYYY-MM-DDDD` adjacent patterns and other hyphenated numbers. Verify matches by checking surrounding context — if the match appears in a date context (near words like "date", "created", "modified", "timestamp") or version string context, downgrade to LOW or skip.

#### Credit Card Numbers
| Pattern | Regex | Notes |
|---------|-------|-------|
| Visa | `\b4\d{3}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b` | Starts with 4, 16 digits |
| Mastercard | `\b5[1-5]\d{2}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b` | Starts with 51-55, 16 digits |
| American Express | `\b3[47]\d{2}[\s\-]?\d{6}[\s\-]?\d{5}\b` | Starts with 34/37, 15 digits |
| Discover | `\b6(?:011\|5\d{2})[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b` | Starts with 6011 or 65, 16 digits |

**Luhn validation**: Where feasible, verify credit card number matches pass the Luhn checksum algorithm. Matches that fail Luhn validation should be downgraded to LOW severity (likely not a real card number).

#### Internal Employee Identifiers
| Pattern | Regex | Notes |
|---------|-------|-------|
| TODO/FIXME with name | `(?i)(TODO\|FIXME\|HACK\|XXX)\s*\(\s*[a-zA-Z][a-zA-Z0-9._\-]*\s*\)` | Format: `TODO(jsmith):`, `FIXME(john.doe):` — captures the username/name inside parentheses |
| Jira ticket reference | `[A-Z][A-Z0-9]+-\d+` | Format: `PROJ-1234`, `TEAM-567` — reveals internal project structure |
| Slack channel reference | `#[a-z][a-z0-9\-_]+` | Format: `#internal-channel`, `#team-backend` — reveals internal communication channels |
| Internal badge/employee ID | `(?i)(employee[_\-]?id\|badge[_\-]?id\|emp[_\-]?id\|staff[_\-]?id)\s*[=:]\s*["']?[A-Za-z0-9\-]+["']?` | Explicit employee ID assignments in code or config |

**Context-awareness for Jira references**: Jira patterns are common in commit messages and changelogs. Only flag them in source code files, config files, and comments — not in `CHANGELOG.md`, `HISTORY.md`, or git commit messages (which will be eliminated by history flatten).

#### Hardcoded Personal Names
| Pattern | Regex | Notes |
|---------|-------|-------|
| Names in TODO/FIXME | `(?i)(TODO\|FIXME\|HACK\|XXX)\s*\(?\s*[A-Z][a-z]+(\s+[A-Z][a-z]+)+\s*\)?` | Full names like `TODO(John Smith)` or `FIXME John Doe:` |
| Names in file headers | `(?i)(@author\|author:\|written by\|created by\|maintained by)\s+[A-Z][a-z]+(\s+[A-Z][a-z]+)+` | Attribution headers in source files |
| Names in test data | Look for string literals containing first+last name patterns in files under `test/`, `tests/`, `spec/`, `fixtures/`, `seeds/`, `__tests__/` directories and files with names containing `test`, `fixture`, `seed`, `mock`, `sample`, `fake` | Hardcoded names in test fixtures and seed data |

**Important**: Name detection has a high false-positive rate. Only flag names that appear to be real personal names (not obviously fictional like "John Doe" — which is in the allowlist). When uncertain, classify as MEDIUM and note the uncertainty.

---

## Severity Guidance

Classify each PII finding using the following rules:

| Severity | Criteria |
|----------|----------|
| **CRITICAL** | SSN, credit card number (passing Luhn), or combination of full name + address/phone/email that constitutes a complete identity profile. Any PII that could enable identity theft. |
| **HIGH** | Personal email address (at personal provider domain) in source code or config. Phone number with area code. Physical/mailing address. Public IP address in production config. Employee ID or badge number. |
| **MEDIUM** | Email address at corporate/internal domain (reveals affiliation but not necessarily personal). TODO/FIXME comments with usernames. Jira ticket references in source code. Slack channel references. Names in file headers or test data that might be real people. Git author emails (flagged by Sub-agent C). |
| **LOW** | Names in test data that appear fictional but are not in the allowlist. IP addresses in non-production config (development, staging). Jira references in changelogs. Phone numbers that may be fake/test numbers (e.g., 555-xxxx area code). Credit card numbers failing Luhn validation. |

### Special Cases

- **Git history-only findings**: Maintain the severity classification but add a note: "Found in git history only — will be eliminated by Phase 8 (History Flatten)."
- **Test/example files**: Findings in directories like `test/`, `tests/`, `spec/`, `examples/`, `docs/` or files named `*example*`, `*sample*`, `*mock*`, `*fixture*`, `*test*` are downgraded by one severity level (e.g., HIGH → MEDIUM), unless they contain SSNs or credit card numbers (which remain at their original severity).
- **Comments vs. code**: PII in code comments (not TODO/FIXME with names) is downgraded by one severity level compared to PII in executable code or config values.
- **License files**: Names in `LICENSE`, `LICENSE.md`, `LICENSE.txt` files are always skipped — these are intentional copyright attributions and should not be flagged.
