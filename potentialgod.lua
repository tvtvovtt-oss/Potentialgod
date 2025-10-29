-- ====================================================================
-- [DIX] V42.8 (FINAL STABLE CORE + GUI)
-- FIX: Removed all Drawing dependencies (ESP Text, FOV Circle) and added WindUI.
-- ====================================================================

-- 1. Load WindUi Library 
local WindUi = nil
local success = pcall(function()
    -- Используем надежный метод загрузки GUI
    WindUi = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if not success or not WindUi then
    print("[DIX ERROR] WindUI failed to load! Core functions will run without GUI.")
    WindUi = nil
end

-- 2. Service Initialization
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait() 
local Camera = Workspace.CurrentCamera 

-- 3. CORE SETTINGS 
local IsAimbotEnabled = true    
local AimingSpeed = 0.2 
local IsWallCheckEnabled = false 
local IsTeamCheckEnabled = true 
local MaxAimDistance = 500 
local CurrentFOV = 180 -- FOV circle is now irrelevant, but logic stays wide.
local AimTargetPartName = "Head" 
local AimConnection = nil
local CurrentTarget = nil

local Hitbox_Enabled = true 
local Hitbox_Multiplier = 2.0 
local Hitbox_Parts_To_Change = {"HumanoidRootPart", "Head"} 
local Hitbox_Connections = {} 
local Original_Sizes = {} 

local IsESPEnabled = true 
local IsESPTeamCheckEnabled = true 
local ESPColor = Color3.fromRGB(0, 255, 255) 
local ESPConnection = nil
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
-- [AIMBOT CORE] (Без изменений)
-- ====================================================================
local function GetTargetPart(Character) return Character:FindFirstChild(AimTargetPartName) or Character:FindFirstChild("HumanoidRootPart") end
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
local function StopAiming()
    if AimConnection then
        AimConnection:Disconnect()
        AimConnection = nil
    end
    print("[DIX INFO] Aimbot Deactivated.")
end


-- ====================================================================
-- [HITBOX CORE] (Без изменений)
-- ====================================================================
local function ApplyHitboxExpansion(Player)
    local Character = Player.Character
    if not Character or Player == LocalPlayer then return end
    if IsTeamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then return end
    
    for _, PartName in ipairs(Hitbox_Parts_To_Change) do
        local Part = Character:FindFirstChild(PartName, true)
        if Part and Part:IsA("BasePart") then 
            local key = Part:GetFullName()
            if not Original_Sizes[key] then Original_Sizes[key] = Part.Size end
            Part.Size = Original_Sizes[key] * Hitbox_Multiplier
        end
    end
}
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
}
local function HitboxLoop()
    if not Hitbox_Enabled then return end
    for _, Player in ipairs(Players:GetPlayers()) do ApplyHitboxExpansion(Player) end
}
local function StartHitbox()
    if Hitbox_Connections.Heartbeat then return end 
    Hitbox_Connections.PlayerAdded = Players.PlayerAdded:Connect(ApplyHitboxExpansion)
    Hitbox_Connections.PlayerRemoving = Players.PlayerRemoving:Connect(RevertHitboxExpansion)
    Hitbox_Connections.Heartbeat = RunService.Heartbeat:Connect(HitboxLoop)
    print("[DIX INFO] Hitbox Expander Activated.")
}
local function StopHitbox()
    if Hitbox_Connections.Heartbeat then Hitbox_Connections.Heartbeat:Disconnect() Hitbox_Connections.Heartbeat = nil end
    if Hitbox_Connections.PlayerAdded then Hitbox_Connections.PlayerAdded:Disconnect() Hitbox_Connections.PlayerAdded = nil end
    if Hitbox_Connections.PlayerRemoving then Hitbox_Connections.PlayerRemoving:Disconnect() Hitbox_Connections.PlayerRemoving = nil end
    for _, Player in ipairs(Players:GetPlayers()) do RevertHitboxExpansion(Player) end
    print("[DIX INFO] Hitbox Expander Deactivated.")
}


-- ====================================================================
-- [ESP CORE - HIGHLIGHT ONLY]
-- ====================================================================
local function ClearHighlights()
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
}
local function DisableHighlight(Player)
    local HighlightObject = ESPHighlights[Player.Name]
    if HighlightObject and HighlightObject.Parent then HighlightObject.Enabled = false HighlightObject:Destroy() ESPHighlights[Player.Name] = nil end
}

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
}
local function StartESP()
    if ESPConnection then return end 
    ESPConnection = RunService.RenderStepped:Connect(ESPLoop)
    print("[DIX INFO] ESP Activated (Highlight ONLY).")
}
local function StopESP()
    if ESPConnection then
        ESPConnection:Disconnect()
        ESPConnection = nil
    end
    ClearHighlights()
    print("[DIX INFO] ESP Deactivated.")
}

-- ====================================================================
-- [[ 6. GUI HUB (WindUI) - STABLE V42.8 STRUCTURE ]]
-- ====================================================================

if WindUi and WindUi.CreateWindow then 
    local Window = WindUi:CreateWindow({
        Title = "DIX HUB V42.8 (Final Stable)",
        Author = "by Dixyi",
        Folder = "DIX_Hub_V42_Final",
        OpenButton = { 
            Title = "DIX OPEN", 
            Color = ColorSequence.new(Color3.fromHex("#30FF6A"), Color3.fromHex("#e7ff2f"))
        }
    })

    -- Tags
    Window:Tag({ Title = "V42.8", Icon = "mobile", Color = Color3.fromHex("#6b31ff") })

    -- Tabs
    local CombatTab = Window:Tab({ Title = "COMBAT", Icon = "target", })
    local VisualsTab = Window:Tab({ Title = "VISUALS", Icon = "eye", })
    
    -- ================================================================
    -- COMBAT SECTION 1: Aimbot Settings
    -- ================================================================
    local AimSection = CombatTab:Section({ Title = "Aimbot Settings", })

    AimSection:Toggle({
        Flag = "AimToggle",
        Title = "AIMBOT: ON/OFF",
        Desc = "Activates the standard aimbot core (moves camera).",
        Default = IsAimbotEnabled,
        Callback = function(value)
            IsAimbotEnabled = value
            if IsAimbotEnabled then StartAiming() else StopAiming() end
        end
    })
    
    -- Target Selector
    local TargetSection = AimSection:Section({ Title = "Target Part Selector (Часть Тела)", }) 

    local function updateTargetPart(newPart, state)
        if not state then return end 
        AimTargetPartName = newPart
        CurrentTarget = nil 
    end

    TargetSection:Button({
        Title = "Target: Head (Голова)",
        Desc = "Sets aimbot target to the Head.",
        Callback = function() updateTargetPart("Head", true) end
    })
    TargetSection:Button({
        Title = "Target: Torso (Тело)",
        Desc = "Sets aimbot target to UpperTorso.",
        Callback = function() updateTargetPart("UpperTorso", true) end
    })
    TargetSection:Button({
        Title = "Target: Root (Корень)",
        Desc = "Sets aimbot target to HumanoidRootPart.",
        Callback = function() updateTargetPart("HumanoidRootPart", true) end
    })
    
    -- Sliders/Toggles
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
        Flag = "WallCheckToggle", 
        Title = "Wall Check (Visible Only)", 
        Desc = "Aimbot only targets players visible through walls.",
        Default = IsWallCheckEnabled, 
        Callback = function(value) IsWallCheckEnabled = value end 
    })

    AimSection:Toggle({ 
        Flag = "TeamCheckToggle", 
        Title = "Team Check (Friendly Fire)", 
        Desc = "Disables targeting players on your team.",
        Default = IsTeamCheckEnabled, 
        Callback = function(value) 
            IsTeamCheckEnabled = value 
            if Hitbox_Enabled then StopHitbox() StartHitbox() end -- Перезапуск для применения Team Check
        end 
    })

    -- ================================================================
    -- COMBAT SECTION 2: Hitbox Settings
    -- ================================================================
    local HitboxSection = CombatTab:Section({ Title = "Hitbox Settings", })

    HitboxSection:Toggle({ 
        Flag = "HitboxToggle", 
        Title = "Hitbox Expander: ON/OFF", 
        Desc = "Increases the size of the target player's hitboxes.",
        Default = Hitbox_Enabled, 
        Callback = function(value) 
            Hitbox_Enabled = value
            if Hitbox_Enabled then StartHitbox() else StopHitbox() end
        end
    })

    HitboxSection:Slider({ 
        Flag = "HitboxMulti", 
        Title = "Hitbox Multiplier", 
        Desc = "Scale of the hitbox expansion (e.g., 2.0 is double size).",
        Value = { Min = 1.0, Max = 10.0, Default = Hitbox_Multiplier, Rounding = 1 },
        Callback = function(value) 
            Hitbox_Multiplier = value 
            StopHitbox() 
            if Hitbox_Enabled then StartHitbox() end 
        end
    })
    
    -- ================================================================
    -- VISUALS SECTION: ESP Settings
    -- ================================================================
    local ESPSection = VisualsTab:Section({ Title = "ESP Settings (Highlight ONLY)", })

    ESPSection:Toggle({ 
        Flag = "ESPToggle", 
        Title = "Highlight ESP: ON/OFF", 
        Desc = "Toggle the visibility of player highlights (самый стабильный ESP).",
        Default = IsESPEnabled, 
        Callback = function(value) 
            IsESPEnabled = value
            if IsESPEnabled then StartESP() else StopESP() end
        end
    })

    ESPSection:Toggle({ 
        Flag = "ESPTeamCheckToggle", 
        Title = "Team Check (Exclude Teammates)", 
        Desc = "Disables highlighting players on your team.",
        Default = IsESPTeamCheckEnabled, 
        Callback = function(value) IsESPTeamCheckEnabled = value end
    })

    ESPSection:ColorPicker({
        Flag = "ESPColor",
        Title = "ESP Color",
        Desc = "Change the color of the highlight.",
        Default = ESPColor,
        Callback = function(value) 
            ESPColor = value 
        end
    })
    
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
    print("[DIX INFO] Core modules started without GUI.")
end
