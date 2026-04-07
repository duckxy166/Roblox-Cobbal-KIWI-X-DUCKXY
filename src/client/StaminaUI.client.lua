-- StaminaUI.client.lua
-- แสดง Stamina Bar ล่างซ้าย

local Players    = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui    = Instance.new("ScreenGui")
gui.Name            = "StaminaUI"
gui.ResetOnSpawn    = false
gui.Parent          = player:WaitForChild("PlayerGui")

-- กรอบ background
local frame = Instance.new("Frame")
frame.Size              = UDim2.new(0, 160, 0, 14)
frame.Position          = UDim2.new(0, 16, 1, -90)   -- เหนือ coins
frame.BackgroundColor3  = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel   = 0
frame.Parent            = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)

-- แถบสตามิน่า
local bar = Instance.new("Frame")
bar.Name            = "Bar"
bar.Size            = UDim2.new(1, 0, 1, 0)
bar.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
bar.BorderSizePixel = 0
bar.Parent          = frame
Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

-- label "Stamina"
local label = Instance.new("TextLabel")
label.Size               = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text               = "Stamina"
label.TextColor3         = Color3.new(1, 1, 1)
label.TextScaled         = true
label.Font               = Enum.Font.GothamBold
label.ZIndex             = 2
label.Parent             = frame

-- อัพเดต bar จาก StaminaState
local function updateBar(current, max)
    local pct = math.clamp(current / max, 0, 1)
    TweenService:Create(bar, TweenInfo.new(0.1), { Size = UDim2.new(pct, 0, 1, 0) }):Play()

    -- เปลี่ยนสีตาม %
    if pct > 0.5 then
        bar.BackgroundColor3 = Color3.fromRGB(50, 200, 100)   -- เขียว
    elseif pct > 0.25 then
        bar.BackgroundColor3 = Color3.fromRGB(230, 180, 0)    -- เหลือง
    else
        bar.BackgroundColor3 = Color3.fromRGB(220, 50, 50)    -- แดง
    end
end

-- รอ StaminaState จาก AttackClient
task.defer(function()
    local attempts = 0
    while not _G.StaminaState and attempts < 100 do
        task.wait(0.1)
        attempts += 1
    end
    if _G.StaminaState then
        _G.StaminaState.onChange = updateBar
        updateBar(_G.StaminaState.current, _G.StaminaState.max)
    end
end)
