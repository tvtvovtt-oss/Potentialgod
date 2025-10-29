-- ====================================================================
-- [DIX] V67.0 - Минимизированная версия (Aimbot, Hitbox, ESP)
-- ====================================================================

local WindUi = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ====================================================================
-- ИНИЦИАЛИЗАЦИЯ СЕРВИСОВ И ПЕРЕМЕННЫХ
-- ====================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RaycastParams = RaycastParams.new()
local CoreGui = game:GetService("CoreGui")

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
if Humanoid then Humanoid.Name = "DIX_Humanoid" end 

_G.aimbotEnabled = false
_G.hitboxEnabled = false
_G.espEnabled = false
_G.teamCheckEnabled = true 
_G.wallCheckEnabled = false 
_G.aimbotFOV = 150        
_G.fovCircleEnabled = true 
_G.LockedTarget = nil     
_G.aimbotSmoothness = 0.15 

_G.AimConnection = nil 
_G.ESPConnection = nil
_G.FOVConnection = nil    
_G.HitboxConnections = {} 
_G.OriginalSizes = {} 
_G.ESPHighlights = {} 
_G.ESPLabels = {}       

RaycastParams.FilterDescendantsInstances = {Character} 
RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- ====================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ====================================================================

local function GetTargetPart(Char) return Char:FindFirstChild("Head") or Char:FindFirstChild("HumanoidRootPart") end
local function GetAngleToTarget(TargetPart) 
    local CameraVector = Camera.CFrame.LookVector 
    local TargetVector = (TargetPart.Position - Camera.CFrame.Position).unit 
    return math.deg(math.acos(CameraVector:Dot(TargetVector))) 
end
local function IsTargetValid(TargetPart)
    local Player = Players:GetPlayerFromCharacter(TargetPart.Parent)
    if not Player or Player == LocalPlayer then return false end
    local TargetHumanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if not TargetHumanoid or TargetHumanoid.Health <= 0 then return false end
    if _G.teamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then return false end
    return true
end
local function IsVisible(TargetPart)
    if not _G.wallCheckEnabled then return true end
    local Origin = Camera.CFrame.Position
    local Direction = (TargetPart.Position - Origin).unit * ((TargetPart.Position - Origin).Magnitude - 0.5) 
    local RaycastResult = Workspace:Raycast(Origin, Direction, RaycastParams)
    return not RaycastResult or (RaycastResult and RaycastResult.Instance:IsDescendantOf(TargetPart.Parent))
end

-- ====================================================================
-- ЯДРО AIMBOT
-- ====================================================================

local function FindNearestTarget()
    local SmallestAngle = _G.aimbotFOV 
    local BestTarget = nil 
    if _G.LockedTarget and _G.LockedTarget.Parent and IsTargetValid(_G.LockedTarget) then
        if GetAngleToTarget(_G.LockedTarget) <= _G.aimbotFOV and IsVisible(_G.LockedTarget) then
            return _G.LockedTarget 
        else
            _G.LockedTarget = nil 
        end
    end
    for _, Player in ipairs(Players:GetPlayers()) do
        local TargetCharacter = Player.Character
        local AimPart = TargetCharacter and GetTargetPart(TargetCharacter)
        if not AimPart or not IsTargetValid(AimPart) then continue end
        if _G.wallCheckEnabled and not IsVisible(AimPart) then continue end
        local Angle = GetAngleToTarget(AimPart)
        if Angle < SmallestAngle then 
            SmallestAngle = Angle
            BestTarget = AimPart
        end
    end
    if BestTarget then _G.LockedTarget = BestTarget end
    return BestTarget
end
local function StartAimbot() 
    if not LocalPlayer.Character or _G.AimConnection then return end 
    _G.AimConnection = RunService.RenderStepped:Connect(function()
        if not _G.aimbotEnabled or not Camera.CFrame then return end 
        local AimPart = FindNearestTarget()
        if AimPart then 
            local TargetCFrame = CFrame.new(Camera.CFrame.Position, AimPart.Position)
            Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, _G.aimbotSmoothness) 
        else 
            _G.LockedTarget = nil 
        end
    end)
end
local function StopAimbot()
    if _G.AimConnection then _G.AimConnection:Disconnect() _G.AimConnection = nil end
    _G.LockedTarget = nil 
end

-- ====================================================================
-- ЯДРО HITBOX
-- ====================================================================

local function ApplyHitboxExpansion(Player)
    local Character = Player.Character
    if not Character or Player == LocalPlayer or not IsTargetValid(Character.PrimaryPart) then return end
    local Parts = {"HumanoidRootPart", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
    local Multiplier = 2.5 
    for _, PartName in ipairs(Parts) do
        local Part = Character:FindFirstChild(PartName, true)
        if Part and Part:IsA("BasePart") then 
            local key = Part:GetFullName()
            if not _G.OriginalSizes[key] then _G.OriginalSizes[key] = Part.Size end
            Part.Size = _G.OriginalSizes[key] * Multiplier
        end
    end
end
local function RevertHitboxExpansion(Player)
    local Character = Player.Character
    if not Character then return end
    local Parts = {"HumanoidRootPart", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
    for _, PartName in ipairs(Parts) do
        local Part = Character:FindFirstChild(PartName, true)
        local key = Part and Part:GetFullName()
        if Part and _G.OriginalSizes[key] then
            Part.Size = _G.OriginalSizes[key]
            _G.OriginalSizes[key] = nil 
        end
    end
end
local function StartHitbox()
    if _G.HitboxConnections.Heartbeat then return end 
    for _, Player in ipairs(Players:GetPlayers()) do ApplyHitboxExpansion(Player) end 
    _G.HitboxConnections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not _G.hitboxEnabled then return end
        for _, Player in ipairs(Players:GetPlayers()) do ApplyHitboxExpansion(Player) end
    end)
    _G.HitboxConnections.PlayerAdded = Players.PlayerAdded:Connect(function(Player)
        _G.HitboxConnections[Player.UserId] = Player.CharacterAdded:Connect(function(Character) 
            if _G.hitboxEnabled then ApplyHitboxExpansion(Player) end
        end)
    end)
    _G.HitboxConnections.PlayerRemoving = Players.PlayerRemoving:Connect(function(Player)
        RevertHitboxExpansion(Player)
        if _G.HitboxConnections[Player.UserId] then
             _G.HitboxConnections[Player.UserId]:Disconnect()
             _G.HitboxConnections[Player.UserId] = nil
        end
    end)
end
local function StopHitbox()
    if _G.HitboxConnections.Heartbeat then _G.HitboxConnections.Heartbeat:Disconnect() _G.HitboxConnections.Heartbeat = nil end
    if _G.HitboxConnections.PlayerAdded then _G.HitboxConnections.PlayerAdded:Disconnect() _G.HitboxConnections.PlayerAdded = nil end
    if _G.HitboxConnections.PlayerRemoving then _G.HitboxConnections.PlayerRemoving:Disconnect() _G.HitboxConnections.PlayerRemoving = nil end
    for _, Player in ipairs(Players:GetPlayers()) do 
        RevertHitboxExpansion(Player) 
        if _G.HitboxConnections[Player.UserId] then
             _G.HitboxConnections[Player.UserId]:Disconnect()
             _G.HitboxConnections[Player.UserId] = nil
        end
    end
end

-- ====================================================================
-- ЯДРО ESP
-- ====================================================================

local function CreateESPLabel(Player)
    local ScreenG = Instance.new("ScreenGui")
    ScreenG.Name = "DIX_ESP_" .. Player.Name
    ScreenG.IgnoreGuiInset = true
    ScreenG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenG.Enabled = false 
    ScreenG.Parent = CoreGui
    
    local NameLabel = Instance.new("TextLabel")
    NameLabel.BackgroundTransparency = 1
    NameLabel.Size = UDim2.new(0, 150, 0, 20)
    NameLabel.Font = Enum.Font.SourceSans
    NameLabel.TextSize = 14
    NameLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
    NameLabel.TextStrokeTransparency = 0.5
    NameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    NameLabel.TextXAlignment = Enum.TextXAlignment.Center
    NameLabel.TextYAlignment = Enum.TextYAlignment.Center
    NameLabel.Name = "NameLabel"
    NameLabel.Parent = ScreenG
    
    local DistanceLabel = NameLabel:Clone()
    DistanceLabel.TextSize = 12
    DistanceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    DistanceLabel.Name = "DistanceLabel"
    DistanceLabel.Parent = ScreenG
    
    _G.ESPLabels[Player] = ScreenG
    return ScreenG
end
local function StartESP()
    if _G.ESPConnection then return end
    local ESPColor = Color3.fromRGB(0, 255, 255) 
    local LocalRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    _G.ESPConnection = RunService.RenderStepped:Connect(function()
        if not _G.espEnabled or not LocalRoot then 
            for player, highlight in pairs(_G.ESPHighlights) do if highlight and highlight.Enabled then highlight.Enabled = false end end
            for player, labelGui in pairs(_G.ESPLabels) do if labelGui.Parent then labelGui.Enabled = false end end
            return 
        end
        
        for _, player in pairs(Players:GetPlayers()) do
            local character = player.Character
            local Head = character and character:FindFirstChild("Head")
            local Root = character and character:FindFirstChild("HumanoidRootPart")
            local isValid = character and Root and IsTargetValid(Root)
            
            -- HIGHLIGHT
            if isValid then
                if not (_G.ESPHighlights[player] and _G.ESPHighlights[player].Parent == character) then
                    local highlight = Instance.new("Highlight")
                    highlight.OutlineTransparency = 0
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent = character
                    _G.ESPHighlights[player] = highlight
                end
                _G.ESPHighlights[player].FillColor = ESPColor
                _G.ESPHighlights[player].OutlineColor = ESPColor
                _G.ESPHighlights[player].Enabled = true
            elseif _G.ESPHighlights[player] then
                _G.ESPHighlights[player].Enabled = false
            end
            
            -- TEXT/DISTANCE
            local labelGui = _G.ESPLabels[player]
            if isValid and Head then
                if not labelGui then labelGui = CreateESPLabel(player) end
                local ScreenPos, Visible = Camera:WorldToScreenPoint(Head.Position)
                
                if Visible then
                    labelGui.Enabled = true
                    local NameLabel = labelGui:FindFirstChild("NameLabel")
                    local DistanceLabel = labelGui:FindFirstChild("DistanceLabel")
                    
                    if NameLabel and DistanceLabel then
                        local distance = math.floor((LocalRoot.Position - Root.Position).Magnitude)
                        local CenterX = ScreenPos.X
                        local CenterY = ScreenPos.Y
                        
                        NameLabel.Text = player.Name
                        DistanceLabel.Text = distance .. "м"
                        
                        NameLabel.Position = UDim2.new(0, CenterX - NameLabel.AbsoluteSize.X / 2, 0, CenterY - 40)
                        DistanceLabel.Position = UDim2.new(0, CenterX - DistanceLabel.AbsoluteSize.X / 2, 0, CenterY + 10)
                    end
                else
                    labelGui.Enabled = false 
                end
            elseif labelGui then
                labelGui.Enabled = false
            end
        end
    end)
end
local function StopESP()
    if _G.ESPConnection then _G.ESPConnection:Disconnect() _G.ESPConnection = nil end
    for _, highlight in pairs(_G.ESPHighlights) do if highlight and highlight.Parent then highlight:Destroy() end end
    table.clear(_G.ESPHighlights)
    for _, labelGui in pairs(_G.ESPLabels) do if labelGui and labelGui.Parent then labelGui:Destroy() end end
    table.clear(_G.ESPLabels)
end

-- ====================================================================
-- ЯДРО FOV CIRCLE
-- ====================================================================

local function StartFOVCircle()
    if _G.FOVCircleGui then return end
    local ScreenG = Instance.new("ScreenGui") ScreenG.Name = "DIX_FOVCircle" ScreenG.DisplayOrder = 999 ScreenG.Parent = CoreGui _G.FOVCircleGui = ScreenG
    local CircleF = Instance.new("Frame") CircleF.AnchorPoint = Vector2.new(0.5, 0.5) CircleF.Position = UDim2.new(0.5, 0, 0.5, 0) CircleF.BackgroundTransparency = 1 CircleF.Parent = ScreenG CircleF.ZIndex = 99
    local Ratio = Instance.new("UIAspectRatioConstraint") Ratio.AspectRatio = 1 Ratio.Parent = CircleF
    local Corner = Instance.new("UICorner") Corner.CornerRadius = UDim.new(0.5, 0) Corner.Parent = CircleF
    local Stroke = Instance.new("UIStroke") Stroke.Thickness = 2 Stroke.Color = Color3.new(1, 1, 1) Stroke.Transparency = 0.5 Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border Stroke.Parent = CircleF
    local initial_size = _G.aimbotFOV * 1.0 CircleF.Size = UDim2.new(0, initial_size, 0, initial_size)
    _G.FOVConnection = RunService.RenderStepped:Connect(function()
        if not _G.fovCircleEnabled or not CircleF.Parent then CircleF.Visible = false return end
        local size = _G.aimbotFOV * 1.0 CircleF.Size = UDim2.new(0, size, 0, size)
        CircleF.Visible = true
    end)
end
local function StopFOVCircle()
    if _G.FOVConnection then _G.FOVConnection:Disconnect() _G.FOVConnection = nil end
    if _G.FOVCircleGui then _G.FOVCircleGui:Destroy() _G.FOVCircleGui = nil end
end


-- ====================================================================
-- GUI (WIND UI)
-- ====================================================================
local Window = WindUi:CreateWindow({
    Title = "DIX V67.0 | Minimized Core", 
    Icon = "shield",
    Author = "By DIX",
    Size = UDim2.fromOffset(450, 400),
    Theme = "Dark", 
    HideSearchBar = true,
})

local Tabs = {
    Combat = Window:Tab({ Title = "Бой", Icon = "sword" }),
    Visual = Window:Tab({ Title = "Визуал", Icon = "palette" }),
    Settings = Window:Tab({ Title = "Настройки", Icon = "settings" })
}

local AimbotSection = Tabs.Combat:Section({ Title = "Аимбот (Aim)", Opened = true })
AimbotSection:Toggle({
    Title = "Aimbot [Активация]", Default = _G.aimbotEnabled,
    Callback = function(value)
        _G.aimbotEnabled = value
        if value then StartAimbot() else StopAimbot() end
    end
})
AimbotSection:Toggle({ Title = "Проверка команды", Default = _G.teamCheckEnabled, Callback = function(value) _G.teamCheckEnabled = value end })
AimbotSection:Toggle({ Title = "Валлчек (Wallcheck)", Default = _G.wallCheckEnabled, Callback = function(value) _G.wallCheckEnabled = value end })
AimbotSection:Toggle({ 
    Title = "Круг FOV (Visual)", Default = _G.fovCircleEnabled,
    Callback = function(value)
        _G.fovCircleEnabled = value
        if value then StartFOVCircle() else StopFOVCircle() end
    end
})
AimbotSection:Slider({
    Title = "Плавность наводки (Smoothness)",
    Desc = "Низкие значения (0.05-0.15) делают наводку плавной.",
    Step = 0.05, ValueFormat = "%.2f", 
    Value = { Min = 0.05, Max = 1.0, Default = _G.aimbotSmoothness },
    Callback = function(value) _G.aimbotSmoothness = value end
})
AimbotSection:Slider({
    Title = "Поле зрения (FOV)",
    Step = 5, 
    Value = { Min = 5, Max = 360, Default = _G.aimbotFOV },
    Callback = function(value)
        _G.aimbotFOV = value
        if _G.FOVCircleGui and _G.FOVCircleGui:FindFirstChild("Frame") then
             _G.FOVCircleGui:FindFirstChild("Frame").Size = UDim2.new(0, value * 1.0, 0, value * 1.0)
        end
    end
})

local HitboxSection = Tabs.Combat:Section({ Title = "Хитбокс (Hitbox)", Opened = true })
HitboxSection:Toggle({
    Title = "Hitbox Expander", Default = _G.hitboxEnabled,
    Callback = function(value)
        _G.hitboxEnabled = value
        if value then StartHitbox() else StopHitbox() end
    end
})

local EspSection = Tabs.Visual:Section({ Title = "ESP", Opened = true })
EspSection:Toggle({
    Title = "Highlight ESP + Text",
    Desc = "Включает подсветку игроков, отображение ника и расстояния.",
    Default = _G.espEnabled,
    Callback = function(value)
        _G.espEnabled = value
        if value then StartESP() else StopESP() end
    end
})

local ThemesSection = Tabs.Settings:Section({ Title = "Настройки GUI", Opened = true })
ThemesSection:ThemeChanger({ Title = "Тема GUI", Desc = "Выберите тему для интерфейса." })


-- АВТО-ЗАПУСК
if _G.fovCircleEnabled then StartFOVCircle() end
