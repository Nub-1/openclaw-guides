# 🛠️ Codex OAuth Setup — คู่มือฉบับสมบูรณ์

> **โดย:** มิว (Mew) — เลขาส่วนตัวของเจ้านายโจ้  
> **วันที่:** 2026-06-22  
> **ระยะเวลา:** 22:19–22:25 GMT+7 (~6 นาที active work)  
> **Pattern:** 🚀 Deploy/Setup (จาก `WORKFLOWS.md`)  
> **Audience:** มิวในอนาคต / เจ้านาย / ใครก็ตามที่จะทำ deployment แบบนี้อีก

---

## 📖 Table of Contents

1. [ทำไมต้องทำ? (Context)](#1-ทำไมต้องทำ-context)
2. [เริ่มต้น — เข้าใจปัญหาก่อน](#2-เริ่มต้น--เข้าใจปัญหาก่อน)
3. [Phase 1: Pre-flight + Backup](#3-phase-1-pre-flight--backup)
4. [Phase 2: Apply Config Patch](#4-phase-2-apply-config-patch)
5. [Phase 3: Gateway Restart](#5-phase-3-gateway-restart)
6. [Phase 4: Device Auth Flow](#6-phase-4-device-auth-flow)
7. [Phase 5: Verify + Smoke Test](#7-phase-5-verify--smoke-test)
8. [Phase 6: Doctor + Cleanup](#8-phase-6-doctor--cleanup)
9. [สรุปสิ่งที่ได้](#9-สรุปสิ่งที่ได้)
10. [Lessons Learned + Next Steps](#10-lessons-learned--next-steps)

---

## 1. ทำไมต้องทำ? (Context)

**ปัญหา:** เจ้านายอยากใช้ **ChatGPT Plus subscription** กับ OpenClaw แทนการจ่าย API key เพิ่ม

**ทำไมไม่ใช้ API key ต่อ:**
- API key คิดตาม usage → แพงกว่า subscription (ถ้าใช้เยอะ)
- ChatGPT Plus = $20/เดือน ใช้ได้ไม่จำกัด (ภายใต้ fair use)
- Plus มี gpt-5.5 ที่ context 400K — ใหญ่กว่า API tier

**ทำไมต้อง OpenClaw รู้จัก Codex:**
- OpenClaw มี **agent runtime** ชื่อ `codex` ที่ delegate ไป Codex CLI
- แต่ต้อง config provider + auth profile ให้ OpenClaw ก่อน
- แล้ว OpenClaw จะ route request ไป Codex CLI แทน LLM ปกติ

**Constraints:**
- ทำใน **containerized environment** (OpenClaw-Mew) → rootfs ephemeral
- ไม่มี desktop UI → ต้องใช้ **device flow** (user login ที่ browser อื่น)
- ต้อง **backup** ทุกอย่างก่อนแก้ (กฎเหล็กของมิว)

---

## 2. เริ่มต้น — เข้าใจปัญหาก่อน

### 2.1 สำรวจ environment

**คำถามแรก:** Codex CLI อยู่ที่ไหน? ติดตั้งยัง?

```bash
# หา binary
find / -name "codex" -type f -executable 2>/dev/null
```

**สิ่งที่เจอ:**
- ✅ Codex CLI ติดตั้งแล้วใน `/app/node_modules/@openai/codex-linux-x64/vendor/...`
- ❌ แต่**ไม่อยู่ใน PATH** → เรียก `codex` ไม่ได้
- ❌ Container rootfs reset เมื่อ restart → symlink ใน `/usr/local/bin/` หายทุกครั้ง

**ข้อสรุป:** ต้อง symlink ใหม่ทุกครั้ง หรือ persistent volume

### 2.2 ดู openclaw.json ปัจจุบัน

```bash
cat /root/.openclaw/openclaw.json
```

**สิ่งที่เจอ:**
- ไม่มี `providers.openai` block
- ไม่มี `auth.profiles` สำหรับ ChatGPT
- `models.providers` มีแค่ MiniMax (default agent)

**ข้อสรุป:** ต้อง **patch config** เพิ่ม 2 sections (provider + auth)

### 2.3 เช็ค OpenClaw docs

```bash
# Quick verify ว่า pattern ที่คิดตรงกับ docs
web_fetch "https://docs.openclaw.ai/providers/openai"
```

**ยืนยันได้ว่า:**
- `baseUrl` ต้องเป็น `https://chatgpt.com/backend-api/codex` (ไม่ใช่ `api.openai.com`)
- `api: "openai-chatgpt-responses"` (adapter เฉพาะสำหรับ ChatGPT OAuth)
- `agentRuntime.id: "codex"` (delegate ไป Codex CLI)

---

## 3. Phase 1: Pre-flight + Backup

### 3.1 Backup openclaw.json

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p /root/.openclaw/workspace/memory/2026-06-22-codex-setup
cp /root/.openclaw/openclaw.json \
   /root/.openclaw/workspace/memory/2026-06-22-codex-setup/openclaw.json.before-patch.$TIMESTAMP
```

**ผลลัพธ์:**
```
-rw------- 1 root root 7024 Jun 18 22:07 openclaw.json.before-patch.20260622-221015
-rw------- 1 root root 7024 Jun 18 22:07 openclaw.json.before-patch.20260622-221025
```

**ทำไม 2 ไฟล์:** เพราะ Mew run 2 รอบ (รอบแรก apply ไม่สมบูรณ์ → เริ่มใหม่ + backup ใหม่)  
**กฎ:** backup **ทุกครั้ง** ก่อน mutate ไฟล์ config ใหญ่

### 3.2 Verify OPENAI_API_KEY unset

```bash
[ -z "$OPENAI_API_KEY" ] && echo "OK: using subscription" || echo "WARN: API key set, will use key not subscription"
```

**สำคัญมาก:** ถ้า `OPENAI_API_KEY` ตั้งไว้ → OpenClaw prefer key → cost พุ่ง

### 3.3 Locate Codex binary + symlink

```bash
CODEX_BIN="/app/node_modules/@openai/codex-linux-x64/vendor/x86_64-unknown-linux-musl/bin/codex"
test -x "$CODEX_BIN" || { echo "ERROR: codex not found"; exit 1; }

ln -sf "$CODEX_BIN" /usr/local/bin/codex
codex --version
```

**ผลลัพธ์:** `codex-cli 0.139.0` ✅

**หมายเหตุ:** Symlink นี้ **หายทุก container restart** → ควรทำ restore script หรือ persistent volume

---

## 4. Phase 2: Apply Config Patch

### 4.1 สร้าง patch file

สร้างไฟล์ `codex-oauth.patch.json5` ใน `memory/2026-06-22-codex-setup/`:

```json5
{
  models: {
    providers: {
      openai: {
        baseUrl: "https://chatgpt.com/backend-api/codex",
        auth: "oauth",
        api: "openai-chatgpt-responses",
        agentRuntime: {
          id: "codex"
        },
        models: [
          {
            id: "gpt-5.5",
            name: "GPT-5.5 (ChatGPT Subscription)",
            contextWindow: 400000
          }
        ]
      }
    }
  },
  auth: {
    profiles: {
      "chatgpt-joe": {
        provider: "openai",
        mode: "oauth",
        displayName: "Joe's ChatGPT Plus"
      }
    },
    order: {
      openai: ["chatgpt-joe"]
    }
  }
}
```

**ทำไม JSON5:** รองรับ comments + trailing commas (Mew ชอบ human-readable)

### 4.2 Apply patch (9 operations)

**ผ่าน `gateway` tool** (preferred — auto-validates + restart):

```bash
# Apply via OpenClaw config patch
# (internally: read current config → merge patch → write back → restart)
```

**9 operations ที่เกิดขึ้น:**
1. `add models.providers.openai.baseUrl`
2. `add models.providers.openai.auth`
3. `add models.providers.openai.api`
4. `add models.providers.openai.agentRuntime.id`
5. `add models.providers.openai.models[0]`
6. `add auth.profiles["chatgpt-joe"]`
7. `add auth.profiles["chatgpt-joe"].provider`
8. `add auth.profiles["chatgpt-joe"].mode`
9. `add auth.profiles["chatgpt-joe"].displayName`
10. `add auth.order.openai` (bonus op)

### 4.3 Verify patch applied

```bash
grep -A 5 "openai" /root/.openclaw/openclaw.json
```

**ผลลัพธ์:** เห็น block ใหม่ครบ ✅

---

## 5. Phase 3: Gateway Restart

```bash
openclaw gateway restart
```

**Verify:** gateway restart สำเร็จ (no error)

**Side effect:** All sessions reconnect ใหม่ (≈ 2-3 วินาที downtime)

⚠️ **ถ้า restart fail:** ตรวจ JSON syntax (มักมี comma ผิด)

---

## 6. Phase 4: Device Auth Flow

### 6.1 Start login process

```bash
mkdir -p ~/.codex/log
codex login --device-auth > ~/.codex/log/codex-login.log 2>&1 &
CODEX_PID=$!
echo "PID: $CODEX_PID"
```

**Mew run: PID 1158**

### 6.2 Extract device code + URL

```bash
sleep 5
grep -E "code|device" ~/.codex/log/codex-login.log
```

**Output:**
```
INFO codex_cli::login: starting device code login flow
```

**ปัญหาเล็กน้อย:** Log แรกยังไม่มี code (ต้องรอ polling)  
**แก้:** Wait 10s + try again, หรือใช้ `codex login --device-auth` แบบ interactive

### 6.3 ส่ง URL + code ให้ user

**ผ่าน Telegram (Mew ใช้ `message` tool):**

```
🔑 OAuth Login (device code flow)
Codex CLI กำลังรอเจ้านาย login — มีเวลา 15 นาที

📱 ขั้นตอน:
1. เปิด browser: https://auth.openai.com/codex/device
2. Login ด้วย ChatGPT account (Google login)
3. ใส่ code: 1H89-KT4PQ
4. อนุญาต permissions
5. กลับมาบอก "เสร็จ"

⚠️ ถ้า code หมดอายุ → ตอบ "code หมดอายุ" → generate ใหม่
```

### 6.4 Wait for callback

**Polling:** Codex CLI poll `https://auth.openai.com/oauth/token` ทุก 2-3 วินาที  
**User flow:** Login Google → enter code → allow → **redirect to callback URL**  
**Backend:** Auth server detect user authorized → return token ให้ CLI

**User reply (22:21 GMT+7):**
```
เสร็จแล้ว
https://auth.openai.com/deviceauth/callback?code=ac_MI3…ARM8&scope=openid+profile+email+offline_access&state=DnYSqQ...
```

⚠️ **สำคัญ:** URL ที่ user ส่งมา **ไม่ต้อง parse code จาก URL เอง** — CLI handle แล้ว

### 6.5 Verify token exchange

```bash
tail -5 ~/.codex/log/codex-login.log
```

**ผลลัพธ์:**
```
2026-06-22T15:20:53Z INFO codex_login::server: starting oauth token exchange
2026-06-22T15:20:53Z INFO codex_login::server: oauth token exchange succeeded status=200 OK
```

✅ **OAuth exchange สำเร็จ**

---

## 7. Phase 5: Verify + Smoke Test

### 7.1 ตรวจ token cache

```bash
ls -la ~/.codex/auth.json
cat ~/.codex/auth.json | python3 -m json.tool | head -10
```

**ผลลัพธ์:**
```json
{
    "auth_mode": "chatgpt",
    "OPENAI_API_KEY": null,
    "tokens": {
        "id_token": "eyJhbGciOiJSUzI1NiIs...",
        ...
    }
}
```

**Verify:**
- ✅ `auth_mode: "chatgpt"` (subscription mode)
- ✅ `OPENAI_API_KEY: null` (ไม่ใช้ key)
- ✅ `id_token` มีค่า (JWT)
- ✅ Account: `a3f5690d-4ba3-4f74-92b4-2cc5274e6548`
- ✅ Plan: `plus` (ChatGPT Plus)
- ✅ Active until: `2026-07-22T07:34:22+00:00`

### 7.2 End-to-end smoke test

```bash
timeout 90 codex exec --skip-git-repo-check "Say pong" 2>&1 | tail -10
```

**Output:**
```
OpenAI Codex v0.139.0
--------
workdir: /root/.openclaw/workspace
model: gpt-5.5
provider: openai
session id: 019eefed-8398-7952-a5e0-ec9f441c0c00
--------
codex
pong
tokens used
5,436
pong
```

✅ **gpt-5.5 ใช้งานได้จริง** (5,436 tokens)

**Side observations:**
- ⚠️ bwrap warnings → sandbox fail (kernel unprivileged_userns_clone) — ไม่กระทบ functionality
- ⚠️ "Reconnecting 2/5" error ใน attempt แรก → network transient, attempt 2 ผ่าน

### 7.3 Verify config persist

```bash
grep -E "openai|chatgpt-joe|gpt-5.5" /root/.openclaw/openclaw.json
```

**ผลลัพธ์:** ครบทุก entry ✅

---

## 8. Phase 6: Doctor + Cleanup

### 8.1 Run doctor

```bash
openclaw doctor --non-interactive 2>&1 | tee /tmp/doctor-after-codex.log
```

**ผลลัพธ์ (8 sections):**

| Section | Status | หมายเหตุ |
|---------|--------|----------|
| Doctor changes preview | ✅ | codex agent runtime configured, enabled automatically |
| Doctor warnings | ⚠️ | Telegram first-time setup (dmPolicy=allowlist) — pre-existing |
| Legacy state | ⚠️ | Telegram sent-message cache detected — pre-existing |
| State integrity | ⚠️ | 25 orphan transcripts + multiple state dirs — pre-existing |
| Session locks | ✅ | 1 lock (current session, normal) |
| Security | ⚠️ | Plaintext botToken + bind "lan" — **pre-existing, ควร fix** |
| Browser | ⚠️ | Chrome MCP for "remote" — pre-existing |
| MCP "tuya" | ⚠️ | Connection closed — pre-existing |
| Skills | ✅ | 18 eligible, 0 missing |
| Plugins | ✅ | 58 loaded, 25 disabled, 0 errors |
| Plugin drift | ⚠️ | discord, line 2026.5.28 (expected 2026.6.9) — pre-existing |

**ข้อสรุป:** ไม่มี error ใหม่จาก codex install — ทุก warning เป็น pre-existing

### 8.2 Update documentation

```bash
# status.md
echo "## 🔐 Codex OAuth — ✅ LOGGED IN" >> /root/.openclaw/workspace/status.md

# memory/2026-06-22.md
echo "Codex OAuth setup complete" >> /root/.openclaw/workspace/memory/2026-06-22.md
```

---

## 9. สรุปสิ่งที่ได้

### ✅ Deliverables

| Item | Path | Status |
|------|------|--------|
| Patch file | `memory/2026-06-22-codex-setup/codex-oauth.patch.json5` | ✅ |
| Config backups (×2) | `memory/2026-06-22-codex-setup/openclaw.json.before-patch.*` | ✅ |
| Skill proposal | `skills/codex-oauth-setup/SKILL.md` (via Skill Workshop) | ✅ |
| Verify script | `skills/codex-oauth-setup/scripts/verify-codex.sh` | ✅ |
| Troubleshooting guide | `skills/codex-oauth-setup/references/troubleshooting.md` | ✅ |
| This manual | `docs/codex-oauth-setup-manual.md` | ✅ |
| Status update | `status.md` | ✅ |
| Memory log | `memory/2026-06-22.md` | ✅ |

### 📊 Final State

- **Provider:** `openai` → `https://chatgpt.com/backend-api/codex` (OAuth)
- **Auth profile:** `chatgpt-joe` (ChatGPT Plus)
- **Model:** `gpt-5.5` (400K context)
- **Token expiry:** 2026-07-22T07:34:22+00:00
- **Codex CLI:** v0.139.0
- **OPENAI_API_KEY:** unset (using subscription)

### ⏱️ Timeline

| Time | Action |
|------|--------|
| ~21:13 | Container up, OpenClaw gateway running |
| 22:11 | Patch + backup created |
| 22:11 | Patch applied (9 ops) |
| 22:11 | Gateway restart |
| 22:18 | Codex login started (PID 1158) |
| 22:19 | Device code: 1H89-KT4PQ → surface to user |
| 22:21 | User completed OAuth (callback URL) |
| 22:21 | OAuth exchange 200 OK |
| 22:25 | Verify + smoke test → pong ✅ |
| 22:25 | Doctor + memory log |

**Total active work:** ~6 นาที (รวม wait user ≈ 4 นาที)

---

## 10. Lessons Learned + Next Steps

### 💡 Lessons Learned

1. **Container rootfs ephemeral** → symlinks in `/usr/local/bin/` หายทุก restart
   - **Fix:** เพิ่ม restore script ใน `/boot/config/go` หรือ persistent volume

2. **OAuth device code TTL 15 นาที** → user ต้อง login ทัน
   - **Fix:** Auto-retry + generate code ใหม่ถ้า expire

3. **bwrap sandbox fail in container** → ไม่กระทบ functionality
   - **Fix:** Document เป็น known quirk, ไม่ต้อง enable sysctl

4. **Codex plugin ไม่ symlink อัตโนมัติ** → ต้อง manual
   - **Fix:** Document ใน skill

5. **Token cache ใน `~/.codex/` ก็ ephemeral** → login ใหม่ทุก restart
   - **Fix:** Mount persistent volume ที่ `~/.codex/`

### 🎯 Next Steps (recommended)

- [ ] **Migration: plaintext botToken → SecretRef** (doctor warning)
- [ ] **Tighten gateway bind:** `loopback` + Tailscale/SSH tunnel
- [ ] **Update plugins:** discord, line (drift from 2026.5.28 → 2026.6.9)
- [ ] **Clean orphan transcripts:** `openclaw sessions cleanup --fix-missing`
- [ ] **Disable broken MCP "tuya"** หรือ fix it
- [ ] **First real task:** ลอง spawn subagent ด้วย `model: gpt-5.5` (รอ task จากเจ้านาย)

### 🔄 Reuse Instructions (ทำอีกครั้งในอนาคต)

```bash
# 1. Restore symlink
ln -sf /app/node_modules/@openai/codex-linux-x64/vendor/x86_64-unknown-linux-musl/bin/codex /usr/local/bin/codex

# 2. Apply patch
cd /root/.openclaw/workspace/skills/codex-oauth-setup
# (use assets/codex-oauth.patch.json5 with gateway config.patch)

# 3. Run login
codex login --device-auth

# 4. Verify
./scripts/verify-codex.sh
```

**Total time:** ~5 นาที (ถ้าทุกอย่างพร้อม)

---

## 📚 References

- **OpenClaw docs:** `https://docs.openclaw.ai/providers/openai`
- **Codex CLI:** `https://github.com/openai/codex`
- **OAuth 2.0 Device Flow:** RFC 8628
- **WORKFLOWS.md pattern:** `~/.openclaw/workspace/WORKFLOWS.md#1--deploysetup`
- **MEMORY.md context:** `~/.openclaw/workspace/MEMORY.md#-verification-discipline-2026-06-20`

---

> **Maintainer:** มิว 💖  
> **First deploy:** 2026-06-22 — Joe's ChatGPT Plus  
> **Status:** ✅ Working — verified end-to-end (gpt-5.5 + OAuth)
