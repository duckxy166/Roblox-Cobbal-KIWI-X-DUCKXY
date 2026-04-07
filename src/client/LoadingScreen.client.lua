-- LoadingScreen.client.lua

local Players         = game:GetService("Players")
local TweenService    = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui    = Instance.new("ScreenGui")
gui.Name            = "LoadingScreen"
gui.ResetOnSpawn    = false
gui.DisplayOrder    = 999
gui.IgnoreGuiInset  = true
gui.Parent          = player:WaitForChild("PlayerGui")

-- พื้นหลังดำ
local bg = Instance.new("Frame")
bg.Size             = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
bg.BorderSizePixel  = 0
bg.Parent           = gui

-- ชื่อเกม
local title = Instance.new("TextLabel")
title.Size               = UDim2.new(0, 400, 0, 60)
title.Position           = UDim2.new(0.5, -200, 0.35, 0)
title.BackgroundTransparency = 1
title.Text               = "MyGame"
title.TextColor3         = Color3.new(1, 1, 1)
title.TextScaled         = true
title.Font               = Enum.Font.GothamBold
title.Parent             = bg

-- กล่อง progress bar
local barBG = Instance.new("Frame")
barBG.Size             = UDim2.new(0, 400, 0, 16)
barBG.Position         = UDim2.new(0.5, -200, 0.55, 0)
barBG.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
barBG.BorderSizePixel  = 0
barBG.Parent           = bg
Instance.new("UICorner", barBG).CornerRadius = UDim.new(1, 0)

-- แถบ progress
local bar = Instance.new("Frame")
bar.Size             = UDim2.new(0, 0, 1, 0)
bar.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
bar.BorderSizePixel  = 0
bar.Parent           = barBG
Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

-- % text
local pctLabel = Instance.new("TextLabel")
pctLabel.Size               = UDim2.new(0, 400, 0, 30)
pctLabel.Position           = UDim2.new(0.5, -200, 0.62, 0)
pctLabel.BackgroundTransparency = 1
pctLabel.Text               = "0%"
pctLabel.TextColor3         = Color3.fromRGB(180, 180, 180)
pctLabel.TextScaled         = true
pctLabel.Font               = Enum.Font.Gotham
pctLabel.Parent             = bg

-- ปุ่ม Skip
local skipBtn = Instance.new("TextButton")
skipBtn.Size               = UDim2.new(0, 120, 0, 36)
skipBtn.Position           = UDim2.new(0.5, -60, 0.72, 0)
skipBtn.BackgroundColor3   = Color3.fromRGB(60, 60, 60)
skipBtn.Text               = "Skip"
skipBtn.TextColor3         = Color3.new(1, 1, 1)
skipBtn.TextScaled         = true
skipBtn.Font               = Enum.Font.GothamBold
skipBtn.BorderSizePixel    = 0
skipBtn.Parent             = bg
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 8)

-- ============================================================
local DURATION = 5  -- วินาที
local skipped  = false

local function closeScreen()
    local tween = TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
    for _, obj in bg:GetDescendants() do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            TweenService:Create(obj, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
        end
        if obj:IsA("Frame") then
            TweenService:Create(obj, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
        end
    end
    tween:Play()
    tween.Completed:Wait()
    gui:Destroy()
end

skipBtn.MouseButton1Click:Connect(function()
    skipped = true
end)

-- รัน progress
local start = tick()
while not skipped do
    local elapsed = tick() - start
    local pct     = math.clamp(elapsed / DURATION, 0, 1)

    bar.Size      = UDim2.new(pct, 0, 1, 0)
    pctLabel.Text = math.floor(pct * 100) .. "%"

    if pct >= 1 then break end
    task.wait(0.05)
end

bar.Size      = UDim2.new(1, 0, 1, 0)
pctLabel.Text = "100%"
task.wait(0.3)

closeScreen()
