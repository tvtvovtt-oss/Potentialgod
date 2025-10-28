Я понял. Проблема, должно быть, в том, что в последних версиях загружался либо нерабочий скрипт, либо пример GUI, а не сама библиотека, которая позволяет создавать ваши вкладки.
Я возвращаюсь к наиболее надежной ссылке на библиотеку WindUI и интегрирую весь ваш рабочий функционал (Combat, Visuals, Silent Aim с мобильной оптимизацией).
Эта версия должна гарантированно отобразить ваши вкладки.
[DIX] FINAL SCRIPT V38.0 (STABLE GUI REVERT & MOBILE)
-- ====================================================================
-- [DIX] FINAL SCRIPT V38.0 (STABLE GUI REVERT & MOBILE)
-- FIX: Reverting WindUI loadstring to the stable main file link.
-- Core logic and mobile optimization are preserved.
-- ====================================================================

-- 1. Load WindUi Library (Using the stable link to ensure library loads correctly)
local success, WindUi = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if not success or not WindUi then
    print("[DIX ERROR] WindUI failed to load! GUI is unavailable. Core functions may still run.")
    print("Error details: " .. tostring(WindUi))
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
local Drawing = pcall(function() return Drawing end) and Drawing or nil
local ReplicatedStorage = game:GetService("ReplicatedStorage") 

-- 3. Aimbot Settings
local IsAimbotEnabled = false
local IsSilentAimEnabled = false
local AimingSpeed = 0.2 
local IsWallCheckEnabled = true 
local IsTeamCheckEnabled = true 
local MaxAimDistance = 500 
local CurrentFOV = 45 

local AimTargetPartName = "Head" 
local Target_Head = true 
local Target_UpperTorso = false
local Target_HumanoidRootPart = false 

local AimConnection = nil
local CurrentTarget = nil    

-- 4. Hitbox Settings 
local Hitbox_Enabled = false 
local Hitbox_Multiplier = 2.0 
local Hitbox_Parts_To_Change = {"HumanoidRootPart", "Head"} 
local Hitbox_Connections = {} 
local Original_Sizes = {} 

-- 5. ESP Settings 
local IsESPEnabled = false
local IsESPNameEnabled = true
local IsESPDistanceEnabled = true
local IsESPTeamCheckEnabled = true 
local ESPColor = Color3.fromRGB(0, 255, 255) 
local ESPConnection = nil
local ESPDrawings = {} 
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
    return not raycastResult or Players:GetPlayerFromCharacter(raycastResult.Instance:FindFirstAncestorOfClass("Model")) == Players:GetPlayerFromCharacter(TargetCharacter)
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

local function AimFunction()
    if not Camera or not LocalPlayer.Character or (not IsAimbotEnabled and not IsSilentAimEnabled) then 
        CurrentTarget = nil 
        return 
    end
    
    local TargetRootPart = nil
    local MyHeadPosition = LocalPlayer.Character:FindFirstChild("Head") and LocalPlayer.Character.Head.CFrame.Position
    if not MyHeadPosition then return end
    
    TargetRootPart = FindNearestTarget()
    if TargetRootPart then CurrentTarget = TargetRootPart end
    
    if IsAimbotEnabled and not IsSilentAimEnabled and TargetRootPart then
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
end

local function StopAiming()
    if AimConnection then
        AimConnection:Disconnect()
        AimConnection = nil
        CurrentTarget = nil 
    end
end

-- ====================================================================
-- [SILENT AIM HANDLER] - CRITICAL BYPASS STRUCTURE
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
                    local originalRaycast
                    RaycastHook = hookfunction(Workspace.Raycast, function(self, origin, direction, params)
                        originalRaycast = RaycastHook 
                        
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

-- Listener for M1 (Left Mouse Button/Touch) or SPACE (Virtual Jump Button)
ContextActionService:BindAction("SilentAimShot", function(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        -- Mobile check: MouseButton1 is usually the touch tap, Space is often the virtual Jump button.
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
end

local function StopHitbox()
    if Hitbox_Connections.Heartbeat then Hitbox_Connections.Heartbeat:Disconnect() Hitbox_Connections.Heartbeat = nil end
    if Hitbox_Connections.PlayerAdded then Hitbox_Connections.PlayerAdded:Disconnect() Hitbox_Connections.PlayerAdded = nil end
    if Hitbox_Connections.PlayerRemoving then Hitbox_Connections.PlayerRemoving:Disconnect() Hitbox_Connections.PlayerRemoving = nil end
    for _, Player in ipairs(Players:GetPlayers()) do
        RevertHitboxExpansion(Player)
    end
end

-- ====================================================================
-- [ESP Core Functions] 
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
    local Character = Player.Character
    local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
    local Head = Character and Character:FindFirstChild("Head")
    if not RootPart or not Head then return end

    local HeadPos, HeadOnScreen = Camera:WorldToScreenPoint(Head.Position)
    if not HeadOnScreen then return end 

    local Distance = math.floor((RootPart.Position - LocalPlayer.Character.PrimaryPart.Position).Magnitude)
    local CenterX = HeadPos.X
    
    if IsESPNameEnabled and Drawing then
        local NameText = ESPDrawings[Player.Name .. "_Name"]
        if not NameText then NameText = Drawing.new("Text") NameText.Size = 12 NameText.Outline = true NameText.Font = Drawing.Fonts.UI ESPDrawings[Player.Name .. "_Name"] = NameText end
        NameText.Text = Player.Name
        NameText.Position = Vector2.new(CenterX, HeadPos.Y - 20) 
        NameText.Color = ESPColor
        NameText.Visible = true
    end
    
    if IsESPDistanceEnabled and Drawing then
        local DistanceText = ESPDrawings[Player.Name .. "_Distance"]
        if not DistanceText then DistanceText = Drawing.new("Text") DistanceText.Size = 10 DistanceText.Outline = true DistanceText.Font = Drawing.Fonts.UI ESPDrawings[Player.Name .. "_Distance"] = DistanceText end
        DistanceText.Text = tostring(Distance) .. "m"
        DistanceText.Position = Vector2.new(CenterX, HeadPos.Y - 5) 
        DistanceText.Color = ESPColor
        DistanceText.Visible = true
    end
end
local function ESPLoop()
    if not IsESPEnabled or not LocalPlayer.Character or not Drawing then 
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
end
local function StopESP()
    if ESPConnection then
        ESPConnection:Disconnect()
        ESPConnection = nil
    end
    ClearDrawingsAndHighlights()
end


-- ====================================================================
-- [[ 6. GUI HUB (WindUI) - INTEGRATED LOGIC ]]
-- ====================================================================

if WindUi and WindUi.CreateWindow then 
    local Window = WindUi:CreateWindow({
        Title = "DIX HUB V38.0 (Mobile)",
        Author = "by Dixyi",
        Folder = "DIX_Hub_V38_Final",
        OpenButton = { 
            Title = "DIX OPEN", 
            Color = ColorSequence.new(Color3.fromHex("#30FF6A"), Color3.fromHex("#e7ff2f"))
        }
    })

    -- Tags
    Window:Tag({ Title = "V38.0", Icon = "mobile", Color = Color3.fromHex("#6b31ff") })

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
    
    -- Target Selector (Toggles)
    local TargetSection = AimSection:Section({ Title = "Target Part Selector", }) 

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
    AimSection:Slider({ 
        Flag = "FOV", 
        Title = "Aim FOV", 
        Desc = "Radius of the aimbot's field of vision (5 - 180 degrees).",
        Value = { Min = 5, Max = 180, Default = CurrentFOV, Step = 5 }, 
        Callback = function(value) CurrentFOV = math.round(value) end 
    })
    AimSection:Slider({ 
        Flag = "Speed", 
        Title = "Aim Speed (Smoothness)", 
        Value = { Min = 0.1, Max = 1.0, Default = AimingSpeed, Step = 0.05 }, 
        Callback = function(value) AimingSpeed = math.round(value * 100) / 100 end 
    })
    AimSection:Toggle({ 
        Flag = "WallCheck", 
        Title = "Wall Check", 
        Default = IsWallCheckEnabled, 
        Callback = function(value) IsWallCheckEnabled = value end 
    })
    AimSection:Toggle({ 
        Flag = "TeamCheck", 
        Title = "Team Check", 
        Default = IsTeamCheckEnabled, 
        Callback = function(value) IsTeamCheckEnabled = value end 
    })

    
    -- ================================================================
    -- COMBAT SECTION 2: Hitbox Expander Settings
    -- ================================================================
    local HitboxSection = CombatTab:Section({ Title = "Hitbox Expander Settings", })

    HitboxSection:Toggle({
        Flag = "HitboxToggle",
        Title = "Hitbox Expander: ON/OFF",
        Desc = "Locally increases the size of enemy hitboxes (HRT/Head).",
        Default = Hitbox_Enabled,
        Callback = function(value)
            Hitbox_Enabled = value
            if Hitbox_Enabled then StartHitbox() else StopHitbox() end
        end
    })
    
    HitboxSection:Slider({ 
        Flag = "Multiplier", 
        Title = "Hitbox Multiplier (Size)", 
        Desc = "How many times the hitbox should be increased (1.1x to 5x).",
        Value = { Min = 1.1, Max = 5.0, Default = Hitbox_Multiplier, Step = 0.1 }, 
        Callback = function(value) Hitbox_Multiplier = math.round(value * 10) / 10 end 
    })
    
    -- ================================================================
    -- VISUALS SECTION 1: ESP Settings (GLOW)
    -- ================================================================
    local ESPSection = VisualsTab:Section({ Title = "Player ESP (Glow/Chams)", })

    ESPSection:Toggle({
        Flag = "ESPToggle",
        Title = "GLOW ESP: ON/OFF",
        Desc = "Highlights enemy models with color.",
        Default = IsESPEnabled,
        Callback = function(value)
            IsESPEnabled = value
            if IsESPEnabled then StartESP() else StopESP() end
        end
    })
    
    ESPSection:Toggle({
        Flag = "ESPTeamCheckToggle",
        Title = "Team Check",
        Desc = "Do not highlight teammates.",
        Default = IsESPTeamCheckEnabled,
        Callback = function(value) 
            IsESPTeamCheckEnabled = value 
            if IsESPEnabled then ESPLoop() end
        end
    })
    
    ESPSection:Toggle({
        Flag = "ESPNameToggle",
        Title = "Draw Name",
        Default = IsESPNameEnabled,
        Callback = function(value) IsESPNameEnabled = value end
    })
    
    ESPSection:Toggle({
        Flag = "ESPDistanceToggle",
        Title = "Draw Distance",
        Default = IsESPDistanceEnabled,
        Callback = function(value) IsESPDistanceEnabled = value end
    })

    -- Color Picker
    ESPSection:ColorPicker({
        Flag = "ESPColor",
        Title = "Glow Color",
        Default = ESPColor,
        Callback = function(color) 
            ESPColor = color
            if IsESPEnabled then ESPLoop() end
        end
    })


    -- Window Closing Cleanup
    Window:OnClose(function()
        StopAiming()
        StopHitbox()
        StopESP()
        ContextActionService:UnbindAction("SilentAimShot")
        if RaycastHook then RaycastHook = nil end 
    end)
    
    print("DIX HUB V38.0 GUI SUCCESSFULLY LAUNCHED (Mobile Ready).")
else
    print("[DIX CRITICAL ERROR] WindUI loading failed. GUI is not available.")
end


-- Start functions if enabled by default (Safety check)
if IsAimbotEnabled or IsSilentAimEnabled then StartAiming() end
if Hitbox_Enabled then StartHitbox() end
if IsESPEnabled then StartESP() end

print("DIX HUB V38.0 Core logic initialized.")

