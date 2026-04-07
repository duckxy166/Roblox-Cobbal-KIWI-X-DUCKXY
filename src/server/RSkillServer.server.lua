local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local PlayerStats       = require(script.Parent:WaitForChild("PlayerStats"))

local DAMAGE_RANGE       = 20   -- same as RSkill CONFIG.DAMAGE_RANGE
local DAMAGE_MULTIPLIER  = 3    -- R skill hits 3× harder than basic attack
local COINS_PER_KILL     = 25   -- enemies give more coins

-- RemoteEvent for AOE enemy hit
local RSkillHit = Instance.new("RemoteEvent")
RSkillHit.Name   = "RSkillHit"
RSkillHit.Parent = ReplicatedStorage

-- Shared remotes created by DummyServer
local HitConfirmed = ReplicatedStorage:WaitForChild("HitConfirmed")
local UpdateCoins  = ReplicatedStorage:WaitForChild("UpdateCoins")
local GetCoins     = script.Parent:WaitForChild("GetCoins", 10)
local SetCoins     = script.Parent:WaitForChild("SetCoins", 10)

-- ── Anti-cheat: basic position sanity check ──────────────────
local MAX_DISTANCE_FROM_SERVER = 60

RSkillHit.OnServerEvent:Connect(function(player, impactPosition)
    if typeof(impactPosition) ~= "Vector3" then return end

    local character = player.Character
    if not character then return end
    local serverRoot = character:FindFirstChild("HumanoidRootPart")
    if not serverRoot then return end

    -- Reject if client position is too far off
    if (serverRoot.Position - impactPosition).Magnitude > MAX_DISTANCE_FROM_SERVER then
        return
    end

    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return end

    local coins      = GetCoins and GetCoins:Invoke(player) or 0
    local coinsEarned = 0

    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        local humanoid = enemy:FindFirstChildOfClass("Humanoid")
        local root     = enemy:FindFirstChild("HumanoidRootPart")

        if humanoid and humanoid.Health > 0 and root then
            local dist = (impactPosition - root.Position).Magnitude
            if dist <= DAMAGE_RANGE then
                local damage, isCrit = PlayerStats.rollDamage(player)
                damage = math.floor(damage * DAMAGE_MULTIPLIER)

                local prevHP = humanoid.Health
                humanoid:TakeDamage(damage)
                local actualDmg = math.min(prevHP, damage)

                -- Show damage number on the correct enemy body
                HitConfirmed:FireClient(player, 3, actualDmg, isCrit, enemy)

                if prevHP > 0 and humanoid.Health <= 0 then
                    coinsEarned = coinsEarned + COINS_PER_KILL
                end
            end
        end
    end

    if coinsEarned > 0 then
        coins = coins + coinsEarned
        if SetCoins then SetCoins:Invoke(player, coins) end
        UpdateCoins:FireClient(player, coins, coinsEarned)
    end
end)
