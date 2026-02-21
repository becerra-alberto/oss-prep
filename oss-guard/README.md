# oss-guard

A Claude Code PreToolUse hook that intercepts `Write` and `Edit` tool calls and scans for high-confidence secret/PII patterns before they hit disk.

When a match is found, it returns `permissionDecision: "ask"` so Claude Code shows a permission dialog — you can approve or deny each case.

## Detected Patterns

| Category | Example |
|----------|---------|
| AWS Access Keys | `AKIA1234567890ABCDEF` |
| GitHub Tokens | `ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`, `github_pat_` |
| Slack Tokens | `xoxb-`, `xoxp-`, `xoxs-` |
| Stripe Live Keys | `sk_live_`, `pk_live_` |
| Notion Tokens | `ntn_` |
| Private Key Blocks | `-----BEGIN RSA PRIVATE KEY-----` |
| Generic Secret Assignments | `api_key = "long_value"` |
| SSN Patterns | `123-45-6789` |

## Skipped Files

Binary files, lock files, and `.env.example`/`.env.sample`/`.env.template` are skipped to avoid false positives.

## Install

```bash
# 1. Copy the hook
cp oss-guard.sh ~/.claude/hooks/oss-guard.sh
chmod +x ~/.claude/hooks/oss-guard.sh

# 2. Register in ~/.claude/settings.json
# Add this entry to hooks.PreToolUse:
```

```json
{
  "matcher": "Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "~/.claude/hooks/oss-guard.sh",
      "timeout": 10
    }
  ]
}
```

## Pair with CLAUDE.md rules

For best coverage, add these rules to `~/.claude/CLAUDE.md`:

```markdown
## OSS-Safe Coding Defaults

- Never hardcode secrets, API keys, tokens, passwords, or credentials in source code
- Never include real email addresses in code or test data — use @example.com (RFC 2606)
- Never include real phone numbers — use 555-0100 through 555-0199 (reserved range)
- Use fictional/placeholder data in tests and examples
- When creating .env.example files, use empty values or descriptive placeholders
- When creating a new project, include a .gitignore covering: .env*, *.pem, *.key, *.p12, credentials.json, service-account*.json
```

The CLAUDE.md rules prevent Claude from generating secrets (~90% coverage), while this hook catches slips at write time.

## Requirements

- `jq` (available on most systems, or `brew install jq`)
- Claude Code with hook support
