-- ====================================================================
-- [DIX] FINAL SCRIPT V41.1-FIX (AIMBOT DEBUG)
-- FIX: IsWallCheckEnabled set to FALSE and FOV set to 180 for immediate target acquisition.
-- ====================================================================

-- 1. Load WindUi Library (UPDATED: Direct execution)
-- Load WindUi Library
local WindUi = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- 2. Service Initialization
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService") 
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait() 
local Camera = Workspace.CurrentCamera 
-- ПРОВЕРКА: Drawing должен быть доступен в твоем эксплойте для FOV Circle и ESP Text
local Drawing = pcall(function() return Drawing end) and Drawing or nil
local ReplicatedStorage = game:GetService("ReplicatedStorage") 

-- 3. Aimbot Settings
local IsAimbotEnabled = true    -- Forced ON
local IsSilentAimEnabled = true -- Forced ON
local AimingSpeed = 0.2 
local IsWallCheckEnabled = false -- 🛑 ИЗМЕНЕНИЕ ДЛЯ ДИАГНОСТИКИ
local IsTeamCheckEnabled = true 
local MaxAimDistance = 500 
local CurrentFOV = 180 -- 🛑 ИЗМЕНЕНИЕ ДЛЯ ДИАГНОСТИКИ
local AimTargetPartName = "Head" 
local Target_Head = true 
local Target_UpperTorso = false
local Target_HumanoidRootPart = false 
local AimConnection = nil
local CurrentTarget = nil    
local IsFOVVisualEnabled = true 
local FOV_Circle = nil 

-- 4. Hitbox Settings 
local Hitbox_Enabled = false 
local Hitbox_Multiplier = 2.0 
local Hitbox_Parts_To_Change = {"HumanoidRootPart", "Head"} 
local Hitbox_Connections = {} 
local Original_Sizes = {} 

-- 5. ESP Settings 
local IsESPEnabled = true 
local IsESPNameEnabled = true
local IsESPDistanceEnabled = true
local IsESPTeamCheckEnabled = true 
local ESPColor = Color3.fromRGB(0, 255, 255) 
local ESPConnection = nil
local ESPDrawings = {} 
local ESPHighlights = {} 

-- ====================================================================
-- [HELPER: PREDICATION & BYPASS LOGIC] 
-- (Без изменений)
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
-- (Без изменений, кроме Debug Print)
-- ====================================================================
local function GetTargetPart(Character) return Character:FindFirstChild(AimTargetPartName) end
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
    
    -- Упрощенная проверка: либо нет попадания, либо попали в модель цели
    local HitModel = raycastResult and raycastResult.Instance:FindFirstAncestorOfClass("Model")
    return not raycastResult or (HitModel == TargetCharacter) 
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
        if Angle > CurrentFOV then continue end 

        local PassesWallCheck = not IsWallCheckEnabled 
        if IsWallCheckEnabled then PassesWallCheck = IsTargetVisible(MyHeadPosition, RootPart) end
        
        if PassesWallCheck then
            if Distance < SmallestDistance then
                SmallestDistance = Distance
                ClosestTargetRootPart = RootPart
            end
        end
    end
    return ClosestTargetRootPart
end

local function UpdateFOVVisual()
    if not Drawing or not Camera or not IsFOVVisualEnabled then
        if FOV_Circle then FOV_Circle.Visible = false end
        return
    end

    if not FOV_Circle then
        FOV_Circle = Drawing.new("Circle")
        FOV_Circle.Color = Color3.new(1, 1, 1) 
        FOV_Circle.Thickness = 1
        FOV_Circle.Filled = false
        FOV_Circle.ZIndex = 1
    end

    local viewportSize = Camera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local radius = ((math.tan(math.rad(CurrentFOV)) / math.tan(math.rad(Camera.FieldOfView))) * viewportSize.Y) / 2
    
    FOV_Circle.Radius = radius
    FOV_Circle.Position = screenCenter
    FOV_Circle.Visible = true
end

local function StopFOVVisual()
    if FOV_Circle then
        FOV_Circle.Visible = false
    end
end

local function AimFunction()
    if not Camera or not LocalPlayer.Character or (not IsAimbotEnabled and not IsSilentAimEnabled) then 
        CurrentTarget = nil 
        StopFOVVisual()
        return 
    end
    
    local TargetRootPart = nil
    local MyHeadPosition = LocalPlayer.Character:FindFirstChild("Head") and LocalPlayer.Character.Head.CFrame.Position
    if not MyHeadPosition then return end
    
    TargetRootPart = FindNearestTarget()
    
    -- 🛑 ДЕБАГ: Печатаем, нашел ли Aimbot цель
    if TargetRootPart then 
        CurrentTarget = TargetRootPart
        print("[DIX DEBUG] Aimbot Target Found: " .. TargetRootPart.Parent.Name)
    else
        CurrentTarget = nil
        -- print("[DIX DEBUG] Aimbot No Target Found.")
    end
    
    if IsAimbotEnabled and not IsSilentAimEnabled and TargetRootPart then
        local AimPart = GetTargetPart(TargetRootPart.Parent)
        if AimPart then
            local TargetPosition = GetPredictedPosition(AimPart, 1500) 
            local TargetCFrame = CFrame.new(Camera.CFrame.Position, TargetPosition)
            Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, AimingSpeed)
        end
    end
    
    UpdateFOVVisual()
end
-- (StartAiming, StopAiming, Silent Aim Handler, Hitbox, ESP - Без изменений)
-- ... [Hitbox Expander Core Functions]
-- ... [ESP Core Functions] 
-- ... [GUI HUB]

if WindUi and WindUi.CreateWindow then 
    local Window = WindUi:CreateWindow({
        Title = "DIX HUB V41.1-FIX (Aimbot Debug)",
        Author = "by Dixyi",
        Folder = "DIX_Hub_V41_Final",
        OpenButton = { 
            Title = "DIX OPEN", 
            Color = ColorSequence.new(Color3.fromHex("#30FF6A"), Color3.fromHex("#e7ff2f"))
        }
    })
    
    -- ... (Вся структура GUI, как в V41.1, с измененными дефолтами для WallCheck/FOV)
    -- ...
    
    -- Target Selector
    local TargetSection = CombatTab:Section({ Title = "Target Part Selector (Часть Тела)", }) 

    local function updateTargetPart(newPart, state)
        if not state then if newPart == AimTargetPartName then return end end

        Target_Head = false
        Target_UpperTorso = false
        Target_HumanoidRootPart = false

        if newPart == "Head" then
            Target_Head = true
            AimTargetPartName = "Head"
        elseif newPart == "UpperTorso" then
            Target_UpperTorso = true
            AimTargetPartName = "UpperTorso"
        elseif newPart == "HumanoidRootPart" then
            Target_HumanoidRootPart = true
            AimTargetPartName = "HumanoidRootPart"
        end

        CurrentTarget = nil 
        
        Window:GetToggle("Target_Head_Toggle"):Set(Target_Head)
        Window:GetToggle("Target_UpperTorso_Toggle"):Set(Target_UpperTorso)
        Window:GetToggle("Target_HRT_Toggle"):Set(Target_HumanoidRootPart)
    end
    
    TargetSection:Toggle({
        Flag = "Target_Head_Toggle",
        Title = "Target: Head (Голова)",
        Default = Target_Head,
        Callback = function(value) updateTargetPart("Head", value) end
    })
    TargetSection:Toggle({
        Flag = "Target_UpperTorso_Toggle",
        Title = "Target: Torso (Тело)",
        Default = Target_UpperTorso,
        Callback = function(value) updateTargetPart("UpperTorso", value) end
    })
    TargetSection:Toggle({
        Flag = "Target_HRT_Toggle",
        Title = "Target: Root (Корень)",
        Default = Target_HumanoidRootPart,
        Callback = function(value) updateTargetPart("HumanoidRootPart", value) end
    })
    
    local AimSection = CombatTab:Section({ Title = "Aimbot Settings", })
    
    AimSection:Toggle({
        Flag = "AimToggle",
        Title = "AIMBOT: ON/OFF (Standard)",
        Desc = "Activates the standard aimbot core (moves camera).",
        Default = IsAimbotEnabled,
        Callback = function(value)
            IsAimbotEnabled = value
            if IsAimbotEnabled or IsSilentAimEnabled then StartAiming() else StopAiming() end
        end
    })
    
    AimSection:Toggle({ 
        Flag = "SilentAimToggle", 
        Title = "Silent AIM: ON/OFF", 
        Desc = "Uses bypass structure. Trigger with **Touch/M1** or **Virtual Jump Button (Mobile)**.", 
        Default = IsSilentAimEnabled, 
        Callback = function(value) 
            IsSilentAimEnabled = value 
            if IsAimbotEnabled or IsSilentAimEnabled then StartAiming() else StopAiming() end
        end 
    })
    
    AimSection:Toggle({ 
        Flag = "WallCheckToggle", 
        Title = "Wall Check (Visible Only)", 
        Desc = "Aimbot/Silent Aim only targets players visible through walls.",
        Default = IsWallCheckEnabled, 
        Callback = function(value) IsWallCheckEnabled = value end 
    })
    
    AimSection:Slider({ 
        Flag = "FOV", 
        Title = "Aim FOV", 
        Desc = "Radius of the aimbot's field of vision (5 - 180 degrees).",
        Value = { Min = 5, Max = 180, Default = CurrentFOV },
        Callback = function(value) CurrentFOV = value end
    })

    AimSection:Slider({ 
        Flag = "AimSpeed", 
        Title = "Aim Speed (Lerp)", 
        Desc = "How smoothly the camera moves (0.01 = slow, 1.0 = instant).",
        Value = { Min = 0.01, Max = 1.0, Default = AimingSpeed, Rounding = 2 },
        Callback = function(value) AimingSpeed = value end
    })
    
    AimSection:Toggle({ 
        Flag = "TeamCheckToggle", 
        Title = "Team Check (Friendly Fire)", 
        Desc = "Disables targeting players on your team.",
        Default = IsTeamCheckEnabled, 
        Callback = function(value) IsTeamCheckEnabled = value end 
    })
    -- ... (Остальные секции GUI)
    
end

-- ====================================================================
-- [[ 7. Initial Call - GUARANTEED STARTUP ]]
-- ====================================================================

StartAiming() 
StartHitbox() 
StartESP()    

if WindUi and WindUi.CreateWindow then 
    StopAiming()
    StopHitbox()
    StopESP()
    StartAiming() 
    StartHitbox() 
    StartESP() 
    print("[DIX INFO] GUI Loaded. Core modules synced with GUI settings.")
else
    print("[DIX INFO] Core modules started with default debug settings (Wall Check OFF, FOV 180).")
end
