-- CoinsUI.client.lua
-- แสดงเหรียญที่มุมล่างซ้าย

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local player = Players.LocalPlayer

-- สร้าง UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "CoinsUI"
screenGui.ResetOnSpawn = false
screenGui.Parent       = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size                  = UDim2.new(0, 160, 0, 50)
frame.Position              = UDim2.new(0, 16, 1, -66)
frame.BackgroundColor3      = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.3
frame.BorderSizePixel       = 0
frame.Parent                = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent       = frame

local label = Instance.new("TextLabel")
label.Size                = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text                = "$ 0"
label.TextColor3          = Color3.fromRGB(255, 215, 0)
label.TextScaled          = true
label.Font                = Enum.Font.GothamBold
label.Parent              = frame

local function showRewardText(text, color)
    local rewardLabel = Instance.new("TextLabel")
    rewardLabel.Size               = UDim2.new(0, 200, 0, 40)
    rewardLabel.Position           = UDim2.new(0, 16, 1, -120)
    rewardLabel.BackgroundTransparency = 1
    rewardLabel.Text               = text
    rewardLabel.TextColor3         = color
    rewardLabel.TextScaled         = true
    rewardLabel.Font               = Enum.Font.GothamBold
    rewardLabel.TextStrokeTransparency = 0.5
    rewardLabel.Parent             = screenGui

    TweenService:Create(rewardLabel,
        TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 16, 1, -160) }):Play()
    TweenService:Create(rewardLabel,
        TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5),
        { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

    Debris:AddItem(rewardLabel, 1.5)
end

-- รับ update จาก server
local UpdateCoins = ReplicatedStorage:WaitForChild("UpdateCoins")
UpdateCoins.OnClientEvent:Connect(function(coins, reward)
    label.Text = "$ " .. coins
    if reward and reward > 0 then
        showRewardText("+ $" .. reward, Color3.fromRGB(255, 215, 0))
    end
end)
