-- ShopUI.client.lua
-- Shop UI shown when clicking NPC

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player       = Players.LocalPlayer
local OpenShopUI   = ReplicatedStorage:WaitForChild("OpenShopUI")
local BuyShopItem  = ReplicatedStorage:WaitForChild("BuyShopItem")
local UpdateCoins  = ReplicatedStorage:WaitForChild("UpdateCoins")

local currentCoins = 0

local SHOP_ITEMS = {
    { id = "potion_hp", name = "Health Potion", price = 50, icon = "HP" },
    { id = "potion_stamina", name = "Stamina Potion", price = 30, icon = "ST" },
    { id = "boost_damage", name = "Damage Boost", price = 100, icon = "DMG" },
    { id = "boost_crit", name = "Crit Boost", price = 150, icon = "CRT" },
}

local gui = Instance.new("ScreenGui")
gui.Name           = "ShopUI"
gui.ResetOnSpawn   = false
gui.DisplayOrder   = 25
gui.Parent         = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name              = "Panel"
panel.Size              = UDim2.new(0, 400, 0, 350)
panel.Position          = UDim2.new(0.5, -200, 0.5, -175)
panel.BackgroundColor3  = Color3.fromRGB(20, 20, 30)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel   = 0
panel.Visible           = false
panel.Parent            = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 215, 0)
panelStroke.Transparency = 0.7
panelStroke.Thickness = 2
panelStroke.Parent = panel

local titleBar = Instance.new("Frame")
titleBar.Size            = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 35, 20)
titleBar.BackgroundTransparency = 0.5
titleBar.BorderSizePixel = 0
titleBar.Parent          = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size               = UDim2.new(1, -50, 1, 0)
titleLabel.Position           = UDim2.new(0, 20, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text               = "SHOP"
titleLabel.TextColor3         = Color3.fromRGB(255, 215, 0)
titleLabel.TextSize           = 24
titleLabel.Font               = Enum.Font.GothamBlack
titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
titleLabel.Parent             = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size              = UDim2.new(0, 36, 0, 36)
closeBtn.Position          = UDim2.new(1, -44, 0, 7)
closeBtn.BackgroundColor3  = Color3.fromRGB(200, 50, 50)
closeBtn.Text              = "X"
closeBtn.TextColor3        = Color3.new(1, 1, 1)
closeBtn.TextSize          = 18
closeBtn.Font              = Enum.Font.GothamBold
closeBtn.BorderSizePixel   = 0
closeBtn.Parent            = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

local shopCoinsLabel = Instance.new("TextLabel")
shopCoinsLabel.Size               = UDim2.new(0, 130, 0, 30)
shopCoinsLabel.Position           = UDim2.new(1, -178, 0.5, -15)
shopCoinsLabel.BackgroundTransparency = 1
shopCoinsLabel.Text               = "💰 0"
shopCoinsLabel.TextColor3         = Color3.fromRGB(255, 215, 0)
shopCoinsLabel.TextSize           = 16
shopCoinsLabel.Font               = Enum.Font.GothamBold
shopCoinsLabel.TextXAlignment     = Enum.TextXAlignment.Right
shopCoinsLabel.Parent             = titleBar

local scroll = Instance.new("ScrollingFrame")
scroll.Size              = UDim2.new(1, -20, 1, -70)
scroll.Position          = UDim2.new(0, 10, 0, 60)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel   = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 215, 0)
scroll.Parent            = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding       = UDim.new(0, 10)
listLayout.Parent        = scroll

local function formatPrice(n)
    if n >= 1000000 then return string.format("%.1fM", n/1000000)
    elseif n >= 1000 then return string.format("%.1fK", n/1000)
    else return tostring(n) end
end

local function createShopItem(item)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, -4, 0, 60)
    row.BackgroundColor3 = Color3.fromRGB(30, 28, 35)
    row.BackgroundTransparency = 0.3
    row.BorderSizePixel  = 0
    row.Parent           = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(255, 215, 0)
    stroke.Transparency = 0.8
    stroke.Thickness = 1
    stroke.Parent    = row

    local iconBox = Instance.new("Frame")
    iconBox.Size             = UDim2.new(0, 44, 0, 44)
    iconBox.Position         = UDim2.new(0, 8, 0.5, -22)
    iconBox.BackgroundColor3 = Color3.fromRGB(50, 45, 30)
    iconBox.BorderSizePixel  = 0
    iconBox.Parent           = row
    Instance.new("UICorner", iconBox).CornerRadius = UDim.new(0, 6)

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size               = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text               = item.icon
    iconLabel.TextColor3         = Color3.fromRGB(255, 215, 0)
    iconLabel.TextScaled         = true
    iconLabel.Font               = Enum.Font.GothamBold
    iconLabel.Parent             = iconBox

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size               = UDim2.new(0, 180, 0, 24)
    nameLbl.Position           = UDim2.new(0, 60, 0, 8)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text               = item.name
    nameLbl.TextColor3         = Color3.new(1, 1, 1)
    nameLbl.TextSize           = 16
    nameLbl.Font               = Enum.Font.GothamBold
    nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
    nameLbl.Parent             = row

    local priceLbl = Instance.new("TextLabel")
    priceLbl.Size               = UDim2.new(0, 80, 0, 20)
    priceLbl.Position           = UDim2.new(0, 60, 0, 34)
    priceLbl.BackgroundTransparency = 1
    priceLbl.Text               = "$ " .. formatPrice(item.price)
    priceLbl.TextColor3         = Color3.fromRGB(255, 215, 0)
    priceLbl.TextSize           = 14
    priceLbl.Font               = Enum.Font.GothamMedium
    priceLbl.TextXAlignment     = Enum.TextXAlignment.Left
    priceLbl.Parent             = row

    local buyBtn = Instance.new("TextButton")
    buyBtn.Size             = UDim2.new(0, 70, 0, 36)
    buyBtn.Position         = UDim2.new(1, -82, 0.5, -18)
    buyBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
    buyBtn.Text             = "BUY"
    buyBtn.TextColor3       = Color3.new(0, 0, 0)
    buyBtn.TextSize         = 14
    buyBtn.Font             = Enum.Font.GothamBlack
    buyBtn.BorderSizePixel  = 0
    buyBtn.Parent           = row
    Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 6)

    buyBtn.MouseButton1Click:Connect(function()
        -- Animate
        TweenService:Create(buyBtn, TweenInfo.new(0.1), { Size = UDim2.new(0, 60, 0, 30) }):Play()
        task.wait(0.1)
        TweenService:Create(buyBtn, TweenInfo.new(0.1), { Size = UDim2.new(0, 70, 0, 36) }):Play()
        -- Fire to server
        BuyShopItem:FireServer(item.id)
    end)

    buyBtn.MouseEnter:Connect(function()
        TweenService:Create(buyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(255, 210, 50) }):Play()
    end)
    buyBtn.MouseLeave:Connect(function()
        TweenService:Create(buyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(255, 180, 0) }):Play()
    end)
end

for _, item in SHOP_ITEMS do
    createShopItem(item)
end

scroll.CanvasSize = UDim2.new(0, 0, 0, #SHOP_ITEMS * 70)

closeBtn.MouseButton1Click:Connect(function()
    panel.Visible = false
end)

OpenShopUI.OnClientEvent:Connect(function()
    panel.Visible = true
    panel.Position = UDim2.new(0.5, -200, 0.5, -175)
    TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 
        { Position = UDim2.new(0.5, -200, 0.5, -175) }):Play()
end)

local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
        panel.Visible = false
    end
end)

UpdateCoins.OnClientEvent:Connect(function(amount)
    currentCoins = amount
    shopCoinsLabel.Text = "💰 " .. formatPrice(amount)
end)
