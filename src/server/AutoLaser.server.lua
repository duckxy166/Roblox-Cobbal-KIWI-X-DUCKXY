-- AutoLaser.server.lua
-- saharatvc96 shoots laser every 5 minutes automatically

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Debris            = game:GetService("Debris")

local TARGET_PLAYER = "saharatvc96"
local LASER_INTERVAL = 300 -- 5 minutes in seconds
local LASER_DAMAGE   = 50

local dummiesFolder = Workspace:FindFirstChild("Dummies")

local function getTargetDummy()
    if not dummiesFolder then return nil end
    for _, dummy in dummiesFolder:GetChildren() do
        if dummy.Name == TARGET_PLAYER .. "_Dummy" then
            return dummy
        end
    end
    return nil
end

local function shootLaser()
    local targetPlayer = Players:FindFirstChild(TARGET_PLAYER)
    if not targetPlayer then return end
    
    local character = targetPlayer.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local dummy = getTargetDummy()
    if not dummy then return end
    
    local dummyRoot = dummy:FindFirstChild("HumanoidRootPart")
    if not dummyRoot then return end
    
    local direction = (dummyRoot.Position - humanoidRootPart.Position).Unit
    
    local laserStart = humanoidRootPart.Position + Vector3.new(0, 1, 0)
    local laserEnd = dummyRoot.Position
    
    local distance = (laserEnd - laserStart).Magnitude
    
    local beam = Instance.new("Part")
    beam.Anchored = true
    beam.CanCollide = false
    beam.Transparency = 0.5
    beam.Color = Color3.fromRGB(255, 0, 0)
    beam.Material = Enum.Material.Neon
    beam.Size = Vector3.new(0.3, 0.3, distance)
    beam.CFrame = CFrame.new(laserStart + (laserEnd - laserStart) / 2, laserEnd)
    beam.Parent = Workspace
    
    local beam2 = beam:Clone()
    beam2.Size = Vector3.new(0.6, 0.6, distance)
    beam2.Transparency = 0.7
    beam2.Parent = Workspace
    
    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid:TakeDamage(LASER_DAMAGE)
    end
    
    Debris:AddItem(beam, 0.3)
    Debris:AddItem(beam2, 0.3)
end

local function startLaserTimer()
    local targetPlayer = Players:FindFirstChild(TARGET_PLAYER)
    if not targetPlayer then
        return
    end
    
    while Players:FindFirstChild(TARGET_PLAYER) do
        task.wait(LASER_INTERVAL)
        if Players:FindFirstChild(TARGET_PLAYER) then
            shootLaser()
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    if player.Name == TARGET_PLAYER then
        task.spawn(startLaserTimer)
    end
end)

if Players:FindFirstChild(TARGET_PLAYER) then
    task.spawn(startLaserTimer)
end
