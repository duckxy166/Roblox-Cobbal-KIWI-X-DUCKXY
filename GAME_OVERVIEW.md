# 📘 ภาพรวมระบบเกม — MyGame (Cobbal KIWI X DUCKXY)

> เกมแนว **Punching Simulator** — ตีหุ่น (Dummy) ใน Plot ส่วนตัว เก็บเหรียญ → upgrade stats → ตีแรงขึ้น → วนไป

---

## 🎮 Game Loop หลัก

```
ผู้เล่นเข้าเกม
   ↓
PlotManager แจก Plot ให้ 1 plot
   ↓
PlotServer Teleport ผู้เล่นไปยัง Plot
   ↓
DummyServer Spawn Dummy ที่ "Spawn dummy" ใน plot
   ↓
ผู้เล่นคลิกเมาส์ → Combo 3 จังหวะ → ตี Dummy
   ↓
Dummy ตาย → ได้เหรียญ +10 → respawn ใหม่
   ↓
ผู้เล่นเปิด Upgrade UI → ใช้เหรียญ upgrade stats
   ↓
ตีแรงขึ้น / Dummy HP สูงขึ้น → loop ต่อ
```

---

## 🗂️ โครงสร้างโปรเจกต์ (Rojo)

| Folder | Map ไปที่ | หน้าที่ |
|--------|----------|--------|
| `src/server/` | `ServerScriptService` | Logic ฝั่ง Server (ของจริง) |
| `src/shared/` | `ReplicatedStorage` | Module ที่ทั้ง Client + Server ใช้ร่วมกัน |
| `src/client/` | `StarterPlayerScripts` | UI + Input + Effect ฝั่งผู้เล่น |

---

## 📦 ไฟล์ทั้งหมด (16 ไฟล์)

### 🔧 SHARED — `src/shared/`

#### 1. `StatsConfig.lua` ⭐ (สำคัญมาก)
**ศูนย์รวมค่าตัวเลขทั้งหมดในเกม** แก้ที่นี่ที่เดียว

| ค่า | Default | ความหมาย |
|-----|---------|---------|
| `DAMAGE` | 10 | ดาเมจต่อหมัด |
| `CRIT_CHANCE` | 1% | โอกาสคริ |
| `CRIT_MULTIPLIER` | x3 | คริคูณ 3 |
| `MAX_STAMINA` | 100 | สตามิน่าสูงสุด |
| `STAMINA_REGEN` | 10/s | regen ต่อวินาที |
| `STAMINA_COST_MULT` | 0.5 | สตามิน่าต่อหมัด = damage × 0.5 |
| `DUMMY_BASE_HP` | 100 | HP เริ่มต้นของ Dummy |
| `DUMMY_HP_UPGRADE_PERCENT` | +5% | HP เพิ่มต่อ level |
| `UPGRADE_COST_MULT` | x2 | ราคาเพิ่ม 2 เท่าทุก level |

มี Helper functions: `getDummyMaxHP()`, `getDummyUpgradeCost()`, `getStaminaCost()`

---

### 🖥️ SERVER — `src/server/`

#### 2. `PlotManager.lua` (ModuleScript)
จัดการการแจก Plot ให้ผู้เล่น
- สแกน Workspace หา Model ที่ชื่อขึ้นต้นว่า `plot` และมี Part `Spawn dummy`
- `assign(player)` → จองให้ผู้เล่น 1 คน 1 plot
- `release(player)` → คืน plot ตอนผู้เล่นออก
- มี `PlotAssigned` (BindableEvent) ให้ script อื่น subscribe

#### 3. `PlotServer.server.lua`
- ฟัง `Players.PlayerAdded` → assign plot → teleport character ไปยัง `Spawn dummy + offset(0,3,8)`
- ส่ง `PlotOwnerUpdate` ไปบอก client ทุกคนว่า plot นี้ใครเป็นเจ้าของ

#### 4. `PlayerStats.lua` (ModuleScript)
จัดการ stats ของผู้เล่นแต่ละคน (เก็บใน table `data[player]`)
- `init/get/cleanup/sync` — CRUD พื้นฐาน
- `rollDamage(player)` → คำนวณดาเมจ + crit roll คืน `(dmg, isCrit)`
- `upgrade(player, type)` — รองรับ 5 ประเภท: `damage`, `critChance`, `maxStamina`, `staminaRegen`, `dummyHP`
- `getUpgradeCost()` — สูตรราคา = `baseCost × MULT^level`
- ส่ง `SyncStats` RemoteEvent กลับ client ทุกครั้งที่ stats เปลี่ยน

#### 5. `DummyServer.server.lua` ⭐ (หัวใจของเกม)
ระบบ Dummy + เหรียญ + การโจมตี
- **Spawn Dummy:** Clone จาก `ReplicatedStorage.DummyModel` วางที่ `Spawn dummy` พร้อม HP Bar (BillboardGui)
- **Anti-cheat:** เช็คระยะ ≤ 20 studs ก่อนรับ damage
- **AttackDummy.OnServerEvent:** รับ punch index → เช็คระยะ → roll damage → หัก HP → เล่น hit anim → fire `HitConfirmed` กลับ client
- **เมื่อ Dummy ตาย:** +10 coins → รอ 2s → destroy → spawn ใหม่
- **BindableFunction `GetCoins`/`SetCoins`** ใช้เป็นสะพานให้ `UpgradeServer` ดึง/หัก coins

RemoteEvents ที่สร้าง: `AttackDummy`, `UpdateCoins`, `HitConfirmed`

#### 6. `UpgradeServer.server.lua`
รับคำขอ upgrade จาก client
- ฟัง `UpgradeRequest.OnServerEvent`
- ดึง coins ผ่าน `GetCoins:Invoke()` → เช็คว่าพอ → เรียก `PlayerStats.upgrade()` → หักเงิน → fire `UpdateCoins` กลับ

---

### 🎨 CLIENT — `src/client/`

#### 7. `AttackClient.client.lua` ⭐ (Combo System)
ระบบโจมตี 3 จังหวะที่ซับซ้อนที่สุด
- โหลด animation 1 ตัว แต่แบ่งเป็น **3 segments** ตาม timecode (frame 0-20, 20-55, 55-79)
- **Combo Logic:**
  1. คลิก → เล่น segment 1 → หักสตามิน่า → ส่ง `AttackDummy:FireServer(1)`
  2. ระหว่างเล่น ถ้าคลิกอีก → คิว combo ต่อ
  3. หมด segment → ถ้ามีคิวค่อย play segment 2/3
  4. ครบ 3 → cooldown 0.5s
- ฟัง `HitConfirmed` → เล่นเสียง + spawn `hit effect` particle + show floating damage text (สีส้มถ้า crit)
- ฟัง `SyncStats` → update stamina max/regen/cost
- Stamina regen ใน `RunService.Heartbeat`
- Export `_G.StaminaState` ให้ StaminaUI อ่าน

#### 8. `UpgradeUI.client.lua`
หน้าต่าง Upgrade (Toggle ปุ่มล่างซ้าย)
- รายการ 5 upgrades: `Attack Power / Critical Hit / Max Stamina / Stamina Regen / Dummy HP`
- แต่ละแถวแสดง: ชื่อ, current → next, ราคา, ปุ่มซื้อ
- คลิกปุ่ม → `UpgradeRequest:FireServer(id)`
- รับ `SyncStats` → refresh ค่าใหม่

#### 9. `CoinsUI.client.lua`
แสดงเหรียญที่มุมล่างซ้าย ฟัง `UpdateCoins` event

#### 10. `StaminaUI.client.lua`
แถบ stamina อ่านจาก `_G.StaminaState`

#### 11. `PlotDisplay.client.lua`
แสดง BillboardGui + ViewportFrame ลอยเหนือ plot บอกว่า "เจ้าของคือใคร" (ฟัง `PlotOwnerUpdate`)

#### 12. `LoadingScreen.client.lua`
หน้าโหลดดำ ๆ ตอนเข้าเกม

---

### ⚙️ Tools / Config

| ไฟล์ | หน้าที่ |
|------|--------|
| `default.project.json` | Rojo project config (map folders → Roblox services) |
| `aftman.toml` | กำหนดให้ใช้ Rojo v7.4.1 |
| `StartRojo.bat` | Double-click เพื่อ start `rojo serve` (สะดวก) |
| `.claude/settings.local.json` | Permissions สำหรับ Claude Code |
| `.claude/launch.json` | Debug config |

---

## 🔌 RemoteEvents / RemoteFunctions ทั้งหมด

| ชื่อ | ทิศทาง | สร้างโดย | ใช้ส่งอะไร |
|------|--------|---------|----------|
| `AttackDummy` | Client → Server | DummyServer | punch index (1/2/3) |
| `HitConfirmed` | Server → Client | DummyServer | (punchIdx, damage, isCrit) |
| `UpdateCoins` | Server → Client | DummyServer | (newAmount, gainedAmount) |
| `SyncStats` | Server → Client | PlayerStats | table ของ stats ทั้งหมด |
| `UpgradeRequest` | Client → Server | UpgradeServer | upgradeType (string) |
| `PlotOwnerUpdate` | Server → Client(All) | PlotServer | (plot, player) |
| `GetCoins` / `SetCoins` | Server ↔ Server | UpgradeServer | BindableFunction สะพาน coins |

---

## 🧱 สิ่งที่ต้องมีใน Roblox Studio (ไม่ได้อยู่ใน Git)

> ⚠️ ไฟล์เหล่านี้อยู่ใน `.rbxl` ไม่ได้ sync ผ่าน Rojo — ต้องเซ็ตเองใน Studio

| Object | Location | จำเป็น |
|--------|----------|-------|
| `DummyModel` (Model + Humanoid + HumanoidRootPart) | `ReplicatedStorage` | ✅ |
| `hit effect` (Part หรือ Model มี ParticleEmitter) | `ReplicatedStorage` | ✅ |
| `plot1`, `plot2`, ... (Model) แต่ละอันมี Part ชื่อ `Spawn dummy` | `Workspace` | ✅ |

---

## 🎯 จุดสังเกต / สิ่งที่ควรรู้

1. **All stats live on server** — client แค่แสดง UI, server เป็นคน roll damage และเก็บ stats จริง
2. **Anti-cheat:** server เช็คระยะก่อนรับ damage (`ATTACK_RANGE = 20 studs`)
3. **Per-player Dummy:** ทุกคนมี Dummy ของตัวเอง ตีของคนอื่นไม่ได้ (เพราะ key ด้วย `playerDummies[player]`)
4. **No DataStore yet:** stats/coins รีเซ็ตทุกครั้งที่ออกจากเกม — ยังไม่มีระบบ save
5. **Combo cancel:** ถ้าไม่กดต่อภายใน 0.2s combo จะรีเซ็ต
6. **Bug เล็ก ๆ ที่เจอ:** `PlotServer.server.lua` บรรทัด 46 มี `player` ที่ไม่ได้ define ใน scope (ใน function `onCharacterAdded` รับแค่ `character, plot`) — อาจ error ตอน fire `PlotOwnerUpdate`

---

## 🚀 อยากเพิ่มอะไรต่อ? (แนะนำ)

- 💾 **DataStore** — save coins + upgrade levels
- 🏆 **Leaderboard** — แสดง top players
- ⚔️ **Weapons / Skins** — เปลี่ยนถุงมือ, ดาบ
- 🎁 **Daily Reward / Quests**
- 🌍 **Rebirth System** — รีเซ็ตเพื่อรับ multiplier
- 🤝 **Co-op Dummy** — ตีร่วมกับเพื่อนได้
