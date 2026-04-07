-- PlotServer.server.lua

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotManager       = require(script.Parent:WaitForChild("PlotManager"))

local PlotOwnerUpdate = Instance.new("RemoteEvent")
PlotOwnerUpdate.Name   = "PlotOwnerUpdate"
PlotOwnerUpdate.Parent = ReplicatedStorage

local PLAYER_OFFSET = Vector3.new(0, 3, 8)  -- ยืนหน้า Dummy

local function teleportToPlot(character, plot)
    local spawnPart = plot:FindFirstChild("Spawn dummy")
    if not spawnPart then
        warn("[PlotServer] ไม่พบ 'Spawn dummy' ใน", plot.Name)
        return
    end

    local root = character:WaitForChild("HumanoidRootPart", 5)
    if not root then return end

    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end

    -- รอให้ physics settle ก่อน
    task.wait(0.2)

    local targetCFrame = CFrame.new(spawnPart.Position + PLAYER_OFFSET)

    -- Set สองครั้งเพื่อให้แน่ใจว่า physics ไม่ reset
    root.CFrame = targetCFrame
    task.wait(0.1)
    root.CFrame = targetCFrame

    print("[PlotServer]", character.Name, "teleported to", plot.Name, "at", targetCFrame.Position)
end

local function onCharacterAdded(character, player, plot)
    task.spawn(function()
        -- รอ character โหลดเสร็จ
        character:WaitForChild("HumanoidRootPart", 10)
        task.wait(0.5)
        teleportToPlot(character, plot)
        task.wait(0.5)
        PlotOwnerUpdate:FireAllClients(plot, player)
    end)
end

local function setupPlayer(player)
    local plot = PlotManager.assign(player)
    if not plot then return end

    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(character, player, plot)
    end)

    if player.Character then
        onCharacterAdded(player.Character, player, plot)
    end
end

Players.PlayerAdded:Connect(setupPlayer)

-- Handle players already in-game when this script starts
for _, player in Players:GetPlayers() do
    setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
    local plot = PlotManager.getPlot(player)
    if plot then
        PlotOwnerUpdate:FireAllClients(plot, nil)
    end
    PlotManager.release(player)
end)
