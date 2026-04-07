-- ShopItemServer.server.lua
-- Handles BuyShopItem purchases from ShopUI

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))

local BuyShopItem = Instance.new("RemoteEvent")
BuyShopItem.Name   = "BuyShopItem"
BuyShopItem.Parent = ReplicatedStorage

-- Bridge to DummyServer coins (same pattern as UpgradeServer)
local GetCoins = script.Parent:WaitForChild("GetCoins", 10)
local SetCoins = script.Parent:WaitForChild("SetCoins", 10)

local UpdateCoins = ReplicatedStorage:WaitForChild("UpdateCoins")

-- ============================================================
--  Item definitions: price + effect applied on server
-- ============================================================
local ITEMS = {
    potion_hp = {
        price  = 50,
        effect = function(player)
            local char = player.Character
            if not char then return end
            local h = char:FindFirstChildOfClass("Humanoid")
            if h then h.Health = h.MaxHealth end
        end,
    },
    potion_stamina = {
        price  = 30,
        effect = function(player)
            -- Signal the stamina system to refill via a global or attribute
            local char = player.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                root:SetAttribute("RefillStamina", true)
            end
        end,
    },
    boost_damage = {
        price  = 100,
        effect = function(player)
            local stats = PlayerStats.get(player)
            if stats then
                stats.damage = stats.damage + 5
                PlayerStats.sync(player)
            end
        end,
    },
    boost_crit = {
        price  = 150,
        effect = function(player)
            local stats = PlayerStats.get(player)
            if stats then
                stats.critChance = stats.critChance + 2
                PlayerStats.sync(player)
            end
        end,
    },
}

BuyShopItem.OnServerEvent:Connect(function(player, itemId)
    local item = ITEMS[itemId]
    if not item then return end

    local coins = GetCoins:Invoke(player)
    if not coins or coins < item.price then return end

    local newCoins = coins - item.price
    SetCoins:Invoke(player, newCoins)
    UpdateCoins:FireClient(player, newCoins, 0)

    item.effect(player)
end)
