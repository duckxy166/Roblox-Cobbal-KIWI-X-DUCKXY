local Players           = game:GetService("Players")
local Debris            = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- ── CONFIG ────────────────────────────────────────────────────
local SPAWN_COOLDOWN  = 8     -- seconds between spawns per player
local AGGRO_RANGE     = 80    -- studs to start chasing
local ATTACK_RANGE    = 5     -- studs to deal damage
local ATTACK_DAMAGE   = 15
local ATTACK_COOLDOWN = 1.5
local ENEMY_MAX_HP    = 300
local RESPAWN_DELAY   = 6

local NPC_STATS = {
    ["Creature of Calamity"] = { hp = 500, damage = 25, speed = 14 },
    ["Dark Zombie"]          = { hp = 200, damage = 10, speed = 10 },
    ["Fallen God"]           = { hp = 800, damage = 40, speed = 12 },
    ["Retro Virus"]          = { hp = 150, damage = 8,  speed = 16 },
    ["Vantablack Shadow"]    = { hp = 350, damage = 20, speed = 18 },
    ["Void Creep"]           = { hp = 450, damage = 30, speed = 13 },
}
-- ─────────────────────────────────────────────────────────────

local templates = ReplicatedStorage:FindFirstChild("EnemyTemplates")
    or ServerStorage:FindFirstChild("EnemyTemplates")

if not templates then
    templates = ReplicatedStorage:WaitForChild("EnemyTemplates", 5)
        or ServerStorage:WaitForChild("EnemyTemplates", 5)
end

if not templates then
    warn("[EnemyServer] EnemyTemplates folder not found in ReplicatedStorage or ServerStorage")
end
local enemiesFolder = workspace:FindFirstChild("Enemies")
if not enemiesFolder then
    enemiesFolder = Instance.new("Folder")
    enemiesFolder.Name   = "Enemies"
    enemiesFolder.Parent = workspace
end

local spawnCooldowns = {}  -- [player] = last spawn tick

-- ── HP Bar ────────────────────────────────────────────────────
local function buildHPBar(enemy, maxHP, label)
    local root = enemy:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local bb = Instance.new("BillboardGui")
    bb.Name         = "HPBar"
    bb.Size         = UDim2.new(0, 150, 0, 40)
    bb.StudsOffset  = Vector3.new(0, 4.5, 0)
    bb.AlwaysOnTop  = false
    bb.Parent       = root

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
    bar.BackgroundColor3 = Color3.fromRGB(220, 45, 45)
    bar.BorderSizePixel  = 0
    bar.Parent           = bg
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

    local nameTag = Instance.new("TextLabel")
    nameTag.Size                 = UDim2.new(1, 0, 0.5, 0)
    nameTag.BackgroundTransparency = 1
    nameTag.Text                 = label
    nameTag.TextColor3           = Color3.fromRGB(255, 200, 200)
    nameTag.TextScaled           = true
    nameTag.Font                 = Enum.Font.GothamBold
    nameTag.TextStrokeTransparency = 0.5
    nameTag.Parent               = bb

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

local function updateHPBar(enemy, hp, maxHP)
    local root = enemy:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local bb = root:FindFirstChild("HPBar")
    if not bb  then return end
    local bg = bb:FindFirstChild("BG")
    if not bg  then return end
    local bar  = bg:FindFirstChild("Bar")
    local txt  = bg:FindFirstChild("HPText")
    local pct  = math.clamp(hp / maxHP, 0, 1)
    if bar then bar.Size  = UDim2.new(pct, 0, 1, 0) end
    if txt then txt.Text  = math.ceil(hp) .. " / " .. maxHP end
end

-- ── Unanchor all parts so NPC can move ───────────────────────
local function prepareForMovement(enemy)
    for _, part in ipairs(enemy:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Anchored  = false
            part.CanCollide = false
        end
    end
    local root = enemy:FindFirstChild("HumanoidRootPart")
    if root then
        root.Anchored   = false
        root.CanCollide = true
    end
end

-- ── Spawn one enemy NPC ───────────────────────────────────────
local function spawnEnemy(templateName, spawnCFrame)
    local template = templates:FindFirstChild(templateName)
    if not template then
        warn("[EnemyServer] Template not found:", templateName)
        return
    end

    local stats   = NPC_STATS[templateName] or { hp = ENEMY_MAX_HP, damage = ATTACK_DAMAGE, speed = 12 }
    local enemy   = template:Clone()
    enemy.Name    = templateName
    enemy.Parent  = enemiesFolder

    prepareForMovement(enemy)
    enemy:PivotTo(spawnCFrame * CFrame.new(0, 4, 0))

    local humanoid = enemy:FindFirstChildOfClass("Humanoid")
    local rootPart = enemy:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then
        warn("[EnemyServer] NPC missing Humanoid or HumanoidRootPart:", templateName)
        enemy:Destroy()
        return
    end

    humanoid.MaxHealth = stats.hp
    humanoid.Health    = stats.hp
    humanoid.WalkSpeed = stats.speed

    buildHPBar(enemy, stats.hp, templateName)

    -- Track HP changes
    humanoid.HealthChanged:Connect(function(hp)
        updateHPBar(enemy, hp, stats.hp)
    end)

    local lastAttack = 0

    -- ── AI Loop ──────────────────────────────────────────────
    task.spawn(function()
        while enemy.Parent and humanoid.Health > 0 do
            local nearest, nearestDist = nil, AGGRO_RANGE

            for _, p in ipairs(Players:GetPlayers()) do
                local char = p.Character
                if char then
                    local pRoot = char:FindFirstChild("HumanoidRootPart")
                    local pHum  = char:FindFirstChildOfClass("Humanoid")
                    if pRoot and pHum and pHum.Health > 0 then
                        local dist = (rootPart.Position - pRoot.Position).Magnitude
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
                            targetHum:TakeDamage(stats.damage)
                        end
                    end
                end
            end

            task.wait(0.15)
        end

        -- Death sequence
        task.wait(0.2)
        for _, part in ipairs(enemy:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = false
            elseif part:IsA("Motor6D") then
                part:Destroy()
            end
        end
        Debris:AddItem(enemy, 4)
    end)
end

-- ── MiddleFloor trigger ───────────────────────────────────────
local middleFloor = workspace:WaitForChild("MiddleFloor")

local allNames = {}
for name in pairs(NPC_STATS) do
    table.insert(allNames, name)
end

local touchDebounce = {}

middleFloor.Touched:Connect(function(hit)
    local character = hit.Parent
    local player    = Players:GetPlayerFromCharacter(character)
    if not player then return end
    if touchDebounce[player] then return end

    -- Cooldown
    local now = tick()
    if spawnCooldowns[player] and (now - spawnCooldowns[player]) < SPAWN_COOLDOWN then return end

    -- Check if enemies already alive
    local aliveCount = 0
    for _, e in ipairs(enemiesFolder:GetChildren()) do
        local h = e:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then aliveCount = aliveCount + 1 end
    end
    if aliveCount >= 3 then return end

    touchDebounce[player] = true
    spawnCooldowns[player] = now

    -- Pick a random NPC
    local chosenName = allNames[math.random(1, #allNames)]
    local spawnCF    = middleFloor.CFrame * CFrame.new(
        math.random(-20, 20), 0, math.random(-20, 20)
    )
    spawnEnemy(chosenName, spawnCF)

    task.delay(2, function()
        touchDebounce[player] = nil
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    spawnCooldowns[p] = nil
    touchDebounce[p]  = nil
end)
