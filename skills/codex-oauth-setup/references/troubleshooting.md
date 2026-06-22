# Codex OAuth Setup — Troubleshooting 🔧

## ❌ "codex: command not found"

**Cause:** Codex binary ไม่อยู่ใน PATH

**Fix:**
```bash
# Locate
find /app/node_modules/@openai/codex-linux-x64 -name codex -type f -executable
# Symlink
ln -sf <path> /usr/local/bin/codex
```

## ❌ "oauth token exchange failed"

**Cause:** Device code expired (TTL 15 นาที) หรือ user ไม่ได้ authorize

**Fix:**
```bash
# Re-run device flow
rm -f ~/.codex/auth.json
codex login --device-auth
```

## ❌ gpt-5.5 ใช้ API key แทน subscription

**Cause:** `OPENAI_API_KEY` ตั้งอยู่ → OpenClaw prefer key ก่อน OAuth

**Fix:**
```bash
unset OPENAI_API_KEY
# remove from ~/.bashrc / systemd env / openclaw.json
openclaw gateway restart
```

## ❌ "Reconnecting... N/5" error

**Cause:** Transient network issue หรือ ChatGPT backend ล่ม

**Fix:** ลองใหม่อีกครั้ง ถ้ายังไม่ได้ → check `https://status.openai.com`

## ⚠️ bwrap warnings

**Cause:** Container kernel ไม่ allow unprivileged user namespaces  
**Impact:** ไม่กระทบ functionality — Codex fallback non-sandbox  
**Fix:** `sysctl kernel.unprivileged_userns_clone=1` (ถ้า host allow)

## ⚠️ MCP "tuya" connection closed

**Cause:** Pre-existing MCP server issue (ไม่กระทบ codex)  
**Fix:** `openclaw doctor --fix` หรือ disable MCP ใน config

## ⚠️ Token cache หายหลัง container restart

**Cause:** `~/.codex/` อยู่ใน container rootfs (ephemeral)  
**Fix:** Mount persistent volume ที่ `~/.codex/` หรือ login ใหม่ทุกครั้ง

## ⚠️ "Codex could not find bubblewrap on PATH"

**Cause:** bwrap ไม่ได้ติดตั้งบน host  
**Fix:** `apt-get install bubblewrap` (host level) — หรือ ignore ถ้าไม่ต้องการ sandbox

## ❌ Doctor เตือน "agents or workspace tools that can read config files may see these API keys/tokens"

**Cause:** Plaintext `botToken` ใน `openclaw.json`  
**Fix:** Migrate เป็น SecretRef:
```bash
openclaw secrets configure
openclaw secrets apply
openclaw secrets audit --check
```

## ❌ Doctor เตือน "Gateway bound to 'lan' (0.0.0.0)"

**Cause:** Gateway expose ทุก interface  
**Fix:** เปลี่ยน `bind: "loopback"` + ใช้ Tailscale หรือ SSH tunnel

## ❌ Codex ไม่อยู่ใน PATH หลัง container restart

**Cause:** Symlink ที่สร้างไว้ใน container rootfs หายเมื่อ restart  
**Fix:** เพิ่ม restore script ใน `/boot/config/go` (Unraid) หรือ mount persistent volume

## 🔗 Related Docs

- [OpenClaw OpenAI Provider docs](https://docs.openclaw.ai/providers/openai)
- [Codex CLI GitHub](https://github.com/openai/codex)
- [OAuth 2.0 Device Flow RFC 8628](https://datatracker.ietf.org/doc/html/rfc8628)
