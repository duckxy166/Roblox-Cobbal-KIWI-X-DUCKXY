-- ShopNPC.server.lua
-- NPC Shop that opens shop UI when clicked, attacks when hit

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local CONFIG = {
    INTERACT_DISTANCE = 8, -- 2 meters in studs (scaled up for gameplay)
    SLAP_FORCE        = 150,
    SLAP_HEIGHT       = 200,
}

local OpenShopUI = Instance.new("RemoteEvent")
OpenShopUI.Name   = "OpenShopUI"
OpenShopUI.Parent = ReplicatedStorage

local shopNPCs    = {}  -- npc → true (alive set)
local plotNPCs    = {}  -- plot → npc (one NPC per plot)

local function getShopSpawnPart(plot)
    return plot:FindFirstChild("Spawn Shopkeeper") or plot:FindFirstChild("Spawn shop")
end

local function createShopNPC(plot)
    local npcModel = ReplicatedStorage:FindFirstChild("ShopNPC") or ReplicatedStorage:FindFirstChild("ShopNPCModel")
    if not npcModel then
        warn("[ShopNPC]  tidak ketemu 'ShopNPC' หรือ 'ShopNPCModel' di ReplicatedStorage")
        return
    end

    local spawnPart = getShopSpawnPart(plot)
    if not spawnPart then
        warn("[ShopNPC]  tidak ketemu 'Spawn Shopkeeper' di plot")
        return
    end

    local npc = npcModel:Clone()
    npc.Name = "ShopNPC"
    npc.Parent = Workspace

    local hrp = npc:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 4, 0)
        hrp.Anchored = true -- Keep NPC in place
    else
        npc:PivotTo(spawnPart.CFrame)
    end

    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = CONFIG.INTERACT_DISTANCE
    clickDetector.Parent = npc

    clickDetector.MouseClick:Connect(function(player)
        local character = player.Character
        if not character then return end

        local playerRoot = character:FindFirstChild("HumanoidRootPart")
        if not playerRoot then return end

        local npcRoot = npc:FindFirstChild("HumanoidRootPart")
        if not npcRoot then return end

        local distance = (playerRoot.Position - npcRoot.Position).Magnitude
        if distance <= CONFIG.INTERACT_DISTANCE then
            OpenShopUI:FireClient(player)
        end
    end)

    shopNPCs[npc] = true
    plotNPCs[plot] = npc

    local humanoid = npc:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.MaxHealth = 100
        humanoid.Health = 100

        humanoid.HealthChanged:Connect(function(health)
            if health <= 0 and shopNPCs[npc] then
                shopNPCs[npc] = nil
                if plotNPCs[plot] == npc then
                    plotNPCs[plot] = nil
                end

                local attacker = humanoid:FindFirstChild("LastHitBy")
                if attacker then
                    local attackPlayer = Players:GetPlayerByUserId(attacker.UserId)
                    if attackPlayer then
                        local char = attackPlayer.Character
                        if char then
                            local playerRoot = char:FindFirstChild("HumanoidRootPart")
                            if playerRoot then
                                local slapDirection = (playerRoot.Position - npcRoot.Position).Unit
                                slapDirection = Vector3.new(slapDirection.X, 0.5, slapDirection.Z).Unit

                                local velocity = Instance.new("BodyVelocity")
                                velocity.Velocity = Vector3.new(
                                    slapDirection.X * CONFIG.SLAP_FORCE,
                                    CONFIG.SLAP_HEIGHT,
                                    slapDirection.Z * CONFIG.SLAP_FORCE
                                )
                                velocity.MaxForce = Vector3.new(10000, 10000, 10000)
                                velocity.Parent = playerRoot

                                task.delay(0.5, function()
                                    if velocity and velocity.Parent then
                                        velocity:Destroy()
                                    end
                                end)
                            end
                        end
                    end
                end

                task.delay(0.5, function()
                    if npc and npc.Parent then
                        npc:Destroy()
                    end
                end)
            end
        end)
    end

    return npc
end

local PlotManager = require(script.Parent:WaitForChild("PlotManager"))

-- Spawn NPC only when a player is actually assigned to a plot
PlotManager.PlotAssigned.Event:Connect(function(player, plot)
    if not plotNPCs[plot] then
        createShopNPC(plot)
    end
end)

-- Clean up NPC when player leaves
Players.PlayerRemoving:Connect(function(player)
    local plot = PlotManager.getPlot(player)
    if plot then
        local npc = plotNPCs[plot]
        if npc and npc.Parent then
            npc:Destroy()
        end
        plotNPCs[plot] = nil
    end
end)

-- Stale reference cleanup
task.spawn(function()
    while true do
        task.wait(5)
        for npc in pairs(shopNPCs) do
            if not npc.Parent then
                shopNPCs[npc] = nil
            end
        end
    end
end)
