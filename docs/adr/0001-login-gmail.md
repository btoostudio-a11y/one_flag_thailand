> Superseded for the current build by [ADR-0004](0004-save-guest-rounds-before-login.md).

# ADR-0001 — Login ด้วย Gmail + ยืนยันอีเมล (แทนเบอร์โทร/OTP)

- **สถานะ:** รับ (Act mode — implemented)
- **วันที่:** 2026-09-15

## บริบท

เกมแจกของรางวัลจริงเมื่อชื่อติด top-10 leaderboard จึงต้องยืนยันตัวตนว่า
"ผู้ที่ได้รางวัลคือตัวจริง ไม่ใช่ชื่อปลอม" เราเลือก path ก่อนหน้านี้เป็น
Guest → ผูกภายหลังด้วยเบอร์โทร + OTP แต่ตัดสินใจเปลี่ยนเป็น Gmail login
เพราะความเฉพาะตัวสูงและไม่ต้องพึ่ง SMS provider ที่มีค่าใช้จ่ายต่อ OTP

## การตัดสินใจ

ใช้ **Supabase Auth + OAuth "Sign in with Google"** (flow PKCE) และยืนยัน
อีเมลก่อนจะให้คะแนนติด leaderboard ได้

## ทางเลือกที่พิจารณา

1. **เบอร์โทร + OTP ผ่าน Supabase Auth** — ยอดเยี่ยมสำหรับมือถือ แต่ต้องตั้งค่า
   SMS provider (เช่น Twilio) และมีค่าใช้จ่ายต่อข้อความ; กลุ่มเป้าหมายไทยนิยมใช้
   พลอยมากกว่าเบอร์โอทีพี → ละทิ้งเพราะต้นทุน/ความซับซ้อนของ provider
2. **OAuth ผ่าน Facebook/Line** — Line ไม่รองรับ native ใน Supabase ต้อง custom;
   Facebook ต้องการ approval สำหรับ scope email
3. **Gmail OAuth + ยืนยันอีเมล (เลือก)** — Supabase รองรับ native, ฟรี ไม่ต้อง
   provider เสริม, identity ยืนยันได้จริง

## ผลที่ตามมา

- ต้องตั้งค่า Google OAuth credentials บน Supabase dashboard
- บน **Web export** ต้องใช้ OAuth PKCE flow อย่างถูกต้อง (redirect กลับมาใน
  tab เดียวกัน) — มีจุดที่ต้องทดสอบจริงบน build/web ไม่ใช่แค่ editor
- ผู้เล่นที่ไม่มีบัญชี Gmail ต้องสมัครก่อน → friction สูงขึ้นเล็กน้อย แต่ยอมรับได้
  เพราะจุดประสงค์คือให้มีรางวัลจริง