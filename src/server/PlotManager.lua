-- PlotManager.lua (ModuleScript)
-- จัดการ plot assignment ให้ทุก script ใช้ร่วมกันได้

local Workspace = game:GetService("Workspace")

local PlotManager = {}
PlotManager.PlotAssigned = Instance.new("BindableEvent")

local plotOwners  = {}  -- plot → player
local playerPlots = {}  -- player → plot
local allPlots    = {}
local plotsReady  = false

-- Scan only direct Workspace children named "plot*" that have a "Spawn dummy"
local function scanPlots()
    allPlots = {}
    for _, obj in Workspace:GetChildren() do
        local nameLower = obj.Name:lower()
        if nameLower:sub(1, 4) == "plot" and obj:FindFirstChild("Spawn dummy") then
            table.insert(allPlots, obj)
        end
    end
    plotsReady = true
    print("[PlotManager] พบ", #allPlots, "plot(s):", table.concat(
        (function()
            local names = {}
            for _, p in allPlots do table.insert(names, p.Name) end
            return names
        end)(), ", "
    ))
end

task.defer(function()
    task.wait(0.5)
    scanPlots()
end)

-- Wait until plot scan is done, then find a free plot
function PlotManager.assign(player)
    -- Wait up to 5s for plots to be ready
    local waited = 0
    while not plotsReady and waited < 5 do
        task.wait(0.1)
        waited = waited + 0.1
    end

    if #allPlots == 0 then
        warn("[PlotManager] ไม่พบ plot ใน Workspace สำหรับ", player.Name)
        return nil
    end

    -- Skip if already assigned (prevents double-assign)
    if playerPlots[player] then
        return playerPlots[player]
    end

    for _, plot in allPlots do
        if not plotOwners[plot] then
            plotOwners[plot]    = player
            playerPlots[player] = plot
            PlotManager.PlotAssigned:Fire(player, plot)
            print("[PlotManager] Assigned", plot.Name, "→", player.Name)
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
        print("[PlotManager] Released", plot.Name, "from", player.Name)
    end
end

function PlotManager.getPlot(player)
    return playerPlots[player]
end

function PlotManager.getOwner(plot)
    return plotOwners[plot]
end

return PlotManager
