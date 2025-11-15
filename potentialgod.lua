-- Load WindUi Library
local WindUi = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- [1] ИНИЦИАЛИЗАЦИЯ
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local Camera = Workspace.CurrentCamera
local RaycastParams = RaycastParams.new()
local Character = LocalPlayer.Character 

-- Глобальные переменные (Настройки)
_G.aimbotEnabled, _G.hitboxEnabled, _G.espEnabled, _G.teamCheckEnabled, _G.wallCheckEnabled, _G.fovCircleEnabled = false, false, false, true, false, true
_G.aimbotFOV, _G.aimbotSmoothness, _G.hitboxMultiplier, _G.aimbotPrediction = 90, 0.15, 1.5, 0.05 
_G.LockedTarget = nil     
_G.AimConnection, _G.ESPConnection, _G.FOVConnection, _G.HitboxConnections, _G.OriginalSizes, _G.ESPHighlights, _G.FOVCircleGui = nil, nil, nil, {}, {}, {}, nil     

-- Обновление Character (Respawn Safe)
local function UpdateCharacter(newCharacter)
    if not newCharacter then return end
    Character = newCharacter
    RaycastParams.FilterDescendantsInstances = {Character}
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if Humanoid then Humanoid.Name = "DIX_Humanoid" end 
end
LocalPlayer.CharacterAdded:Connect(UpdateCharacter)
UpdateCharacter(LocalPlayer.Character) 
RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- [2] ЯДРО И ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
local function GetTargetPart(Char) return Char:FindFirstChild("Head") or Char:FindFirstChild("HumanoidRootPart") end
local function GetAngleToTarget(TargetPart) 
    return math.deg(math.acos(Camera.CFrame.LookVector:Dot((TargetPart.Position - Camera.CFrame.Position).unit)))
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
    if not _G.wallCheckEnabled or not Character then return true end 
    local RaycastResult = Workspace:Raycast(Camera.CFrame.Position, TargetPart.Position - Camera.CFrame.Position, RaycastParams)
    return RaycastResult and RaycastResult.Instance:IsDescendantOf(TargetPart.Parent)
end
local function PredictPosition(TargetPart)
    local HRP = TargetPart.Parent and TargetPart.Parent:FindFirstChild("HumanoidRootPart")
    if HRP and _G.aimbotPrediction > 0 then
        return TargetPart.Position + HRP.Velocity * _G.aimbotPrediction
    end
    return TargetPart.Position
end
local function FindNearestTarget()
    local SmallestAngle, BestTarget = _G.aimbotFOV, nil 
    if _G.LockedTarget and _G.LockedTarget.Parent and IsTargetValid(_G.LockedTarget) then
        if GetAngleToTarget(_G.LockedTarget) <= _G.aimbotFOV and IsVisible(_G.LockedTarget) then return _G.LockedTarget end
        _G.LockedTarget = nil 
    end
    for _, Player in ipairs(Players:GetPlayers()) do
        local AimPart = Player.Character and GetTargetPart(Player.Character)
        if not AimPart or not IsTargetValid(AimPart) or (_G.wallCheckEnabled and not IsVisible(AimPart)) then continue end 
        local Angle = GetAngleToTarget(AimPart)
        if Angle < SmallestAngle then 
            SmallestAngle = Angle
            BestTarget = AimPart
        end
    end
    if BestTarget then _G.LockedTarget = BestTarget end
    return BestTarget
end

-- Aimbot Core
local function StartAimbot() 
    if _G.AimConnection then return end 
    local camScripts = LocalPlayer.PlayerScripts:FindFirstChild("CameraModule")
    if camScripts then camScripts.Enabled = false end 
    _G.AimConnection = RunService.RenderStepped:Connect(function()
        if not _G.aimbotEnabled or not Camera.CFrame or not Character then return end 
        local AimPart = FindNearestTarget()
        if AimPart then 
            local PredictedPos = PredictPosition(AimPart) 
            pcall(function() Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, PredictedPos), _G.aimbotSmoothness) end)
        else _G.LockedTarget = nil end
    end)
end
local function StopAimbot()
    if _G.AimConnection then _G.AimConnection:Disconnect() _G.AimConnection = nil end
    _G.LockedTarget = nil 
    local camScripts = LocalPlayer.PlayerScripts:FindFirstChild("CameraModule")
    if camScripts then camScripts.Enabled = true end 
end

-- FOV Circle
local function StartFOVCircle()
    if _G.FOVCircleGui then return end
    local ScreenG = Instance.new("ScreenGui") ScreenG.Name = "DIX_FOVCircle" ScreenG.DisplayOrder, ScreenG.Parent = 999, CoreGui _G.FOVCircleGui = ScreenG
    local CircleF = Instance.new("Frame") CircleF.AnchorPoint = Vector2.new(0.5, 0.5) CircleF.Position = UDim2.new(0.5, 0, 0.5, 0) CircleF.BackgroundTransparency, CircleF.Parent, CircleF.ZIndex = 1, ScreenG, 99
    Instance.new("UIAspectRatioConstraint").AspectRatio, Instance.new("UICorner").CornerRadius, Instance.new("UIStroke").Thickness, Instance.new("UIStroke").Color, Instance.new("UIStroke").Transparency, Instance.new("UIStroke").ApplyStrokeMode, Instance.new("UIStroke").Parent = 1, UDim.new(0.5, 0), 2, Color3.new(1, 1, 1), 0.5, Enum.ApplyStrokeMode.Border, CircleF
    CircleF.Size = UDim2.new(0, _G.aimbotFOV * 1.0, 0, _G.aimbotFOV * 1.0)
    _G.FOVConnection = RunService.RenderStepped:Connect(function()
        if not _G.fovCircleEnabled or not CircleF.Parent then CircleF.Visible = false return end
        CircleF.Size = UDim2.new(0, _G.aimbotFOV * 1.0, 0, _G.aimbotFOV * 1.0)
        CircleF.Visible = true
    end)
end
local function StopFOVCircle()
    if _G.FOVConnection then _G.FOVConnection:Disconnect() _G.FOVConnection = nil end
    if _G.FOVCircleGui then _G.FOVCircleGui:Destroy() _G.FOVCircleGui = nil end
end

-- Hitbox Expander
local function ApplyHitboxExpansion(Player)
    local Char = Player.Character
    if not Char or Player == LocalPlayer or not IsTargetValid(Char.PrimaryPart) then return end
    for _, PartName in ipairs({"HumanoidRootPart", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}) do
        local Part = Char:FindFirstChild(PartName, true)
        if Part and Part:IsA("BasePart") then 
            local key = Part:GetFullName()
            if not _G.OriginalSizes[key] then _G.OriginalSizes[key] = Part.Size end
            Part.Size = _G.OriginalSizes[key] * _G.hitboxMultiplier
        end
    end
end
local function RevertHitboxExpansion(Player)
    local Char = Player.Character
    if not Char then return end
    for _, PartName in ipairs({"HumanoidRootPart", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}) do
        local Part = Char:FindFirstChild(PartName, true)
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
        if _G.hitboxEnabled then for _, Player in ipairs(Players:GetPlayers()) do ApplyHitboxExpansion(Player) end end
    end)
    _G.HitboxConnections.PlayerAdded = Players.PlayerAdded:Connect(function(Player) Player.CharacterAdded:Connect(function(Char) ApplyHitboxExpansion(Player) end) end)
    _G.HitboxConnections.PlayerRemoving = Players.PlayerRemoving:Connect(RevertHitboxExpansion)
end
local function StopHitbox()
    if _G.HitboxConnections.Heartbeat then _G.HitboxConnections.Heartbeat:Disconnect() _G.HitboxConnections.Heartbeat = nil end
    if _G.HitboxConnections.PlayerAdded then _G.HitboxConnections.PlayerAdded:Disconnect() _G.HitboxConnections.PlayerAdded = nil end
    if _G.HitboxConnections.PlayerRemoving then _G.HitboxConnections.PlayerRemoving:Disconnect() _G.HitboxConnections.PlayerRemoving = nil end
    for _, Player in ipairs(Players:GetPlayers()) do RevertHitboxExpansion(Player) end
end

-- ESP Highlight
local function StartESP()
    if _G.ESPConnection then return end
    local ENEMY_COLOR, TEAM_COLOR = Color3.fromRGB(0, 255, 255), Color3.fromRGB(0, 255, 0)
    _G.ESPConnection = RunService.Heartbeat:Connect(function()
        if not _G.espEnabled then 
            for _, highlight in pairs(_G.ESPHighlights) do if highlight and highlight.Parent then highlight.Enabled = false end end
            return 
        end
        for _, player in pairs(Players:GetPlayers()) do
            local character, primaryPart = player.Character, player.Character and player.Character.PrimaryPart
            if player == LocalPlayer or not primaryPart or not character:FindFirstChildOfClass("Humanoid") or character:FindFirstChildOfClass("Humanoid").Health <= 0 then 
                if _G.ESPHighlights[player] then _G.ESPHighlights[player].Enabled = false end
                continue 
            end
            local isTeammate = LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team
            local shouldShow = not (_G.teamCheckEnabled and isTeammate)
            
            if shouldShow then
                if not (_G.ESPHighlights[player] and _G.ESPHighlights[player].Parent == character) then
                    local highlight = Instance.new("Highlight")
                    highlight.OutlineTransparency, highlight.DepthMode, highlight.Parent = 0, Enum.HighlightDepthMode.AlwaysOnTop, character
                    _G.ESPHighlights[player] = highlight
                end
                local highlightInstance = _G.ESPHighlights[player]
                local color = isTeammate and TEAM_COLOR or ENEMY_COLOR
                highlightInstance.FillColor, highlightInstance.OutlineColor, highlightInstance.Enabled = color, color, true
            elseif _G.ESPHighlights[player] then
                _G.ESPHighlights[player].Enabled = false
            end
        end
    end)
end
local function StopESP()
    if _G.ESPConnection then _G.ESPConnection:Disconnect() _G.ESPConnection = nil end
    for _, highlight in pairs(_G.ESPHighlights) do if highlight and highlight.Parent then highlight:Destroy() end end
    table.clear(_G.ESPHighlights)
end


-- [3] ЗАГРУЗКА ИНТЕРФЕЙСА (GUI)
local Window = WindUi:CreateWindow({
    Title = "DIX V67.0 | Cleaned Hub", 
    Icon = "shield", Author = "By DIX", Size = UDim2.fromOffset(450, 400), Theme = "Dark", HideSearchBar = true,
})

local CombatTab = Window:Tab({ Title = "Бой", Icon = "sword" })
local VisualTab = Window:Tab({ Title = "Визуал", Icon = "palette" })
local SettingsTab = Window:Tab({ Title = "Настройки", Icon = "settings" })

-- COMBAT: Aimbot
local AimbotSection = CombatTab:Section({ Title = "Аимбот (Aim)", Opened = true })
AimbotSection:Toggle({ Title = "Aimbot [Активация]", Default = _G.aimbotEnabled, Callback = function(v) _G.aimbotEnabled = v if v then StartAimbot() else StopAimbot() end end})
AimbotSection:Toggle({ Title = "Проверка команды", Desc = "Игнорировать союзников.", Default = _G.teamCheckEnabled, Callback = function(v) _G.teamCheckEnabled = v end})
AimbotSection:Toggle({ Title = "Валлчек (Wallcheck)", Desc = "Работать только по видимым целям.", Default = _G.wallCheckEnabled, Callback = function(v) _G.wallCheckEnabled = v end})
AimbotSection:Toggle({ Title = "Круг FOV (Visual)", Default = _G.fovCircleEnabled, Callback = function(v) _G.fovCircleEnabled = v if v then StartFOVCircle() else StopFOVCircle() end end})
AimbotSection:Slider({Title = "Плавность наводки", Step = 0.05, ValueFormat = "%.2f", Value = { Min = 0.05, Max = 1.0, Default = _G.aimbotSmoothness, }, Callback = function(v) _G.aimbotSmoothness = v end})
AimbotSection:Slider({Title = "Смещение предсказания", Desc = "Компенсирует задержку.", Step = 0.01, ValueFormat = "%.2f", Value = { Min = 0.0, Max = 0.3, Default = _G.aimbotPrediction, }, Callback = function(v) _G.aimbotPrediction = v end})
AimbotSection:Slider({Title = "Поле зрения (FOV)", Step = 5, Value = { Min = 5, Max = 360, Default = _G.aimbotFOV, }, Callback = function(v) _G.aimbotFOV = v if _G.FOVCircleGui and _G.FOVCircleGui:FindFirstChild("Frame") then _G.FOVCircleGui:FindFirstChild("Frame").Size = UDim2.new(0, v * 1.0, 0, v * 1.0) end end})

-- COMBAT: Hitbox
local HitboxSection = CombatTab:Section({ Title = "Хитбокс (Hitbox)", Opened = true })
HitboxSection:Toggle({ Title = "Hitbox Expander", Default = _G.hitboxEnabled, Callback = function(v) _G.hitboxEnabled = v if v then StartHitbox() else StopHitbox() end end})
HitboxSection:Slider({Title = "Множитель хитбокса", Step = 0.1, ValueFormat = "%.1f", Value = { Min = 1.1, Max = 5.0, Default = _G.hitboxMultiplier, }, Callback = function(v) _G.hitboxMultiplier = v if _G.hitboxEnabled then for _, Player in ipairs(Players:GetPlayers()) do RevertHitboxExpansion(Player) ApplyHitboxExpansion(Player) end end end})

-- VISUAL: ESP
local EspSection = VisualTab:Section({ Title = "Highlight ESP", Opened = true })
EspSection:Toggle({ Title = "Highlight ESP", Default = _G.espEnabled, Callback = function(v) _G.espEnabled = v if v then StartESP() else StopESP() end end})
EspSection:Toggle({ Title = "Проверка команды (Фильтр)", Desc = "Если ВКЛ., союзники не отображаются.", Default = _G.teamCheckEnabled, Callback = function(v) _G.teamCheckEnabled = v end})

-- SETTINGS TAB
SettingsTab:Section({ Title = "Настройки GUI", Opened = true }):ThemeChanger({ Title = "Тема GUI" })


-- Initial FOV Circle
if _G.fovCircleEnabled then StartFOVCircle() end
