# 📚 OpenClaw Guides

> คู่มือและบทแนะนำสำหรับ OpenClaw — ผู้ช่วยอัจฉริยะสำหรับงานรายวัน

[![OpenClaw](https://img.shields.io/badge/OpenClaw-2026.6.9-blue)](https://github.com/openclaw/openclaw)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Author](https://img.shields.io/badge/Author-Mew-purple)](https://github.com/openclaw)

---

## 📋 สารบัญ

| เอกสาร | คำอธิบาย |
|---------|-----------|
| [คู่มือปิด Exec Approval](docs/exec-approval-disable-guide.md) | วิธีปิดระบบ approval สำหรับ shell commands ใน OpenClaw |
| [คู่มือติดตั้ง Codex OAuth](docs/codex-oauth-setup-manual.md) | ตั้งค่า OpenAI Codex CLI ใช้ ChatGPT Plus subscription (gpt-5.5) |

---

## 📖 เอกสารที่มี

### 🔐 การปิด Exec Approval

**ไฟล์:** [`docs/exec-approval-disable-guide.md`](docs/exec-approval-disable-guide.md)

ครอบคลุม:
- ปัญหาที่พบเมื่อเปิด execApprovals
- วิธีปิดด้วยคำสั่งเดียว (ไม่ต้อง restart)
- การตรวจสอบ config หลังปิด
- คำแนะนำด้านความปลอดภัย
- สถานะ config ที่ถูกต้อง

### 🤖 การติดตั้ง Codex OAuth (gpt-5.5 ผ่าน ChatGPT Plus)

**ไฟล์:** [`docs/codex-oauth-setup-manual.md`](docs/codex-oauth-setup-manual.md)

ครอบคลุม:
- ติดตั้ง OpenAI Codex CLI ใน OpenClaw container
- ใช้ ChatGPT Plus subscription แทน API key (ประหยัด cost)
- OAuth device flow login (code 1H89-KT4PQ → callback → token)
- Config patch (provider + auth profile + model gpt-5.5)
- End-to-end smoke test (gpt-5.5 pong, ~5,400 tokens)
- 7 pitfalls & gotchas ที่เจอจริง
- **Skill พร้อม verify script** — `skills/codex-oauth-setup/`
  - `SKILL.md` — full step-by-step
  - `scripts/verify-codex.sh` — 8 verification gates (auto)
  - `references/troubleshooting.md` — 9 issues + fixes
  - `assets/codex-oauth.patch.json5` — patch template

---

## 🛠️ ข้อมูลทั่วไป

| รายการ | รายละเอียด |
|---------|-------------|
| **เวอร์ชัน OpenClaw** | 2026.4.1 ขึ้นไป |
| **ผู้เขียน** | มิว (Mew) — ผู้ช่วยอัจฉริยะ |
| **ผู้พัฒนา** | โจ้ พัฒนากร |
| **สัญญาอนุญาต** | MIT License |

---

## 🔗 ลิงก์ที่เกี่ยวข้อง

- [OpenClaw Documentation](https://docs.openclaw.ai)
- [OpenClaw Community](https://discord.com/invite/clawd)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)

---

*คู่มือนี้เป็นส่วนหนึ่งของ OpenClaw Guides — พัฒนาโดย โจ้ พัฒนากร | ผู้เขียน: มิว (Mew AI)* 💖
