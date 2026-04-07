-- UpgradeUI.client.lua

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player      = Players.LocalPlayer
local StatsConfig = require(ReplicatedStorage:WaitForChild("StatsConfig"))
local SyncStats   = ReplicatedStorage:WaitForChild("SyncStats")
local UpgradeRequest = ReplicatedStorage:WaitForChild("UpgradeRequest")

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

-- Panel (เริ่มซ่อน)
local panel = Instance.new("Frame")
panel.Name              = "Panel"
panel.Size              = UDim2.new(0, 480, 0, 420)
panel.Position          = UDim2.new(0.5, -240, 0.5, -210)
panel.BackgroundColor3  = Color3.fromRGB(18, 18, 18)
panel.BorderSizePixel   = 0
panel.Visible           = false
panel.Parent            = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size            = UDim2.new(1, 0, 0, 46)
titleBar.BackgroundColor3 = Color3.fromRGB(160, 20, 20)
titleBar.BorderSizePixel = 0
titleBar.Parent          = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

-- ปิดมุมล่างของ titleBar ให้ตรง
local titleFill = Instance.new("Frame")
titleFill.Size = UDim2.new(1, 0, 0.5, 0)
titleFill.Position = UDim2.new(0, 0, 0.5, 0)
titleFill.BackgroundColor3 = Color3.fromRGB(160, 20, 20)
titleFill.BorderSizePixel = 0
titleFill.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size               = UDim2.new(1, -50, 1, 0)
titleLabel.Position           = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text               = "Upgrades"
titleLabel.TextColor3         = Color3.new(1, 1, 1)
titleLabel.TextScaled         = true
titleLabel.Font               = Enum.Font.GothamBold
titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
titleLabel.Parent             = titleBar

-- ปุ่ม X
local closeBtn = Instance.new("TextButton")
closeBtn.Size              = UDim2.new(0, 36, 0, 36)
closeBtn.Position          = UDim2.new(1, -42, 0, 5)
closeBtn.BackgroundColor3  = Color3.fromRGB(200, 30, 30)
closeBtn.Text              = "✕"
closeBtn.TextColor3        = Color3.new(1, 1, 1)
closeBtn.TextScaled        = true
closeBtn.Font              = Enum.Font.GothamBold
closeBtn.BorderSizePixel   = 0
closeBtn.Parent            = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Scroll frame สำหรับ rows
local scroll = Instance.new("ScrollingFrame")
scroll.Size              = UDim2.new(1, -16, 1, -56)
scroll.Position          = UDim2.new(0, 8, 0, 52)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel   = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(160, 20, 20)
scroll.Parent            = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding       = UDim.new(0, 6)
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
    row.Size             = UDim2.new(1, -4, 0, 64)
    row.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    row.BorderSizePixel  = 0
    row.Parent           = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    -- เส้นกรอบแดง
    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(160, 20, 20)
    stroke.Thickness = 1.5
    stroke.Parent    = row

    -- Icon placeholder
    local iconBox = Instance.new("Frame")
    iconBox.Size             = UDim2.new(0, 50, 0, 50)
    iconBox.Position         = UDim2.new(0, 8, 0.5, -25)
    iconBox.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    iconBox.BorderSizePixel  = 0
    iconBox.Parent           = row
    Instance.new("UICorner", iconBox).CornerRadius = UDim.new(0, 6)

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size               = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text               = "icon"
    iconLabel.TextColor3         = Color3.fromRGB(100, 220, 100)
    iconLabel.TextScaled         = true
    iconLabel.Font               = Enum.Font.GothamBold
    iconLabel.FontFace           = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
    iconLabel.Parent             = iconBox

    -- ชื่อ upgrade
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size               = UDim2.new(0, 160, 0, 22)
    nameLbl.Position           = UDim2.new(0, 66, 0, 8)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text               = upgradeDef.name
    nameLbl.TextColor3         = Color3.new(1, 1, 1)
    nameLbl.TextScaled         = true
    nameLbl.Font               = Enum.Font.GothamBold
    nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
    nameLbl.Parent             = row

    -- ค่า current -> next
    local valueLbl = Instance.new("TextLabel")
    valueLbl.Size              = UDim2.new(0, 180, 0, 24)
    valueLbl.Position          = UDim2.new(0, 66, 0, 32)
    valueLbl.BackgroundTransparency = 1
    valueLbl.RichText          = true
    valueLbl.Text              = ""
    valueLbl.TextScaled        = true
    valueLbl.Font              = Enum.Font.Gotham
    valueLbl.TextXAlignment    = Enum.TextXAlignment.Left
    valueLbl.Parent            = row

    -- ราคา
    local costLbl = Instance.new("TextLabel")
    costLbl.Size               = UDim2.new(0, 90, 0, 32)
    costLbl.Position           = UDim2.new(1, -150, 0.5, -16)
    costLbl.BackgroundTransparency = 1
    costLbl.Text               = ""
    costLbl.TextColor3         = Color3.fromRGB(255, 200, 0)
    costLbl.TextScaled         = true
    costLbl.Font               = Enum.Font.GothamBold
    costLbl.Parent             = row

    -- ปุ่ม upgrade
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 48, 0, 48)
    btn.Position         = UDim2.new(1, -60, 0.5, -24)
    btn.BackgroundColor3 = Color3.fromRGB(220, 170, 0)
    btn.Text             = "▲▲"
    btn.TextColor3       = Color3.new(1, 1, 1)
    btn.TextScaled       = true
    btn.Font             = Enum.Font.GothamBold
    btn.BorderSizePixel  = 0
    btn.Parent           = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function()
        UpgradeRequest:FireServer(upgradeDef.id)
    end)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(255, 200, 0) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(220, 170, 0) }):Play()
    end)

    rowLabels[upgradeDef.id] = { valueLbl, costLbl }
end

for _, upg in UPGRADES do
    createRow(upg)
end

-- อัพเดตค่าใน rows
local function refreshRows()
    scroll.CanvasSize = UDim2.new(0, 0, 0, #UPGRADES * 70)
    for _, upg in UPGRADES do
        local lbls = rowLabels[upg.id]
        if lbls then
            local cur  = upg.current()
            local nxt  = upg.next()
            local cost = upg.cost()
            lbls[1].Text = '<font color="rgb(255,255,255)">' .. cur .. '</font>'
                        .. '<font color="rgb(180,180,180)"> → </font>'
                        .. '<font color="rgb(255, 200, 0)">' .. nxt .. '</font>'
            lbls[2].Text = "$ " .. formatCost(cost)
        end
    end
end

-- ============================================================
--  Toggle Button (ล่างซ้าย)
-- ============================================================
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size             = UDim2.new(0, 60, 0, 60)
toggleBtn.Position         = UDim2.new(0, 16, 1, -150)
toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
toggleBtn.Text             = "▲▲"
toggleBtn.TextColor3       = Color3.fromRGB(255, 200, 0)
toggleBtn.TextScaled       = true
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.BorderSizePixel  = 0
toggleBtn.Parent           = gui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

local stroke2 = Instance.new("UIStroke")
stroke2.Color     = Color3.fromRGB(160, 20, 20)
stroke2.Thickness = 2
stroke2.Parent    = toggleBtn

local toggleLbl = Instance.new("TextLabel")
toggleLbl.Size               = UDim2.new(1, 0, 0, 16)
toggleLbl.Position           = UDim2.new(0, 0, 1, 2)
toggleLbl.BackgroundTransparency = 1
toggleLbl.Text               = "Upgrade"
toggleLbl.TextColor3         = Color3.new(1, 1, 1)
toggleLbl.TextScaled         = true
toggleLbl.Font               = Enum.Font.Gotham
toggleLbl.Parent             = toggleBtn

-- เปิด/ปิด panel
toggleBtn.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
    if panel.Visible then refreshRows() end
end)

closeBtn.MouseButton1Click:Connect(function()
    panel.Visible = false
end)

-- รับ stats update
SyncStats.OnClientEvent:Connect(function(s)
    for k, v in s do stats[k] = v end
    if panel.Visible then refreshRows() end
end)
