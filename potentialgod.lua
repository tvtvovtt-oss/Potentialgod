-- ====================================================================
-- [DIX] V42.7 (ESP Highlighting + Text)
-- Цель: Проверить совместимость с библиотекой Drawing.
-- ====================================================================

-- 1. Service Initialization
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait() 
local Camera = Workspace.CurrentCamera 
-- ПРОВЕРКА: Drawing должен быть доступен
local DrawingSuccess, Drawing = pcall(function() return Drawing end)
if not DrawingSuccess or type(Drawing) ~= "table" then
    print("[DIX WARNING] Drawing library not available. ESP Text/FOV Circle disabled.")
    Drawing = nil
end

-- 2. CORE SETTINGS 
local IsAimbotEnabled = true    
local AimingSpeed = 0.2 
local IsWallCheckEnabled = false 
local IsTeamCheckEnabled = true -- Включаем Team Check по умолчанию
local MaxAimDistance = 500 
local CurrentFOV = 180 
local AimTargetPartName = "Head" 
local AimConnection = nil
local CurrentTarget = nil

local Hitbox_Enabled = true 
local Hitbox_Multiplier = 2.0 
local Hitbox_Parts_To_Change = {"HumanoidRootPart", "Head"} 
local Hitbox_Connections = {} 
local Original_Sizes = {} 

local IsESPEnabled = true 
local IsESPNameEnabled = true
local IsESPDistanceEnabled = true
local IsESPTeamCheckEnabled = true 
local ESPColor = Color3.fromRGB(0, 255, 255) 
local ESPConnection = nil
local ESPDrawings = {} 
local ESPHighlights = {} 

-- ====================================================================
-- [HELPER: PREDICATION] (Без изменений)
-- ====================================================================
local function GetPredictedPosition(TargetPart, BulletSpeed)
    if not TargetPart or not TargetPart:IsA("BasePart") then return nil end
    local Velocity = TargetPart.AssemblyLinearVelocity
    local MyPosition = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart.Position
    if not MyPosition then return TargetPart.Position end
    local TargetPosition = TargetPart.Position
    local Distance = (MyPosition - TargetPosition).Magnitude
    local TimeToTarget = Distance / (BulletSpeed or 2000) 
    local PredictedPosition = TargetPosition + (Velocity * TimeToTarget)
    if (PredictedPosition - TargetPosition).Magnitude > 20 then return TargetPosition end
    return PredictedPosition
end

-- ====================================================================
-- [AIMBOT CORE] (Team Check включен)
-- ====================================================================
local function GetTargetPart(Character) return Character:FindFirstChild(AimTargetPartName) or Character:FindFirstChild("HumanoidRootPart") end

local function IsTargetValid(TargetPart)
    local Player = Players:GetPlayerFromCharacter(TargetPart.Parent)
    if not Player then return false end
    local TargetCharacter = Player.Character
    if not TargetCharacter or not TargetCharacter:FindFirstChildOfClass("Humanoid") or TargetCharacter.Humanoid.Health <= 0 then return false end
    if Player == LocalPlayer then return false end
    -- Team Check включен
    if IsTeamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then return false end
    if not GetTargetPart(TargetCharacter) then return false end
    return true
end

local function FindNearestTarget()
    local Character = LocalPlayer.Character 
    if not Character or not Character:FindFirstChild("Head") then return nil end
    local MyHeadPosition = Character:FindFirstChild("Head").CFrame.Position
    local ClosestTargetRootPart = nil
    local SmallestDistance = math.huge

    for _, Player in ipairs(Players:GetPlayers()) do
        local TargetCharacter = Player.Character
        local RootPart = TargetCharacter and TargetCharacter:FindFirstChild("HumanoidRootPart") 
        local AimPart = TargetCharacter and GetTargetPart(TargetCharacter)
        
        if not RootPart or not AimPart or not IsTargetValid(RootPart) then continue end
        local TargetPosition = RootPart.Position 
        local Distance = (MyHeadPosition - TargetPosition).Magnitude
        if Distance > MaxAimDistance then continue end

        local CameraVector = Camera.CFrame.LookVector
        local TargetVector = (AimPart.Position - Camera.CFrame.Position).unit 
        local Angle = math.deg(math.acos(CameraVector:Dot(TargetVector)))
        if Angle > CurrentFOV then continue end 
        
        if Distance < SmallestDistance then
            SmallestDistance = Distance
            ClosestTargetRootPart = RootPart
        end
    end
    return ClosestTargetRootPart
end

local function AimFunction()
    if not Camera or not LocalPlayer.Character or not IsAimbotEnabled then return end
    
    local TargetRootPart = FindNearestTarget()
    
    if TargetRootPart then 
        local AimPart = GetTargetPart(TargetRootPart.Parent)
        if AimPart then
            local TargetPosition = GetPredictedPosition(AimPart, 1500) 
            local TargetCFrame = CFrame.new(Camera.CFrame.Position, TargetPosition)
            Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, AimingSpeed)
        end
    end
end

local function StartAiming()
    if AimConnection then return end 
    AimConnection = RunService.RenderStepped:Connect(AimFunction)
    print("[DIX INFO] Aimbot Activated.")
end

-- ====================================================================
-- [HITBOX CORE] (Team Check включен)
-- ====================================================================
local function ApplyHitboxExpansion(Player)
    local Character = Player.Character
    if not Character or Player == LocalPlayer then return end
    
    -- Team Check
    if IsTeamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then return end
    
    for _, PartName in ipairs(Hitbox_Parts_To_Change) do
        local Part = Character:FindFirstChild(PartName, true)
        if Part and Part:IsA("BasePart") then 
            local key = Part:GetFullName()
            if not Original_Sizes[key] then Original_Sizes[key] = Part.Size end
            Part.Size = Original_Sizes[key] * Hitbox_Multiplier
        end
    end
end
local function RevertHitboxExpansion(Player)
    local Character = Player.Character
    if not Character then return end
    for _, PartName in ipairs(Hitbox_Parts_To_Change) do
        local Part = Character:FindFirstChild(PartName, true)
        local key = Part and Part:GetFullName()
        if Part and Original_Sizes[key] then
            Part.Size = Original_Sizes[key]
            Original_Sizes[key] = nil 
        end
    end
end
local function HitboxLoop()
    if not Hitbox_Enabled then return end
    for _, Player in ipairs(Players:GetPlayers()) do ApplyHitboxExpansion(Player) end
end
local function StartHitbox()
    if Hitbox_Connections.Heartbeat then return end 
    Hitbox_Connections.PlayerAdded = Players.PlayerAdded:Connect(ApplyHitboxExpansion)
    Hitbox_Connections.PlayerRemoving = Players.PlayerRemoving:Connect(RevertHitboxExpansion)
    Hitbox_Connections.Heartbeat = RunService.Heartbeat:Connect(HitboxLoop)
    print("[DIX INFO] Hitbox Expander Activated.")
end
local function StopHitbox()
    if Hitbox_Connections.Heartbeat then Hitbox_Connections.Heartbeat:Disconnect() Hitbox_Connections.Heartbeat = nil end
    if Hitbox_Connections.PlayerAdded then Hitbox_Connections.PlayerAdded:Disconnect() Hitbox_Connections.PlayerAdded = nil end
    if Hitbox_Connections.PlayerRemoving then Hitbox_Connections.PlayerRemoving:Disconnect() Hitbox_Connections.PlayerRemoving = nil end
    for _, Player in ipairs(Players:GetPlayers()) do RevertHitboxExpansion(Player) end
    print("[DIX INFO] Hitbox Expander Deactivated.")
end

-- ====================================================================
-- [ESP CORE]
-- ====================================================================
local function ClearDrawingsAndHighlights()
    if Drawing then for _, drawing in pairs(ESPDrawings) do if drawing and drawing.Remove then drawing:Remove() end end end
    ESPDrawings = {}
    for _, highlight in pairs(ESPHighlights) do if highlight and highlight.Parent then highlight:Destroy() end end
    ESPHighlights = {}
}
local function SetupHighlight(Player)
    local Character = Player.Character
    if not Character then return end
    local HighlightObject = ESPHighlights[Player.Name]
    if not HighlightObject then
        HighlightObject = Instance.new("Highlight")
        HighlightObject.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        HighlightObject.FillTransparency = 0.5 HighlightObject.OutlineTransparency = 0 
        HighlightObject.Parent = Character
        ESPHighlights[Player.Name] = HighlightObject
    end
    HighlightObject.FillColor = ESPColor
    HighlightObject.OutlineColor = ESPColor
    HighlightObject.Enabled = true
    HighlightObject.Parent = Character 
end
local function DisableHighlight(Player)
    local HighlightObject = ESPHighlights[Player.Name]
    if HighlightObject and HighlightObject.Parent then HighlightObject.Enabled = false HighlightObject:Destroy() ESPHighlights[Player.Name] = nil end
    if Drawing and ESPDrawings[Player.Name .. "_Name"] then ESPDrawings[Player.Name .. "_Name"]:Remove() ESPDrawings[Player.Name .. "_Name"] = nil end
    if Drawing and ESPDrawings[Player.Name .. "_Distance"] then ESPDrawings[Player.Name .. "_Distance"]:Remove() ESPDrawings[Player.Name .. "_Distance"] = nil end
end

local function DrawPlayerInfo(Player)
    if not Drawing then return end
    local Character = Player.Character
    local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
    local Head = Character and Character:FindFirstChild("Head")
    if not RootPart or not Head then return end

    local HeadPos, HeadOnScreen = Camera:WorldToScreenPoint(Head.Position)
    local RootPos, RootOnScreen = Camera:WorldToScreenPoint(RootPart.Position)

    if not HeadOnScreen or not RootOnScreen then return end 

    local Distance = math.floor((RootPart.Position - LocalPlayer.Character.PrimaryPart.Position).Magnitude)
    
    local BottomY = math.max(HeadPos.Y, RootPos.Y) 
    local CenterX = RootPos.X 
    
    local Y_Offset_Start = BottomY + 5 

    if IsESPNameEnabled and Drawing then
        local NameText = ESPDrawings[Player.Name .. "_Name"]
        if not NameText then NameText = Drawing.new("Text") NameText.Size = 12 NameText.Outline = true NameText.Font = Drawing.Fonts.UI NameText.TextAlignment = Drawing.Alignments.Center ESPDrawings[Player.Name .. "_Name"] = NameText end
        NameText.Text = Player.Name
        NameText.Position = Vector2.new(CenterX, Y_Offset_Start) 
        NameText.Color = ESPColor
        NameText.Visible = true
    end
    
    if IsESPDistanceEnabled and Drawing then
        local DistanceText = ESPDrawings[Player.Name .. "_Distance"]
        if not DistanceText then DistanceText = Drawing.new("Text") DistanceText.Size = 10 DistanceText.Outline = true DistanceText.Font = Drawing.Fonts.UI DistanceText.TextAlignment = Drawing.Alignments.Center ESPDrawings[Player.Name .. "_Distance"] = DistanceText end
        DistanceText.Text = tostring(Distance) .. "m"
        DistanceText.Position = Vector2.new(CenterX, Y_Offset_Start + 15) 
        DistanceText.Color = ESPColor
        DistanceText.Visible = true
    end
end

local function ESPLoop()
    if not IsESPEnabled or not LocalPlayer.Character then 
        ClearDrawingsAndHighlights()
        return 
    end
    
    -- Скрываем все Drawing
    if Drawing then for name, drawing in pairs(ESPDrawings) do if drawing.Visible then drawing.Visible = false end end end
    local CurrentPlayerNames = {}
    
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            
            local ShouldHighlight = true
            if IsESPTeamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then
                ShouldHighlight = false 
            end
            
            if ShouldHighlight then
                SetupHighlight(Player)
                DrawPlayerInfo(Player)
                table.insert(CurrentPlayerNames, Player.Name)
            else
                DisableHighlight(Player) 
            end
        else
            DisableHighlight(Player) 
        end
    end
    
    -- Очищаем неиспользуемые хайлайты
    for name, _ in pairs(ESPHighlights) do
        local found = false
        for _, currentName in ipairs(CurrentPlayerNames) do
            if currentName == name then found = true; break end
        end
        if not found then DisableHighlight(Players:FindFirstChild(name)) end
    end
end
local function StartESP()
    if ESPConnection then return end 
    ESPConnection = RunService.RenderStepped:Connect(ESPLoop)
    print("[DIX INFO] ESP Activated (Highlight + Text).")
end
local function StopESP()
    if ESPConnection then
        ESPConnection:Disconnect()
        ESPConnection = nil
    end
    ClearDrawingsAndHighlights()
    print("[DIX INFO] ESP Deactivated.")
end

-- ====================================================================
-- [[ STARTUP ]]
-- ====================================================================

StartAiming() 
StartHitbox() 
StartESP()

print("[DIX SUCCESS] V42.7 (ESP Core) запущен.")
