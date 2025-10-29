-- ====================================================================
-- [DIX] V50.0 - ФИНАЛЬНАЯ ВЕРСИЯ CORE СТРУКТУРЫ НА WINDUI
-- ✅ Использует рабочий загрузчик WindUI из вашего скрипта.
-- ✅ Сохранен рабочий метод инициализации.
-- ✅ Добавлена чистая структура для Aimbot, Hitbox, ESP и Noclip.
-- ====================================================================

-- 1. ЗАГРУЗКА WINDUI (РАБОЧАЯ СТРОКА)
local WindUi = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- 2. СЕРВИСЫ И ПЕРЕМЕННЫЕ
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

-- Глобальные переменные для управления состоянием чита
_G.aimbotEnabled = false
_G.hitboxEnabled = false
_G.espEnabled = false
_G.noclipEnabled = false
_G.teamCheckEnabled = true 
_G.aimbotFOV = 200

-- Контейнеры для подключений (ВАЖНО для остановки циклов)
_G.AimConnection = nil 
_G.ESPConnection = nil
_G.HitboxConnections = {} 
_G.OriginalSizes = {} 

-- ====================================================================
-- 3. ФУНКЦИИ ЯДРА (СЮДА ВСТАВЬТЕ ВАШ РАБОЧИЙ КОД)
-- ====================================================================

-- [[ Aimbot Functions ]]
local function StartAimbot() 
    print("[DIX: Aimbot] Аимбот ВКЛ. ВСТАВЬТЕ РАБОЧИЙ КОД ИЗ V48.0 СЮДА.")
    -- ПРИМЕР: _G.AimConnection = RunService.RenderStepped:Connect(function() ... end)
end
local function StopAimbot()
    print("[DIX: Aimbot] Аимбот ВЫКЛ.")
    -- ПРИМЕР: if _G.AimConnection then _G.AimConnection:Disconnect() _G.AimConnection = nil end
end

-- [[ Hitbox Functions ]]
local function StartHitbox()
    print("[DIX: Hitbox] Экспандер ВКЛ. ВСТАВЬТЕ РАБОЧИЙ КОД СЮДА.")
    -- ПРИМЕР: Логика изменения размера Hitbox (HumanoidRootPart, Head)
end
local function StopHitbox()
    print("[DIX: Hitbox] Экспандер ВЫКЛ.")
    -- ПРИМЕР: Логика возврата оригинального размера
end

-- [[ ESP Functions ]]
local function StartESP()
    print("[DIX: ESP] ESP ВКЛ. ВСТАВЬТЕ РАБОЧИЙ КОД СЮДА.")
    -- ПРИМЕР: _G.ESPConnection = RunService.Heartbeat:Connect(function() ... end)
end
local function StopESP()
    print("[DIX: ESP] ESP ВЫКЛ.")
    -- ПРИМЕР: Логика удаления всех Highlight/Box ESP
end

-- [[ Noclip Functions ]]
local function EnableNoclip()
    print("[DIX: Noclip] Noclip ВКЛ. ВСТАВЬТЕ РАБОЧИЙ КОД СЮДА.")
    -- ПРИМЕР: LocalPlayer.Character.Humanoid.PlatformStand = true; Игнорирование коллизий.
end
local function DisableNoclip()
    print("[DIX: Noclip] Noclip ВЫКЛ.")
    -- ПРИМЕР: LocalPlayer.Character.Humanoid.PlatformStand = false; Восстановление коллизий.
end


-- ====================================================================
-- 4. СОЗДАНИЕ ОКНА GUI (УПРОЩЕНО)
-- ====================================================================

local Window = WindUi:CreateWindow({
    Title = "DIX V50.0 | WindUI Core", 
    Icon = "shield",
    Author = "By DIX",
    Size = UDim2.fromOffset(450, 400),
    Theme = "Dark", 
    HideSearchBar = true,
})

-- ====================================================================
-- 5. ВКЛАДКИ И ЭЛЕМЕНТЫ УПРАВЛЕНИЯ
-- ====================================================================

local Tabs = {
    Combat = Window:Tab({ Title = "Бой", Icon = "sword" }),
    Visual = Window:Tab({ Title = "Визуал", Icon = "palette" }),
    Movement = Window:Tab({ Title = "Движение", Icon = "zap" }),
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
    Desc = "Игнорировать игроков из своей команды.",
    Default = _G.teamCheckEnabled,
    Callback = function(value)
        _G.teamCheckEnabled = value
    end
})
AimbotSection:Slider({
    Title = "Поле зрения (FOV)",
    Default = _G.aimbotFOV,
    Min = 50, Max = 800, Step = 10,
    Callback = function(value)
        _G.aimbotFOV = value
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

-- MOVEMENT
local MovementPlayerSection = Tabs.Movement:Section({ Title = "Движение", Opened = true })

MovementPlayerSection:Toggle({
    Title = "Noclip",
    Default = _G.noclipEnabled,
    Callback = function(value)
        _G.noclipEnabled = value
        if value then EnableNoclip() else DisableNoclip() end
    end
})
MovementPlayerSection:Slider({
    Title = "Скорость бега",
    Default = 16, Min = 16, Max = 100, Step = 1,
    Callback = function(value)
        if LocalPlayer.Character and Humanoid then
            Humanoid.WalkSpeed = value
        end
    end
})

-- SETTINGS TAB
local ThemesSection = Tabs.Settings:Section({ Title = "Настройки GUI", Opened = true })
ThemesSection:ThemeChanger({ Title = "Тема GUI", Desc = "Выберите тему для интерфейса." })

print("[DIX SUCCESS] V50.0 - WindUI Hub готов к использованию.")
