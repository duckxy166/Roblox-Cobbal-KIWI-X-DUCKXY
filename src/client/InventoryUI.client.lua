local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer

local equipEvent = ReplicatedStorage:WaitForChild("EquipWeapon")

local WEAPONS = {
    {
        name = "Po's Dagger (2.0)",
        icon = "🗡️",
        color = Color3.fromRGB(255, 100, 100),
        equipped = true
    },
    {
        name = "NoobSword",
        icon = "⚔️",
        color = Color3.fromRGB(100, 150, 255),
        equipped = false
    },
}

local gui = Instance.new("ScreenGui")
gui.Name = "InventoryUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 15
gui.Enabled = false -- HIDE UI
gui.Parent = player:WaitForChild("PlayerGui")

local inventoryFrame = Instance.new("Frame")
inventoryFrame.Name = "InventoryFrame"
inventoryFrame.Size = UDim2.new(0, 60, 0, 280)
inventoryFrame.Position = UDim2.new(1, -80, 0.5, -140)
inventoryFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
inventoryFrame.BackgroundTransparency = 0.3
inventoryFrame.BorderSizePixel = 0
inventoryFrame.Parent = gui
Instance.new("UICorner", inventoryFrame).CornerRadius = UDim.new(0, 10)

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(255, 255, 255)
frameStroke.Transparency = 0.8
frameStroke.Thickness = 1.5
frameStroke.Parent = inventoryFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "WEAPONS"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextSize = 12
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = inventoryFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.Parent = inventoryFrame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 35)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.Parent = inventoryFrame

local slotButtons = {}

local function createWeaponSlot(weaponData, index)
    local slot = Instance.new("TextButton")
    slot.Name = "Slot" .. index
    slot.Size = UDim2.new(0, 44, 0, 44)
    slot.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    slot.BackgroundTransparency = 0.2
    slot.BorderSizePixel = 0
    slot.Text = ""
    slot.Parent = inventoryFrame
    Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 8)
    
    local slotStroke = Instance.new("UIStroke")
    slotStroke.Color = weaponData.equipped and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(255, 255, 255)
    slotStroke.Transparency = weaponData.equipped and 0.3 or 0.9
    slotStroke.Thickness = weaponData.equipped and 2 or 1
    slotStroke.Parent = slot
    
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(1, 0, 0.7, 0)
    iconLabel.Position = UDim2.new(0, 0, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = weaponData.icon
    iconLabel.TextColor3 = weaponData.color
    iconLabel.TextScaled = true
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.Parent = slot
    
    local iconPad = Instance.new("UIPadding")
    iconPad.PaddingTop = UDim.new(0, 6)
    iconPad.PaddingBottom = UDim.new(0, 6)
    iconPad.PaddingLeft = UDim.new(0, 6)
    iconPad.PaddingRight = UDim.new(0, 6)
    iconPad.Parent = iconLabel
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
    nameLabel.Position = UDim2.new(0, 0, 0.7, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = string.sub(weaponData.name, 1, 1)
    nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    nameLabel.TextSize = 10
    nameLabel.Font = Enum.Font.GothamMedium
    nameLabel.Parent = slot
    
    local numberLabel = Instance.new("TextLabel")
    numberLabel.Size = UDim2.new(0, 16, 0, 16)
    numberLabel.Position = UDim2.new(0, 2, 0, 2)
    numberLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    numberLabel.BackgroundTransparency = 0.5
    numberLabel.Text = tostring(index)
    numberLabel.TextColor3 = Color3.new(1, 1, 1)
    numberLabel.TextSize = 10
    numberLabel.Font = Enum.Font.GothamBold
    numberLabel.BorderSizePixel = 0
    numberLabel.Parent = slot
    Instance.new("UICorner", numberLabel).CornerRadius = UDim.new(0, 4)
    
    slot.MouseEnter:Connect(function()
        TweenService:Create(slot, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        }):Play()
        TweenService:Create(slotStroke, TweenInfo.new(0.15), {
            Transparency = 0.5
        }):Play()
    end)
    
    slot.MouseLeave:Connect(function()
        TweenService:Create(slot, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        }):Play()
        if not weaponData.equipped then
            TweenService:Create(slotStroke, TweenInfo.new(0.15), {
                Transparency = 0.9
            }):Play()
        end
    end)
    
    slot.MouseButton1Click:Connect(function()
        for i, weapon in ipairs(WEAPONS) do
            weapon.equipped = (i == index)
            local btn = slotButtons[i]
            if btn then
                local stroke = btn:FindFirstChildOfClass("UIStroke")
                if stroke then
                    stroke.Color = weapon.equipped and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(255, 255, 255)
                    TweenService:Create(stroke, TweenInfo.new(0.2), {
                        Transparency = weapon.equipped and 0.3 or 0.9,
                        Thickness = weapon.equipped and 2 or 1
                    }):Play()
                end
            end
        end
        
        TweenService:Create(slot, TweenInfo.new(0.1), {
            Size = UDim2.new(0, 48, 0, 48)
        }):Play()
        task.wait(0.1)
        TweenService:Create(slot, TweenInfo.new(0.1), {
            Size = UDim2.new(0, 44, 0, 44)
        }):Play()
        
        _G.EquippedWeapon = weaponData.name
        equipEvent:FireServer(weaponData.name)
        print("Equipped:", weaponData.name)
    end)
    
    slotButtons[index] = slot
    return slot
end

for i, weapon in ipairs(WEAPONS) do
    createWeaponSlot(weapon, i)
end

player.CharacterAdded:Connect(function()
    task.wait(0.5) -- wait for character to load fully
    for i, weapon in ipairs(WEAPONS) do
        if weapon.equipped then
            equipEvent:FireServer(weapon.name)
            break
        end
    end
end)

-- Initial equip
task.spawn(function()
    if player.Character then
        for i, weapon in ipairs(WEAPONS) do
            if weapon.equipped then
                _G.EquippedWeapon = weapon.name
                equipEvent:FireServer(weapon.name)
                break
            end
        end
    end
end)

local keybindConnection
keybindConnection = game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    local keyNumber = tonumber(input.KeyCode.Name:match("%d+"))
    if keyNumber and keyNumber >= 1 and keyNumber <= #WEAPONS then
        local slot = slotButtons[keyNumber]
        if slot then
            slot.MouseButton1Click:Fire()
        end
    end
end)
