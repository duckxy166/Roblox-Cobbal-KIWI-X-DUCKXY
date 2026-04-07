local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStorage = game:WaitForChild("GameStorage")

-- Create RemoteEvent if it doesn't exist
local equipEvent = ReplicatedStorage:FindFirstChild("EquipWeapon")
if not equipEvent then
    equipEvent = Instance.new("RemoteEvent")
    equipEvent.Name = "EquipWeapon"
    equipEvent.Parent = ReplicatedStorage
end

equipEvent.OnServerEvent:Connect(function(player, weaponName)
    local character = player.Character
    if not character then return end
    
    local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    if not rightHand then return end
    
    -- Remove existing weapon
    local existing = character:FindFirstChild("EquippedWeapon")
    if existing then
        existing:Destroy()
    end
    
    -- Find weapon model in GameStorage
    local sourceWeapon = GameStorage:FindFirstChild(weaponName)
    if not sourceWeapon then
        warn("Could not find weapon model in GameStorage: " .. weaponName)
        return
    end
    
    -- Clone the weapon
    local weaponClone = sourceWeapon:Clone()
    weaponClone.Name = "EquippedWeapon"
    
    -- Make it non-collidable and massless so it doesn't mess with physics
    for _, part in ipairs(weaponClone:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.Massless = true
            part.Anchored = false
        end
    end
    
    -- Find handle
    local handle = weaponClone:FindFirstChild("Handle") or weaponClone:FindFirstChildOfClass("BasePart")
    if not handle then
        warn("Weapon model " .. weaponName .. " doesn't have a Handle part!")
        weaponClone:Destroy()
        return
    end
    
    weaponClone.Parent = character
    
    -- Weld to hand
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = rightHand
    weld.Part1 = handle
    
    -- Adjust position
    handle.CFrame = rightHand.CFrame * CFrame.new(0, -handle.Size.Y/2, 0) * CFrame.Angles(math.rad(90), 0, 0)
    
    weld.Parent = handle
end)
