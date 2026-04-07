-- GrapplingHook.client.lua
-- Spider-Man style grappling hook: right-click to shoot, hold to swing, release to fly

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local Debris           = game:GetService("Debris")

local player    = Players.LocalPlayer
local camera    = workspace.CurrentCamera
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

-- ============================================================
--  CONFIG
-- ============================================================
local CONFIG = {
    MAX_RANGE        = 200,   -- max raycast distance (studs)
    GRAVITY          = 196.2, -- Roblox default workspace gravity
    SWING_DAMPING    = 0.995, -- velocity damping per frame (1 = no damping)
    LAUNCH_SPEED     = 80,    -- speed boost toward anchor on attach
    COOLDOWN         = 0.3,
    ROPE_COLOR       = Color3.fromRGB(0, 220, 255),
    ANCHOR_COLOR     = Color3.fromRGB(255, 240, 80),
}

-- ============================================================
--  State
-- ============================================================
local isGrappling  = false
local anchorPoint  = nil   -- Vector3 fixed in world space
local ropeLength   = 0     -- fixed rope length = distance at attach time
local anchorPart   = nil
local ropePart     = nil
local lastCastTime = 0
local bv           = nil   -- BodyVelocity used during swing

-- ============================================================
--  VFX helpers
-- ============================================================
local function createAnchorSphere(pos)
    local sphere = Instance.new("Part")
    sphere.Anchored   = true
    sphere.CanCollide = false
    sphere.Shape      = Enum.PartType.Ball
    sphere.Size       = Vector3.new(0.6, 0.6, 0.6)
    sphere.CFrame     = CFrame.new(pos)
    sphere.Material   = Enum.Material.Neon
    sphere.Color      = CONFIG.ANCHOR_COLOR
    sphere.Parent     = workspace

    TweenService:Create(sphere, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(1.4, 1.4, 1.4),
    }):Play()
    return sphere
end

local function createRopePart()
    local rope = Instance.new("Part")
    rope.Anchored    = true
    rope.CanCollide  = false
    rope.Material    = Enum.Material.Neon
    rope.Color       = CONFIG.ROPE_COLOR
    rope.CastShadow  = false
    rope.Transparency = 0.15
    rope.Parent      = workspace
    return rope
end

local function updateRope()
    if not ropePart or not anchorPoint then return end
    local origin = rootPart.Position
    local diff   = anchorPoint - origin
    local dist   = diff.Magnitude
    if dist < 0.1 then return end
    ropePart.Size   = Vector3.new(0.07, 0.07, dist)
    ropePart.CFrame = CFrame.new(origin + diff * 0.5, anchorPoint)
end

local function destroyRope()
    if bv and bv.Parent then bv:Destroy() end
    bv = nil
    if ropePart then ropePart:Destroy(); ropePart = nil end
    if anchorPart then
        TweenService:Create(anchorPart, TweenInfo.new(0.18), {
            Size = Vector3.new(0, 0, 0),
            Transparency = 1,
        }):Play()
        Debris:AddItem(anchorPart, 0.2)
        anchorPart = nil
    end
end

local function createDetachBurst(pos)
    local ring = Instance.new("Part")
    ring.Anchored     = true
    ring.CanCollide   = false
    ring.Transparency = 0.3
    ring.Shape        = Enum.PartType.Cylinder
    ring.Size         = Vector3.new(0.15, 2, 2)
    ring.CFrame       = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
    ring.Material     = Enum.Material.Neon
    ring.Color        = CONFIG.ROPE_COLOR
    ring.Parent       = workspace
    TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.15, 12, 12),
        Transparency = 1,
    }):Play()
    Debris:AddItem(ring, 0.35)
end

local function createShootTrail(origin, target)
    local diff = target - origin
    local dist = diff.Magnitude
    local t = Instance.new("Part")
    t.Anchored    = true
    t.CanCollide  = false
    t.Material    = Enum.Material.Neon
    t.Color       = CONFIG.ROPE_COLOR
    t.Transparency = 0.1
    t.Size        = Vector3.new(0.05, 0.05, dist)
    t.CFrame      = CFrame.new(origin + diff * 0.5, target)
    t.Parent      = workspace
    TweenService:Create(t, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(0.01, 0.01, dist),
    }):Play()
    Debris:AddItem(t, 0.2)
end

-- ============================================================
--  Grapple attach / detach
-- ============================================================
local function attachGrapple()
    if isGrappling then return end
    local now = tick()
    if now - lastCastTime < CONFIG.COOLDOWN then return end
    lastCastTime = now

    local mousePos = UserInputService:GetMouseLocation()
    local ray      = camera:ScreenPointToRay(mousePos.X, mousePos.Y)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { character }

    local result = workspace:Raycast(ray.Origin, ray.Direction * CONFIG.MAX_RANGE, rayParams)
    if not result then return end

    anchorPoint = result.Position
    ropeLength  = (anchorPoint - rootPart.Position).Magnitude
    isGrappling = true

    -- Shoot trail flash
    createShootTrail(rootPart.Position, anchorPoint)

    -- Rope + anchor appear after trail
    task.delay(0.12, function()
        if not isGrappling then return end
        anchorPart = createAnchorSphere(anchorPoint)
        ropePart   = createRopePart()
    end)

    -- BodyVelocity takes over physics during swing
    bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent   = rootPart

    -- Launch toward anchor preserving full 3D momentum
    local toAnchor   = (anchorPoint - rootPart.Position).Unit
    local currentVel = rootPart.AssemblyLinearVelocity
    local launchVel  = currentVel + toAnchor * CONFIG.LAUNCH_SPEED
    bv.Velocity = launchVel
end

local function detachGrapple()
    if not isGrappling then return end
    isGrappling = false

    -- Release: keep whatever velocity was built up so player flies free
    local releaseVel = bv and bv.Velocity or rootPart.AssemblyLinearVelocity
    destroyRope()

    -- Apply momentum after BodyVelocity removed
    task.defer(function()
        if rootPart and rootPart.Parent then
            rootPart.AssemblyLinearVelocity = releaseVel
        end
    end)

    createDetachBurst(rootPart.Position)
    anchorPoint = nil
    ropeLength  = 0
end

-- ============================================================
--  Swing physics (Heartbeat) — true pendulum constraint
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
    if not isGrappling or not anchorPoint or not bv or not bv.Parent then return end

    updateRope()

    local pos    = rootPart.Position
    local toAnchor = anchorPoint - pos
    local dist   = toAnchor.Magnitude

    if dist < 1.5 then
        detachGrapple()
        return
    end

    local vel = bv.Velocity

    -- 1. Apply gravity manually (since BodyVelocity suppresses it)
    vel = vel + Vector3.new(0, -CONFIG.GRAVITY * dt, 0)

    -- 2. Rope constraint: enforce fixed rope length with vector physics
    local ropeDir = toAnchor.Unit    -- direction from player toward anchor
    
    -- Calculate stretch beyond rope length
    local stretch = dist - ropeLength
    if stretch > 0 then
        -- Apply corrective force vector toward anchor
        local correctionForce = ropeDir * (stretch * 200 * dt)
        vel = vel + correctionForce
    end

    -- Remove radial velocity component (away from anchor) to maintain rope constraint
    local radialVel = vel:Dot(ropeDir)
    if radialVel < 0 then
        vel = vel - ropeDir * radialVel
    end

    -- 3. Slight damping to prevent infinite energy buildup
    vel = vel * CONFIG.SWING_DAMPING

    bv.Velocity = vel
end)

-- ============================================================
--  Input
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.C then
        attachGrapple()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.C then
        detachGrapple()
    end
end)

-- ============================================================
--  Respawn handling
-- ============================================================
player.CharacterAdded:Connect(function(newChar)
    character   = newChar
    humanoid    = newChar:WaitForChild("Humanoid")
    rootPart    = newChar:WaitForChild("HumanoidRootPart")
    isGrappling = false
    anchorPoint = nil
    ropeLength  = 0
    destroyRope()
end)
