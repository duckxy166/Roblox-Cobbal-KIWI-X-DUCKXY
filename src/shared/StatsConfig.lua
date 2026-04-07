-- StatsConfig.lua (ModuleScript - ReplicatedStorage)
-- ค่า base stats ทั้งหมดของเกม แก้ได้ที่นี่ที่เดียว

local StatsConfig = {}

-- ============================================================
--  Player Stats
-- ============================================================
StatsConfig.DAMAGE            = 10      -- ดาเมจต่อหมัด
StatsConfig.CRIT_CHANCE       = 1       -- % โอกาสติดคริ
StatsConfig.CRIT_MULTIPLIER   = 3       -- คริ = ดาเมจ x3
StatsConfig.MAX_STAMINA       = 100     -- สตามิน่าสูงสุด
StatsConfig.STAMINA_REGEN     = 10      -- สตามิน่า regen ต่อวินาที
StatsConfig.STAMINA_COST_MULT = 0.5     -- staminaCost = damage * STAMINA_COST_MULT

-- ============================================================
--  Dummy Upgrade Stats
-- ============================================================
StatsConfig.DUMMY_BASE_HP            = 100
StatsConfig.DUMMY_HP_UPGRADE_PERCENT = 0.05   -- +5% ต่อ 1 level
StatsConfig.DUMMY_UPGRADE_BASE_COST  = 50
StatsConfig.DUMMY_UPGRADE_COST_MULT  = 2

-- ============================================================
--  Player Upgrade Increments & Costs
-- ============================================================
StatsConfig.DAMAGE_PER_UPGRADE      = 5
StatsConfig.DAMAGE_UPGRADE_COST     = 50

StatsConfig.CRIT_PER_UPGRADE        = 1       -- +1% ต่อ level
StatsConfig.CRIT_UPGRADE_COST       = 100

StatsConfig.STAMINA_PER_UPGRADE     = 20
StatsConfig.STAMINA_UPGRADE_COST    = 75

StatsConfig.REGEN_PER_UPGRADE       = 5
StatsConfig.REGEN_UPGRADE_COST      = 75

StatsConfig.UPGRADE_COST_MULT       = 2       -- x2 ทุก level (ใช้กับทุก stat)

-- ============================================================
--  Helper Functions
-- ============================================================

-- คำนวณ max HP ของ Dummy ตาม level
function StatsConfig.getDummyMaxHP(level)
    local hp = StatsConfig.DUMMY_BASE_HP
    for _ = 1, level do
        hp = hp * (1 + StatsConfig.DUMMY_HP_UPGRADE_PERCENT)
    end
    return math.floor(hp)
end

-- คำนวณต้นทุน upgrade Dummy HP
function StatsConfig.getDummyUpgradeCost(currentLevel)
    return math.floor(
        StatsConfig.DUMMY_UPGRADE_BASE_COST *
        (StatsConfig.DUMMY_UPGRADE_COST_MULT ^ currentLevel)
    )
end

-- คำนวณ stamina cost จาก damage
function StatsConfig.getStaminaCost(damage)
    return math.max(1, math.floor(damage * StatsConfig.STAMINA_COST_MULT))
end

return StatsConfig
