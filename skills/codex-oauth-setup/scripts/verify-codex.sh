#!/bin/bash
# verify-codex.sh — verify Codex OAuth setup ทำงานครบทุก gate
# ใช้หลัง deploy เพื่อ confirm ว่าทุกอย่างพร้อมใช้งาน
# Date: 2026-06-22

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
  local name="$1"
  local cmd="$2"
  local optional="${3:-no}"

  if eval "$cmd" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $name"
    PASS=$((PASS+1))
  else
    if [ "$optional" = "warn" ]; then
      echo -e "${YELLOW}⚠${NC} $name (warning, not blocking)"
      WARN=$((WARN+1))
    else
      echo -e "${RED}✗${NC} $name"
      FAIL=$((FAIL+1))
    fi
  fi
}

echo "=== Codex OAuth Verification ==="
echo

# Gate 1: Binary
check "codex binary in PATH" "command -v codex"
check "codex --version" "codex --version"

# Gate 2: Token cache
check "~/.codex/auth.json exists" "test -s \$HOME/.codex/auth.json"
check "auth.json has auth_mode=chatgpt" "grep -q 'auth_mode.*chatgpt' \$HOME/.codex/auth.json"
check "auth.json has id_token" "grep -q 'id_token' \$HOME/.codex/auth.json"

# Gate 3: OpenClaw config
check "openclaw.json has openai provider" "grep -q '\"openai\"' /root/.openclaw/openclaw.json"
check "openclaw.json has chatgpt-joe auth" "grep -q '\"chatgpt-joe\"' /root/.openclaw/openclaw.json"
check "openclaw.json uses codex baseUrl" "grep -q 'chatgpt.com/backend-api/codex' /root/.openclaw/openclaw.json"
check "gpt-5.5 model configured" "grep -q '\"gpt-5.5\"' /root/.openclaw/openclaw.json"

# Gate 4: End-to-end (live test — slower)
echo
echo "=== End-to-end smoke test (gpt-5.5) ==="
if timeout 90 codex exec --skip-git-repo-check "Reply with just: pong" 2>&1 | tail -20 | grep -q "pong"; then
  echo -e "${GREEN}✓${NC} gpt-5.5 end-to-end OK"
  PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC} gpt-5.5 end-to-end FAILED"
  FAIL=$((FAIL+1))
fi

# Gate 5: Pre-existing quirks (warning only)
echo
echo "=== Known quirks (non-blocking) ==="
if [ -f /root/.openclaw/workspace/.git ]; then
  check "bwrap sandbox (warn only)" "bwrap --version" "warn"
fi

# Summary
echo
echo "=== Summary ==="
echo -e "  ${GREEN}PASS: $PASS${NC}"
echo -e "  ${YELLOW}WARN: $WARN${NC}"
echo -e "  ${RED}FAIL: $FAIL${NC}"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
