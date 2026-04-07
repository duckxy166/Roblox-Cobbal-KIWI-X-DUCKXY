-- PlotDisplay.client.lua
-- แสดง Billboard + ViewportFrame ของเจ้าของ plot

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotOwnerUpdate = ReplicatedStorage:WaitForChild("PlotOwnerUpdate")

local billboards = {}  -- [plot] = BillboardGui

local function removeBillboard(plot)
    if billboards[plot] then
        billboards[plot]:Destroy()
        billboards[plot] = nil
    end
end

local function buildBillboard(plot, player)
    removeBillboard(plot)

    local billboard = Instance.new("BillboardGui")
    billboard.Name        = "PlotBillboard"
    billboard.Size        = UDim2.new(0, 110, 0, 150)
    billboard.StudsOffset = Vector3.new(0, 20, 0)   -- สูงขึ้น
    billboard.AlwaysOnTop = false
    billboard.Parent      = plot

    -- กรอบหลัก
    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
    bg.BackgroundTransparency = 0.25
    bg.BorderSizePixel        = 0
    bg.Parent                 = billboard
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)

    -- ViewportFrame แสดงโมเดลผู้เล่น
    local viewport = Instance.new("ViewportFrame")
    viewport.Size                   = UDim2.new(1, -8, 0.78, -8)
    viewport.Position               = UDim2.new(0, 4, 0, 4)
    viewport.BackgroundTransparency = 1
    viewport.LightDirection         = Vector3.new(-1, -2, -1)
    viewport.Ambient                = Color3.fromRGB(200, 200, 200)
    viewport.Parent                 = bg
    Instance.new("UICorner", viewport).CornerRadius = UDim.new(0, 8)

    -- ชื่อผู้เล่น
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size               = UDim2.new(1, -8, 0.2, -4)
    nameLabel.Position           = UDim2.new(0, 4, 0.8, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text               = player.Name
    nameLabel.TextColor3         = Color3.new(1, 1, 1)
    nameLabel.TextScaled         = true
    nameLabel.Font               = Enum.Font.GothamBold
    nameLabel.Parent             = bg

    billboards[plot] = billboard

    -- โหลด character เข้า ViewportFrame
    local character = player.Character
    if not character then return end

    local worldModel = Instance.new("WorldModel")
    worldModel.Parent = viewport

    local clone = character:Clone()

    -- ลบ script ออก
    for _, obj in clone:GetDescendants() do
        if obj:IsA("Script") or obj:IsA("LocalScript") then
            obj:Destroy()
        end
    end

    -- Anchor ทุก part
    for _, obj in clone:GetDescendants() do
        if obj:IsA("BasePart") then
            obj.Anchored = true
        end
    end

    clone.Parent = worldModel

    -- ย้าย character ไปกลาง viewport ด้วย PivotTo
    local root = clone:FindFirstChild("HumanoidRootPart")
    if root then
        clone:PivotTo(CFrame.new(0, 0, 0))
    end

    -- Camera มองตรงๆ ที่ตัวละคร
    local cam = Instance.new("Camera")
    cam.FieldOfView    = 50
    cam.CFrame         = CFrame.new(Vector3.new(0, 2, 4.5), Vector3.new(0, 2, 0))
    viewport.CurrentCamera = cam
    cam.Parent         = viewport
end

PlotOwnerUpdate.OnClientEvent:Connect(function(plot, player)
    if player then
        buildBillboard(plot, player)
    else
        removeBillboard(plot)
    end
end)
