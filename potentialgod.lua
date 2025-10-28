-- ====================================================================
-- [DIX] FINAL SCRIPT V30.1 (Target Refactor) - АВАРИЙНЫЙ ГУИ
-- ПОЧИНКА: Многоуровневая загрузка WindUi + Fallback на стандартный Roblox GUI
-- ====================================================================

-- 1. Load WindUi Library (Многоуровневая загрузка с Fallback)
local WindUi = nil

local function TryLoadWindUi()
    local success, errorMessage = pcall(function()
        -- Метод 1: Оригинальная загрузка (часто блокируется)
        local rawCode = game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua")
        if rawCode then
            return loadstring(rawCode)()
        end
        return nil
    end)
    return success and errorMessage or nil
end

WindUi = TryLoadWindUi()

if not WindUi then
    warn("[DIX WARNING] WindUi Failed to load. Activating Fallback GUI.")

    -- ================================================================
    -- FALLBACK GUI: Минимальный рабочий интерфейс на Roblox ScreenGui
    -- (Активирует ядро, но без продвинутых настроек WindUi)
    -- ================================================================
    
    local FallbackGui = Instance.new("ScreenGui")
    FallbackGui.Name = "DIX_Fallback_GUI"
    FallbackGui.Parent = LocalPlayer.PlayerGui

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 200, 0, 100)
    Frame.Position = UDim2.new(0.5, -100, 0.5, -50)
    Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Frame.BorderSizePixel = 0
    Frame.Parent = FallbackGui

    local TextLabel = Instance.new("TextLabel")
    TextLabel.Size = UDim2.new(1, 0, 0, 20)
    TextLabel.Text = "DIX V30.1 CORE (Fallback Mode)"
    TextLabel.BackgroundColor3 = Color3.fromRGB(255, 72, 48)
    TextLabel.TextColor3 = Color3.new(1, 1, 1)
    TextLabel.Parent = Frame

    local ToggleAim = Instance.new("TextButton")
    ToggleAim.Size = UDim2.new(1, 0, 0, 40)
    ToggleAim.Position = UDim2.new(0, 0, 0, 20)
    ToggleAim.Text = "Aimbot: OFF"
    ToggleAim.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    ToggleAim.Parent = Frame
    
    local ToggleESP = Instance.new("TextButton")
    ToggleESP.Size = UDim2.new(1, 0, 0, 40)
    ToggleESP.Position = UDim2.new(0, 0, 0, 60)
    ToggleESP.Text = "Glow ESP: OFF"
    ToggleESP.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    ToggleESP.Parent = Frame

    ToggleAim.MouseButton1Click:Connect(function()
        IsAimbotEnabled = not IsAimbotEnabled
        ToggleAim.Text = "Aimbot: " .. (IsAimbotEnabled and "ON" or "OFF")
        ToggleAim.BackgroundColor3 = IsAimbotEnabled and Color3.fromRGB(30, 180, 30) or Color3.fromRGB(80, 80, 80)
        if IsAimbotEnabled then StartAiming() else StopAiming() end
    end)

    ToggleESP.MouseButton1Click:Connect(function()
        IsESPEnabled = not IsESPEnabled
        ToggleESP.Text = "Glow ESP: " .. (IsESPEnabled and "ON" or "OFF")
        ToggleESP.BackgroundColor3 = IsESPEnabled and Color3.fromRGB(30, 180, 30) or Color3.fromRGB(80, 80, 80)
        if IsESPEnabled then StartESP() else StopESP() end
    end)
    
    -- Установка начальных значений для Fallback
    IsAimbotEnabled = false
    IsESPEnabled = false
    AimTargetPartName = "Head" -- Фиксированная цель
    IsTeamCheckEnabled = true
    IsWallCheckEnabled = true
    AimingSpeed = 0.3
    ESPColor = Color3.fromRGB(255, 0, 255)
end

-- 2. Service Initialization (Остальной код ядра остается неизменным)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait() 
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera 
local Drawing = pcall(function() return Drawing end) and Drawing or nil 

-- 3. Configuration Variables (Оставлены для ядра)
local ConfigName = "DIX_HUB_V30_CONFIG"

-- Aimbot Settings
local IsAimbotEnabled = WindUi and false or IsAimbotEnabled -- Настройки берутся из Fallback, если WindUi не загрузился
local AimingSpeed = WindUi and 0.2 or AimingSpeed
local IsWallCheckEnabled = WindUi and true or IsWallCheckEnabled
local IsTeamCheckEnabled = WindUi and true or IsTeamCheckEnabled
local MaxAimDistance = 500 
local CurrentFOV = WindUi and 45 or 60
local AimTargetPartName = WindUi and "Head" or AimTargetPartName

local AimConnection = nil
local CurrentTarget = nil    

-- ESP Settings 
local IsESPEnabled = WindUi and false or IsESPEnabled
local IsESPNameEnabled = true
local IsESPDistanceEnabled = true
local IsESPTeamCheckEnabled = WindUi and true or IsESPTeamCheckEnabled
local ESPColor = WindUi and Color3.fromRGB(255, 255, 0) or ESPColor
local ESPConnection = nil
local ESPDrawings = {} 
local ESPHighlights = {} 

-- 4. Hitbox Settings (Disabled functions remain)
local function StartHitbox() print("[DIX WARNING] Hitbox Expander Disabled for Stability.") end
local function StopHitbox() print("[DIX WARNING] Hitbox Expander Disabled for Stability.") end

-- ====================================================================
-- [DIX CONFIG CORE] - Save & Load (WindUi-зависимые)
-- ====================================================================

local function SaveConfig()
    if not WindUi or not WindUi.SaveSettings then return end
    
    local settingsTable = {
        IsAimbotEnabled = IsAimbotEnabled,
        AimingSpeed = AimingSpeed,
        IsWallCheckEnabled = IsWallCheckEnabled,
        IsTeamCheckEnabled = IsTeamCheckEnabled,
        CurrentFOV = CurrentFOV,
        AimTargetPartName = AimTargetPartName,
        
        IsESPEnabled = IsESPEnabled,
        IsESPNameEnabled = IsESPNameEnabled,
        IsESPDistanceEnabled = IsESPDistanceEnabled,
        IsESPTeamCheckEnabled = IsESPTeamCheckEnabled,
        
        ESPColorR = ESPColor.R,
        ESPColorG = ESPColor.G,
        ESPColorB = ESPColor.B,
    }

    WindUi:SaveSettings(ConfigName, settingsTable)
    print("[DIX INFO] Configuration saved successfully to: " .. ConfigName)
end

local function LoadConfig()
    if not WindUi or not WindUi.LoadSettings then return end
    
    local loadedSettings = WindUi:LoadSettings(ConfigName)
    if not loadedSettings then
        print("[DIX INFO] No saved configuration found. Using default values.")
        return
    end

    print("[DIX INFO] Loading saved configuration...")
    
    IsAimbotEnabled = loadedSettings.IsAimbotEnabled or IsAimbotEnabled
    AimingSpeed = loadedSettings.AimingSpeed or AimingSpeed
    IsWallCheckEnabled = loadedSettings.IsWallCheckEnabled or IsWallCheckEnabled
    IsTeamCheckEnabled = loadedSettings.IsTeamCheckEnabled or IsTeamCheckEnabled
    CurrentFOV = loadedSettings.CurrentFOV or CurrentFOV
    AimTargetPartName = loadedSettings.AimTargetPartName or AimTargetPartName

    IsESPEnabled = loadedSettings.IsESPEnabled or IsESPEnabled
    IsESPNameEnabled = loadedSettings.IsESPNameEnabled or IsESPNameEnabled
    IsESPDistanceEnabled = loadedSettings.IsESPDistanceEnabled or IsESPDistanceEnabled
    IsESPTeamCheckEnabled = loadedSettings.IsESPTeamCheckEnabled or IsESPTeamCheckEnabled
    
    local r = loadedSettings.ESPColorR or ESPColor.R
    local g = loadedSettings.ESPColorG or ESPColor.G
    local b = loadedSettings.ESPColorB or ESPColor.B
    ESPColor = Color3.fromRGB(r * 255, g * 255, b * 255) 
    
    print("[DIX INFO] Configuration loaded successfully.")
end

-- ====================================================================
-- [DIX FOV MODULE V30.1] (Требует Drawing)
-- ====================================================================

local FOVDrawing = nil 

local function UpdateFOVVisual()
    if not Drawing then return end
    
    if not FOVDrawing then
        FOVDrawing = Drawing.new("Circle")
        FOVDrawing.Thickness = 2
        FOVDrawing.Color = Color3.fromRGB(0, 255, 255)
        FOVDrawing.Filled = false 
        FOVDrawing.Transparency = 0.5
        FOVDrawing.ZIndex = 1
        FOVDrawing.Visible = false 
    end
    
    local ScreenSize = Camera.ViewportSize
    local Center = Vector2.new(ScreenSize.X / 2, ScreenSize.Y / 2)
    
    local CameraFOV = Camera.FieldOfView
    local Radius = (math.tan(math.rad(CurrentFOV) / 2) / math.tan(math.rad(CameraFOV) / 2)) * (ScreenSize.Y / 2)
    
    FOVDrawing.Radius = Radius
    FOVDrawing.Position = Center
    FOVDrawing.Visible = IsAimbotEnabled and Drawing 
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
    local SmallestAngle = CurrentFOV + 1

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
            if Angle < SmallestAngle then
                SmallestAngle = Angle
                ClosestTargetRootPart = RootPart
            end
        end
    end
    return ClosestTargetRootPart
end

local function AimFunction()
    if not Camera or not LocalPlayer.Character or not IsAimbotEnabled then 
        CurrentTarget = nil 
        UpdateFOVVisual()
        return 
    end
    UpdateFOVVisual()

    local TargetRootPart = nil
    local MyHeadPosition = LocalPlayer.Character:FindFirstChild("Head") and LocalPlayer.Character.Head.CFrame.Position
    
    if CurrentTarget and CurrentTarget.Parent and IsTargetValid(CurrentTarget) then
        local AimPart = GetTargetPart(CurrentTarget.Parent)
        if AimPart then
            local AimPosition = AimPart.Position
            local CameraVector = Camera.CFrame.LookVector
            local TargetVector = (AimPosition - Camera.CFrame.Position).unit
            local Angle = math.deg(math.acos(CameraVector:Dot(TargetVector)))
            
            local PassesWallCheck = not IsWallCheckEnabled 
            if IsWallCheckEnabled then PassesWallCheck = IsTargetVisible(MyHeadPosition, CurrentTarget) end
            
            if PassesWallCheck and (MyHeadPosition - CurrentTarget.Position).Magnitude <= MaxAimDistance and Angle <= CurrentFOV * 1.5 then 
                 TargetRootPart = CurrentTarget
            else
                 CurrentTarget = nil
            end
        end
    end

    if not TargetRootPart then
        TargetRootPart = FindNearestTarget()
        if TargetRootPart then CurrentTarget = TargetRootPart end
    end

    if TargetRootPart then
        local AimPart = GetTargetPart(TargetRootPart.Parent)
        if AimPart then
            local TargetPosition = AimPart.Position 
            local TargetCFrame = CFrame.new(Camera.CFrame.Position, TargetPosition)
            Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, AimingSpeed)
        end
    end
end

local function StartAiming()
    if AimConnection then return end 
    AimConnection = RunService.RenderStepped:Connect(AimFunction)
    UpdateFOVVisual()
}

local function StopAiming()
    if AimConnection then
        AimConnection:Disconnect()
        AimConnection = nil
        CurrentTarget = nil 
    end
    UpdateFOVVisual()
}

-- ====================================================================
-- [ESP Core Functions]
-- ====================================================================

local function ClearDrawingsAndHighlights()
    if Drawing then
        for _, drawing in pairs(ESPDrawings) do if drawing and drawing.Remove then drawing:Remove() end end
        ESPDrawings = {}
        if FOVDrawing then FOVDrawing:Remove() FOVDrawing = nil end
    end
    for _, highlight in pairs(ESPHighlights) do if highlight and highlight.Parent then highlight:Destroy() end end
    ESPHighlights = {}
}

local function SetupHighlight(Player)
    local HighlightObject = ESPHighlights[Player.Name]
    local Character = Player.Character
    
    if not HighlightObject and Character then
        HighlightObject = Instance.new("Highlight")
        HighlightObject.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        HighlightObject.FillTransparency = 0.5 
        HighlightObject.OutlineTransparency = 0 
        HighlightObject.Parent = Character
        ESPHighlights[Player.Name] = HighlightObject
    end
    
    if HighlightObject then
        HighlightObject.FillColor = ESPColor
        HighlightObject.OutlineColor = ESPColor
        HighlightObject.Enabled = true
        HighlightObject.Parent = Character 
    end
}

local function DisableHighlight(Player)
    local HighlightObject = ESPHighlights[Player.Name]
    if HighlightObject and HighlightObject.Parent then
        HighlightObject.Enabled = false
        HighlightObject:Destroy() 
        ESPHighlights[Player.Name] = nil
    end
    if Drawing then
        if ESPDrawings[Player.Name .. "_Name"] then ESPDrawings[Player.Name .. "_Name"]:Remove() ESPDrawings[Player.Name .. "_Name"] = nil end
        if ESPDrawings[Player.Name .. "_Distance"] then ESPDrawings[Player.Name .. "_Distance"]:Remove() ESPDrawings[Player.Name .. "_Distance"] = nil end
    end
}

local function DrawPlayerInfo(Player)
    if not Drawing then return end
    
    local Character = Player.Character
    local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
    local Head = Character and Character:FindFirstChild("Head")
    if not RootPart or not Head then return end

    local HeadPos, HeadOnScreen = Camera:WorldToScreenPoint(Head.Position)
    
    local Distance = math.floor((RootPart.Position - LocalPlayer.Character.PrimaryPart.Position).Magnitude)
    local CenterX = HeadPos.X 
    
    if not HeadOnScreen then return end 

    if IsESPNameEnabled then
        local NameText = ESPDrawings[Player.Name .. "_Name"]
        if not NameText then
            NameText = Drawing.new("Text")
            NameText.Size = 12
            NameText.Outline = true
            NameText.Font = Drawing.Fonts.UI
            NameText.Center = true
            ESPDrawings[Player.Name .. "_Name"] = NameText
        end
        NameText.Text = Player.Name
        NameText.Position = Vector2.new(CenterX, HeadPos.Y - 20) 
        NameText.Color = ESPColor
        NameText.Visible = true
    end
    
    if IsESPDistanceEnabled then
        local DistanceText = ESPDrawings[Player.Name .. "_Distance"]
        if not DistanceText then
            DistanceText = Drawing.new("Text")
            DistanceText.Size = 10
            DistanceText.Outline = true
            DistanceText.Font = Drawing.Fonts.UI
            DistanceText.Center = true
            ESPDrawings[Player.Name .. "_Distance"] = DistanceText
        end
        DistanceText.Text = tostring(Distance) .. "m"
        DistanceText.Position = Vector2.new(CenterX, HeadPos.Y - 5) 
        DistanceText.Color = ESPColor
        DistanceText.Visible = true
    end
}

local function ESPLoop()
    if not IsESPEnabled then 
        if Drawing then
            for name, drawing in pairs(ESPDrawings) do if drawing.Visible then drawing.Visible = false end end
        end
        for name, highlight in pairs(ESPHighlights) do DisableHighlight(Players:FindFirstChild(name)) end
        return 
    end
    
    if Drawing then
        for name, drawing in pairs(ESPDrawings) do
            if drawing.Visible then drawing.Visible = false end
        end
    end

    local CurrentPlayerNames = {}
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChild("Head") then
            
            local ShouldHighlight = true
            if IsESPTeamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then
                ShouldHighlight = false 
            end
            
            if ShouldHighlight then
                SetupHighlight(Player)
                if Drawing then DrawPlayerInfo(Player) end
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
        if not found then
            DisableHighlight(Players:FindFirstChild(name))
        end
    end
}

local function StartESP()
    if ESPConnection then return end 
    ESPConnection = RunService.RenderStepped:Connect(ESPLoop)
    Players.PlayerAdded:Connect(function(Player)
        Player.CharacterAdded:Connect(function(Character)
            task.wait(0.5) 
            if IsESPEnabled then SetupHighlight(Player) end
        end)
    end)
}

local function StopESP()
    if ESPConnection then
        ESPConnection:Disconnect()
        ESPConnection = nil
    end
    ClearDrawingsAndHighlights()
}

-- ====================================================================
-- [[ 6. GUI HUB (WindUI) ]]
-- ====================================================================

if WindUi then
    
    LoadConfig() -- Загрузка конфига

    local Window = WindUi:CreateWindow({
        Title = "DIX HUB V30.1 (Target Refactor)",
        Author = "by Dixyi",
        Folder = "DIX_Hub_V30_Final",
        OpenButton = { Title = "DIX OPEN", Color = ColorSequence.new(Color3.fromHex("#FF4830"), Color3.fromHex("#FFBB30")) }
    })
    
    Window:Tag({ Title = "V30.1R", Icon = "flash", Color = Color3.fromHex("#00BFFF") })

    local CombatTab = Window:Tab({ Title = "COMBAT", Icon = "target", })
    local VisualsTab = Window:Tab({ Title = "VISUALS", Icon = "eye", })
    local UtilityTab = Window:Tab({ Title = "UTILITY", Icon = "tool", })

    
    -- (Весь код секций GUI остается неизменным)
    -- ================================================================
    -- COMBAT SECTION 1: Aimbot Settings
    -- ================================================================
    local AimSection = CombatTab:Section({ Title = "Aimbot Settings (Core)", })

    AimSection:Toggle({
        Flag = "AimToggle",
        Title = "AIMBOT: ON/OFF",
        Desc = "Activates the aimbot core and FOV Visualizer.",
        Default = IsAimbotEnabled,
        Callback = function(value)
            IsAimbotEnabled = value
            if IsAimbotEnabled then StartAiming() else StopAiming() end
            SaveConfig()
        end
    })
    
    AimSection:Slider({ 
        Flag = "FOV", 
        Title = "Aim FOV (Visual Circle)", 
        Desc = "Radius of the aimbot's field of vision (5 - 180 degrees).",
        Value = { Min = 5, Max = 180, Default = CurrentFOV, Step = 5 }, 
        Callback = function(value) 
            CurrentFOV = math.round(value)
            UpdateFOVVisual() 
            SaveConfig()
        end 
    })
    
    AimSection:Slider({ 
        Flag = "Speed", 
        Title = "Aim Speed (Smoothness)", 
        Value = { Min = 0.1, Max = 1.0, Default = AimingSpeed, Step = 0.05 }, 
        Callback = function(value) 
            AimingSpeed = math.round(value * 100) / 100 
            SaveConfig()
        end 
    })
    
    AimSection:Toggle({ 
        Flag = "WallCheck", 
        Title = "Wall Check", 
        Default = IsWallCheckEnabled, 
        Callback = function(value) 
            IsWallCheckEnabled = value 
            SaveConfig()
        end 
    })
    
    AimSection:Toggle({ 
        Flag = "TeamCheck", 
        Title = "Team Check", 
        Default = IsTeamCheckEnabled, 
        Callback = function(value) 
            IsTeamCheckEnabled = value 
            SaveConfig()
        end 
    })
    
    -- ================================================================
    -- COMBAT SECTION 2: Target Part Selector (Исправленное расположение)
    -- ================================================================
    local TargetSection = CombatTab:Section({ Title = "Target Part Selector", }) 

    TargetSection:Dropdown({
        Flag = "TargetPartDropdown",
        Title = "Target Part",
        Options = { "Head", "UpperTorso", "HumanoidRootPart" },
        Default = AimTargetPartName,
        Callback = function(selectedOption)
            AimTargetPartName = selectedOption
            CurrentTarget = nil 
            print("[DIX INFO] Target part set to: " .. selectedOption)
            SaveConfig()
        end
    })
    
    -- ================================================================
    -- COMBAT SECTION 3: Hitbox Expander Settings (Disabled)
    -- ================================================================
    CombatTab:Section({ Title = "Hitbox Expander (Disabled)", }):Button({
        Title = "Hitbox Expander Disabled",
        Desc = "Функция отключена из-за критических ошибок (зависания).",
        Color = Color3.fromHex("#880000"),
        Callback = function() 
            print("[DIX WARNING] Hitbox Expander Disabled. Reactivate only if game is stable.")
        end
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
            SaveConfig()
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
            SaveConfig()
        end
    })
    
    ESPSection:Toggle({
        Flag = "ESPNameToggle",
        Title = "Draw Name",
        Default = IsESPNameEnabled,
        Callback = function(value) 
            IsESPNameEnabled = value 
            SaveConfig()
        end
    })
    
    ESPSection:Toggle({
        Flag = "ESPDistanceToggle",
        Title = "Draw Distance",
        Default = IsESPDistanceEnabled,
        Callback = function(value) 
            IsESPDistanceEnabled = value 
            SaveConfig()
        end
    })

    -- Color Picker
    ESPSection:ColorPicker({
        Flag = "ESPColor",
        Title = "Glow Color",
        Default = ESPColor,
        Callback = function(color) 
            ESPColor = color
            if IsESPEnabled then ESPLoop() end
            SaveConfig()
        end
    })
    
    -- ================================================================
    -- UTILITY SECTION 1: Config & Cleanup
    -- ================================================================
    local UtilitySection = UtilityTab:Section({ Title = "Configuration", })
    
    UtilitySection:Button({
        Title = "SAVE CONFIG",
        Desc = "Сохранить текущие настройки для автоматической загрузки.",
        Color = Color3.fromHex("#32CD32"),
        Callback = SaveConfig
    })
    
    UtilitySection:Button({
        Title = "LOAD CONFIG (Manual)",
        Desc = "Загрузить сохраненные настройки (происходит автоматически при запуске).",
        Color = Color3.fromHex("#FFD700"),
        Callback = function()
            LoadConfig()
            Window:Sync() 
            if IsAimbotEnabled then StartAiming() else StopAiming() end
            if IsESPEnabled then StartESP() else StopESP() end
        end
    })


    -- Window Closing Cleanup
    Window:OnClose(function()
        StopAiming()
        StopESP()
    end)

    if IsAimbotEnabled then StartAiming() end
    if IsESPEnabled then StartESP() end

    print("DIX HUB V30.1 Refactored launched.")
else
    -- Запуск ядер для Fallback GUI
    if IsAimbotEnabled then StartAiming() end
    if IsESPEnabled then StartESP() end
    print("DIX HUB V30.1 запущен в Fallback режиме.")
end
