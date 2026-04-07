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
    DASH_DISTANCE  = 30,
    DASH_DURATION  = 0.2,
    STAMINA_COST   = 15,
    COOLDOWN       = 0.5,
}

local canDash      = true
local isDashing    = false

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

local function createDashTrail()
    local attachment0 = Instance.new("Attachment")
    attachment0.Parent = rootPart
    
    local attachment1 = Instance.new("Attachment")
    attachment1.Parent = rootPart
    
    local trail = Instance.new("Trail")
    trail.Attachment0 = attachment0
    trail.Attachment1 = attachment1
    trail.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 200, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 150, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 100, 200))
    }
    trail.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1)
    }
    trail.Lifetime = 0.3
    trail.MinLength = 0
    trail.WidthScale = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0)
    }
    trail.Parent = rootPart
    
    Debris:AddItem(attachment0, 1)
    Debris:AddItem(attachment1, 1)
    Debris:AddItem(trail, 1)
    
    return trail
end

local function createSpeedLines()
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Size = Vector3.new(1, 1, 1)
    part.CFrame = rootPart.CFrame
    part.Parent = workspace
    
    local particleEmitter = Instance.new("ParticleEmitter")
    particleEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particleEmitter.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255))
    particleEmitter.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 0)
    }
    particleEmitter.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    }
    particleEmitter.Lifetime = NumberRange.new(0.2, 0.4)
    particleEmitter.Rate = 100
    particleEmitter.Speed = NumberRange.new(20, 30)
    particleEmitter.SpreadAngle = Vector2.new(30, 30)
    particleEmitter.Enabled = true
    particleEmitter.Parent = part
    
    task.delay(0.2, function()
        particleEmitter.Enabled = false
    end)
    
    Debris:AddItem(part, 1)
end

local function cameraShake()
    local camera = workspace.CurrentCamera
    local originalCF = camera.CFrame
    
    for i = 1, 5 do
        local shake = CFrame.Angles(
            math.rad(math.random(-2, 2)),
            math.rad(math.random(-2, 2)),
            math.rad(math.random(-2, 2))
        )
        camera.CFrame = camera.CFrame * shake
        task.wait(0.02)
    end
end

local function createDashEffect()
    local effect = Instance.new("Part")
    effect.Anchored = true
    effect.CanCollide = false
    effect.Size = Vector3.new(4, 4, 0.5)
    effect.CFrame = rootPart.CFrame
    effect.Material = Enum.Material.Neon
    effect.Color = Color3.fromRGB(100, 200, 255)
    effect.Transparency = 0.5
    effect.Parent = workspace
    
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = effect
    
    TweenService:Create(effect, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(8, 8, 1)
    }):Play()
    
    Debris:AddItem(effect, 0.5)
end

local function dash()
    if not canDash or isDashing then return end
    
    local currentStamina = getStamina()
    if currentStamina < CONFIG.STAMINA_COST then return end
    
    setStamina(currentStamina - CONFIG.STAMINA_COST)
    
    isDashing = true
    canDash   = false
    
    local camera = workspace.CurrentCamera
    local direction = camera.CFrame.LookVector
    direction = Vector3.new(direction.X, 0, direction.Z).Unit
    
    if direction.Magnitude == 0 then
        direction = rootPart.CFrame.LookVector
        direction = Vector3.new(direction.X, 0, direction.Z).Unit
    end
    
    local startPos = rootPart.Position
    local targetPos = startPos + (direction * CONFIG.DASH_DISTANCE)
    local lookAtTarget = CFrame.lookAt(startPos, startPos + direction)
    
    createDashEffect()
    createDashTrail()
    createSpeedLines()
    task.spawn(cameraShake)
    
    local originalC0 = rootPart:FindFirstChild("RootJoint") and rootPart.RootJoint.C0 or CFrame.new()
    local tiltAngle = math.rad(15)
    
    if rootPart:FindFirstChild("RootJoint") then
        local tiltTween = TweenService:Create(
            rootPart.RootJoint,
            TweenInfo.new(CONFIG.DASH_DURATION * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { C0 = originalC0 * CFrame.Angles(tiltAngle, 0, 0) }
        )
        tiltTween:Play()
        
        task.delay(CONFIG.DASH_DURATION * 0.5, function()
            local resetTween = TweenService:Create(
                rootPart.RootJoint,
                TweenInfo.new(CONFIG.DASH_DURATION * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { C0 = originalC0 }
            )
            resetTween:Play()
        end)
    end
    
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
    bodyVelocity.Velocity = direction * (CONFIG.DASH_DISTANCE / CONFIG.DASH_DURATION)
    bodyVelocity.Parent = rootPart
    
    task.delay(CONFIG.DASH_DURATION, function()
        bodyVelocity:Destroy()
        isDashing = false
        createDashEffect()
    end)
    
    task.delay(CONFIG.COOLDOWN, function()
        canDash = true
    end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        dash()
    end
end)

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid  = newChar:WaitForChild("Humanoid")
    rootPart  = newChar:WaitForChild("HumanoidRootPart")
    canDash   = true
    isDashing = false
end)
