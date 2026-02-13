# Secret Detection Pattern Library

## Consumers

This pattern library is referenced by:
- **Phase 1** (Secrets & Credentials Audit) — primary scan
- **Phase 8** (History Flatten) — post-flatten verification scan

## Modification Policy

Any changes to patterns in this file must be reflected across all consumer phases. Do not duplicate or redefine these patterns in phase files — always reference this file by path.

---

## Pattern Categories

Scan for the following pattern categories. Each category includes one or more regex patterns.

#### AWS Credentials
| Pattern | Regex | Notes |
|---------|-------|-------|
| AWS Access Key ID | `AKIA[0-9A-Z]{16}` | Always starts with `AKIA` |
| AWS Secret Access Key | `(?i)aws_secret_access_key\s*[=:]\s*[A-Za-z0-9/+=]{40}` | 40-char base64 string |
| AWS Session Token | `(?i)aws_session_token\s*[=:]\s*[A-Za-z0-9/+=]+` | Variable length |

#### GCP Credentials
| Pattern | Regex | Notes |
|---------|-------|-------|
| GCP Service Account Key | `"type"\s*:\s*"service_account"` | JSON key file indicator |
| GCP API Key | `AIza[0-9A-Za-z_-]{35}` | Starts with `AIza` |
| GCP OAuth Client Secret | `(?i)client_secret.*[0-9a-zA-Z_-]{24,}` | In OAuth JSON files |

#### Azure Credentials
| Pattern | Regex | Notes |
|---------|-------|-------|
| Azure Subscription Key | `(?i)(azure\|subscription)[_-]?(key\|secret)\s*[=:]\s*[0-9a-f]{32}` | 32-char hex |
| Azure Connection String | `(?i)(DefaultEndpointsProtocol\|AccountKey)\s*=\s*[A-Za-z0-9/+=]+` | Storage connection strings |

#### GitHub Tokens
| Pattern | Regex | Notes |
|---------|-------|-------|
| GitHub PAT (classic) | `ghp_[0-9a-zA-Z]{36}` | Personal access token |
| GitHub OAuth Token | `gho_[0-9a-zA-Z]{36}` | OAuth access token |
| GitHub User Token | `ghu_[0-9a-zA-Z]{36}` | User-to-server token |
| GitHub Server Token | `ghs_[0-9a-zA-Z]{36}` | Server-to-server token |
| GitHub Refresh Token | `ghr_[0-9a-zA-Z]{36}` | Refresh token |
| GitHub Fine-Grained PAT | `github_pat_[0-9a-zA-Z_]{82}` | Fine-grained token |

#### Generic API Keys and Tokens
| Pattern | Regex | Notes |
|---------|-------|-------|
| API Key assignment | `(?i)[Aa]pi[_-]?[Kk]ey\s*[=:]\s*["']?[A-Za-z0-9_\-]{16,}["']?` | Generic API key pattern |
| API Token assignment | `(?i)[Aa]pi[_-]?[Tt]oken\s*[=:]\s*["']?[A-Za-z0-9_\-]{16,}["']?` | Generic API token pattern |
| Secret Key assignment | `(?i)[Ss]ecret[_-]?[Kk]ey\s*[=:]\s*["']?[A-Za-z0-9_\-]{16,}["']?` | Generic secret key pattern |
| Auth Token assignment | `(?i)(auth\|access\|bearer)[_-]?[Tt]oken\s*[=:]\s*["']?[A-Za-z0-9_\-\.]{16,}["']?` | Auth/access/bearer token |
| Private Key assignment | `(?i)private[_-]?[Kk]ey\s*[=:]\s*["']?[A-Za-z0-9_\-/+=]{16,}["']?` | Generic private key value |
| Password assignment | `(?i)(password\|passwd\|pwd)\s*[=:]\s*["']?[^\s"']{8,}["']?` | Hardcoded passwords |

#### Database Connection Strings
| Pattern | Regex | Notes |
|---------|-------|-------|
| MongoDB URI | `mongodb(\+srv)?://[^\s"']+` | MongoDB connection string |
| PostgreSQL URI | `postgres(ql)?://[^\s"']+` | PostgreSQL connection string |
| MySQL URI | `mysql://[^\s"']+` | MySQL connection string |
| Redis URI | `redis://[^\s"']+` | Redis connection string |
| MSSQL URI | `mssql://[^\s"']+` | SQL Server connection string |
| JDBC URL | `jdbc:[a-z]+://[^\s"']+` | Java database connectivity |

#### Private Keys (PEM Format)
| Pattern | Regex | Notes |
|---------|-------|-------|
| RSA Private Key | `-----BEGIN RSA PRIVATE KEY-----` | PKCS#1 RSA key |
| DSA Private Key | `-----BEGIN DSA PRIVATE KEY-----` | DSA key |
| EC Private Key | `-----BEGIN EC PRIVATE KEY-----` | Elliptic curve key |
| Ed25519 Private Key | `-----BEGIN OPENSSH PRIVATE KEY-----` | OpenSSH format (Ed25519 and others) |
| Generic Private Key | `-----BEGIN PRIVATE KEY-----` | PKCS#8 format |
| Encrypted Private Key | `-----BEGIN ENCRYPTED PRIVATE KEY-----` | Encrypted PKCS#8 (lower severity) |
| PGP Private Key | `-----BEGIN PGP PRIVATE KEY BLOCK-----` | PGP/GPG private key |

#### JWT & OAuth
| Pattern | Regex | Notes |
|---------|-------|-------|
| JWT Signing Secret | `(?i)(jwt[_-]?secret\|jwt[_-]?key\|signing[_-]?secret)\s*[=:]\s*["']?[^\s"']{8,}["']?` | JWT secret key |
| OAuth Client Secret | `(?i)(client[_-]?secret\|oauth[_-]?secret)\s*[=:]\s*["']?[A-Za-z0-9_\-]{16,}["']?` | OAuth client secret |

#### SMTP Credentials
| Pattern | Regex | Notes |
|---------|-------|-------|
| SMTP URI | `smtp://[^\s"']+` | SMTP connection string |
| SMTP Password | `(?i)smtp[_-]?(password\|pass\|pwd)\s*[=:]\s*["']?[^\s"']+["']?` | SMTP auth password |

#### .env File Contents
| Pattern | Regex | Notes |
|---------|-------|-------|
| Non-empty env var | `^[A-Z][A-Z0-9_]*=.+` | Any KEY=value pair in `.env*` files |
| Quoted env value | `^[A-Z][A-Z0-9_]*=["'].+["']` | Quoted values in `.env*` files |

**Scope**: Apply `.env` patterns only to files whose name matches `.env*` (e.g., `.env`, `.env.local`, `.env.production`). Do not apply these patterns to all files.

#### Vendor-Specific Tokens
| Pattern | Regex | Notes |
|---------|-------|-------|
| Slack Token | `xox[baprs]-[0-9a-zA-Z-]+` | Slack bot/app/user tokens |
| Stripe Key | `(sk\|pk)_(test\|live)_[0-9a-zA-Z]{24,}` | Stripe secret/publishable key |
| Twilio Auth Token | `(?i)twilio.*[0-9a-f]{32}` | 32-char hex token |
| SendGrid API Key | `SG\.[0-9A-Za-z_-]{22}\.[0-9A-Za-z_-]{43}` | SendGrid key format |
| Heroku API Key | `(?i)heroku.*[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}` | UUID format |
| Notion Integration Token | `(ntn\|secret)_[0-9a-zA-Z]{40,}` | Notion API token |

---

## Severity Guidance

Classify each finding using a combination of pattern confidence and Shannon entropy of the matched value.

### Entropy Calculation

For each matched value (the credential portion, not the key name), compute Shannon entropy:

```
H = -Σ (p(c) × log₂(p(c))) for each unique character c in the value
```

Where `p(c)` is the frequency of character `c` divided by the total length.

Entropy thresholds (bits per character):
- **High entropy**: H > 3.5 — likely a real credential
- **Moderate entropy**: 2.0 < H ≤ 3.5 — possibly real, possibly structured
- **Low entropy**: H ≤ 2.0 — likely a placeholder or dummy value

### Classification Rules

| Severity | Criteria |
|----------|----------|
| **CRITICAL** | Confirmed credential pattern (AWS key, PEM private key, GitHub token with valid prefix) AND high entropy (H > 3.5). OR any PEM-format private key (regardless of entropy). |
| **HIGH** | Pattern match in a non-example context (file is not in `test/`, `tests/`, `spec/`, `examples/`, `docs/` and filename does not contain `example`, `sample`, `mock`, `fixture`, `dummy`, `test`) AND moderate-to-high entropy (H > 2.0). |
| **MEDIUM** | Pattern match but low entropy (H ≤ 2.0), OR value matches known placeholder patterns: `YOUR_*_HERE`, `xxx`, `changeme`, `TODO`, `FIXME`, `placeholder`, `replace_me`, `insert_*_here`, `<REDACTED>`, `dummy`, `fake`, `test`. |
| **LOW** | Pattern match in an example/documentation file (README, docs/, examples/), OR value is an obvious dummy (e.g., `password`, `secret`, `12345`, `abcdef`), OR the match is in a code comment explaining a pattern rather than setting a value. |

### Special Cases

- **Encrypted private keys** (`BEGIN ENCRYPTED PRIVATE KEY`): Classify as MEDIUM (encrypted, lower risk but still worth noting).
- **Git history-only findings**: If the secret no longer exists in the working tree but was found in git history, maintain the severity classification but add a note: "Found in git history only — will be eliminated by Phase 8 (History Flatten)."
- **`.env.example` files**: Always classify as LOW — these files are intentionally committed with placeholder values.
- **Lock files** (`package-lock.json`, `yarn.lock`, `Cargo.lock`, etc.): Skip entirely — these contain integrity hashes, not secrets.
