-- UpgradeServer.server.lua
-- จัดการคำขอ upgrade จาก client

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))

local UpgradeRequest = Instance.new("RemoteEvent")
UpgradeRequest.Name   = "UpgradeRequest"
UpgradeRequest.Parent = ReplicatedStorage

-- เก็บ coins ต้องดึงจาก DummyServer — ใช้ BindableFunction เป็นสะพาน
local GetCoins = Instance.new("BindableFunction")
GetCoins.Name   = "GetCoins"
GetCoins.Parent = script.Parent

local SetCoins = Instance.new("BindableFunction")
SetCoins.Name   = "SetCoins"
SetCoins.Parent = script.Parent

local UpdateCoins = ReplicatedStorage:WaitForChild("UpdateCoins")

UpgradeRequest.OnServerEvent:Connect(function(player, upgradeType)
    -- ดึง coins จาก DummyServer
    local coins = GetCoins:Invoke(player)
    if not coins then return end

    local cost = PlayerStats.getUpgradeCost(player, upgradeType)
    if coins < cost then return end  -- เงินไม่พอ

    local ok = PlayerStats.upgrade(player, upgradeType)
    if not ok then return end

    -- หักเงิน
    local newCoins = coins - cost
    SetCoins:Invoke(player, newCoins)
    UpdateCoins:FireClient(player, newCoins, 0)
end)
