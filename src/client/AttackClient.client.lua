-- AttackClient.client.lua
-- ระบบโจมตี 3 จังหวะ (Combo)

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local animator  = humanoid:WaitForChild("Animator")

-- ============================================================
--  CONFIG  (แก้ค่าตรงนี้ได้เลย)
-- ============================================================
local CONFIG = {
    ANIMATION_ID  = "rbxassetid://103216657138627",
    COMBO_WINDOW   = 0.2,  -- วินาทีที่รอให้กดต่อ combo ก่อน reset
    COMBO_COOLDOWN = 0.5,  -- คูลดาวน์หลังจบ combo 3 จังหวะ

    -- เฟรม → วินาที (60 FPS)
    SEGMENTS = {
        { startTime = 0  / 60, endTime = 20 / 60, sound = "rbxassetid://132504023010884" },
        { startTime = 20 / 60, endTime = 55 / 60, sound = "rbxassetid://98954842300721"  },
        { startTime = 55 / 60, endTime = 79 / 60, sound = "rbxassetid://112581434421666" },
    },
}
-- ============================================================

local animInstance = Instance.new("Animation")
animInstance.AnimationId = CONFIG.ANIMATION_ID

local track = animator:LoadAnimation(animInstance)
track.Priority = Enum.AnimationPriority.Action

-- โหลดเสียงล่วงหน้า
local sounds = {}
for i, seg in CONFIG.SEGMENTS do
    local sound = Instance.new("Sound")
    sound.SoundId = seg.sound
    sound.Parent  = workspace
    sounds[i] = sound
end


local TweenService  = game:GetService("TweenService")
local Debris        = game:GetService("Debris")

local AttackDummy       = ReplicatedStorage:WaitForChild("AttackDummy")
local HitConfirmed      = ReplicatedStorage:WaitForChild("HitConfirmed")
local SyncStats         = ReplicatedStorage:WaitForChild("SyncStats")

-- ============================================================
--  Stamina State
-- ============================================================
local stamina = {
    current      = 100,
    max          = 100,
    regen        = 10,
    cost         = 5,
    onChange     = nil,   -- callback สำหรับ UI
}

SyncStats.OnClientEvent:Connect(function(stats)
    stamina.max     = stats.maxStamina
    stamina.regen   = stats.staminaRegen
    stamina.cost    = stats.staminaCost
    stamina.current = math.min(stamina.current, stamina.max)
    if stamina.onChange then stamina.onChange(stamina.current, stamina.max) end
end)

RunService.Heartbeat:Connect(function(dt)
    if stamina.current < stamina.max then
        stamina.current = math.min(stamina.max, stamina.current + stamina.regen * dt)
        if stamina.onChange then stamina.onChange(stamina.current, stamina.max) end
    end
end)

-- export ให้ StaminaUI ใช้
_G.StaminaState = stamina
local hitEffectTemplate = ReplicatedStorage:WaitForChild("hit effect")
local dummiesFolder     = workspace:WaitForChild("Dummies")

local function getDummy()
    return dummiesFolder:FindFirstChild(player.Name .. "_Dummy")
end

local function showFloatingText(position, text, color)
    local part = Instance.new("Part")
    part.Anchored     = true
    part.CanCollide   = false
    part.Transparency = 1
    part.Size         = Vector3.new(1, 1, 1)
    part.Position     = position
    part.Parent       = workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Size        = UDim2.new(0, 100, 0, 40)
    billboard.StudsOffset = Vector3.new(math.random(-1, 1), 2, 0)
    billboard.Parent      = part

    local label = Instance.new("TextLabel")
    label.Size               = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text               = text
    label.TextColor3         = color
    label.TextScaled         = true
    label.Font               = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0.5
    label.Parent             = billboard

    TweenService:Create(part, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = position + Vector3.new(0, 4, 0) }):Play()
    TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.3),
        { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

    Debris:AddItem(part, 1.2)
end

local function spawnHitEffect(target)
    if not target then return end

    local torso = target:FindFirstChild("Torso") or target:FindFirstChild("UpperTorso")
    if not torso then return end

    local effect = hitEffectTemplate:Clone()

    -- ย้าย effect ไปที่ตำแหน่ง Torso ก่อน parent
    if effect:IsA("BasePart") then
        effect.CFrame = torso.CFrame
        effect.Parent = torso
    elseif effect:IsA("Model") then
        effect.Parent = workspace
        if effect.PrimaryPart then
            effect:PivotTo(torso.CFrame)
        else
            -- หา Part แรกแล้วย้าย
            local part = effect:FindFirstChildOfClass("BasePart")
            if part then
                effect:PivotTo(CFrame.new(torso.Position))
            end
        end
    else
        effect.Parent = torso
    end

    -- Emit ParticleEmitter ถ้ามี
    for _, obj in effect:GetDescendants() do
        if obj:IsA("ParticleEmitter") then
            obj:Emit(obj.Rate > 0 and math.ceil(obj.Rate * 0.1) or 10)
        end
    end

    game:GetService("Debris"):AddItem(effect, 2)
end

local isAttacking  = false
local comboQueued  = false
local comboIndex   = 0

local function runCombo()
    isAttacking = true

    while true do
        local seg = CONFIG.SEGMENTS[comboIndex]
        comboQueued = false

        -- เล่น segment ที่ถูกต้อง
        if not track.IsPlaying then
            track:Play(0)
            task.wait()
        end
        track.TimePosition = seg.startTime

        -- หักสตามิน่า
        stamina.current = math.max(0, stamina.current - stamina.cost)
        if stamina.onChange then stamina.onChange(stamina.current, stamina.max) end

        -- แจ้ง server ว่าโจมตีด้วย punch ไหน
        AttackDummy:FireServer(comboIndex)

        task.wait(seg.endTime - seg.startTime)

        -- หยุด animation ไว้ก่อน
        track:AdjustSpeed(0)

        -- จบ punch สุดท้าย → reset
        if comboIndex >= #CONFIG.SEGMENTS then break end

        -- รอ combo window
        local deadline = tick() + CONFIG.COMBO_WINDOW
        repeat
            task.wait(0.016)
        until comboQueued or tick() >= deadline

        if not comboQueued then break end

        -- กดต่อ → เล่นต่อ
        track:AdjustSpeed(1)

        comboIndex += 1
    end

    local finishedFullCombo = comboIndex >= #CONFIG.SEGMENTS
    track:Stop(0.2)

    if finishedFullCombo then
        task.wait(CONFIG.COMBO_COOLDOWN)
    end

    isAttacking = false
    comboIndex  = 0
end

-- เล่นเสียง + effect + damage text
HitConfirmed.OnClientEvent:Connect(function(punchIndex, damage, isCrit, target)
    local sound = sounds[punchIndex]
    if sound then sound:Play() end
    spawnHitEffect(target)

    if target then
        local torso = target:FindFirstChild("Torso") or target:FindFirstChild("UpperTorso")
        if torso then
            if isCrit then
                showFloatingText(torso.Position, "CRIT! -" .. damage, Color3.fromRGB(255, 170, 0))
            else
                showFloatingText(torso.Position, "-" .. damage, Color3.fromRGB(255, 60, 60))
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

    if not isAttacking then
        if stamina.current < stamina.cost then return end  -- สตามิน่าไม่พอ
        comboIndex = 1
        task.spawn(runCombo)
    elseif comboIndex < #CONFIG.SEGMENTS then
        comboQueued = true
    end
end)
