-- DaggerRain.client.lua
-- Po's Dagger (2.0) special: Press E to launch multiple daggers into the sky, then rain down on enemies

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local DaggerRainEvent = ReplicatedStorage:WaitForChild("DaggerRain")
local DaggerRainFeedback = ReplicatedStorage:WaitForChild("DaggerRainFeedback")

local DAGGER_COUNT = 7
local COOLDOWN     = 5
local lastUsed     = -COOLDOWN

local cooldownGui = nil
local cooldownLabel = nil

-- ── Cooldown UI ──────────────────────────────────────────────
local function buildCooldownUI()
    local sg = Instance.new("ScreenGui")
    sg.Name          = "DaggerRainCooldownUI"
    sg.ResetOnSpawn  = false
    sg.DisplayOrder  = 20
    sg.Parent        = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size                  = UDim2.new(0, 120, 0, 36)
    frame.Position              = UDim2.new(0.5, -60, 0, 80)
    frame.BackgroundColor3      = Color3.fromRGB(15, 15, 20)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel       = 0
    frame.Visible               = false
    frame.Parent                = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color       = Color3.fromRGB(255, 80, 80)
    stroke.Thickness   = 1.5
    stroke.Transparency = 0.4
    stroke.Parent      = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size                 = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3           = Color3.fromRGB(255, 180, 180)
    lbl.Font                 = Enum.Font.GothamBold
    lbl.TextSize             = 15
    lbl.Text                 = "🗡️ E: Dagger Rain"
    lbl.Parent               = frame

    cooldownGui   = frame
    cooldownLabel = lbl
end

local function showCooldown(remaining)
    if not cooldownGui then return end
    cooldownGui.Visible = true
    cooldownLabel.Text  = string.format("🗡️ Cooldown: %.1fs", remaining)
    task.delay(remaining, function()
        if cooldownGui then
            cooldownGui.Visible = false
            cooldownLabel.Text  = "🗡️ E: Dagger Rain"
        end
    end)
end

-- ── Dagger Projectile Visual ──────────────────────────────────
local function spawnDaggerVisual(originPos, targetPos, delay)
    task.delay(delay, function()
        local dagger = Instance.new("Part")
        dagger.Name          = "DaggerRainProjectile"
        dagger.Size          = Vector3.new(0.18, 2.2, 0.18)
        dagger.Material      = Enum.Material.Neon
        dagger.BrickColor    = BrickColor.new("Bright red")
        dagger.Anchored      = true
        dagger.CanCollide    = false
        dagger.CastShadow    = false
        dagger.CFrame        = CFrame.new(originPos) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
        dagger.Parent        = workspace

        -- Fire effect
        local fire = Instance.new("Fire")
        fire.Heat            = 4
        fire.Size            = 1
        fire.Color           = Color3.fromRGB(255, 40, 40)
        fire.SecondaryColor  = Color3.fromRGB(255, 180, 0)
        fire.Parent          = dagger

        -- Trail
        local a0 = Instance.new("Attachment", dagger)
        a0.Position = Vector3.new(0,  1.1, 0)
        local a1 = Instance.new("Attachment", dagger)
        a1.Position = Vector3.new(0, -1.1, 0)
        local trail = Instance.new("Trail", dagger)
        trail.Attachment0  = a0
        trail.Attachment1  = a1
        trail.Color        = ColorSequence.new(Color3.fromRGB(255, 40, 40), Color3.fromRGB(255, 200, 50))
        trail.Lifetime     = 0.25
        trail.MinLength    = 0
        trail.WidthScale   = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0)
        })

        -- Phase 1: launch up
        local peakPos = originPos + Vector3.new(
            math.random(-4, 4),
            math.random(22, 32),
            math.random(-4, 4)
        )
        TweenService:Create(dagger, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            CFrame = CFrame.new(peakPos) * CFrame.Angles(math.pi / 2, 0, 0)
        }):Play()

        task.wait(0.45)

        -- Phase 2: rain down toward target
        TweenService:Create(dagger, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            CFrame = CFrame.new(targetPos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, 0)
        }):Play()

        task.wait(0.3)

        -- Impact ring
        local ring = Instance.new("Part")
        ring.Size              = Vector3.new(1, 0.1, 1)
        ring.Anchored          = true
        ring.CanCollide        = false
        ring.Material          = Enum.Material.Neon
        ring.BrickColor        = BrickColor.new("Bright red")
        ring.CFrame            = CFrame.new(targetPos + Vector3.new(0, 0.1, 0))
        ring.Parent            = workspace

        TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size         = Vector3.new(7, 0.1, 7),
            Transparency = 1
        }):Play()

        Debris:AddItem(ring,   0.4)
        Debris:AddItem(dagger, 0)
    end)
end

-- ── Launch ───────────────────────────────────────────────────
local function launchDaggerRain()
    local now = tick()
    local elapsed = now - lastUsed
    if elapsed < COOLDOWN then
        showCooldown(COOLDOWN - elapsed)
        return
    end
    if (_G.EquippedWeapon or "") ~= "Po's Dagger (2.0)" then return end

    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    lastUsed = now

    -- Tell server to deal damage and get back target positions
    DaggerRainEvent:FireServer()

    -- Spawn visuals: circle of daggers around player
    local origin = root.Position
    for i = 1, DAGGER_COUNT do
        local angle  = (i / DAGGER_COUNT) * math.pi * 2
        local radius = math.random(4, 9)
        local spawn  = origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        -- rain toward nearby area with slight scatter
        local land   = origin + Vector3.new(
            math.cos(angle + math.random() * 0.5) * math.random(2, 6),
            0,
            math.sin(angle + math.random() * 0.5) * math.random(2, 6)
        )
        spawnDaggerVisual(spawn, land, (i - 1) * 0.07)
    end
end

-- ── Input ────────────────────────────────────────────────────
buildCooldownUI()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.E then
        launchDaggerRain()
    end
end)

-- Refresh character reference on respawn
player.CharacterAdded:Connect(function(char)
    character = char
end)
