[DIX]:
-- ====================================================================
-- [DIX] FINAL SCRIPT V41.8 (HARDENED CORE-ONLY)
-- FIX: Removed all dependencies on 'Drawing' and 'WindUI' for max compatibility.
-- Core functions (Aimbot/Hitbox/Highlight ESP) are guaranteed to run.
-- ====================================================================

-- 1. Service Initialization
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait() 
local Camera = Workspace.CurrentCamera 

-- ====================================================================
-- 2. CORE SETTINGS (Aimbot & Hitbox - FORCED ON)
-- ====================================================================
local IsAimbotEnabled = true    
local AimingSpeed = 0.2 
local IsWallCheckEnabled = false 
local IsTeamCheckEnabled = true 
local MaxAimDistance = 500 
local CurrentFOV = 180 
local AimTargetPartName = "Head" 
local AimConnection = nil
local CurrentTarget = nil    

local Hitbox_Enabled = true -- Forced ON
local Hitbox_Multiplier = 2.0 
local Hitbox_Parts_To_Change = {"HumanoidRootPart", "Head", "UpperTorso"} 
local Hitbox_Connections = {} 
local Original_Sizes = {} 

local IsESPEnabled = true -- Forced ON (Only Highlight)
local IsESPTeamCheckEnabled = true 
local ESPColor = Color3.fromRGB(0, 255, 255) 
local ESPConnection = nil
local ESPHighlights = {} 

-- ====================================================================
-- [HELPER: PREDICATION & BYPASS LOGIC] 
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
    
    if (PredictedPosition - TargetPosition).Magnitude > 20 then
        return TargetPosition 
    end
    
    return PredictedPosition
end

-- ====================================================================
-- [Aimbot Core Functions]
-- ====================================================================

local function GetTargetPart(Character) 
    local part = Character:FindFirstChild(AimTargetPartName) 
    if not part and AimTargetPartName ~= "HumanoidRootPart" then
        return Character:FindFirstChild("HumanoidRootPart")
    end
    return part
end

local function IsTargetValid(TargetPart)
    local Player = Players:GetPlayerFromCharacter(TargetPart.Parent)
    if not Player then return false end
    local TargetCharacter = Player.Character
    if not TargetCharacter or not TargetCharacter:FindFirstChildOfClass("Humanoid") or TargetCharacter.Humanoid.Health <= 0 then return false end
    if Player == LocalPlayer then return false end
    if IsTeamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then return false end
    if not GetTargetPart(TargetCharacter) then return false end
    return true
end

local function IsTargetVisible(Origin, TargetPart)
    local TargetCharacter = TargetPart.Parent
    local AimPart = GetTargetPart(TargetCharacter) 
    if not AimPart then return false end
    
    local TargetPosition = AimPart.Position 
    local RaycastParams = RaycastParams.new()
    RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
    RaycastParams.FilterDescendantsInstances = {LocalPlayer.Character, TargetCharacter}
    local Direction = TargetPosition - Origin
    local raycastResult = Workspace:Raycast(Origin, Direction.unit * (Origin - TargetPosition).Magnitude, RaycastParams)
    
    if not raycastResult then return true end
    
    local HitModel = raycastResult.Instance:FindFirstAncestorOfClass("Model")
    if HitModel and HitModel == TargetCharacter then return true end
    
    return false 
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
        local AimPosition = AimPart.Position
        local TargetVector = (AimPosition - Camera.CFrame.Position).unit 
        local Angle = math.deg(math.acos(CameraVector:Dot(TargetVector)))
        if IsAimbotEnabled and Angle > CurrentFOV then continue end 

        local PassesWallCheck = not IsWallCheckEnabled 
        if IsWallCheckEnabled then PassesWallCheck = IsTargetVisible(MyHeadPosition, RootPart) end
        
        if PassesWallCheck then
            if Angle < math.deg(math.acos(CameraVector:Dot((ClosestTargetRootPart and GetTargetPart(ClosestTargetRootPart.Parent) or RootPart).Position - Camera.CFrame.Position).unit)) or not ClosestTargetRootPart then
                SmallestDistance = Distance
                ClosestTargetRootPart = RootPart
            end
        end
    end
    return ClosestTargetRootPart
end

local function AimFunction()
    if not Camera or not LocalPlayer.Character or not IsAimbotEnabled then 
        CurrentTarget = nil 
        return 
    end
    
    local TargetRootPart = nil
    local MyHeadPosition = LocalPlayer.Character:FindFirstChild("Head") and LocalPlayer.Character.Head.CFrame.Position
    if not MyHeadPosition then return end
    
    TargetRootPart = FindNearestTarget()
    if TargetRootPart then CurrentTarget = TargetRootPart end
    
    if IsAimbotEnabled and TargetRootPart then
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
    print("[DIX INFO] Aimbot Activated (Head/180 FOV).")
end

local function StopAiming()
    if AimConnection then
        AimConnection:Disconnect()
        AimConnection = nil
        CurrentTarget = nil 
    end
    print("[DIX INFO] Aimbot Deactivated.")
end

-- ====================================================================
-- [Hitbox Expander Core Functions] 
-- ====================================================================

local function ApplyHitboxExpansion(Player)
    local Character = Player.Character
    if not Character then return end
    
    local function isPlayerTargetable(p)
        if not p or p == LocalPlayer then return false end
        local c = p.Character
        if not c or not c:FindFirstChildOfClass("Humanoid") or c.Humanoid.Health <= 0 then return false end
        if IsTeamCheckEnabled and LocalPlayer.Team and p.Team and LocalPlayer.Team == p.Team then return false end
        return true
    end
    
    if not isPlayerTargetable(Player) then return end
    
    for _, PartName in ipairs(Hitbox_Parts_To_Change) do
        local Part = Character:FindFirstChild(PartName, true)
        
        if Part and Part:IsA("BasePart") and Part.Name ~= "HumanoidRootPart" then 
            if not Original_Sizes[Part:GetFullName()] then
                 Original_Sizes[Part:GetFullName()] = Part.Size
            end
            Part.Size = Original_Sizes[Part:GetFullName()] * Hitbox_Multiplier
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
    for _, Player in ipairs(Players:GetPlayers()) do
        ApplyHitboxExpansion(Player)
    end
end

local function StartHitbox()
    if Hitbox_Connections.Heartbeat then return end 
    Hitbox_Connections.PlayerAdded = Players.PlayerAdded:Connect(ApplyHitboxExpansion)
    Hitbox_Connections.PlayerRemoving = Players.PlayerRemoving:Connect(RevertHitboxExpansion)
    Hitbox_Connections.Heartbeat = RunService.Heartbeat:Connect(HitboxLoop)
    print("[DIX INFO] Hitbox Expander Activated (x2.0).")
end

local function StopHitbox()
    if Hitbox_Connections.Heartbeat then Hitbox_Connections.Heartbeat:Disconnect() Hitbox_Connections.Heartbeat = nil end
    if Hitbox_Connections.PlayerAdded then Hitbox_Connections.PlayerAdded:Disconnect() Hitbox_Connections.PlayerAdded = nil end
    if Hitbox_Connections.PlayerRemoving then Hitbox_Connections.PlayerRemoving:Disconnect() Hitbox_Connections.PlayerRemoving = nil end
    for _, Player in ipairs(Players:GetPlayers()) do
        RevertHitboxExpansion(Player)
    end
    print("[DIX INFO] Hitbox Expander Deactivated.")
end

-- ====================================================================
-- [Highlight ESP Core Functions] 
-- (Не требует Drawing)
-- ====================================================================

local function ClearHighlights()
    for _, highlight in pairs(ESPHighlights) do if highlight and highlight.Parent then highlight:Destroy() end end
    ESPHighlights = {}
end
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
end

local function ESPLoop()
    if not IsESPEnabled or not LocalPlayer.Character then 
        ClearHighlights()
        return 
    end
    
    local CurrentPlayerNames = {}
    
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            
            local ShouldHighlight = true
            if IsESPTeamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then
                ShouldHighlight = false 
            end
            
            if ShouldHighlight then
                SetupHighlight(Player)
                table.insert(CurrentPlayerNames, Player.Name)
            else
                DisableHighlight(Player) 
            end
        else
            DisableHighlight(Player) 
        end
    end
    
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
    print("[DIX INFO] Highlight ESP Activated.")
end
local function StopESP()
    if ESPConnection then
        ESPConnection:Disconnect()
        ESPConnection = nil
    end
    ClearHighlights()
    print("[DIX INFO] Highlight ESP Deactivated.")
end


-- ====================================================================
-- [[ 3. Initial Call - HARDENED STARTUP ]]
-- ====================================================================

-- Гарантированный запуск Aimbot, Hitbox и Highlight ESP.
StartAiming() 
StartHitbox() 
StartESP()    

print("[DIX SUCCESS] Скрипт V41.8 активирован. Основной функционал запущен.")
