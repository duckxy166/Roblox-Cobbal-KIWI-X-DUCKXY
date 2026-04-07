-- UpgradeUI.client.lua

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player      = Players.LocalPlayer
local StatsConfig    = require(ReplicatedStorage:WaitForChild("StatsConfig"))
local SyncStats      = ReplicatedStorage:WaitForChild("SyncStats")
local UpgradeRequest = ReplicatedStorage:WaitForChild("UpgradeRequest")
local UpdateCoins    = ReplicatedStorage:WaitForChild("UpdateCoins")

local currentCoins = 0

-- ============================================================
--  State
-- ============================================================
local stats = {
    damage = StatsConfig.DAMAGE, critChance = StatsConfig.CRIT_CHANCE,
    maxStamina = StatsConfig.MAX_STAMINA, staminaRegen = StatsConfig.STAMINA_REGEN,
    damageLevel = 0, critLevel = 0, staminaLevel = 0, regenLevel = 0, dummyHpLevel = 0,
}

-- ============================================================
--  Upgrade Definitions
-- ============================================================
local UPGRADES = {
    {
        id = "damage", name = "Attack Power",
        current = function() return tostring(stats.damage) end,
        next    = function() return tostring(stats.damage + StatsConfig.DAMAGE_PER_UPGRADE) end,
        cost    = function() return math.floor(StatsConfig.DAMAGE_UPGRADE_COST * StatsConfig.UPGRADE_COST_MULT ^ stats.damageLevel) end,
    },
    {
        id = "critChance", name = "Critical Hit",
        current = function() return stats.critChance .. "%" end,
        next    = function() return (stats.critChance + StatsConfig.CRIT_PER_UPGRADE) .. "%" end,
        cost    = function() return math.floor(StatsConfig.CRIT_UPGRADE_COST * StatsConfig.UPGRADE_COST_MULT ^ stats.critLevel) end,
    },
    {
        id = "maxStamina", name = "Max Stamina",
        current = function() return tostring(stats.maxStamina) end,
        next    = function() return tostring(stats.maxStamina + StatsConfig.STAMINA_PER_UPGRADE) end,
        cost    = function() return math.floor(StatsConfig.STAMINA_UPGRADE_COST * StatsConfig.UPGRADE_COST_MULT ^ stats.staminaLevel) end,
    },
    {
        id = "staminaRegen", name = "Stamina Regen",
        current = function() return stats.staminaRegen .. "/s" end,
        next    = function() return (stats.staminaRegen + StatsConfig.REGEN_PER_UPGRADE) .. "/s" end,
        cost    = function() return math.floor(StatsConfig.REGEN_UPGRADE_COST * StatsConfig.UPGRADE_COST_MULT ^ stats.regenLevel) end,
    },
    {
        id = "dummyHP", name = "Dummy HP",
        current = function() return tostring(StatsConfig.getDummyMaxHP(stats.dummyHpLevel)) end,
        next    = function() return tostring(StatsConfig.getDummyMaxHP(stats.dummyHpLevel + 1)) end,
        cost    = function() return StatsConfig.getDummyUpgradeCost(stats.dummyHpLevel) end,
    },
}

-- ============================================================
--  Build UI
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name           = "UpgradeUI"
gui.ResetOnSpawn   = false
gui.DisplayOrder   = 20
gui.Parent         = player:WaitForChild("PlayerGui")

-- Panel
local panel = Instance.new("Frame")
panel.Name              = "Panel"
panel.Size              = UDim2.new(0, 480, 0, 450)
panel.Position          = UDim2.new(0.5, -240, 0.5, -225)
panel.BackgroundColor3  = Color3.fromRGB(15, 15, 20)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel   = 0
panel.Visible           = false
panel.Parent            = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 255, 255)
panelStroke.Transparency = 0.8
panelStroke.Thickness = 1.5
panelStroke.Parent = panel

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size            = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
titleBar.BackgroundTransparency = 0.5
titleBar.BorderSizePixel = 0
titleBar.Parent          = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

local titleFill = Instance.new("Frame")
titleFill.Size = UDim2.new(1, 0, 0.5, 0)
titleFill.Position = UDim2.new(0, 0, 0.5, 0)
titleFill.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
titleFill.BackgroundTransparency = 0.5
titleFill.BorderSizePixel = 0
titleFill.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size               = UDim2.new(0, 180, 1, 0)
titleLabel.Position           = UDim2.new(0, 20, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text               = "UPGRADES"
titleLabel.TextColor3         = Color3.new(1, 1, 1)
titleLabel.TextSize           = 22
titleLabel.Font               = Enum.Font.GothamBlack
titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
titleLabel.Parent             = titleBar

-- ปุ่ม X
local closeBtn = Instance.new("TextButton")
closeBtn.Size              = UDim2.new(0, 36, 0, 36)
closeBtn.Position          = UDim2.new(1, -44, 0, 7)
closeBtn.BackgroundColor3  = Color3.fromRGB(200, 50, 50)
closeBtn.Text              = "✕"
closeBtn.TextColor3        = Color3.new(1, 1, 1)
closeBtn.TextSize          = 18
closeBtn.Font              = Enum.Font.GothamBold
closeBtn.BorderSizePixel   = 0
closeBtn.Parent            = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- Coin balance display
local coinsLabel = Instance.new("TextLabel")
coinsLabel.Size               = UDim2.new(0, 140, 0, 30)
coinsLabel.Position           = UDim2.new(1, -192, 0.5, -15)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text               = "💰 0"
coinsLabel.TextColor3         = Color3.fromRGB(255, 220, 50)
coinsLabel.TextSize           = 17
coinsLabel.Font               = Enum.Font.GothamBold
coinsLabel.TextXAlignment     = Enum.TextXAlignment.Right
coinsLabel.Parent             = titleBar

-- Scroll frame สำหรับ rows
local scroll = Instance.new("ScrollingFrame")
scroll.Size              = UDim2.new(1, -20, 1, -70)
scroll.Position          = UDim2.new(0, 10, 0, 60)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel   = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
scroll.Parent            = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding       = UDim.new(0, 8)
listLayout.Parent        = scroll

-- ============================================================
--  สร้าง Row
-- ============================================================
local rowLabels = {}  -- [id] = {valueLbl, costLbl}

local function formatCost(n)
    if n >= 1000000 then return string.format("%.1fM", n/1000000)
    elseif n >= 1000 then return string.format("%.1fK", n/1000)
    else return tostring(n) end
end

local function createRow(upgradeDef)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, -4, 0, 70)
    row.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    row.BackgroundTransparency = 0.2
    row.BorderSizePixel  = 0
    row.Parent           = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.9
    stroke.Thickness = 1
    stroke.Parent    = row

    local iconBox = Instance.new("Frame")
    iconBox.Size             = UDim2.new(0, 54, 0, 54)
    iconBox.Position         = UDim2.new(0, 8, 0.5, -27)
    iconBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    iconBox.BorderSizePixel  = 0
    iconBox.Parent           = row
    Instance.new("UICorner", iconBox).CornerRadius = UDim.new(0, 8)

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size               = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text               = "⚡"
    iconLabel.TextColor3         = Color3.fromRGB(255, 255, 255)
    iconLabel.TextScaled         = true
    iconLabel.Font               = Enum.Font.GothamBold
    iconLabel.Parent             = iconBox
    
    local iconPad = Instance.new("UIPadding")
    iconPad.PaddingTop = UDim.new(0, 10)
    iconPad.PaddingBottom = UDim.new(0, 10)
    iconPad.Parent = iconLabel

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size               = UDim2.new(0, 160, 0, 24)
    nameLbl.Position           = UDim2.new(0, 74, 0, 8)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text               = upgradeDef.name
    nameLbl.TextColor3         = Color3.new(1, 1, 1)
    nameLbl.TextSize           = 18
    nameLbl.Font               = Enum.Font.GothamBold
    nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
    nameLbl.Parent             = row

    local valueLbl = Instance.new("TextLabel")
    valueLbl.Size              = UDim2.new(0, 180, 0, 24)
    valueLbl.Position          = UDim2.new(0, 74, 0, 36)
    valueLbl.BackgroundTransparency = 1
    valueLbl.RichText          = true
    valueLbl.Text              = ""
    valueLbl.TextSize          = 16
    valueLbl.Font              = Enum.Font.GothamMedium
    valueLbl.TextXAlignment    = Enum.TextXAlignment.Left
    valueLbl.Parent            = row

    local costLbl = Instance.new("TextLabel")
    costLbl.Size               = UDim2.new(0, 90, 0, 32)
    costLbl.Position           = UDim2.new(1, -150, 0.5, -16)
    costLbl.BackgroundTransparency = 1
    costLbl.Text               = ""
    costLbl.TextColor3         = Color3.fromRGB(255, 220, 50)
    costLbl.TextSize           = 18
    costLbl.Font               = Enum.Font.GothamBlack
    costLbl.Parent             = row

    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 54, 0, 54)
    btn.Position         = UDim2.new(1, -62, 0.5, -27)
    btn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    btn.Text             = "▲"
    btn.TextColor3       = Color3.new(1, 1, 1)
    btn.TextSize         = 24
    btn.Font             = Enum.Font.GothamBlack
    btn.BorderSizePixel  = 0
    btn.Parent           = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function()
        UpgradeRequest:FireServer(upgradeDef.id)
    end)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(50, 200, 100) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(40, 180, 80) }):Play()
    end)

    rowLabels[upgradeDef.id] = { valueLbl, costLbl }
end

for _, upg in UPGRADES do
    createRow(upg)
end

local function refreshRows()
    scroll.CanvasSize = UDim2.new(0, 0, 0, #UPGRADES * 78)
    for _, upg in UPGRADES do
        local lbls = rowLabels[upg.id]
        if lbls then
            local cur  = upg.current()
            local nxt  = upg.next()
            local cost = upg.cost()
            lbls[1].Text = '<font color="rgb(220,220,220)">' .. cur .. '</font>'
                        .. '<font color="rgb(100,100,100)"> → </font>'
                        .. '<font color="rgb(50, 200, 100)">' .. nxt .. '</font>'
            lbls[2].Text = "$ " .. formatCost(cost)
        end
    end
end

-- ============================================================
--  Toggle Button (ล่างซ้าย)
-- ============================================================
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size             = UDim2.new(0, 46, 0, 46)
toggleBtn.Position         = UDim2.new(0, 20, 1, -126)
toggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
toggleBtn.BackgroundTransparency = 0.4
toggleBtn.Text             = "⬆️"
toggleBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
toggleBtn.TextScaled       = true
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.BorderSizePixel  = 0
toggleBtn.Visible          = true
toggleBtn.Parent           = gui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

local stroke2 = Instance.new("UIStroke")
stroke2.Color     = Color3.fromRGB(255, 255, 255)
stroke2.Transparency = 0.8
stroke2.Thickness = 1.5
stroke2.Parent    = toggleBtn

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.Parent = toggleBtn

toggleBtn.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
    if panel.Visible then refreshRows() end
end)

toggleBtn.MouseEnter:Connect(function()
    TweenService:Create(toggleBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(40, 40, 50) }):Play()
end)
toggleBtn.MouseLeave:Connect(function()
    TweenService:Create(toggleBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(15, 15, 20) }):Play()
end)

closeBtn.MouseButton1Click:Connect(function()
    panel.Visible = false
end)

SyncStats.OnClientEvent:Connect(function(s)
    for k, v in s do stats[k] = v end
    if panel.Visible then refreshRows() end
end)

-- [U] to toggle, ESC to close
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.U then
        panel.Visible = not panel.Visible
        if panel.Visible then refreshRows() end
    elseif input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
        panel.Visible = false
    end
end)

-- Keep coin balance in sync
UpdateCoins.OnClientEvent:Connect(function(amount)
    currentCoins = amount
    coinsLabel.Text = "💰 " .. formatCost(amount)
end)
