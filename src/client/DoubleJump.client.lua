-- DoubleJump.client.lua
-- Double jump with cool animation and VFX

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

local CONFIG = {
    DOUBLE_JUMP_COST     = 20,
    JUMP_FORCE           = 50,
    MAX_JUMPS            = 2,
    COOLDOWN             = 0.5,
}

local jumpCount     = 0
local lastJumpTime  = 0
local wasGrounded   = true

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
--  VFX: Jump Burst (ring expanding from feet)
-- ============================================================
local function createJumpBurst(isDouble)
    local color = isDouble and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(100, 255, 100)
    local size = isDouble and 8 or 4
    local thickness = isDouble and 0.5 or 0.3

    local burst = Instance.new("Part")
    burst.Anchored    = true
    burst.CanCollide  = false
    burst.Transparency = 0.3
    burst.Size        = Vector3.new(thickness, size, size)
    burst.CFrame      = rootPart.CFrame * CFrame.Angles(0, 0, math.rad(90))
    burst.Material    = Enum.Material.Neon
    burst.Color       = color
    burst.Parent      = workspace

    TweenService:Create(burst, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(thickness, size * 2.5, size * 2.5),
        Transparency = 1,
    }):Play()
    Debris:AddItem(burst, 0.5)

    local burst2 = burst:Clone()
    burst2.CFrame = rootPart.CFrame * CFrame.Angles(math.rad(90), 0, 0)
    TweenService:Create(burst2, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(thickness, size * 2, size * 2),
        Transparency = 1,
    }):Play()
    Debris:AddItem(burst2, 0.5)
end

-- ============================================================
--  VFX: Trail particles during jump
-- ============================================================
local function createJumpTrail()
    local trail = Instance.new("Part")
    trail.Anchored    = true
    trail.CanCollide  = false
    trail.Transparency = 1
    trail.Size        = Vector3.new(0.5, 0.5, 0.5)
    trail.CFrame      = rootPart.CFrame * CFrame.new(0, -2, 0)
    trail.Parent      = workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture       = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color         = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 200, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 255, 200)),
    }
    emitter.Size          = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 0),
    }
    emitter.Transparency  = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    }
    emitter.Lifetime      = NumberRange.new(0.3, 0.6)
    emitter.Rate          = 50
    emitter.Speed         = NumberRange.new(5, 15)
    emitter.SpreadAngle   = Vector2.new(60, 60)
    emitter.Parent        = trail

    task.delay(0.3, function()
        emitter.Enabled = false
    end)
    Debris:AddItem(trail, 0.8)
end

-- ============================================================
--  VFX: Shockwave ring
-- ============================================================
local function createShockwave()
    local ring = Instance.new("Part")
    ring.Anchored    = true
    ring.CanCollide  = false
    ring.Transparency = 0.4
    ring.Shape       = Enum.PartType.Cylinder
    ring.Size        = Vector3.new(0.2, 3, 3)
    ring.CFrame      = rootPart.CFrame * CFrame.new(0, -2, 0) * CFrame.Angles(0, 0, math.rad(90))
    ring.Material    = Enum.Material.Neon
    ring.Color       = Color3.fromRGB(0, 200, 255)
    ring.Parent      = workspace

    TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.2, 15, 15),
        Transparency = 1,
    }):Play()
    Debris:AddItem(ring, 0.6)
end

-- ============================================================
--  VFX: Energy sphere around player
-- ============================================================
local function createEnergyAura()
    local sphere = Instance.new("Part")
    sphere.Anchored    = true
    sphere.CanCollide  = false
    sphere.Transparency = 0.6
    sphere.Shape       = Enum.PartType.Ball
    sphere.Size        = Vector3.new(4, 4, 4)
    sphere.CFrame      = rootPart.CFrame
    sphere.Material    = Enum.Material.Neon
    sphere.Color       = Color3.fromRGB(0, 200, 255)
    sphere.Parent      = workspace

    TweenService:Create(sphere, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(6, 6, 6),
        Transparency = 1,
    }):Play()
    Debris:AddItem(sphere, 0.4)
end

-- ============================================================
--  Animation: Character pose during jump
-- ============================================================
local function playJumpPose(isDouble)
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    local jumpAnim = Instance.new("Animation")
    jumpAnim.AnimationId = "rbxassetid://507770239" -- Default jump animation

    local track = animator:LoadAnimation(jumpAnim)
    track.Priority = Enum.AnimationPriority.Action
    track.Looped = false

    if isDouble then
        track.Speed = 1.5
        createEnergyAura()
        createShockwave()
    else
        track.Speed = 1
        createJumpBurst(false)
    end

    track:Play()

    task.delay(0.3, function()
        track:Stop(0.2)
    end)
end

-- Double jump logic (only fires when already in the air)
local function doJump()
    local inAir = humanoid.FloorMaterial == Enum.Material.Air
    if not inAir then return end           -- first jump handled by Humanoid normally
    if jumpCount >= CONFIG.MAX_JUMPS then return end

    local now = tick()
    if now - lastJumpTime < 0.1 then return end -- debounce

    local stamina = getStamina()
    if stamina < CONFIG.DOUBLE_JUMP_COST then return end
    setStamina(stamina - CONFIG.DOUBLE_JUMP_COST)

    jumpCount = jumpCount + 1
    lastJumpTime = now

    createJumpBurst(true)
    createJumpTrail()
    createEnergyAura()
    createShockwave()

    rootPart.AssemblyLinearVelocity = Vector3.new(
        rootPart.AssemblyLinearVelocity.X,
        CONFIG.JUMP_FORCE,
        rootPart.AssemblyLinearVelocity.Z
    )

    playJumpPose(true)
end

-- Track leaving ground to allow one double jump per airtime
RunService.Heartbeat:Connect(function()
    local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
    if grounded then
        jumpCount = 0
        wasGrounded = true
    elseif wasGrounded then
        -- just left the ground (normal jump happened)
        jumpCount = 1
        wasGrounded = false
        lastJumpTime = tick()
        createJumpBurst(false)
    end
end)

-- Input handling
UserInputService.JumpRequest:Connect(function()
    doJump()
end)

-- ============================================================
--  Respawn handling
-- ============================================================
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid  = newChar:WaitForChild("Humanoid")
    rootPart  = newChar:WaitForChild("HumanoidRootPart")
    jumpCount = 0
end)
