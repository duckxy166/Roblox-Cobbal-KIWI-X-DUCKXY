-- MainHUD.client.lua (Replaces old CoinsUI)
-- Shows Money, HP/Stamina, and control hints: Press F, Right Click, Shift

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local player = Players.LocalPlayer

-- ─── UI Setup ──────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "MainHUD"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.IgnoreGuiInset = true
screenGui.Parent       = player:WaitForChild("PlayerGui")

-- ─── Money UI (Top Right) ──────────────────────────────────────────────
local moneyFrame = Instance.new("Frame")
moneyFrame.Name                  = "MoneyFrame"
moneyFrame.Size                  = UDim2.new(0, 200, 0, 46)
moneyFrame.Position              = UDim2.new(1, -220, 0, 20)
moneyFrame.BackgroundColor3      = Color3.fromRGB(15, 15, 20)
moneyFrame.BackgroundTransparency = 0.4
moneyFrame.BorderSizePixel       = 0
moneyFrame.Parent                = screenGui

local moneyStroke = Instance.new("UIStroke")
moneyStroke.Color = Color3.fromRGB(255, 255, 255)
moneyStroke.Transparency = 0.8
moneyStroke.Thickness = 1.5
moneyStroke.Parent = moneyFrame

Instance.new("UICorner", moneyFrame).CornerRadius = UDim.new(0, 8)

local moneyIcon = Instance.new("TextLabel")
moneyIcon.Size = UDim2.new(0, 46, 0, 46)
moneyIcon.BackgroundTransparency = 1
moneyIcon.Text = "💰"
moneyIcon.TextScaled = true
moneyIcon.Font = Enum.Font.GothamBold
moneyIcon.Parent = moneyFrame

local iconPad = Instance.new("UIPadding")
iconPad.PaddingTop = UDim.new(0, 8)
iconPad.PaddingBottom = UDim.new(0, 8)
iconPad.Parent = moneyIcon

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Size                = UDim2.new(1, -56, 1, 0)
moneyLabel.Position            = UDim2.new(0, 46, 0, 0)
moneyLabel.BackgroundTransparency = 1
moneyLabel.Text                = "0"
moneyLabel.TextColor3          = Color3.fromRGB(255, 220, 50)
moneyLabel.TextScaled          = true
moneyLabel.TextXAlignment      = Enum.TextXAlignment.Left
moneyLabel.Font                = Enum.Font.GothamBold
moneyLabel.Parent              = moneyFrame

local labelPad = Instance.new("UIPadding")
labelPad.PaddingTop = UDim.new(0, 10)
labelPad.PaddingBottom = UDim.new(0, 10)
labelPad.Parent = moneyLabel

-- ─── Helper Functions ──────────────────────────────────────────────────
local function formatNumber(n)
    if n >= 1000000 then return string.format("%.1fM", n/1000000)
    elseif n >= 1000 then return string.format("%.1fK", n/1000)
    else return tostring(n) end
end

local function showRewardText(text, color)
    local rewardLabel = Instance.new("TextLabel")
    rewardLabel.Size               = UDim2.new(0, 200, 0, 40)
    rewardLabel.Position           = UDim2.new(1, -220, 0, 70)
    rewardLabel.BackgroundTransparency = 1
    rewardLabel.Text               = text
    rewardLabel.TextColor3         = color
    rewardLabel.TextScaled         = true
    rewardLabel.Font               = Enum.Font.GothamBlack
    rewardLabel.TextStrokeTransparency = 0.2
    rewardLabel.TextStrokeColor3   = Color3.fromRGB(0, 0, 0)
    rewardLabel.Parent             = screenGui

    TweenService:Create(rewardLabel,
        TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(1, -220, 0, 110) }):Play()
    TweenService:Create(rewardLabel,
        TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5),
        { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

    Debris:AddItem(rewardLabel, 1.5)
end

-- ─── Update Money ──────────────────────────────────────────────────────
local UpdateCoins = ReplicatedStorage:WaitForChild("UpdateCoins")
UpdateCoins.OnClientEvent:Connect(function(coins, reward)
    moneyLabel.Text = formatNumber(coins)
    if reward and reward > 0 then
        showRewardText("+" .. formatNumber(reward), Color3.fromRGB(255, 220, 50))
    end
end)

-- ─── HP & Stamina Bars (Top Left) ──────────────────────────────────────
local statsContainer = Instance.new("Frame")
statsContainer.Name = "StatsContainer"
statsContainer.Size = UDim2.new(0, 280, 0, 60)
statsContainer.Position = UDim2.new(0, 20, 0, 20)
statsContainer.BackgroundTransparency = 1
statsContainer.Parent = screenGui

local function createBar(name, color, order, yPos)
    local frame = Instance.new("Frame")
    frame.Name = name .. "Frame"
    frame.Size = UDim2.new(1, 0, 0, 20)
    frame.Position = UDim2.new(0, 0, 0, yPos)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    frame.BackgroundTransparency = 0.4
    frame.BorderSizePixel = 0
    frame.Parent = statsContainer
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.8
    stroke.Thickness = 1.5
    stroke.Parent = frame

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.Parent = frame
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)
    
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150))
    })
    gradient.Parent = fill

    local lbl = Instance.new("TextLabel")
    lbl.Name = "Label"
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.Position = UDim2.new(0, 5, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name .. " 100 / 100"
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.TextStrokeTransparency = 0.5
    lbl.ZIndex = 2
    lbl.Parent = frame
    
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 3)
    pad.PaddingBottom = UDim.new(0, 3)
    pad.Parent = lbl

    return fill, lbl
end

local hpFill, hpLabel = createBar("HP", Color3.fromRGB(220, 40, 40), 1, 0)
local stamFill, stamLabel = createBar("STAMINA", Color3.fromRGB(50, 200, 100), 2, 28)

-- HP Logic
local function updateHealth(humanoid)
    local max = humanoid.MaxHealth
    local cur = humanoid.Health
    local pct = math.clamp(cur / max, 0, 1)
    
    TweenService:Create(hpFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
    hpLabel.Text = string.format("HP %d / %d", math.floor(cur), max)

    if pct > 0.5 then hpFill.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
    elseif pct > 0.25 then hpFill.BackgroundColor3 = Color3.fromRGB(200, 100, 20)
    else hpFill.BackgroundColor3 = Color3.fromRGB(150, 0, 0) end
end

local function setupCharacter(char)
    local humanoid = char:WaitForChild("Humanoid")
    updateHealth(humanoid)
    humanoid.HealthChanged:Connect(function() updateHealth(humanoid) end)
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

-- Stamina Logic
local function updateStamina(current, max)
    local pct = math.clamp(current / max, 0, 1)
    TweenService:Create(stamFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
    stamLabel.Text = string.format("STAMINA %d / %d", math.floor(current), max)

    if pct > 0.5 then stamFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    elseif pct > 0.25 then stamFill.BackgroundColor3 = Color3.fromRGB(230, 180, 0)
    else stamFill.BackgroundColor3 = Color3.fromRGB(220, 50, 50) end
end

task.defer(function()
    local attempts = 0
    while not _G.StaminaState and attempts < 100 do
        task.wait(0.1)
        attempts += 1
    end
    if _G.StaminaState then
        _G.StaminaState.onChange = updateStamina
        updateStamina(_G.StaminaState.current, _G.StaminaState.max)
    end
end)

-- ─── Controls Hints UI (Bottom Right) ──────────────────────────────────
local hintsContainer = Instance.new("Frame")
hintsContainer.Name = "HintsContainer"
hintsContainer.Size = UDim2.new(0, 250, 0, 160)
hintsContainer.Position = UDim2.new(1, -270, 1, -200)
hintsContainer.BackgroundTransparency = 1
hintsContainer.Parent = screenGui

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = hintsContainer

local function createHint(text, order)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 30)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    frame.BackgroundTransparency = 0.4
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(200, 200, 200)
    stroke.Transparency = 0.7
    stroke.Thickness = 1
    stroke.Parent = frame
    
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.Parent = frame
    
    return frame
end

-- Create the specific hints
local hint1 = createHint("[1], [2] - Weapons", 1)
local hint2 = createHint("[F] - Open Seed Shop", 2)
local hint3 = createHint("[C] - Web Shooter", 3)
local hint4 = createHint("[Shift] - Dash", 4)

hint1.Parent = hintsContainer
hint2.Parent = hintsContainer
hint3.Parent = hintsContainer
hint4.Parent = hintsContainer
