-- RSkill.client.lua
-- R Skill: Ground Slam with cool VFX + camera shake + shockwave

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")
local animator  = humanoid:WaitForChild("Animator")

-- ============================================================
--  CONFIG
-- ============================================================
local CONFIG = {
    COOLDOWN       = 8,
    STAMINA_COST   = 30,
    JUMP_HEIGHT    = 40,
    SLAM_DELAY     = 0.4,
    SHOCKWAVE_SIZE = 50,
    DAMAGE_RANGE   = 20,
}

local canUseR   = true
local isUsingR  = false

-- ============================================================
--  Stamina helpers
-- ============================================================
local function getStamina()
    return _G.StaminaState and _G.StaminaState.current or 100
end

local function setStamina(value)
    if _G.StaminaState then
        _G.StaminaState.current = value
        if _G.StaminaState.onChange then
            _G.StaminaState.onChange(_G.StaminaState.current, _G.StaminaState.max)
        end
    end
end

-- ============================================================
--  VFX: Charge Aura (rising energy around player)
-- ============================================================
local function createChargeAura()
    local aura = Instance.new("Part")
    aura.Anchored    = true
    aura.CanCollide  = false
    aura.Transparency = 0.6
    aura.Shape       = Enum.PartType.Cylinder
    aura.Size        = Vector3.new(0.5, 6, 6)
    aura.CFrame      = rootPart.CFrame * CFrame.Angles(0, 0, math.rad(90))
    aura.Material    = Enum.Material.Neon
    aura.Color       = Color3.fromRGB(255, 80, 30)
    aura.Parent      = workspace

    TweenService:Create(aura, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.5, 14, 14),
        Transparency = 1,
    }):Play()

    Debris:AddItem(aura, 0.5)

    local particles = Instance.new("Part")
    particles.Anchored    = true
    particles.CanCollide  = false
    particles.Transparency = 1
    particles.Size        = Vector3.new(1, 1, 1)
    particles.CFrame      = rootPart.CFrame
    particles.Parent      = workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture       = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color         = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 30)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 40, 0)),
    }
    emitter.Size          = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 1.5),
        NumberSequenceKeypoint.new(1, 0),
    }
    emitter.Transparency  = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    }
    emitter.Lifetime      = NumberRange.new(0.3, 0.6)
    emitter.Rate          = 200
    emitter.Speed         = NumberRange.new(10, 25)
    emitter.SpreadAngle   = Vector2.new(360, 360)
    emitter.Parent        = particles

    task.delay(0.35, function()
        emitter.Enabled = false
    end)
    Debris:AddItem(particles, 1)
end

-- ============================================================
--  VFX: Shockwave ring on ground
-- ============================================================
local function createShockwave(pos)
    local ring = Instance.new("Part")
    ring.Anchored    = true
    ring.CanCollide  = false
    ring.Transparency = 0.4
    ring.Shape       = Enum.PartType.Cylinder
    ring.Size        = Vector3.new(0.3, 4, 4)
    ring.CFrame      = CFrame.new(pos.X, pos.Y - 2, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
    ring.Material    = Enum.Material.Neon
    ring.Color       = Color3.fromRGB(255, 100, 0)
    ring.Parent      = workspace

    TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.3, CONFIG.SHOCKWAVE_SIZE, CONFIG.SHOCKWAVE_SIZE),
        Transparency = 1,
    }):Play()
    Debris:AddItem(ring, 0.6)

    local ring2 = Instance.new("Part")
    ring2.Anchored    = true
    ring2.CanCollide  = false
    ring2.Transparency = 0.5
    ring2.Shape       = Enum.PartType.Cylinder
    ring2.Size        = Vector3.new(0.3, 4, 4)
    ring2.CFrame      = CFrame.new(pos.X, pos.Y - 2, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
    ring2.Material    = Enum.Material.Neon
    ring2.Color       = Color3.fromRGB(255, 200, 50)
    ring2.Parent      = workspace

    TweenService:Create(ring2, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.3, CONFIG.SHOCKWAVE_SIZE * 0.6, CONFIG.SHOCKWAVE_SIZE * 0.6),
        Transparency = 1,
    }):Play()
    Debris:AddItem(ring2, 0.5)
end

-- ============================================================
--  VFX: Ground crack / impact
-- ============================================================
local function createImpact(pos)
    local sphere = Instance.new("Part")
    sphere.Anchored    = true
    sphere.CanCollide  = false
    sphere.Transparency = 0.3
    sphere.Shape       = Enum.PartType.Ball
    sphere.Size        = Vector3.new(4, 4, 4)
    sphere.CFrame      = CFrame.new(pos)
    sphere.Material    = Enum.Material.Neon
    sphere.Color       = Color3.fromRGB(255, 60, 0)
    sphere.Parent      = workspace

    TweenService:Create(sphere, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(20, 20, 20),
        Transparency = 1,
    }):Play()
    Debris:AddItem(sphere, 0.5)

    for i = 1, 8 do
        local debris = Instance.new("Part")
        debris.Anchored   = false
        debris.CanCollide = true
        debris.Size       = Vector3.new(
            math.random(10, 25) / 10,
            math.random(10, 25) / 10,
            math.random(10, 25) / 10
        )
        debris.CFrame     = CFrame.new(pos) * CFrame.new(math.random(-3, 3), 1, math.random(-3, 3))
        debris.Material   = Enum.Material.Slate
        debris.Color      = Color3.fromRGB(80, 70, 60)
        debris.Parent     = workspace

        local angle = (i / 8) * math.pi * 2
        debris.AssemblyLinearVelocity = Vector3.new(
            math.cos(angle) * math.random(20, 40),
            math.random(30, 60),
            math.sin(angle) * math.random(20, 40)
        )

        TweenService:Create(debris, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1), {
            Transparency = 1,
        }):Play()
        Debris:AddItem(debris, 3)
    end
end

-- ============================================================
--  VFX: Pillar of fire
-- ============================================================
local function createFirePillar(pos)
    local pillar = Instance.new("Part")
    pillar.Anchored    = true
    pillar.CanCollide  = false
    pillar.Transparency = 1
    pillar.Size        = Vector3.new(6, 1, 6)
    pillar.CFrame      = CFrame.new(pos)
    pillar.Parent      = workspace

    local fire = Instance.new("ParticleEmitter")
    fire.Texture       = "rbxasset://textures/particles/sparkles_main.dds"
    fire.Color         = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 20, 0)),
    }
    fire.Size          = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 3),
        NumberSequenceKeypoint.new(0.5, 5),
        NumberSequenceKeypoint.new(1, 0),
    }
    fire.Transparency  = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    }
    fire.Lifetime      = NumberRange.new(0.4, 0.8)
    fire.Rate          = 300
    fire.Speed         = NumberRange.new(30, 50)
    fire.SpreadAngle   = Vector2.new(10, 10)
    fire.Rotation      = NumberRange.new(0, 360)
    fire.Parent        = pillar

    task.delay(0.5, function()
        fire.Enabled = false
    end)
    Debris:AddItem(pillar, 2)
end

-- ============================================================
--  Camera: Heavy Shake
-- ============================================================
local function heavyCameraShake(intensity, duration)
    task.spawn(function()
        local camera = workspace.CurrentCamera
        local elapsed = 0
        while elapsed < duration do
            local dt = RunService.RenderStepped:Wait()
            elapsed = elapsed + dt
            local fade = 1 - (elapsed / duration)
            local rx = math.rad(math.random(-intensity, intensity) * fade)
            local ry = math.rad(math.random(-intensity, intensity) * fade)
            local rz = math.rad(math.random(-intensity, intensity) * fade * 0.5)
            camera.CFrame = camera.CFrame * CFrame.Angles(rx, ry, rz)
        end
    end)
end

-- ============================================================
--  Cooldown UI indicator
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name         = "RSkillUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent       = player:WaitForChild("PlayerGui")

local skillBtn = Instance.new("Frame")
skillBtn.Size              = UDim2.new(0, 54, 0, 54)
skillBtn.Position          = UDim2.new(0, 80, 1, -126)
skillBtn.BackgroundColor3  = Color3.fromRGB(15, 15, 20)
skillBtn.BackgroundTransparency = 0.4
skillBtn.BorderSizePixel   = 0
skillBtn.Parent            = gui
Instance.new("UICorner", skillBtn).CornerRadius = UDim.new(0, 8)

local skillStroke = Instance.new("UIStroke")
skillStroke.Color        = Color3.fromRGB(255, 100, 30)
skillStroke.Transparency = 0.6
skillStroke.Thickness    = 2
skillStroke.Parent       = skillBtn

local skillLabel = Instance.new("TextLabel")
skillLabel.Size                  = UDim2.new(1, 0, 1, 0)
skillLabel.BackgroundTransparency = 1
skillLabel.Text                  = "R"
skillLabel.TextColor3            = Color3.fromRGB(255, 120, 40)
skillLabel.TextScaled            = true
skillLabel.Font                  = Enum.Font.GothamBlack
skillLabel.Parent                = skillBtn

local skillPad = Instance.new("UIPadding")
skillPad.PaddingTop    = UDim.new(0, 10)
skillPad.PaddingBottom = UDim.new(0, 10)
skillPad.Parent        = skillLabel

local cdOverlay = Instance.new("Frame")
cdOverlay.Size              = UDim2.new(1, 0, 0, 0)
cdOverlay.Position          = UDim2.new(0, 0, 1, 0)
cdOverlay.AnchorPoint       = Vector2.new(0, 1)
cdOverlay.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
cdOverlay.BackgroundTransparency = 0.5
cdOverlay.BorderSizePixel   = 0
cdOverlay.Parent            = skillBtn
Instance.new("UICorner", cdOverlay).CornerRadius = UDim.new(0, 8)

local function showCooldown()
    cdOverlay.Size = UDim2.new(1, 0, 1, 0)
    skillLabel.TextColor3 = Color3.fromRGB(120, 60, 20)
    TweenService:Create(cdOverlay, TweenInfo.new(CONFIG.COOLDOWN, Enum.EasingStyle.Linear), {
        Size = UDim2.new(1, 0, 0, 0),
    }):Play()
    task.delay(CONFIG.COOLDOWN, function()
        skillLabel.TextColor3 = Color3.fromRGB(255, 120, 40)
    end)
end

-- ============================================================
--  R Skill: Ground Slam
-- ============================================================
local AttackDummy = ReplicatedStorage:WaitForChild("AttackDummy")
local RSkillHit   = ReplicatedStorage:WaitForChild("RSkillHit")

local function useRSkill()
    if not canUseR or isUsingR then return end

    local currentStamina = getStamina()
    if currentStamina < CONFIG.STAMINA_COST then return end

    setStamina(currentStamina - CONFIG.STAMINA_COST)

    isUsingR = true
    canUseR  = false
    showCooldown()

    -- Phase 1: Charge up (brief pause + aura)
    createChargeAura()

    -- Phase 2: Jump up
    rootPart.AssemblyLinearVelocity = Vector3.new(0, CONFIG.JUMP_HEIGHT, 0)

    task.wait(CONFIG.SLAM_DELAY)

    -- Phase 3: Slam down
    rootPart.AssemblyLinearVelocity = Vector3.new(0, -150, 0)

    -- Wait to land
    local landed = false
    local timeout = 0
    while not landed and timeout < 1.5 do
        local dt = task.wait(0.02)
        timeout = timeout + dt

        local rayOrigin = rootPart.Position
        local rayDirection = Vector3.new(0, -4, 0)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {character}
        local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
        if result then
            landed = true
        end
    end

    -- Phase 4: Impact
    local impactPos = rootPart.Position
    createShockwave(impactPos)
    createImpact(impactPos)
    createFirePillar(impactPos)
    heavyCameraShake(5, 0.4)

    -- Fire server attack: hits nearby dummy using same path as leftClick (x3 damage)
    AttackDummy:FireServer(3, true)
    -- Fire AOE hit: damages ALL void creatures within DAMAGE_RANGE
    RSkillHit:FireServer(impactPos)

    isUsingR = false

    task.delay(CONFIG.COOLDOWN, function()
        canUseR = true
    end)
end

-- ============================================================
--  Input
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.R then
        useRSkill()
    end
end)

-- ============================================================
--  Respawn handling
-- ============================================================
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid  = newChar:WaitForChild("Humanoid")
    rootPart  = newChar:WaitForChild("HumanoidRootPart")
    animator  = humanoid:WaitForChild("Animator")
    canUseR   = true
    isUsingR  = false
end)
