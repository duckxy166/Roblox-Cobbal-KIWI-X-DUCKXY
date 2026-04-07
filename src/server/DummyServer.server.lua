-- DummyServer.server.lua
-- ระบบ Dummy + เหรียญ (per-player, ใช้ PlotManager)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local PlotManager = require(script.Parent:WaitForChild("PlotManager"))
local PlayerStats  = require(script.Parent:WaitForChild("PlayerStats"))

-- ============================================================
--  CONFIG
-- ============================================================
local CONFIG = {
    DUMMY_RESPAWN = 3,    -- วินาทีก่อน Dummy respawn
    ATTACK_RANGE  = 20,   -- studs
    COINS_PER_KILL = 10,

    HIT_ANIMS = {
        "rbxassetid://74805136277269",   -- hit 1
        "rbxassetid://131787149262088",  -- hit 2
        "rbxassetid://76905950691174",   -- hit 3
    },
}
-- ============================================================

-- RemoteEvents
local AttackDummy = Instance.new("RemoteEvent")
AttackDummy.Name   = "AttackDummy"
AttackDummy.Parent = ReplicatedStorage

local UpdateCoins = Instance.new("RemoteEvent")
UpdateCoins.Name   = "UpdateCoins"
UpdateCoins.Parent = ReplicatedStorage

local HitConfirmed = Instance.new("RemoteEvent")
HitConfirmed.Name   = "HitConfirmed"
HitConfirmed.Parent = ReplicatedStorage

-- โฟลเดอร์เก็บ Dummy ใน Workspace
local dummiesFolder = Instance.new("Folder")
dummiesFolder.Name   = "Dummies"
dummiesFolder.Parent = Workspace

-- ข้อมูลผู้เล่น
local playerCoins   = {}  -- [player] = จำนวนเหรียญ
local playerDummies = {}  -- [player] = dummy model
local dummyDead     = {}  -- [dummy]  = กำลัง respawn อยู่
local dummyMaxHP    = {}  -- [dummy]  = max HP (dynamic ตาม upgrade)

-- ============================================================
--  HP Bar
-- ============================================================
local function buildHPBar(dummy, maxHP)
    local root = dummy:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name        = "HPBar"
    billboard.Size        = UDim2.new(0, 130, 0, 18)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = false
    billboard.Parent      = root

    local bg = Instance.new("Frame")
    bg.Name              = "BG"
    bg.Size              = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3  = Color3.fromRGB(40, 40, 40)
    bg.BorderSizePixel   = 0
    bg.Parent            = billboard
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 4)

    local bar = Instance.new("Frame")
    bar.Name             = "Bar"
    bar.Size             = UDim2.new(1, 0, 1, 0)
    bar.BackgroundColor3 = Color3.fromRGB(210, 40, 40)
    bar.BorderSizePixel  = 0
    bar.Parent           = bg
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

    local label = Instance.new("TextLabel")
    label.Name               = "HPText"
    label.Size               = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text               = maxHP .. " / " .. maxHP
    label.TextColor3         = Color3.new(1, 1, 1)
    label.TextScaled         = true
    label.Font               = Enum.Font.GothamBold
    label.ZIndex             = 2
    label.Parent             = bg
end

local function updateHPBar(dummy, hp, maxHP)
    local root = dummy:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local billboard = root:FindFirstChild("HPBar")
    if not billboard then return end
    local bg    = billboard:FindFirstChild("BG")
    if not bg   then return end

    local bar   = bg:FindFirstChild("Bar")
    local label = bg:FindFirstChild("HPText")
    local pct   = math.clamp(hp / maxHP, 0, 1)
    if bar   then bar.Size   = UDim2.new(pct, 0, 1, 0) end
    if label then label.Text = hp .. " / " .. maxHP    end
end

-- ============================================================
--  Spawn Dummy ที่ตำแหน่ง "Spawn dummy" ใน plot
-- ============================================================
local function spawnDummy(player, plot)
    print("[DummyServer] spawnDummy สำหรับ", player.Name)

    local model = ReplicatedStorage:FindFirstChild("DummyModel")
    if not model then
        warn("[DummyServer] ไม่พบ 'DummyModel' ใน ReplicatedStorage")
        return
    end

    local spawnPart = plot:FindFirstChild("Spawn dummy")
    if not spawnPart then
        warn("[DummyServer] ไม่พบ 'Spawn dummy' ใน plot ของ", player.Name)
        return
    end

    local dummy = model:Clone()
    dummy.Name = player.Name .. "_Dummy"

    -- ใช้ PivotTo แทน SetPrimaryPartCFrame (ไม่ต้องการ PrimaryPart)
    dummy.Parent = dummiesFolder
    dummy:PivotTo(spawnPart.CFrame)

    local maxHP    = PlayerStats.getDummyMaxHP(player)
    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.MaxHealth = maxHP
        humanoid.Health    = maxHP
        print("[DummyServer] Dummy HP ตั้งเป็น", maxHP)
    else
        warn("[DummyServer] ไม่พบ Humanoid ใน DummyModel")
    end

    local root = dummy:FindFirstChild("HumanoidRootPart")
    print("[DummyServer] HumanoidRootPart:", root and "พบ" or "ไม่พบ")

    buildHPBar(dummy, maxHP)
    dummyMaxHP[dummy]     = maxHP
    playerDummies[player] = dummy
    dummyDead[dummy]      = false
    print("[DummyServer] Dummy spawn สำเร็จ:", dummy.Name)
end

-- ============================================================
--  Hit Animation
-- ============================================================
local function playHitAnim(dummy, punchIndex)
    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator        = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local anim       = Instance.new("Animation")
    anim.AnimationId = CONFIG.HIT_ANIMS[punchIndex] or CONFIG.HIT_ANIMS[1]

    local track      = animator:LoadAnimation(anim)
    track.Priority   = Enum.AnimationPriority.Action
    track:Play()
end

local function getNearestShopNPC(origin)
    local nearestNPC
    local nearestRoot
    local nearestDistance

    for _, candidate in Workspace:GetChildren() do
        if candidate:IsA("Model") and candidate.Name == "ShopNPC" then
            local humanoid = candidate:FindFirstChildOfClass("Humanoid")
            local root = candidate:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and root then
                local distance = (origin - root.Position).Magnitude
                if distance <= CONFIG.ATTACK_RANGE and (not nearestDistance or distance < nearestDistance) then
                    nearestNPC = candidate
                    nearestRoot = root
                    nearestDistance = distance
                end
            end
        end
    end

    return nearestNPC, nearestRoot, nearestDistance
end

local function getNearestEnemy(origin)
    local nearestEnemy
    local nearestRoot
    local nearestDistance

    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, candidate in enemiesFolder:GetChildren() do
            if candidate:IsA("Model") then
                local humanoid = candidate:FindFirstChildOfClass("Humanoid")
                local root = candidate:FindFirstChild("HumanoidRootPart")
                if humanoid and humanoid.Health > 0 and root then
                    local distance = (origin - root.Position).Magnitude
                    if distance <= CONFIG.ATTACK_RANGE and (not nearestDistance or distance < nearestDistance) then
                        nearestEnemy = candidate
                        nearestRoot = root
                        nearestDistance = distance
                    end
                end
            end
        end
    end

    return nearestEnemy, nearestRoot, nearestDistance
end

local function retaliateShopNPC(player, npc, playerRoot)
    local character = player.Character
    if not character then return end

    local playerHumanoid = character:FindFirstChildOfClass("Humanoid")
    if not playerHumanoid or playerHumanoid.Health <= 0 then return end

    playerRoot.AssemblyLinearVelocity = Vector3.new(0, 1000, 0)

    task.delay(0.5, function()
        if not playerHumanoid.Parent or playerHumanoid.Health <= 0 then return end

        local creatorTag = playerHumanoid:FindFirstChild("creator")
        if creatorTag then
            creatorTag:Destroy()
        end

        creatorTag = Instance.new("ObjectValue")
        creatorTag.Name = "creator"
        creatorTag.Value = npc
        creatorTag.Parent = playerHumanoid

        task.delay(2, function()
            if creatorTag.Parent then
                creatorTag:Destroy()
            end
        end)

        playerHumanoid.Health = 0
    end)
end

-- ============================================================
--  Players
-- ============================================================
-- Dummy spawn หลังจาก PlotManager assign plot แล้ว
PlotManager.PlotAssigned.Event:Connect(function(player, plot)
    print("[DummyServer] PlotAssigned fired สำหรับ", player.Name, "| plot:", plot.Name)
    playerCoins[player] = 0
    UpdateCoins:FireClient(player, 0)
    PlayerStats.init(player)
    spawnDummy(player, plot)
end)

-- เชื่อม BindableFunction กับ UpgradeServer
local ServerScriptService = game:GetService("ServerScriptService")
task.defer(function()
    local GetCoins = script.Parent:WaitForChild("GetCoins", 10)
    local SetCoins = script.Parent:WaitForChild("SetCoins", 10)
    if GetCoins then
        GetCoins.OnInvoke = function(player) return playerCoins[player] or 0 end
    end
    if SetCoins then
        SetCoins.OnInvoke = function(player, amount) playerCoins[player] = amount end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local dummy = playerDummies[player]
    if dummy then dummy:Destroy() end
    playerDummies[player] = nil
    playerCoins[player]   = nil
    PlayerStats.cleanup(player)
end)

-- ============================================================
--  Attack Handler
-- ============================================================
AttackDummy.OnServerEvent:Connect(function(player, punchIndex, isRSkill)
    local character  = player.Character
    if not character then return end
    local playerRoot = character:FindFirstChild("HumanoidRootPart")
    if not playerRoot then return end

    local dummy = playerDummies[player]
    local dummyRoot = dummy and dummy:FindFirstChild("HumanoidRootPart")
    local dummyDistance
    if dummy and not dummyDead[dummy] and dummyRoot then
        dummyDistance = (playerRoot.Position - dummyRoot.Position).Magnitude
        if dummyDistance > CONFIG.ATTACK_RANGE then
            dummyDistance = nil
        end
    end

    local shopNPC, _, shopDistance = getNearestShopNPC(playerRoot.Position)
    local enemy, _, enemyDistance = getNearestEnemy(playerRoot.Position)

    local target = nil
    local targetType = nil
    local minDistance = math.huge

    if dummyDistance then
        target = dummy
        targetType = "Dummy"
        minDistance = dummyDistance
    end

    if shopDistance and shopDistance < minDistance then
        target = shopNPC
        targetType = "ShopNPC"
        minDistance = shopDistance
    end

    if enemyDistance and enemyDistance < minDistance then
        target = enemy
        targetType = "Enemy"
        minDistance = enemyDistance
    end

    if not target then
        return
    end

    if targetType == "ShopNPC" then
        retaliateShopNPC(player, target, playerRoot)
        return
    elseif targetType == "Enemy" then
        local humanoid = target:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end
        
        local damage, isCrit = PlayerStats.rollDamage(player)
        local prevHP = humanoid.Health
        humanoid:TakeDamage(damage)
        local actualDmg = math.min(prevHP, damage)
        HitConfirmed:FireClient(player, punchIndex, actualDmg, isCrit, target)

        if prevHP > 0 and humanoid.Health <= 0 then
            playerCoins[player] = (playerCoins[player] or 0) + (CONFIG.COINS_PER_KILL * 5)
            UpdateCoins:FireClient(player, playerCoins[player], CONFIG.COINS_PER_KILL * 5)
        end
        return
    end

    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local damage, isCrit = PlayerStats.rollDamage(player)
    if isRSkill then damage = math.floor(damage * 3) end
    local prevHP = humanoid.Health
    humanoid:TakeDamage(damage)
    local newHP  = humanoid.Health
    local maxHP  = dummyMaxHP[dummy] or humanoid.MaxHealth

    updateHPBar(dummy, math.ceil(newHP), maxHP)
    playHitAnim(dummy, punchIndex)

    -- แจ้ง client (เสียง + damage text + crit flag)
    local actualDmg = math.min(prevHP, damage)
    HitConfirmed:FireClient(player, punchIndex, actualDmg, isCrit, dummy)

    if prevHP > 0 and newHP <= 0 then
        dummyDead[dummy] = true
        playerDummies[player] = nil

        playerCoins[player] = (playerCoins[player] or 0) + CONFIG.COINS_PER_KILL
        UpdateCoins:FireClient(player, playerCoins[player], CONFIG.COINS_PER_KILL)

        task.delay(2, function()
            if not dummy or not dummy.Parent then return end

            dummyMaxHP[dummy] = nil
            dummy:Destroy()
        end)

        task.delay(2 + CONFIG.DUMMY_RESPAWN, function()
            if not player.Parent then
                print("[DummyServer] Player left, skip respawn")
                return
            end

            local plot = PlotManager.getPlot(player)
            if not plot then
                warn("[DummyServer] No plot found for respawn")
                return
            end

            print("[DummyServer] Respawning dummy for", player.Name)
            spawnDummy(player, plot)
        end)
    end
end)
