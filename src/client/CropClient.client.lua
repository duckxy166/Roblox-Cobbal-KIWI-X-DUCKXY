-- CropClient.client.lua
-- Client-side UI for selecting and planting seeds on the player's plot.
-- Press F to open seed picker, click a seed to plant it.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PlantSeed  = ReplicatedStorage:WaitForChild("PlantSeed")
local CropSeeds  = ReplicatedStorage:WaitForChild("CropSeeds")

-- ── Seed Picker UI ───────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "CropSeedPicker"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 25
screenGui.Parent       = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name                  = "SeedFrame"
mainFrame.Size                  = UDim2.new(0, 320, 0, 340)
mainFrame.Position              = UDim2.new(0.5, -160, 0.5, -170)
mainFrame.BackgroundColor3      = Color3.fromRGB(20, 30, 20)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel       = 0
mainFrame.Visible               = false
mainFrame.Parent                = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke")
stroke.Color       = Color3.fromRGB(80, 180, 80)
stroke.Thickness   = 2
stroke.Transparency = 0.3
stroke.Parent      = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Name                  = "Title"
title.Size                  = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text                  = "Plant a Seed (F)"
title.TextColor3            = Color3.fromRGB(120, 255, 120)
title.TextScaled            = true
title.Font                  = Enum.Font.GothamBold
title.Parent                = mainFrame

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name                  = "Close"
closeBtn.Size                  = UDim2.new(0, 30, 0, 30)
closeBtn.Position              = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3      = Color3.fromRGB(180, 50, 50)
closeBtn.Text                  = "X"
closeBtn.TextColor3            = Color3.new(1, 1, 1)
closeBtn.Font                  = Enum.Font.GothamBold
closeBtn.TextSize              = 16
closeBtn.Parent                = mainFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Scroll frame for seeds
local scroll = Instance.new("ScrollingFrame")
scroll.Name                    = "SeedList"
scroll.Size                    = UDim2.new(1, -20, 1, -50)
scroll.Position                = UDim2.new(0, 10, 0, 45)
scroll.BackgroundTransparency  = 1
scroll.ScrollBarThickness      = 4
scroll.CanvasSize              = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize     = Enum.AutomaticSize.Y
scroll.Parent                  = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.Name
listLayout.Padding   = UDim.new(0, 6)
listLayout.Parent    = scroll

-- ── Build seed buttons ───────────────────────────────────────
local SEED_COLORS = {
    ["Eggplant Seed"]   = Color3.fromRGB(100, 50, 150),
    ["Blueberry Seed"]  = Color3.fromRGB(50, 80, 180),
    ["Carrot Seed"]     = Color3.fromRGB(220, 130, 30),
    ["Bamboo Seed"]     = Color3.fromRGB(80, 160, 60),
    ["Watermelon Seed"] = Color3.fromRGB(40, 160, 80),
}

for _, seed in ipairs(CropSeeds:GetChildren()) do
    local btn = Instance.new("TextButton")
    btn.Name                  = seed.Name
    btn.Size                  = UDim2.new(1, 0, 0, 50)
    btn.BackgroundColor3      = SEED_COLORS[seed.Name] or Color3.fromRGB(60, 120, 60)
    btn.BackgroundTransparency = 0.2
    btn.Text                  = seed.Name
    btn.TextColor3            = Color3.new(1, 1, 1)
    btn.TextScaled            = true
    btn.Font                  = Enum.Font.GothamBold
    btn.Parent                = scroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function()
        print("[CropClient] Planting:", seed.Name)
        PlantSeed:FireServer(seed.Name)
        mainFrame.Visible = false
    end)
end

-- ── Toggle UI ────────────────────────────────────────────────
closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

-- Refresh character
player.CharacterAdded:Connect(function()
    -- UI persists (ResetOnSpawn = false)
end)
