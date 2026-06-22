---
name: codex-oauth-setup
description: Set up OpenAI Codex CLI in OpenClaw using ChatGPT Plus OAuth device flow: config patch + login + gpt-5.5 smoke test.
---

# Codex OAuth Setup 🛠️

> **Status:** Live (verified 2026-06-22)  
> **Pattern:** 🚀 Deploy/Setup (จาก `WORKFLOWS.md`)  
> **Author:** มิว (Mew)

## 🎯 Purpose

ติดตั้ง **OpenAI Codex CLI** ให้กับ OpenClaw โดยใช้ **ChatGPT Plus subscription** ผ่าน OAuth device flow แทน API key → ประหยัด cost + ใช้ quota ของ subscription

**ผลลัพธ์:**
- Provider `openai` ใน `openclaw.json` ชี้ไปที่ ChatGPT Codex backend
- Auth profile `chatgpt-joe` ใช้ OAuth mode
- Model `gpt-5.5` ใช้งานได้ (400K context)
- `~/.codex/auth.json` populated with valid tokens

## 📋 When to use

ใช้ skill นี้เมื่อ:
- ต้องการใช้ ChatGPT Plus/Pro subscription กับ OpenClaw (แทน API key)
- Container/fresh install แล้วยังไม่ได้ login Codex
- Token cache หายหรือ expired
- ต้องการ migrate จาก API key → OAuth subscription

**อย่าใช้ถ้า:**
- มี `OPENAI_API_KEY` อยู่แล้วและต้องการใช้ต่อ
- ใช้ enterprise SSO (flow จะต่าง)

## 🛫 Pre-flight checks

```bash
# 1. Codex CLI binary ต้องอยู่ใน node_modules
ls /app/node_modules/@openai/codex-linux-x64/vendor/x86_64-unknown-linux-musl/bin/codex

# 2. openclaw.json ต้อง backup ได้
test -w /root/.openclaw/openclaw.json

# 3. OPENAI_API_KEY ต้อง unset (เพื่อให้ใช้ subscription)
[ -z "$OPENAI_API_KEY" ] && echo "OK"

# 4. ต้องเข้า browser ได้ (สำหรับ OAuth flow)
```

ถ้า binary ไม่อยู่ → install Codex plugin ก่อน: `openclaw plugins install codex`  
ถ้า backup ไม่ได้ → หยุด + ถามเจ้านาย

## 📝 Step-by-step

### Step 1: Backup + locate binary

```bash
# Backup openclaw.json (timestamped)
mkdir -p /root/.openclaw/workspace/memory/$(date +%Y-%m-%d)-codex-setup
cp /root/.openclaw/openclaw.json \
   /root/.openclaw/workspace/memory/$(date +%Y-%m-%d)-codex-setup/openclaw.json.before-patch.$(date +%Y%m%d-%H%M%S)

# Locate codex binary
CODEX_BIN=$(find /app/node_modules/@openai/codex-linux-x64 -name codex -type f -executable | head -1)
echo "Codex: $CODEX_BIN"

# Symlink to PATH
ln -sf "$CODEX_BIN" /usr/local/bin/codex
codex --version
```

### Step 2: Apply config patch

ใช้ `assets/codex-oauth.patch.json5` เป็น template:

```bash
# Apply via OpenClaw gateway config patch
openclaw config patch ./assets/codex-oauth.patch.json5
```

หรือ apply manually โดยเพิ่ม 3 sections ใน `openclaw.json`:

1. `models.providers.openai` → `baseUrl: chatgpt.com/backend-api/codex`, `auth: oauth`, `api: openai-chatgpt-responses`
2. `models.providers.openai.agentRuntime.id` → `codex`
3. `models.providers.openai.models` → `gpt-5.5` (400K context)
4. `auth.profiles["chatgpt-joe"]` → mode `oauth`
5. `auth.order.openai` → `["chatgpt-joe"]`

### Step 3: Restart gateway

```bash
openclaw gateway restart
```

⚠️ **Verify:** gateway ตอบสนองหลัง restart (check logs)

### Step 4: Start device flow + surface URL to user

```bash
# Start codex login ใน background
mkdir -p ~/.codex/log
codex login --device-auth > ~/.codex/log/codex-login.log 2>&1 &
CODEX_PID=$!
echo "CODEX_PID=$CODEX_PID"

# รอให้ code + URL ปรากฏ
sleep 5
grep -E "code|URL|device" ~/.codex/log/codex-login.log
```

**ส่งให้ user:**
- URL: `https://auth.openai.com/codex/device`
- Code: (เช่น `1H89-KT4PQ`)
- TTL: **15 นาที**
- Step: login Google → enter code → allow → กลับมาบอก "เสร็จ"

### Step 5: Wait for user confirmation + verify

```bash
# รอ user ตอบ "เสร็จ" หรือ callback URL
# แล้ว verify token cache
test -s ~/.codex/auth.json && cat ~/.codex/auth.json | python3 -m json.tool | head -20

# ตรวจว่า auth_mode = "chatgpt" และมี id_token
```

### Step 6: End-to-end smoke test

```bash
# ทดสอบ gpt-5.5 จริง (timeout 90s)
timeout 90 codex exec --skip-git-repo-check "Reply with just: pong" 2>&1 | tail -10
```

**Expected output:**
- `model: gpt-5.5`
- `provider: openai`
- Response: `pong`
- Token usage line

### Step 7: Run verify script (automated gates)

```bash
./scripts/verify-codex.sh
```

### Step 8: Update status + memory

```bash
# status.md → append "Codex OAuth — ✅ LOGGED IN"
# memory/YYYY-MM-DD.md → full log + token expiry + account id
```

## ✅ Verification Gates (ต้องผ่านทั้งหมด)

- [ ] `~/.codex/auth.json` มี `auth_mode: "chatgpt"` + `id_token`
- [ ] `codex login` log แสดง `oauth token exchange succeeded status=200 OK`
- [ ] `codex --version` ตอบ (เช่น `codex-cli 0.139.0`)
- [ ] `codex exec "pong"` → response = "pong" (5K-10K tokens)
- [ ] `openclaw.json` มี provider `openai` + auth profile `chatgpt-joe`
- [ ] `openclaw doctor` ไม่มี error ใหม่ (warning เก่า OK)
- [ ] `status.md` + `memory/YYYY-MM-DD.md` อัปเดตแล้ว

## ⚠️ Pitfalls & Gotchas

1. **Codex binary ไม่อยู่ใน PATH** — OpenClaw plugin ไม่ symlink อัตโนมัติ → ต้อง symlink เอง
2. **OPENAI_API_KEY ต้อง unset** — ถ้าตั้งไว้จะใช้ key แทน subscription → cost พุ่ง
3. **bwrap sandbox fail** — container kernel ไม่ allow unprivileged user namespaces → Codex fallback non-sandbox (ใช้ได้ปกติ)
4. **Device code หมดอายุ 15 นาที** — ถ้า user ไม่ทัน → re-run `codex login --device-auth`
5. **MCP "tuya" error** — pre-existing, ไม่กระทบ codex → ignore
6. **Token cache หายทุก container restart** — ต้อง login ใหม่ (ยกเว้นใช้ persistent volume)
7. **Container rootfs ephemeral** — `~/.codex/` ก็หายด้วย → mount volume หรือทำ restore script

## 🔁 Reuse / Variations

- **API key mode:** เปลี่ยน `auth: "oauth"` → `auth: "api"`, ใส่ `apiKey`, เอา `agentRuntime` ออก
- **Multiple accounts:** เพิ่ม `auth.profiles["chatgpt-other"]` แล้ว `auth.order.openai = ["chatgpt-joe", "chatgpt-other"]`
- **Refresh token:** `codex logout && codex login` (device flow ใหม่)

## 📚 Files

- `assets/codex-oauth.patch.json5` — patch template
- `scripts/verify-codex.sh` — automated verification (8 gates)
- `references/troubleshooting.md` — 9 issues + fixes
- Manual: see OpenClaw Guides repo (`docs/codex-oauth-setup-manual.md`)

## 🧪 Test เคสที่ผ่านแล้ว

- 2026-06-22 22:19-22:25 GMT+7 — Joe's ChatGPT Plus (`a3f5690d-4ba3-4f74-92b4-2cc5274e6548`)
- End-to-end: ✅ `pong` (5,436 tokens)
- Doctor: ✅ ไม่มี error ใหม่

---

> **Maintainer:** มิว 💖  
> **Origin:** First deployment 2026-06-22 — Joe's ChatGPT Plus migration
