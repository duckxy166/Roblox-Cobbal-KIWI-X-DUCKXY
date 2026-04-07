-- DaggerRainServer.server.lua
-- Handles server-side damage for Po's Dagger (2.0) rain ability

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAGGER_COUNT   = 7
local DAMAGE_PER_HIT = 30
local AoE_RANGE      = 25

-- Remote events (created here; client waits for them)
local DaggerRainEvent = Instance.new("RemoteEvent")
DaggerRainEvent.Name   = "DaggerRain"
DaggerRainEvent.Parent = ReplicatedStorage

local DaggerRainFeedback = Instance.new("RemoteEvent")
DaggerRainFeedback.Name   = "DaggerRainFeedback"
DaggerRainFeedback.Parent = ReplicatedStorage

-- Wait for HitConfirmed and UpdateCoins created by DummyServer
local HitConfirmed = ReplicatedStorage:WaitForChild("HitConfirmed")
local UpdateCoins  = ReplicatedStorage:WaitForChild("UpdateCoins")

local playerCoins = {}

Players.PlayerAdded:Connect(function(p)
    playerCoins[p] = 0
end)
Players.PlayerRemoving:Connect(function(p)
    playerCoins[p] = nil
end)

local function findEnemiesInRange(origin, range, excludeCharacter)
    local targets = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Health > 0 then
            local model = obj.Parent
            if model ~= excludeCharacter then
                local root = model:FindFirstChild("HumanoidRootPart")
                if root and (root.Position - origin).Magnitude <= range then
                    table.insert(targets, { humanoid = obj, model = model, root = root })
                end
            end
        end
    end
    return targets
end

DaggerRainEvent.OnServerEvent:Connect(function(player)
    local character = player.Character
    if not character then return end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local selfHumanoid = character:FindFirstChildOfClass("Humanoid")
    if not selfHumanoid or selfHumanoid.Health <= 0 then return end

    local targets = findEnemiesInRange(root.Position, AoE_RANGE, character)
    if #targets == 0 then return end

    -- Distribute DAGGER_COUNT hits across targets (random spread)
    local coinsEarned = 0
    for i = 1, DAGGER_COUNT do
        local t = targets[math.random(1, #targets)]
        if t.humanoid and t.humanoid.Health > 0 then
            local prevHP = t.humanoid.Health
            t.humanoid:TakeDamage(DAMAGE_PER_HIT)

            HitConfirmed:FireClient(player, 1, DAMAGE_PER_HIT, false, t.model)

            if prevHP > 0 and t.humanoid.Health <= 0 then
                coinsEarned = coinsEarned + 15
            end
        end
    end

    if coinsEarned > 0 then
        playerCoins[player] = (playerCoins[player] or 0) + coinsEarned
        UpdateCoins:FireClient(player, playerCoins[player], coinsEarned)
    end
end)
