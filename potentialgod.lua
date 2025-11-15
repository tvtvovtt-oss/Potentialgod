-- Load WindUi Library
local WindUi = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

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
_G.AimConnection, _G.ESPConnection, _G.FOVConnection, _G.HitboxConnections, _G.OriginalSizes, _G.ESPHighlights, _G.FOVCircleGui, _G.AimbotSafetyCheck = nil, nil, nil, {}, {}, {}, nil, nil     

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

-- ЛОГИКА ТИМ-ЧЕКА
local function IsTeammate(Player)
    if not LocalPlayer.Team or not Player.Team then 
        return false 
    end
    return LocalPlayer.Team == Player.Team
end

local function GetTargetPart(Char) return Char:FindFirstChild("Head") or Char:FindFirstChild("HumanoidRootPart") end
local function GetAngleToTarget(TargetPart) 
    return math.deg(math.acos(Camera.CFrame.LookVector:Dot((TargetPart.Position - Camera.CFrame.Position).unit)))
end
local function IsTargetValid(TargetPart)
    local Player = Players:GetPlayerFromCharacter(TargetPart.Parent)
    if not Player or Player == LocalPlayer then return false end
    local TargetHumanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if not TargetHumanoid or TargetHumanoid.Health <= 0 then return false end
    if _G.teamCheckEnabled and IsTeammate(Player) then return false end 
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

-- ЛОГИКА ПОИСКА ЦЕЛИ АИМБОТА
local function FindNearestTarget()
    local SmallestAngle, BestTarget = _G.aimbotFOV, nil 
    
    if _G.LockedTarget and _G.LockedTarget.Parent and IsTargetValid(_G.LockedTarget) then
        if GetAngleToTarget(_G.LockedTarget) <= _G.aimbotFOV then 
            if not _G.wallCheckEnabled or IsVisible(_G.LockedTarget) then
                return _G.LockedTarget 
            end
        end
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
    
    if BestTarget then 
        _G.LockedTarget = BestTarget 
    end
    return BestTarget
end

-- ⚡️ НОВАЯ ФУНКЦИЯ: Синхронизация ориентации персонажа с камерой
local function SyncCharacterOrientation()
    if not Character then return end
    local HRP = Character:FindFirstChild("HumanoidRootPart")
    local Head = Character:FindFirstChild("Head")
    
    if HRP and Head then
        -- Вычисляем новую ориентацию (только поворот вокруг оси Y)
        local camCFrame = Camera.CFrame
        local hrpCFrame = HRP.CFrame
        
        -- Создаем новую CFrame для HRP, сохраняя позицию, но используя только Y-поворот камеры
        local newHrpCFrame = CFrame.new(hrpCFrame.Position) * CFrame.Angles(0, camCFrame:ToOrientation(), 0)
        
        -- Плавное сглаживание:
        HRP.CFrame = HRP.CFrame:Lerp(newHrpCFrame, 0.5) 
        
        -- Также поворачиваем голову, чтобы снайперский прицел/прицеливание выглядело естественно
        local Neck = HRP:FindFirstChild("Neck") or Head:FindFirstChild("Neck")
        if Neck and Neck:IsA("Motor6D") then
             Neck.C0 = Neck.C0:Lerp(CFrame.new(0, 1, 0) * CFrame.Angles(0, -math.rad(90), 0) * CFrame.Angles(-(camCFrame:ToOrientation()), 0, 0), 0.5)
        end
    end
end

-- Aimbot Core
local function StartAimbot() 
    if _G.AimConnection then return end 
    local camScripts = LocalPlayer.PlayerScripts:FindFirstChild("CameraModule")
    
    if camScripts then camScripts.Enabled = false end 
    Camera.CameraType = Enum.CameraType.Scriptable
    
    task.wait(0.1)
    if camScripts then camScripts.Enabled = false end 
    Camera.CameraType = Enum.CameraType.Scriptable

    -- Постоянная проверка режима камеры
    _G.AimbotSafetyCheck = RunService.Heartbeat:Connect(function()
        if _G.aimbotEnabled and Camera.CameraType ~= Enum.CameraType.Scriptable then
            Camera.CameraType = Enum.CameraType.Scriptable
        end
    end)
    
    _G.AimConnection = RunService.Heartbeat:Connect(function()
        if not _G.aimbotEnabled or not Camera.CFrame or not Character then return end 
        
        -- ⚡️ Вызываем синхронизацию тела!
        SyncCharacterOrientation() 
        
        local AimPart = FindNearestTarget()
        if AimPart then 
            local PredictedPos = PredictPosition(AimPart) 
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, PredictedPos), _G.aimbotSmoothness)
        else _G.LockedTarget = nil end
    end)
end

local function StopAimbot()
    if _G.AimbotSafetyCheck then _G.AimbotSafetyCheck:Disconnect() _G.AimbotSafetyCheck = nil end
    if _G.AimConnection then _G.AimConnection:Disconnect() _G.AimConnection = nil end
    _G.LockedTarget = nil 
    local camScripts = LocalPlayer.PlayerScripts:FindFirstChild("CameraModule")
    
    if camScripts then camScripts.Enabled = true end 
    Camera.CameraType = Enum.CameraType.Custom 
end

-- FOV Circle, Hitbox, ESP (Без изменений)
-- ... (Остальные функции и GUI остались прежними для краткости)

-- [3] ЗАГРУЗКА ИНТЕРФЕЙСА (GUI)
local Window = WindUi:CreateWindow({
    Title = "DIX V76.0 | Character Sync Fix", 
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
