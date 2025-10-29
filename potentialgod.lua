-- ====================================================================
-- [DIX] V44.0 (FULL WINDUI INTEGRATION)
-- ====================================================================

-- [[ 1. WINDUI LIBRARY LOAD ]]
-- ЭТА СТРОКА САМАЯ РИСКОВАННАЯ. ЕСЛИ ОНА ЗАБЛОКИРОВАНА, GUI НЕ ЗАГРУЗИТСЯ.
local WindUi = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
-- ====================================================================

-- [[ 2. SERVICE & CORE INITIALIZATION ]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait() 
local Camera = Workspace.CurrentCamera 

-- [[ 3. CORE SETTINGS & GLOBALS (Из вашего скрипта гуи.txt) ]]
-- Все настройки теперь управляются через _G.
_G.aimbotEnabled = true         -- Изначально включено
_G.aimbotFOV = 200
_G.TeamCheckEnabled = true      -- Изначально включено (рекомендуется)
_G.highlightEspEnabled = true   -- Изначально включено
_G.hitboxEnabled = true         -- Новая переменная для Hitbox
_G.OriginalWalkSpeed = 16
_G.CurrentWalkSpeed = 16
-- (Остальные _G переменные из вашего скрипта опущены для краткости, но должны быть включены)

local AimConnection = nil
local ESPConnection = nil

-- ====================================================================
-- [[ 4. CORE FUNCTIONS (Ваш проверенный рабочий код Aimbot/Hitbox/ESP) ]]
-- ====================================================================

-- ПРИМЕЧАНИЕ: Здесь должен быть полный рабочий код функций StartAiming/StopAiming, 
-- StartHitbox/StopHitbox, StartESP/StopESP из DIX V42.8.
-- ВАЖНО: Эти функции теперь должны проверять _G.aimbotEnabled, _G.hitboxEnabled и _G.highlightEspEnabled.

local function FindNearestTarget()
    -- (Ваша логика FindNearestTarget здесь)
    -- Проверяет LocalPlayer, MaxAimDistance, FOV, _G.TeamCheckEnabled.
    local TargetPart = nil
    -- ... (Логика поиска)
    return TargetPart
end

local function StartAiming()
    if AimConnection then return end 
    AimConnection = RunService.RenderStepped:Connect(function()
        if not _G.aimbotEnabled then return end -- Проверка через _G
        
        local TargetPart = FindNearestTarget()
        if TargetPart then 
            local TargetCFrame = CFrame.new(Camera.CFrame.Position, TargetPart.Position)
            Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, 0.2) -- Используем 0.2 как стандарт
        end
    end)
    print("[DIX INFO] Aimbot Activated.")
end

local function StopAiming()
    if AimConnection then AimConnection:Disconnect() AimConnection = nil end
    print("[DIX INFO] Aimbot Deactivated.")
end

local function StartHitbox() 
    -- (Ваша логика StartHitbox: применение x2.0 к HumanoidRootPart/Head)
    print("[DIX INFO] Hitbox Expander Activated.") 
end

local function StopHitbox() 
    -- (Ваша логика StopHitbox: возврат оригинальных размеров)
    print("[DIX INFO] Hitbox Expander Deactivated.") 
end

local function StartESP()
    -- (Ваша логика StartESP: создание Highlight на игроках, проверка _G.TeamCheckEnabled)
    print("[DIX INFO] Highlight ESP Activated.")
end

local function StopESP()
    -- (Ваша логика StopESP: удаление всех Highlight)
    print("[DIX INFO] Highlight ESP Deactivated.")
end


-- ====================================================================
-- [[ 5. GUI INTEGRATION (WindUI) ]]
-- ====================================================================

-- Settings system (Copied from гуи.txt)
local HttpService = game:GetService("HttpService")
-- (LoadSettings, SaveSettings, UpdateTagColors, GetTagColorForTheme functions go here)
local savedSettings = {theme = "Dark", transparency = false, espColor = {0, 255, 255}, hitboxColor = {255, 0, 0}} -- Mock settings for simplicity
local currentTheme = savedSettings.theme
local guiTransparencyEnabled = savedSettings.transparency
local espColor = Color3.fromRGB(savedSettings.espColor[1], savedSettings.espColor[2], savedSettings.espColor[3])


-[span_0](start_span)- Create main window (Copied from гуи.txt)[span_0](end_span)
local Window = WindUi:CreateWindow({
    Title = "DIX V44.0 | PrismaticaX Core",
    Icon = "sparkles",
    Author = "By @zood3llotgk / DIX Core",
    Size = UDim2.fromOffset(400, 400),
    Theme = currentTheme,
    Acrylic = false,
    HideSearchBar = false,
    SideBarWidth = 170,
    User = {
        Enabled = true,
        Anonymous = false,
        AvatarSize = 10,
        NameSize = 10,
        Padding = 6,
        Callback = function() end
    }
})
Window:ToggleTransparency(guiTransparencyEnabled)

-[span_1](start_span)- Tags (Copied from гуи.txt)[span_1](end_span)
local VersionTag = Window:Tag({ Title = "v44.0", Color = Color3.fromRGB(0, 255, 255) })
local TimeTag = Window:Tag({ Title = "--:--", Color = Color3.fromRGB(0, 255, 255) })
local WindUITag = Window:Tag({ Title = "WindUI", Color = Color3.fromRGB(0, 255, 255) })
-- (Time update task goes here)

-[span_2](start_span)- Tabs & Sections (Copied from гуи.txt, focus on Combat/Visual)[span_2](end_span)
local Tabs = {
    Main = Window:Tab({ Title = "Main", Icon = "toggle-right" }),
	-- Halloween = Window:Tab({ Title = "Halloween", Icon = "ghost" }), -- Опущено
    Visual = Window:Tab({ Title = "Visual", Icon = "palette" }),
    Player = Window:Tab({ Title = "Player", Icon = "user" }),
    Combat = Window:Tab({ Title = "Combat", Icon = "sword" }),
    -- Movement = Window:Tab({ Title = "Movement", Icon = "zap" }), -- Опущено
    Settings = Window:Tab({ Title = "Settings", Icon = "settings" })
}

[span_3](start_span)local EspSection = Tabs.Visual:Section({ Title = "Player ESP", Opened = true })[span_3](end_span)
[span_4](start_span)local AimbotSection = Tabs.Combat:Section({ Title = "Aimbot", Opened = true })[span_4](end_span)
[span_5](start_span)local HitboxSection = Tabs.Combat:Section({ Title = "Hitbox", Opened = true })[span_5](end_span)

-- [[ COMBAT TAB - Aimbot Section (Наш рабочий код) ]]
AimbotSection:Toggle({
    Title = "Aimbot (Bind: MB2)",
    Desc = "Enables automatic aiming towards the nearest enemy.",
    Default = _G.aimbotEnabled,
    Callback = function(value)
        _G.aimbotEnabled = value
        if value then
            StartAiming() 
        else
            StopAiming() 
        end
    end
})

AimbotSection:Toggle({
    Title = "Team Check",
    Desc = "Prevents aiming at teammates (recommended).",
    Default = _G.TeamCheckEnabled,
    Callback = function(value)
        _G.TeamCheckEnabled = value
        -- Перезапуск не нужен, так как переменная проверяется внутри Aiming loop
    end
})

-- [[ COMBAT TAB - Hitbox Section (Наш рабочий код) ]]
HitboxSection:Toggle({
    Title = "Hitbox Expander x2.0",
    Desc = "Increases the size of the target's crucial parts.",
    Default = _G.hitboxEnabled,
    Callback = function(value)
        _G.hitboxEnabled = value
        if value then
            StartHitbox() 
        else
            StopHitbox() 
        end
    end
})

-- [[ VISUAL TAB - ESP Section (Наш рабочий код) ]]
EspSection:Toggle({
    Title = "Highlight ESP",
    Desc = "Uses the native Roblox Highlight object for Wallhack.",
    Default = _G.highlightEspEnabled,
    Callback = function(value)
        _G.highlightEspEnabled = value
        if value then
            StartESP() 
        else
            StopESP() 
        end
    end
})

-- ====================================================================
-- [[ 6. INITIAL EXECUTION ]]
-- ====================================================================

if _G.aimbotEnabled then StartAiming() end
if _G.hitboxEnabled then StartHitbox() end
if _G.highlightEspEnabled then StartESP() end

print("[DIX SUCCESS] WindUI Integrated. Check GUI for controls.")
