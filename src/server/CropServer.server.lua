-- CropServer.server.lua
-- Handles planting seeds on soil, growing through stages, and transforming
-- fully-grown crops into walking hostile enemies.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")

local PlotManager = require(script.Parent:WaitForChild("PlotManager"))

-- ── CONFIG ────────────────────────────────────────────────────
local GROW_INTERVAL   = 5      -- seconds between growth stages
local ENEMY_HP        = 150
local ENEMY_SPEED     = 10
local ENEMY_DAMAGE    = 12
local ENEMY_RANGE     = 60     -- aggro range
local ATTACK_RANGE    = 5
local ATTACK_COOLDOWN = 1.8
-- ─────────────────────────────────────────────────────────────

-- Asset folders (moved to ReplicatedStorage)
local CropModels  = ReplicatedStorage:WaitForChild("CropModels")
local CropSeeds   = ReplicatedStorage:WaitForChild("CropSeeds")

-- Remotes
local PlantSeed = Instance.new("RemoteEvent")
PlantSeed.Name   = "PlantSeed"
PlantSeed.Parent = ReplicatedStorage

local HitConfirmed = ReplicatedStorage:WaitForChild("HitConfirmed", 10)
local UpdateCoins  = ReplicatedStorage:WaitForChild("UpdateCoins", 10)

-- Enemies folder (shared with EnemyServer)
local enemiesFolder = workspace:FindFirstChild("Enemies")
if not enemiesFolder then
    enemiesFolder = Instance.new("Folder")
    enemiesFolder.Name   = "Enemies"
    enemiesFolder.Parent = workspace
end

-- ── Seed → Crop name mapping ─────────────────────────────────
local SEED_TO_CROP = {}
for _, seed in ipairs(CropSeeds:GetChildren()) do
    local cropName = seed.Name:gsub(" Seed$", "")
    SEED_TO_CROP[seed.Name] = cropName
end

-- Track active crops per plot  { [plotPart] = { model, stage, cropName, soilPart } }
local activeCrops = {}

-- ── Helpers ───────────────────────────────────────────────────
local function getSoilParts(plot)
    local plotOne = plot:FindFirstChild("PlotOne")
    if not plotOne then return {} end
    local parts = {}
    for _, child in ipairs(plotOne:GetDescendants()) do
        if child:IsA("BasePart") and child.Parent and child.Parent.Name == "RightSoil" then
            table.insert(parts, child)
        end
    end
    return parts
end

local function getStageCount(cropTemplate)
    local model = cropTemplate:FindFirstChild("Model")
    if not model then return 0 end
    local count = 0
    for _, child in ipairs(model:GetChildren()) do
        if child.Name:find("^STAGE_") then
            count = count + 1
        end
    end
    return count
end

local function getStageFolder(cropTemplate, stageNum)
    local model = cropTemplate:FindFirstChild("Model")
    if not model then return nil end
    return model:FindFirstChild("STAGE_" .. stageNum)
end

-- ── Build HP bar for crop enemy ──────────────────────────────
local function buildHPBar(parent, maxHP, label)
    local bb = Instance.new("BillboardGui")
    bb.Name        = "HPBar"
    bb.Size        = UDim2.new(0, 130, 0, 36)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = false
    bb.Parent      = parent

    local nameTag = Instance.new("TextLabel")
    nameTag.Size                 = UDim2.new(1, 0, 0.45, 0)
    nameTag.BackgroundTransparency = 1
    nameTag.Text                 = label
    nameTag.TextColor3           = Color3.fromRGB(180, 255, 180)
    nameTag.TextScaled           = true
    nameTag.Font                 = Enum.Font.GothamBold
    nameTag.TextStrokeTransparency = 0.5
    nameTag.Parent               = bb

    local bg = Instance.new("Frame")
    bg.Name             = "BG"
    bg.Size             = UDim2.new(1, 0, 0.45, 0)
    bg.Position         = UDim2.new(0, 0, 0.55, 0)
    bg.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    bg.BorderSizePixel  = 0
    bg.Parent           = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 4)

    local bar = Instance.new("Frame")
    bar.Name             = "Bar"
    bar.Size             = UDim2.new(1, 0, 1, 0)
    bar.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    bar.BorderSizePixel  = 0
    bar.Parent           = bg
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

    local hpText = Instance.new("TextLabel")
    hpText.Name                  = "HPText"
    hpText.Size                  = UDim2.new(1, 0, 1, 0)
    hpText.BackgroundTransparency = 1
    hpText.Text                  = maxHP .. " / " .. maxHP
    hpText.TextColor3            = Color3.new(1, 1, 1)
    hpText.TextScaled            = true
    hpText.Font                  = Enum.Font.Gotham
    hpText.ZIndex                = 2
    hpText.Parent                = bg
end

local function updateHPBar(rootPart, hp, maxHP)
    local bb = rootPart:FindFirstChild("HPBar")
    if not bb then return end
    local bg  = bb:FindFirstChild("BG")
    if not bg then return end
    local bar = bg:FindFirstChild("Bar")
    local txt = bg:FindFirstChild("HPText")
    local pct = math.clamp(hp / maxHP, 0, 1)
    if bar then bar.Size  = UDim2.new(pct, 0, 1, 0) end
    if txt then txt.Text  = math.ceil(hp) .. " / " .. maxHP end
end

-- ── Transform crop into walking enemy ─────────────────────────
local function transformToEnemy(cropModel, cropName, spawnCFrame)
    -- Create an enemy Model that wraps the crop visual
    local enemy = Instance.new("Model")
    enemy.Name = cropName .. " (Hostile)"

    -- Create HumanoidRootPart
    local root = Instance.new("Part")
    root.Name         = "HumanoidRootPart"
    root.Size         = Vector3.new(2, 2, 1)
    root.Transparency = 1
    root.Anchored     = false
    root.CanCollide   = true
    root.Parent       = enemy
    enemy.PrimaryPart = root

    -- Create Humanoid
    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = ENEMY_HP
    humanoid.Health    = ENEMY_HP
    humanoid.WalkSpeed = ENEMY_SPEED
    humanoid.Parent    = enemy

    -- Create body parts for R6 rig so Humanoid can walk
    local torso = Instance.new("Part")
    torso.Name        = "Torso"
    torso.Size        = Vector3.new(2, 2, 1)
    torso.Transparency = 1
    torso.CanCollide   = false
    torso.Parent       = enemy

    local head = Instance.new("Part")
    head.Name        = "Head"
    head.Size        = Vector3.new(1, 1, 1)
    head.Transparency = 1
    head.CanCollide   = false
    head.Parent       = enemy

    local leftArm = Instance.new("Part")
    leftArm.Name        = "Left Arm"
    leftArm.Size        = Vector3.new(1, 2, 1)
    leftArm.Transparency = 1
    leftArm.CanCollide   = false
    leftArm.Parent       = enemy

    local rightArm = Instance.new("Part")
    rightArm.Name        = "Right Arm"
    rightArm.Size        = Vector3.new(1, 2, 1)
    rightArm.Transparency = 1
    rightArm.CanCollide   = false
    rightArm.Parent       = enemy

    local leftLeg = Instance.new("Part")
    leftLeg.Name        = "Left Leg"
    leftLeg.Size        = Vector3.new(1, 2, 1)
    leftLeg.Transparency = 1
    leftLeg.CanCollide   = false
    leftLeg.Parent       = enemy

    local rightLeg = Instance.new("Part")
    rightLeg.Name        = "Right Leg"
    rightLeg.Size        = Vector3.new(1, 2, 1)
    rightLeg.Transparency = 1
    rightLeg.CanCollide   = false
    rightLeg.Parent       = enemy

    -- Motor6D joints
    local function makeMotor(name, part0, part1, c0, c1)
        local m = Instance.new("Motor6D")
        m.Name  = name
        m.Part0 = part0
        m.Part1 = part1
        m.C0    = c0
        m.C1    = c1 or CFrame.new()
        m.Parent = part0
    end

    makeMotor("RootJoint",       root,  torso,    CFrame.new())
    makeMotor("Neck",            torso, head,     CFrame.new(0, 1.5, 0))
    makeMotor("Left Shoulder",   torso, leftArm,  CFrame.new(-1.5, 0.5, 0), CFrame.new(0, 0.5, 0))
    makeMotor("Right Shoulder",  torso, rightArm, CFrame.new(1.5, 0.5, 0),  CFrame.new(0, 0.5, 0))
    makeMotor("Left Hip",        torso, leftLeg,  CFrame.new(-0.5, -1, 0),  CFrame.new(0, 1, 0))
    makeMotor("Right Hip",       torso, rightLeg, CFrame.new(0.5, -1, 0),   CFrame.new(0, 1, 0))

    -- Attach crop visual to the torso via weld
    local visual = cropModel:Clone()
    visual.Name = "CropVisual"
    for _, part in ipairs(visual:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored  = false
            part.CanCollide = false
        end
    end
    visual.Parent = enemy

    -- Weld all visual parts to the torso
    for _, part in ipairs(visual:GetDescendants()) do
        if part:IsA("BasePart") then
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = torso
            weld.Part1 = part
            weld.Parent = part
        end
    end

    enemy.Parent = enemiesFolder
    enemy:PivotTo(spawnCFrame * CFrame.new(0, 3, 0))

    buildHPBar(root, ENEMY_HP, cropName)

    humanoid.HealthChanged:Connect(function(hp)
        updateHPBar(root, hp, ENEMY_HP)
    end)

    -- ── AI Loop ──────────────────────────────────────────────
    local lastAttack = 0

    task.spawn(function()
        while enemy.Parent and humanoid.Health > 0 do
            local nearest, nearestDist = nil, ENEMY_RANGE

            for _, p in ipairs(Players:GetPlayers()) do
                local char = p.Character
                if char then
                    local pRoot = char:FindFirstChild("HumanoidRootPart")
                    local pHum  = char:FindFirstChildOfClass("Humanoid")
                    if pRoot and pHum and pHum.Health > 0 then
                        local dist = (root.Position - pRoot.Position).Magnitude
                        if dist < nearestDist then
                            nearestDist = dist
                            nearest     = char
                        end
                    end
                end
            end

            if nearest then
                local targetRoot = nearest:FindFirstChild("HumanoidRootPart")
                local targetHum  = nearest:FindFirstChildOfClass("Humanoid")
                if targetRoot then
                    humanoid:MoveTo(targetRoot.Position)
                    if nearestDist <= ATTACK_RANGE and tick() - lastAttack >= ATTACK_COOLDOWN then
                        lastAttack = tick()
                        if targetHum and targetHum.Health > 0 then
                            targetHum:TakeDamage(ENEMY_DAMAGE)
                        end
                    end
                end
            end

            task.wait(0.15)
        end

        -- Death
        task.wait(0.2)
        for _, part in ipairs(enemy:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = false
            elseif part:IsA("Motor6D") or part:IsA("WeldConstraint") then
                part:Destroy()
            end
        end
        Debris:AddItem(enemy, 4)
    end)
end

-- ── Display a crop stage visually on a soil part ─────────────
local function showStage(stageFolder, position)
    if not stageFolder then return nil end
    local visual = Instance.new("Model")
    visual.Name = "CropVisual"

    for _, child in ipairs(stageFolder:GetChildren()) do
        if child:IsA("BasePart") then
            local clone = child:Clone()
            clone.Anchored = true
            clone.CanCollide = false
            clone.Parent = visual
        end
    end

    visual.Parent = workspace
    visual:PivotTo(CFrame.new(position + Vector3.new(0, 1, 0)))
    return visual
end

-- ── Plant + Grow logic ───────────────────────────────────────
local function plantOnSoil(player, seedName, soilPart)
    local cropName = SEED_TO_CROP[seedName]
    if not cropName then
        warn("[CropServer] Unknown seed:", seedName)
        return
    end

    local cropTemplate = CropModels:FindFirstChild(cropName)
    if not cropTemplate then
        warn("[CropServer] No crop model for:", cropName)
        return
    end

    local stageCount = getStageCount(cropTemplate)
    if stageCount == 0 then
        warn("[CropServer] No stages for:", cropName)
        return
    end

    -- Show first stage
    print("[CropServer] Planting", cropName, "with", stageCount, "stages")
    local currentVisual = showStage(getStageFolder(cropTemplate, 1), soilPart.Position)
    local currentStage  = 1

    -- Mark soil as occupied
    soilPart:SetAttribute("Occupied", true)
    soilPart:SetAttribute("CropName", cropName)

    -- Grow through stages
    task.spawn(function()
        while currentStage < stageCount do
            task.wait(GROW_INTERVAL)
            currentStage = currentStage + 1
            print("[CropServer]", cropName, "growing to stage", currentStage, "/", stageCount)

            -- Remove old visual
            if currentVisual then
                currentVisual:Destroy()
            end

            -- Show new stage
            currentVisual = showStage(
                getStageFolder(cropTemplate, currentStage),
                soilPart.Position
            )
        end

        -- Fully grown → wait a beat, then transform to enemy
        task.wait(2)

        if currentVisual then
            local spawnCF = CFrame.new(soilPart.Position)
            local finalVisual = currentVisual
            currentVisual = nil

            print("[CropServer]", cropName, "fully grown! Transforming to enemy...")
            transformToEnemy(finalVisual, cropName, spawnCF)
            finalVisual:Destroy()
            print("[CropServer]", cropName, "enemy spawned!")
        end

        -- Free the soil
        soilPart:SetAttribute("Occupied", false)
        soilPart:SetAttribute("CropName", nil)
    end)
end

-- ── Remote Handler ───────────────────────────────────────────
PlantSeed.OnServerEvent:Connect(function(player, seedName)
    print("[CropServer]", player.Name, "wants to plant:", seedName)
    local plot = PlotManager.getPlot(player)
    if not plot then
        warn("[CropServer]", player.Name, "has no plot assigned")
        return
    end
    print("[CropServer] Plot found:", plot.Name)

    local soilParts = getSoilParts(plot)
    print("[CropServer] Soil parts found:", #soilParts)
    if #soilParts == 0 then
        warn("[CropServer] No soil parts in", plot.Name)
        return
    end

    -- Find an unoccupied soil part
    local targetSoil
    for _, soil in ipairs(soilParts) do
        if not soil:GetAttribute("Occupied") then
            targetSoil = soil
            break
        end
    end

    if not targetSoil then
        warn("[CropServer] All soil occupied in", plot.Name)
        return
    end

    print("[CropServer] Planting", seedName, "on", targetSoil.Name, "at", tostring(targetSoil.Position))
    plantOnSoil(player, seedName, targetSoil)
end)

print("[CropServer] Loaded. Seeds:", #CropSeeds:GetChildren(), "Crops:", #CropModels:GetChildren())
