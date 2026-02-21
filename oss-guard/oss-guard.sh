#!/usr/bin/env bash
# oss-guard.sh — Claude Code PreToolUse hook for Write|Edit
# Scans file content for high-confidence secret/PII patterns.
# Outputs JSON with permissionDecision: "ask" if a match is found,
# so the user sees a permission dialog and can approve or deny.
#
# Install:
#   1. Copy this file to ~/.claude/hooks/oss-guard.sh
#   2. chmod +x ~/.claude/hooks/oss-guard.sh
#   3. Add to ~/.claude/settings.json under hooks.PreToolUse:
#      {
#        "matcher": "Write|Edit",
#        "hooks": [{ "type": "command", "command": "~/.claude/hooks/oss-guard.sh", "timeout": 10 }]
#      }

set -euo pipefail

INPUT=$(cat)

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL" != "Write" && "$TOOL" != "Edit" ]]; then
  exit 0
fi

# Extract the file path
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty')

# Skip binary files, lock files, and .env.example
if [[ -n "$FILE_PATH" ]]; then
  BASENAME=$(basename "$FILE_PATH")
  case "$BASENAME" in
    *.lock|*.lockb|*.png|*.jpg|*.jpeg|*.gif|*.ico|*.woff|*.woff2|*.ttf|*.eot|*.pdf)
      exit 0 ;;
    .env.example|.env.sample|.env.template)
      exit 0 ;;
  esac
fi

# Gather content to scan — new_string for Edit, content for Write
CONTENT=$(echo "$INPUT" | jq -r '
  (.tool_input.content // "") + "\n" +
  (.tool_input.new_string // "") + "\n" +
  (.tool_input.newString // "")
')

if [[ -z "$CONTENT" || "$CONTENT" == $'\n\n' ]]; then
  exit 0
fi

FINDINGS=""

check_pattern() {
  local label="$1" pattern="$2"
  if echo "$CONTENT" | grep -qE -- "$pattern" 2>/dev/null; then
    MATCH=$(echo "$CONTENT" | grep -oE -- "$pattern" 2>/dev/null | head -1)
    FINDINGS="${FINDINGS}${label}: ${MATCH}\n"
  fi
}

# High-signal patterns only
check_pattern "AWS Access Key"         "AKIA[0-9A-Z]{16}"
check_pattern "GitHub Token"           "(ghp_|gho_|ghu_|ghs_|ghr_|github_pat_)[A-Za-z0-9_]{10,}"
check_pattern "Slack Token"            "xox[bpors]-[A-Za-z0-9-]{10,}"
check_pattern "Stripe Live Key"        "(sk_live_|pk_live_)[A-Za-z0-9]{10,}"
check_pattern "Notion Token"           "ntn_[A-Za-z0-9]{10,}"
check_pattern "Private Key Block"      "-----BEGIN[A-Z ]*PRIVATE KEY-----"
check_pattern "Generic Secret Assign"  "(api_key|secret_key|api_token|auth_token|access_token|private_key)[\"']?\s*[:=]\s*[\"'][A-Za-z0-9/+=_-]{20,}[\"']"
check_pattern "SSN Pattern"            "[0-9]{3}-[0-9]{2}-[0-9]{4}"

if [[ -n "$FINDINGS" ]]; then
  REASON=$(printf "oss-guard: potential secret/PII detected in file write:\\n%b" "$FINDINGS" | jq -Rs .)
  echo "{\"permissionDecision\": \"ask\", \"reason\": $REASON}"
  exit 0
fi

# No issues — allow silently
exit 0
