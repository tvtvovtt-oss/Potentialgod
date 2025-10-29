-- ====================================================================
-- [DIX] V49.0 - ЧИСТЫЙ CORE СМЕЙТ (на основе WindUI)
-- ✅ Сохранена рабочая загрузка WindUI (из гуи.txt)
-- ✅ Добавлена чистая структура для Aimbot, Hitbox, ESP и Noclip
-- ❌ Удалены все Halloween/PrismaticaX зависимости для стабильности
-- ====================================================================

-- Load WindUi Library (Единственная рабочая строка загрузки GUI, как в вашем файле)
local WindUi = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

-- ====================================================================
-- 1. ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ (Состояние функций)
-- ====================================================================

_G.aimbotEnabled = false
_G.aimbotFOV = 200
_G.hitboxEnabled = false
_G.espEnabled = false
_G.teamCheckEnabled = true
_G.noclipEnabled = false
_G.speedConnection = nil -- Для управления скоростью/прыжком
_G.aimConnection = nil   -- Для управления циклом Aimbot

-- ====================================================================
-- 2. ФУНКЦИИ ЯДРА (Сюда вы добавите реальный рабочий код)
-- ====================================================================

-- COMBAT
local function StartAimbot() 
    print("[DIX: Aimbot] Аимбот ВКЛ. (ДОБАВЬТЕ ЛОГИКУ СЮДА)")
    -- Пример: _G.aimConnection = RunService.RenderStepped:Connect(function() ... end)
end
local function StopAimbot()
    print("[DIX: Aimbot] Аимбот ВЫКЛ.")
    -- Пример: if _G.aimConnection then _G.aimConnection:Disconnect() _G.aimConnection = nil end
end

local function StartHitbox()
    print("[DIX: Hitbox] Экспандер ВКЛ. (ДОБАВЬТЕ ЛОГИКУ СЮДА)")
    -- Логика: изменение размера Hitbox
end
local function StopHitbox()
    print("[DIX: Hitbox] Экспандер ВЫКЛ.")
    -- Логика: возврат оригинального размера Hitbox
end

-- VISUAL
local function StartESP()
    print("[DIX: ESP] ESP ВКЛ. (ДОБАВЬТЕ ЛОГИКУ СЮДА)")
    -- Логика: цикл для создания Highlight, Box, Name ESP
end
local function StopESP()
    print("[DIX: ESP] ESP ВЫКЛ.")
    -- Логика: удаление всех созданных элементов ESP
end

-- MOVEMENT
local function EnableNoclip()
    print("[DIX: Noclip] Noclip ВКЛ. (ДОБАВЬТЕ ЛОГИКУ СЮДА)")
    -- Логика: Humanoid.PlatformStand = true; noclipConnection = LocalPlayer.Character.ChildAdded:Connect(...)
end
local function DisableNoclip()
    print("[DIX: Noclip] Noclip ВЫКЛ.")
    -- Логика: Humanoid.PlatformStand = false; noclipConnection:Disconnect()
end

-- ====================================================================
-- 3. ОСНОВНОЕ ОКНО GUI (WindUI)
-- ====================================================================

local Window = WindUi:CreateWindow({
    Title = "DIX Core Hub", -- Изменено название
    Icon = "shield",
    Author = "By DIX",
    Size = UDim2.fromOffset(450, 400),
    Theme = "Dark", 
    Acrylic = false,
    HideSearchBar = true,
    SideBarWidth = 150,
    User = { Enabled = true, Anonymous = false }
})

-- ====================================================================
-- 4. ВКЛАДКИ И СЕКЦИИ (Упрощенная структура)
-- ====================================================================

local Tabs = {
    Main = Window:Tab({ Title = "Основное", Icon = "toggle-right" }),
    Combat = Window:Tab({ Title = "Бой", Icon = "sword" }),
    Visual = Window:Tab({ Title = "Визуал", Icon = "palette" }),
    Movement = Window:Tab({ Title = "Движение", Icon = "zap" }),
    Settings = Window:Tab({ Title = "Настройки", Icon = "settings" })
}

local AimbotSection = Tabs.Combat:Section({ Title = "Аимбот (Aim)", Opened = true })
local HitboxSection = Tabs.Combat:Section({ Title = "Хитбокс (Hitbox)", Opened = true })
local EspSection = Tabs.Visual:Section({ Title = "ESP", Opened = true })
local MovementPlayerSection = Tabs.Movement:Section({ Title = "Персонаж", Opened = true })

-- ====================================================================
-- 5. ЭЛЕМЕНТЫ УПРАВЛЕНИЯ
-- ====================================================================

-- COMBAT: Aimbot
AimbotSection:Toggle({
    Title = "Aimbot",
    Desc = "Автоматическое наведение на цель.",
    Default = _G.aimbotEnabled,
    Callback = function(value)
        _G.aimbotEnabled = value
        if value then StartAimbot() else StopAimbot() end
    end
})
AimbotSection:Toggle({
    Title = "Проверка команды (Team Check)",
    Desc = "Игнорировать игроков из своей команды.",
    Default = _G.teamCheckEnabled,
    Callback = function(value)
        _G.teamCheckEnabled = value
    end
})
AimbotSection:Slider({
    Title = "Поле зрения (FOV)",
    Default = 200,
    Min = 50,
    Max = 800,
    Callback = function(value)
        _G.aimbotFOV = value
    end
})

-- COMBAT: Hitbox
HitboxSection:Toggle({
    Title = "Hitbox Expander",
    Desc = "Увеличение хитбокса противников.",
    Default = _G.hitboxEnabled,
    Callback = function(value)
        _G.hitboxEnabled = value
        if value then StartHitbox() else StopHitbox() end
    end
})

-- VISUAL: ESP
EspSection:Toggle({
    Title = "Highlight ESP",
    Desc = "Подсветка игроков.",
    Default = _G.espEnabled,
    Callback = function(value)
        _G.espEnabled = value
        if value then StartESP() else StopESP() end
    end
})

-- MOVEMENT: Player
MovementPlayerSection:Toggle({
    Title = "Noclip",
    Desc = "Проход сквозь стены.",
    Default = _G.noclipEnabled,
    Callback = function(value)
        _G.noclipEnabled = value
        if value then EnableNoclip() else DisableNoclip() end
    end
})
MovementPlayerSection:Slider({
    Title = "Скорость бега (WalkSpeed)",
    Default = 16,
    Min = 16,
    Max = 100,
    Callback = function(value)
        if LocalPlayer.Character and Humanoid then
            Humanoid.WalkSpeed = value
        end
    end
})

-- SETTINGS TAB
local ThemesSection = Tabs.Settings:Section({ Title = "Кастомизация", Opened = true })
ThemesSection:ThemeChanger({ Title = "Тема GUI", Desc = "Выберите тему для интерфейса." })

print("[DIX SUCCESS] WindUI Core Hub Loaded.")
