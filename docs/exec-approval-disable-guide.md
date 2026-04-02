# คู่มือการปิดระบบ Exec Approval ใน OpenClaw

**เวอร์ชัน:** OpenClaw 2026.4.1 ขึ้นไป  
**ผู้เขียน:** มิว (Mew) — ผู้ช่วยอัจฉริยะ  
**ผู้พัฒนา:** โจ้ พัฒนากร  
**วันที่เผยแพร่:** 2 เมษายน 2569  
**สัญญาอนุญาต:** MIT License  

---

## 📋 สารบัญ

1. [บทนำ](#บทนำ)
2. [ปัญหาที่พบ](#ปัญหาที่พบ)
3. [วิธีแก้ไข](#วิธีแก้ไข)
4. [การตรวจสอบ](#การตรวจสอบ)
5. [การแก้ไขปัญหาเพิ่มเติม](#การแก้ไขปัญหาเพิ่มเติม)
6. [คำแนะนำด้านความปลอดภัย](#คำแนะนำด้านความปลอดภัย)
7. [สรุป](#สรุป)

---

## บทนำ

เมื่อใช้งาน OpenClaw ในโหมดเริ่มต้น (default) ระบบจะเปิด **Exec Approval** ไว้ — หมายความว่าทุกครั้งที่มีการรัน shell command ผ่าน OpenClaw จะต้องได้รับการอนุมัติก่อนผ่าน Telegram หรือช่องทางอื่นที่เชื่อมต่ออยู่

สำหรับผู้ใช้งานในระบบ local หรือ sandbox ที่มีความปลอดภัยสูง การต้องอนุมัติทุกคำสั่งอาจทำให้การทำงานลำบากและช้าลง

คู่มือนี้จะอธิบายวิธี **ปิดระบบ Exec Approval** อย่างถูกต้องและปลอดภัย

---

## ปัญหาที่พบ

เมื่อ `execApprovals.mode: on` (ค่าเริ่มต้น) จะเกิดอาการดังนี้:

```
⚠️ Approval Required
━━━━━━━━━━━━━━━━━━━
Command: echo "test"
Submitted: just now
By: Telegram (Parinya Witchutawet)
Approve/Deny
```

- ทุกคำสั่ง shell ต้องรอ approval ก่อนรัน
- ถ้าไม่กดอนุมัติภายใน 5 นาที จะ timeout
- ต้องคอยเปิด Telegram ตลอดเพื่อกด approve
- ทำงานซ้ำๆ ต้องกดอนุมัติทุกครั้ง

---

## วิธีแก้ไข

### ขั้นตอนที่ 1: เปิดหน้าต่าง Chat กับ OpenClaw

เปิด Telegram หรือช่องทางที่เชื่อมต่อ OpenClaw ไว้ แล้วพิมพ์คำสั่งด้านล่าง:

```
config.set execApprovals.enabled false
```

> **หมายเหตุ:** คำสั่งนี้ใช้ได้ทันที **ไม่ต้อง restart gateway** หรือ container ใดๆ

### ขั้นตอนที่ 2: ตั้งค่า Exec Mode (แนะนำเพิ่มเติม)

เพื่อให้ shell commands รันได้เลยโดยไม่ถามอะไรเพิ่มเติม ให้พิมพ์ตามด้วย:

```
config.set tools.exec.ask off
config.set tools.exec.security full
```

### ขั้นตอนที่ 3: Restart Gateway (กรณีจำเป็น)

ถ้าคำสั่งข้างต้นยังไม่มีผล ให้ restart gateway:

```
openclaw gateway restart
```

หรือถ้าใช้ Docker:

```bash
docker exec -it <container_name> openclaw gateway restart
```

---

## การตรวจสอบ

### ตรวจสอบว่าปิดแล้ว

พิมพ์คำสั่ง:

```
config.get execApprovals
```

**ผลลัพธ์ที่ถูกต้อง:**

```json
{
  "enabled": false,
  "approvers": ["1941976453"]
}
```

### ตรวจสอบ tools.exec

พิมพ์:

```
config.get tools.exec
```

**ผลลัพธ์ที่ถูกต้อง:**

```json
{
  "ask": "off",
  "security": "full"
}
```

### ทดสอบการรันคำสั่ง

ลองรันคำสั่งง่ายๆ:

```
echo "ทดสอบ"
```

ถ้าไม่มี approval prompt ขึ้นมา แสดงว่าปิดสำเร็จแล้ว ✅

---

## การแก้ไขปัญหาเพิ่มเติม

### ถ้ายังมี Approval ค้างอยู่

พิมพ์ `/approve` ใน Telegram เพื่อดูรายการ approvals ที่รออยู่ แล้ว deny ทิ้งได้เลย

### ถ้าต้องการเปิดใหม่

```
config.set execApprovals.enabled true
```

### คำสั่ง Config ที่เกี่ยวข้อง

| คำสั่ง | ผลลัพธ์ |
|--------|---------|
| `config.get` | ดู config ทั้งหมด |
| `config.get exec` | ดู config เฉพาะ exec |
| `config.get execApprovals` | ดู config เฉพาะ approval |
| `config.set <key> <value>` | ตั้งค่า config (ใช้ได้ทันที) |
| `openclaw gateway restart` | Restart gateway |

---

## คำแนะนำด้านความปลอดภัย

> ⚠️ **คำเตือนสำคัญ:** การปิด execApprovals หมายความว่า shell commands ทุกคำสั่งจะรันได้เลยโดยไม่ต้องยืนยันใดๆ

### ควรปฏิบัติดังนี้:

1. **ใช้ในระบบที่ปลอดภัย** — เช่น local server, sandbox, หรือ development environment
2. **อย่าเปิด Telegram ให้สาธารณะ** — ถ้าเปิดไว้ควรตั้ง `allowFrom` เป็น user ID จริงๆ
3. **ตั้งค่า allowFrom อย่างถูกต้อง** — ดูด้านล่าง

### ตัวอย่าง: ตั้งค่า allowFrom อย่างปลอดภัย

**Telegram:**

```
config.set elevated.allowFrom.telegram '["1941976453"]'
```

**Discord:**

```
config.set discord.allowFrom '["216562036245659658"]'
config.set discord.dmPolicy allowlist
config.set discord.groupPolicy allowlist
```

**หลีกเลี่ยง:**

```json
// ❌ ไม่ควรใช้ wildcard — เปิดให้ทุกคนเข้าถึงได้
"allowFrom": ["*"]

// ✅ ควรใช้ user ID จริง
"allowFrom": ["1941976453"]
```

---

## สรุป

### คำสั่งที่ต้องรัน

```bash
# 1. ปิด exec approval (ใช้ได้ทันที ไม่ต้อง restart)
config.set execApprovals.enabled false

# 2. ปิดการถามก่อน exec (แนะนำ)
config.set tools.exec.ask off
config.set tools.exec.security full

# 3. Restart กรณีจำเป็น (ถ้ายังไม่มีผล)
openclaw gateway restart
```

### สถานะ config ที่ถูกต้อง

| Config Key | ค่าที่ถูกต้อง |
|-----------|--------------|
| `execApprovals.enabled` | `false` |
| `tools.exec.ask` | `off` |
| `tools.exec.security` | `full` |

---

## แหล่งอ้างอิง

- **OpenClaw Documentation:** https://docs.openclaw.ai
- **OpenClaw Community:** https://discord.com/invite/clawd

---

**เวอร์ชัน OpenClaw ที่ทดสอบ:** 2026.4.1  
**อัปเดตล่าสุด:** 2 เมษายน 2569

---

*เอกสารนี้เป็นส่วนหนึ่งของ OpenClaw — ผู้ช่วยอัจฉริยะสำหรับงานรายวัน*  
*พัฒนาโดย โจ้ พัฒนากร | ผู้เขียน: มิว (Mew AI)*
