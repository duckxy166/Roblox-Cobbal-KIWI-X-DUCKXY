-- PlayerStats.lua (ModuleScript - ServerScriptService)
-- จัดการ stats ของผู้เล่นแต่ละคน + ฟังก์ชัน upgrade

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatsConfig       = require(ReplicatedStorage:WaitForChild("StatsConfig"))

local PlayerStats = {}

local data = {}  -- [player] = stat table

-- RemoteEvent ส่ง stats ไปให้ client
local SyncStats = Instance.new("RemoteEvent")
SyncStats.Name   = "SyncStats"
SyncStats.Parent = ReplicatedStorage

local function newStats()
    return {
        damage        = StatsConfig.DAMAGE,
        critChance    = StatsConfig.CRIT_CHANCE,
        maxStamina    = StatsConfig.MAX_STAMINA,
        staminaRegen  = StatsConfig.STAMINA_REGEN,
        -- upgrade levels
        dummyHpLevel  = 0,
        damageLevel   = 0,
        critLevel     = 0,
        staminaLevel  = 0,
        regenLevel    = 0,
    }
end

-- เริ่ม stats ให้ผู้เล่น
function PlayerStats.init(player)
    data[player] = newStats()
    PlayerStats.sync(player)
end

-- ดึง stats ของผู้เล่น
function PlayerStats.get(player)
    return data[player]
end

-- ส่ง stats ปัจจุบันไปให้ client
function PlayerStats.sync(player)
    local s = data[player]
    if not s then return end
    SyncStats:FireClient(player, {
        damage       = s.damage,
        critChance   = s.critChance,
        maxStamina   = s.maxStamina,
        staminaRegen = s.staminaRegen,
        staminaCost  = StatsConfig.getStaminaCost(s.damage),
        -- levels สำหรับคำนวณ cost ใน UI
        damageLevel  = s.damageLevel,
        critLevel    = s.critLevel,
        staminaLevel = s.staminaLevel,
        regenLevel   = s.regenLevel,
        dummyHpLevel = s.dummyHpLevel,
    })
end

-- ลบ stats ตอนผู้เล่นออก
function PlayerStats.cleanup(player)
    data[player] = nil
end

-- คำนวณดาเมจพร้อม crit (เรียกตอนโจมตี)
function PlayerStats.rollDamage(player)
    local s = data[player]
    if not s then return StatsConfig.DAMAGE, false end
    local isCrit = math.random(1, 100) <= s.critChance
    local dmg    = isCrit and math.floor(s.damage * StatsConfig.CRIT_MULTIPLIER) or s.damage
    return dmg, isCrit
end

-- Max HP ของ Dummy ตาม level ของผู้เล่น
function PlayerStats.getDummyMaxHP(player)
    local s = data[player]
    if not s then return StatsConfig.DUMMY_BASE_HP end
    return StatsConfig.getDummyMaxHP(s.dummyHpLevel)
end

-- ราคา upgrade Dummy HP ครั้งถัดไป
function PlayerStats.getDummyUpgradeCost(player)
    local s = data[player]
    if not s then return StatsConfig.getDummyUpgradeCost(0) end
    return StatsConfig.getDummyUpgradeCost(s.dummyHpLevel)
end

-- ============================================================
--  Upgrade Functions
-- ============================================================

local upgradeDefs = {
    damage = function(s)
        s.damageLevel += 1
        s.damage += StatsConfig.DAMAGE_PER_UPGRADE
    end,
    critChance = function(s)
        s.critLevel += 1
        s.critChance += StatsConfig.CRIT_PER_UPGRADE
    end,
    maxStamina = function(s)
        s.staminaLevel += 1
        s.maxStamina += StatsConfig.STAMINA_PER_UPGRADE
    end,
    staminaRegen = function(s)
        s.regenLevel += 1
        s.staminaRegen += StatsConfig.REGEN_PER_UPGRADE
    end,
    dummyHP = function(s)
        s.dummyHpLevel += 1
    end,
}

local costDefs = {
    damage      = function(s) return math.floor(StatsConfig.DAMAGE_UPGRADE_COST   * StatsConfig.UPGRADE_COST_MULT ^ s.damageLevel)   end,
    critChance  = function(s) return math.floor(StatsConfig.CRIT_UPGRADE_COST     * StatsConfig.UPGRADE_COST_MULT ^ s.critLevel)     end,
    maxStamina  = function(s) return math.floor(StatsConfig.STAMINA_UPGRADE_COST  * StatsConfig.UPGRADE_COST_MULT ^ s.staminaLevel)  end,
    staminaRegen= function(s) return math.floor(StatsConfig.REGEN_UPGRADE_COST    * StatsConfig.UPGRADE_COST_MULT ^ s.regenLevel)    end,
    dummyHP     = function(s) return StatsConfig.getDummyUpgradeCost(s.dummyHpLevel) end,
}

function PlayerStats.getUpgradeCost(player, upgradeType)
    local s = data[player]
    if not s or not costDefs[upgradeType] then return 0 end
    return costDefs[upgradeType](s)
end

-- คืนค่า success, newStats หรือ nil
function PlayerStats.upgrade(player, upgradeType)
    local s = data[player]
    if not s then return false end
    if not upgradeDefs[upgradeType] then return false end
    upgradeDefs[upgradeType](s)
    PlayerStats.sync(player)
    return true
end

function PlayerStats.upgradeDummyHP(player)
    local s = data[player]
    if not s then return false, 0 end
    s.dummyHpLevel += 1
    return true, StatsConfig.getDummyMaxHP(s.dummyHpLevel)
end

return PlayerStats
