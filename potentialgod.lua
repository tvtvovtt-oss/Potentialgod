-- ====================================================================
-- [DIX] V63.0 - ФИНАЛЬНАЯ СБОРКА: Wind UI Slider Syntax Fix
-- ✅ ФИКС: Исправлен синтаксис Slider (используется Value = {Min, Max, Default}).
-- ✅ Логика: Сохранена плавная наводка Aimbot с настраиваемым Smoothness.
-- ====================================================================

-- Load WindUi Library (ОБНОВЛЕННАЯ РАБОЧАЯ ССЫЛКА)
local WindUi = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ====================================================================
-- 1. СТАРТОВАЯ ИНИЦИАЛИЗАЦИЯ (Без изменений)
-- ====================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local ContextActionService = game:GetService("ContextActionService")
local Camera = Workspace.CurrentCamera
local RaycastParams = RaycastParams.new()
local CoreGui = game:GetService("CoreGui")

local Humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") or nil
if Humanoid then Humanoid.Name = "DIX_Humanoid" end 

-- Глобальные переменные для управления состоянием чита
_G.aimbotEnabled = false
_G.hitboxEnabled = false
_G.espEnabled = false
_G.teamCheckEnabled = true 
_G.wallCheckEnabled = false 
_G.aimbotFOV = 150        
_G.fovCircleEnabled = true 
_G.LockedTarget = nil     -- Target Locking State

-- ПЕРЕМЕННАЯ ДЛЯ ПЛАВНОСТИ
_G.aimbotSmoothness = 0.15 -- Снижено значение по умолчанию для более плавного старта

-- Контейнеры для подключений
_G.AimConnection = nil 
_G.ESPConnection = nil
_G.FOVConnection = nil    
_G.HitboxConnections = {} 
_G.OriginalSizes = {} 
_G.ESPHighlights = {} 
_G.FOVCircleGui = nil     

-- Настройка RaycastParams
RaycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- ====================================================================
-- 2. ФУНКЦИИ ЯДРА 
-- ====================================================================

-- [[ Helper Functions ]]
local function GetTargetPart(Character) return Character:FindFirstChild("Head") or Character:FindFirstChild("HumanoidRootPart") end
local function GetAngleToTarget(TargetPart) local CameraVector = Camera.CFrame.LookVector local TargetVector = (TargetPart.Position - Camera.CFrame.Position).unit return math.deg(math.acos(CameraVector:Dot(TargetVector))) end
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
    local Direction = TargetPart.Position - Origin
    local RaycastResult = Workspace:Raycast(Origin, Direction, RaycastParams)
    return RaycastResult and RaycastResult.Instance:IsDescendantOf(TargetPart.Parent)
end

-- [[ Aimbot Functions (Target Locking / Smoothness) ]]
local function FindNearestTarget()
    local SmallestAngle = _G.aimbotFOV 
    local BestTarget = nil 
    -- Блокировка цели:
    if _G.LockedTarget and _G.LockedTarget.Parent and IsTargetValid(_G.LockedTarget) then
        if GetAngleToTarget(_G.LockedTarget) <= _G.aimbotFOV and (_G.wallCheckEnabled and IsVisible(_G.LockedTarget) or not _G.wallCheckEnabled) then
            return _G.LockedTarget 
        else
            _G.LockedTarget = nil 
        end
    end
    -- Поиск новой цели:
    for _, Player in ipairs(Players:GetPlayers()) do
        local TargetCharacter = Player.Character
        local AimPart = TargetCharacter and GetTargetPart(TargetCharacter)
        if not AimPart or not IsTargetValid(AimPart) or (_G.wallCheckEnabled and not IsVisible(AimPart)) then continue end
        local Angle = GetAngleToTarget(AimPart)
        if Angle < SmallestAngle then 
            SmallestAngle = Angle
            BestTarget = AimPart
        end
    end
    if BestTarget then 
        _G.LockedTarget = BestTarget 
    end
    return BestTarget
end
local function StartAimbot() 
    if _G.AimConnection then return end 
    _G.AimConnection = RunService.RenderStepped:Connect(function()
        if not _G.aimbotEnabled then return end
        local AimPart = FindNearestTarget()
        if AimPart then 
            local TargetCFrame = CFrame.new(Camera.CFrame.Position, AimPart.Position)
            -- Применяем настраиваемую плавность
            Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, _G.aimbotSmoothness) 
        else 
            _G.LockedTarget = nil 
        end
    end)
    print("[DIX: Aimbot] Аимбот ВКЛ.")
end
local function StopAimbot()
    if _G.AimConnection then _G.AimConnection:Disconnect() _G.AimConnection = nil end
    _G.LockedTarget = nil 
    print("[DIX: Aimbot] Аимбот ВЫКЛ.")
end

-- [[ FOV Circle, Hitbox, ESP Functions (Сохранены без изменений) ]]
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
    print("[DIX: FOV Circle] Круг FOV ВКЛ (ScreenGui Mode).")
end
local function StopFOVCircle()
    if _G.FOVConnection then _G.FOVConnection:Disconnect() _G.FOVConnection = nil end
    if _G.FOVCircleGui then _G.FOVCircleGui:Destroy() _G.FOVCircleGui = nil end
    print("[DIX: FOV Circle] Круг FOV ВЫКЛ.")
end
local function ApplyHitboxExpansion(Player)
    local Character = Player.Character
    if not Character or Player == LocalPlayer or not IsTargetValid(Character.PrimaryPart) then return end
    local Hitbox_Parts_To_Change = {"HumanoidRootPart", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
    local Hitbox_Multiplier = 2.5 
    for _, PartName in ipairs(Hitbox_Parts_To_Change) do
        local Part = Character:FindFirstChild(PartName, true)
        if Part and Part:IsA("BasePart") then 
            local key = Part:GetFullName()
            if not _G.OriginalSizes[key] then _G.OriginalSizes[key] = Part.Size end
            Part.Size = _G.OriginalSizes[key] * Hitbox_Multiplier
        end
    end
end
local function RevertHitboxExpansion(Player)
    local Character = Player.Character
    if not Character then return end
    local Hitbox_Parts_To_Change = {"HumanoidRootPart", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
    for _, PartName in ipairs(Hitbox_Parts_To_Change) do
        local Part = Character:FindFirstChild(PartName, true)
        local key = Part and Part:GetFullName()
        if Part and _G.OriginalSizes[key] then
            Part.Size = _G.OriginalSizes[key]
            _G.OriginalSizes[key] = nil 
        end
    end
end
local function StartHitbox()
    if _G.hitboxEnabled then return end 
    for _, Player in ipairs(Players:GetPlayers()) do ApplyHitboxExpansion(Player) end 
    _G.HitboxConnections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not _G.hitboxEnabled then return end
        for _, Player in ipairs(Players:GetPlayers()) do ApplyHitboxExpansion(Player) end
    end)
    _G.HitboxConnections.PlayerAdded = Players.PlayerAdded:Connect(function(Player)
        Player.CharacterAdded:Connect(function(Character) ApplyHitboxExpansion(Player) end)
    end)
    _G.HitboxConnections.PlayerRemoving = Players.PlayerRemoving:Connect(RevertHitboxExpansion)
    print("[DIX: Hitbox] Экспандер ВКЛ.")
end
local function StopHitbox()
    if _G.HitboxConnections.Heartbeat then _G.HitboxConnections.Heartbeat:Disconnect() _G.HitboxConnections.Heartbeat = nil end
    if _G.HitboxConnections.PlayerAdded then _G.HitboxConnections.PlayerAdded:Disconnect() _G.HitboxConnections.PlayerAdded = nil end
    if _G.HitboxConnections.PlayerRemoving then _G.HitboxConnections.PlayerRemoving:Disconnect() _G.HitboxConnections.PlayerRemoving = nil end
    for _, Player in ipairs(Players:GetPlayers()) do RevertHitboxExpansion(Player) end
    print("[DIX: Hitbox] Экспандер ВЫКЛ.")
end
local function StartESP()
    if _G.ESPConnection then return end
    local ESPColor = Color3.fromRGB(0, 255, 255) 
    _G.ESPConnection = RunService.Heartbeat:Connect(function()
        if not _G.espEnabled then 
            for player, highlight in pairs(_G.ESPHighlights) do if highlight and highlight.Enabled then highlight.Enabled = false end end
            return 
        end
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character.PrimaryPart and IsTargetValid(player.Character.PrimaryPart) then
                local character = player.Character
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
        end
    end)
    print("[DIX: ESP] ESP ВКЛ.")
end
local function StopESP()
    if _G.ESPConnection then _G.ESPConnection:Disconnect() _G.ESPConnection = nil end
    for _, highlight in pairs(_G.ESPHighlights) do if highlight and highlight.Parent then highlight:Destroy() end end
    table.clear(_G.ESPHighlights)
    print("[DIX: ESP] ESP ВЫКЛ.")
end

-- ====================================================================
-- 3. СОЗДАНИЕ ОКНА GUI (Wind UI)
-- ====================================================================

local Window = WindUi:CreateWindow({
    Title = "DIX V63.0 | Smooth Aim Core", 
    Icon = "shield",
    Author = "By DIX",
    Size = UDim2.fromOffset(450, 400),
    Theme = "Dark", 
    HideSearchBar = true,
})

-- ====================================================================
-- 4. ВКЛАДКИ И ЭЛЕМЕНТЫ УПРАВЛЕНИЯ
-- ====================================================================

local Tabs = {
    Combat = Window:Tab({ Title = "Бой", Icon = "sword" }),
    Visual = Window:Tab({ Title = "Визуал", Icon = "palette" }),
    Settings = Window:Tab({ Title = "Настройки", Icon = "settings" })
}

-- COMBAT: Aimbot
local AimbotSection = Tabs.Combat:Section({ Title = "Аимбот (Aim)", Opened = true })

AimbotSection:Toggle({
    Title = "Aimbot [Активация]",
    Default = _G.aimbotEnabled,
    Callback = function(value)
        _G.aimbotEnabled = value
        if value then StartAimbot() else StopAimbot() end
    end
})
AimbotSection:Toggle({
    Title = "Проверка команды",
    Default = _G.teamCheckEnabled,
    Callback = function(value)
        _G.teamCheckEnabled = value
    end
})
AimbotSection:Toggle({
    Title = "Валлчек (Wallcheck)",
    Desc = "Aimbot будет работать только на видимых целях",
    Default = _G.wallCheckEnabled,
    Callback = function(value)
        _G.wallCheckEnabled = value
    end
})
AimbotSection:Toggle({ 
    Title = "Круг FOV (Visual)",
    Desc = "Показать радиус действия Aimbot на экране.",
    Default = _G.fovCircleEnabled,
    Callback = function(value)
        _G.fovCircleEnabled = value
        if value then StartFOVCircle() else StopFOVCircle() end
    end
})

-- ИСПРАВЛЕННЫЙ СЛАЙДЕР: Плавность наводки
AimbotSection:Slider({
    Title = "Плавность наводки (Smoothness)",
    Desc = "Низкие значения (0.05-0.15) делают наводку плавной, высокие (0.5+) - мгновенной.",
    Step = 0.05, 
    ValueFormat = "%.2f", 
    Value = {
        Min = 0.05, 
        Max = 1.0, 
        Default = _G.aimbotSmoothness, -- Используем значение из _G.aimbotSmoothness
    },
    Callback = function(value)
        print("[DIX: Smoothness Slider] New Smoothness Value:", value)
        _G.aimbotSmoothness = value
    end
})

-- ИСПРАВЛЕННЫЙ СЛАЙДЕР: Поле зрения (FOV)
AimbotSection:Slider({
    Title = "Поле зрения (FOV)",
    Step = 5, 
    Value = {
        Min = 5, 
        Max = 360, 
        Default = _G.aimbotFOV, -- Используем значение из _G.aimbotFOV
    },
    Callback = function(value)
        print("[DIX: FOV Slider] New FOV Value:", value)
        _G.aimbotFOV = value
        -- Гарантированное обновление размера круга FOV 
        if _G.FOVCircleGui and _G.FOVCircleGui:FindFirstChild("Frame") then
             local size = value * 1.0
             _G.FOVCircleGui:FindFirstChild("Frame").Size = UDim2.new(0, size, 0, size)
        end
    end
})

-- COMBAT: Hitbox
local HitboxSection = Tabs.Combat:Section({ Title = "Хитбокс (Hitbox)", Opened = true })
HitboxSection:Toggle({
    Title = "Hitbox Expander",
    Default = _G.hitboxEnabled,
    Callback = function(value)
        _G.hitboxEnabled = value
        if value then StartHitbox() else StopHitbox() end
    end
})

-- VISUAL: ESP
local EspSection = Tabs.Visual:Section({ Title = "ESP", Opened = true })
EspSection:Toggle({
    Title = "Highlight ESP",
    Default = _G.espEnabled,
    Callback = function(value)
        _G.espEnabled = value
        if value then StartESP() else StopESP() end
    end
})

-- SETTINGS TAB
local ThemesSection = Tabs.Settings:Section({ Title = "Настройки GUI", Opened = true })
ThemesSection:ThemeChanger({ Title = "Тема GUI", Desc = "Выберите тему для интерфейса." })


-- Запускаем круг FOV по умолчанию
if _G.fovCircleEnabled then
    StartFOVCircle()
end

print("[DIX SUCCESS] V63.0 - Aimbot полностью настроен и использует корректный синтаксис GUI. Наслаждайтесь плавной наводкой!")
