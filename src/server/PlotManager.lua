-- PlotManager.lua (ModuleScript)
-- จัดการ plot assignment ให้ทุก script ใช้ร่วมกันได้

local Workspace = game:GetService("Workspace")

local PlotManager = {}
PlotManager.PlotAssigned = Instance.new("BindableEvent")

local plotOwners  = {}  -- plot Model → player
local playerPlots = {}  -- player → plot Model
local allPlots    = {}

-- รอ Workspace โหลดเสร็จโดยไม่ block script อื่น
task.defer(function()
    task.wait(0.5)
    for _, obj in Workspace:GetDescendants() do
        if obj.Name:lower():sub(1, 4) == "plot" and obj:FindFirstChild("Spawn dummy") then
            table.insert(allPlots, obj)
        end
    end
    print("[PlotManager] พบ", #allPlots, "plot(s)")
end)

function PlotManager.assign(player)
    for _, plot in allPlots do
        if not plotOwners[plot] then
            plotOwners[plot]    = player
            playerPlots[player] = plot
            PlotManager.PlotAssigned:Fire(player, plot)
            return plot
        end
    end
    warn("[PlotManager] Plot เต็มแล้ว ไม่มีที่ว่างสำหรับ", player.Name)
    return nil
end

function PlotManager.release(player)
    local plot = playerPlots[player]
    if plot then
        plotOwners[plot]    = nil
        playerPlots[player] = nil
    end
end

function PlotManager.getPlot(player)
    return playerPlots[player]
end

return PlotManager
