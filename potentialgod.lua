-- ====================================================================
-- [DIX] FINAL SCRIPT V41.1-FINAL (AIMBOT DEBUG + Custom GUI Loader)
-- ACTION: Using user's GUI loader and checking for Aimbot target acquisition.
-- ====================================================================

-- 1. Load WindUi Library (UPDATED: Using user's direct execution style with pcall protection)
local WindUi = nil
local success = pcall(function()
    -- 🛑 ИСПОЛЬЗУЕМ ВАШУ СТРОКУ ЗАГРУЗКИ:
    WindUi = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if not success or not WindUi then
    print("[DIX ERROR] WindUI failed to load! Only core functions will run.")
    print("Error details (if any): " .. tostring(WindUi))
    WindUi = nil 
end

-- 2. Service Initialization
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService") 
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait() 
local Camera = Workspace.CurrentCamera 
-- ПРОВЕРКА: Drawing должен быть доступен
local Drawing = pcall(function() return Drawing end) and Drawing or nil
local ReplicatedStorage = game:GetService("ReplicatedStorage") 

-- 3. Aimbot Settings
local IsAimbotEnabled = true    -- Forced ON
local IsSilentAimEnabled = true -- Forced ON
local AimingSpeed = 0.2 
local IsWallCheckEnabled = false -- 🛑 DEBUG: Wall Check OFF
local IsTeamCheckEnabled = true 
local MaxAimDistance = 500 
local CurrentFOV = 180 -- 🛑 DEBUG: Wide FOV
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
-- ====================================================================
local function GetTargetPart(Character) 
    local part = Character:FindFirstChild(AimTargetPartName) 
    if not part then return Character:FindFirstChild("HumanoidRootPart") end
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

local function StartAiming()
    if AimConnection then return end 
    AimConnection = RunService.RenderStepped:Connect(AimFunction)
    print("[DIX INFO] Aimbot/Silent Aim Activated.")
end

local function StopAiming()
    if AimConnection then
        AimConnection:Disconnect()
        AimConnection = nil
        CurrentTarget = nil 
    end
    StopFOVVisual()
    print("[DIX INFO] Aimbot/Silent Aim Deactivated.")
end

-- ====================================================================
-- [SILENT AIM HANDLER] 
-- (Без изменений)
-- ====================================================================

local IsBypassActive = false
local RaycastHook = nil 

local function HandleSilentAimShot()
    if not IsSilentAimEnabled or not LocalPlayer.Character then return end
    
    local TargetRootPart = FindNearestTarget() 
    
    if TargetRootPart then
        local AimPart = GetTargetPart(TargetRootPart.Parent)
        
        if AimPart and AimPart:IsA("BasePart") then
            
            local PredictedPosition = GetPredictedPosition(AimPart, 1500) 
            
            if hookfunction and Workspace.Raycast and AimPart.CFrame then 
                IsBypassActive = true
                
                if not RaycastHook then
                    RaycastHook = hookfunction(Workspace.Raycast, function(self, origin, direction, params)
                        
                        if IsSilentAimEnabled and IsBypassActive and AimPart.Parent and AimPart.CFrame then
                            
                            local TargetVector = PredictedPosition - origin
                            local TargetDirection = TargetVector.unit
                            
                            return RaycastHook(self, origin, TargetDirection, params)
                            
                        else
                            return RaycastHook(self, origin, direction, params)
                        end
                    end)
                    
                    print("[DIX INFO] Silent Aim: Raycast hook applied.")
                end
            else
                 print("[DIX WARNING] Silent Aim: Cannot apply Raycast hook (Missing 'hookfunction' or 'Workspace.Raycast').")
            end

            task.delay(0.1, function()
                IsBypassActive = false
            end)
            
        end
    end
end

ContextActionService:BindAction("SilentAimShot", function(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.KeyCode == Enum.KeyCode.Space then
             if IsSilentAimEnabled then
                 HandleSilentAimShot()
             end
        end
    end
    return Enum.ContextActionResult.Pass
end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.Space)


-- ====================================================================
-- [Hitbox Expander Core Functions] 
-- (Без изменений)
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
    print("[DIX INFO] Hitbox Expander Activated.")
}

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
-- [ESP Core Functions] 
-- (Без изменений)
-- ====================================================================
local function ClearDrawingsAndHighlights()
    for _, drawing in pairs(ESPDrawings) do if drawing and drawing.Remove then drawing:Remove() end end
    ESPDrawings = {}
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
    if ESPDrawings[Player.Name .. "_Name"] then ESPDrawings[Player.Name .. "_Name"]:Remove() ESPDrawings[Player.Name .. "_Name"] = nil end
    if ESPDrawings[Player.Name .. "_Distance"] then ESPDrawings[Player.Name .. "_Distance"]:Remove() ESPDrawings[Player.Name .. "_Distance"] = nil end
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
        if not NameText then NameText = Drawing.new("Text") NameText.Size = 12 NameText.Outline = true NameText.Font = Drawing.Fonts.UI ESPDrawings[Player.Name .. "_Name"] = NameText end
        
        NameText.Text = Player.Name
        NameText.Position = Vector2.new(CenterX, Y_Offset_Start) 
        NameText.Color = ESPColor
        NameText.Visible = true
    end
    
    if IsESPDistanceEnabled and Drawing then
        local DistanceText = ESPDrawings[Player.Name .. "_Distance"]
        if not DistanceText then DistanceText = Drawing.new("Text") DistanceText.Size = 10 DistanceText.Outline = true DistanceText.Font = Drawing.Fonts.UI ESPDrawings[Player.Name .. "_Distance"] = DistanceText end
        
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
    
    for name, drawing in pairs(ESPDrawings) do if drawing.Visible then drawing.Visible = false end end
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
    print("[DIX INFO] ESP Activated.")
}

local function StopESP()
    if ESPConnection then
        ESPConnection:Disconnect()
        ESPConnection = nil
    end
    ClearDrawingsAndHighlights()
    print("[DIX INFO] ESP Deactivated.")
end


-- ====================================================================
-- [[ 6. GUI HUB (WindUI) - STABLE V33.0 STRUCTURE ]]
-- ====================================================================

if WindUi and WindUi.CreateWindow then 
    local Window = WindUi:CreateWindow({
        Title = "DIX HUB V41.1-FINAL (Aimbot Debug)",
        Author = "by Dixyi",
        Folder = "DIX_Hub_V41_Final",
        OpenButton = { 
            Title = "DIX OPEN", 
            Color = ColorSequence.new(Color3.fromHex("#30FF6A"), Color3.fromHex("#e7ff2f"))
        }
    })

    -- Tags
    Window:Tag({ Title = "V41.1-F", Icon = "mobile", Color = Color3.fromHex("#6b31ff") })

    -- Tabs
    local CombatTab = Window:Tab({ Title = "COMBAT", Icon = "target", })
    local VisualsTab = Window:Tab({ Title = "VISUALS", Icon = "eye", })
    
    -- ================================================================
    -- COMBAT SECTION 1: Aimbot Settings
    -- ================================================================
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
    
    -- Target Selector
    local TargetSection = AimSection:Section({ Title = "Target Part Selector (Часть Тела)", }) 

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
    
    -- Sliders/Toggles
    AimSection:Toggle({ 
        Flag = "FOVVisualToggle", 
        Title = "Draw FOV Circle", 
        Desc = "Displays the FOV circle radius on your screen.",
        Default = IsFOVVisualEnabled, 
        Callback = function(value) 
            IsFOVVisualEnabled = value 
            if not IsFOVVisualEnabled then StopFOVVisual() end 
        end 
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
        Flag = "WallCheckToggle", 
        Title = "Wall Check (Visible Only)", 
        Desc = "Aimbot/Silent Aim only targets players visible through walls.",
        Default = IsWallCheckEnabled, 
        Callback = function(value) IsWallCheckEnabled = value end 
    })

    AimSection:Toggle({ 
        Flag = "TeamCheckToggle", 
        Title = "Team Check (Friendly Fire)", 
        Desc = "Disables targeting players on your team.",
        Default = IsTeamCheckEnabled, 
        Callback = function(value) IsTeamCheckEnabled = value end 
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
    local VisualsTab = Window:Tab({ Title = "VISUALS", Icon = "eye", })
    local ESPSection = VisualsTab:Section({ Title = "ESP Settings (Highlights + Text)", })

    ESPSection:Toggle({ 
        Flag = "ESPToggle", 
        Title = "ESP Visuals: ON/OFF", 
        Desc = "Toggle the visibility of all ESP features (Highlight, Name, Distance).",
        Default = IsESPEnabled, 
        Callback = function(value) 
            IsESPEnabled = value
            if IsESPEnabled then StartESP() else StopESP() end
        end
    })

    ESPSection:Toggle({ 
        Flag = "ESPNameToggle", 
        Title = "Show Name ESP", 
        Desc = "Displays the player's name below the model.",
        Default = IsESPNameEnabled, 
        Callback = function(value) IsESPNameEnabled = value end
    })

    ESPSection:Toggle({ 
        Flag = "ESPDistToggle", 
        Title = "Show Distance ESP", 
        Desc = "Displays the player's distance in meters below the name.",
        Default = IsESPDistanceEnabled, 
        Callback = function(value) IsESPDistanceEnabled = value end
    })

    ESPSection:ColorPicker({
        Flag = "ESPColor",
        Title = "ESP Color",
        Desc = "Change the color of the highlight and text.",
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
    print("[DIX INFO] Core modules started with default debug settings (Wall Check OFF, FOV 180).")
end
