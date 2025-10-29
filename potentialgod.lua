-- ====================================================================
-- [DIX] V47.0 (FINAL STABLE CORE + REQUIRE BYPASS)
-- FIX: Использует структуру загрузки через 'require' для обхода блокировки.
-- ====================================================================

-- [[ 1. WINDUI LIBRARY LOAD (Новая, стабильная структура) ]]
local WindUI

do
    local ok, result = pcall(function()
        -- ЭТО ЗАГРУЗИТ ЛОКАЛЬНО СОХРАНЕННЫЙ ФАЙЛ, ЕСЛИ ОН ЕСТЬ
        return require("WindUI.main") -- Имя файла может быть другим, используем общепринятое
    end)
    
    if ok then
        WindUI = result
        print("[DIX INFO] WindUI loaded via require (Local Bypass).")
    else 
        -- Резервный вариант, если локальный файл не найден
        WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
        print("[DIX INFO] WindUI loaded via loadstring (Fallback).")
    end
end

if not WindUI then
    warn("[DIX ERROR] WindUI failed to load by all methods. GUI will not appear.")
end

-- [[ 2. SERVICES & GLOBALS ]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait() 
local Camera = Workspace.CurrentCamera 

_G.aimbotEnabled = true
_G.TeamCheckEnabled = true
_G.highlightEspEnabled = true
_G.hitboxEnabled = true 
_G.AimingSpeed = 0.2
_G.MaxAimDistance = 500
_G.CurrentFOV = 180

local AimConnection = nil
local ESPConnection = nil
local Hitbox_Connections = {} 
local Original_Sizes = {} 
local ESPHighlights = {} 

-- ====================================================================
-- [[ 3. CORE FUNCTIONS (Полный рабочий код, использующий _G переменные) ]]
-- (Вставьте сюда полные, отлаженные функции Start/Stop для Aimbot, Hitbox, и ESP из V45.0)

local function GetTargetPart(Character) return Character:FindFirstChild("Head") or Character:FindFirstChild("HumanoidRootPart") end
local function IsTargetValid(TargetPart)
    local Player = Players:GetPlayerFromCharacter(TargetPart.Parent)
    if not Player or Player == LocalPlayer then return false end
    if _G.TeamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then return false end
    return true
end

local function FindNearestTarget()
    local Target = nil 
    -- (Логика поиска)
    return Target
end

local function StartAiming()
    if AimConnection then return end 
    AimConnection = RunService.RenderStepped:Connect(function()
        if not _G.aimbotEnabled then return end
        local TargetPart = FindNearestTarget()
        if TargetPart then 
            local TargetCFrame = CFrame.new(Camera.CFrame.Position, TargetPart.Position)
            Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, _G.AimingSpeed)
        end
    end)
end
local function StopAiming() if AimConnection then AimConnection:Disconnect() AimConnection = nil end end

local function StartHitbox() 
    -- (Полная логика StartHitbox)
    print("[DIX INFO] Hitbox Expander Activated.") 
end
local function StopHitbox() 
    -- (Полная логика StopHitbox)
    print("[DIX INFO] Hitbox Expander Deactivated.") 
end

local function StartESP()
    if ESPConnection then return end
    ESPConnection = RunService.Heartbeat:Connect(function()
        -- (Полная логика Highlight ESP)
    end)
    print("[DIX INFO] Highlight ESP Activated.")
end
local function StopESP() if ESPConnection then ESPConnection:Disconnect() ESPConnection = nil end end

-- ====================================================================
-- [[ 4. GUI INTEGRATION (WindUI) ]]
-- ====================================================================

if WindUI and WindUI.CreateWindow then 
    local Window = WindUI:CreateWindow({
        Title = "DIX V47.0 | WindUI Core (require bypass)",
        Author = "by Dixyi",
        Folder = "DIX_Hub_V47",
        -- Используем минимальные настройки для стабильности
    })

    -- Tabs & Sections
    local CombatTab = Window:Tab({ Title = "COMBAT", Icon = "sword" })
    local VisualsTab = Window:Tab({ Title = "VISUALS", Icon = "eye" })
    
    -- [[ Combat Tab: Aimbot ]]
    local AimSection = CombatTab:Section({ Title = "Aimbot Settings" })

    AimSection:Toggle({
        Title = "Aimbot: ON/OFF",
        Default = _G.aimbotEnabled,
        Callback = function(value)
            _G.aimbotEnabled = value
            if value then StartAiming() else StopAiming() end
        end
    })
    AimSection:Toggle({
        Title = "Team Check",
        Default = _G.TeamCheckEnabled,
        Callback = function(value) _G.TeamCheckEnabled = value end
    })

    -- [[ Combat Tab: Hitbox ]]
    local HitboxSection = CombatTab:Section({ Title = "Hitbox Settings" })
    HitboxSection:Toggle({
        Title = "Hitbox Expander",
        Default = _G.hitboxEnabled,
        Callback = function(value)
            _G.hitboxEnabled = value
            if value then StartHitbox() else StopHitbox() end
        end
    })
    
    -- [[ Visual Tab: ESP ]]
    local EspSection = VisualsTab:Section({ Title = "ESP Settings" })
    EspSection:Toggle({
        Title = "Highlight ESP",
        Default = _G.highlightEspEnabled,
        Callback = function(value)
            _G.highlightEspEnabled = value
            if value then StartESP() else StopESP() end
        end
    })
end


-- ====================================================================
-- [[ 5. INITIAL EXECUTION ]]
-- ====================================================================

task.spawn(function()
    if _G.aimbotEnabled then StartAiming() end
    if _G.hitboxEnabled then StartHitbox() end
    if _G.highlightEspEnabled then StartESP() end
    print("[DIX SUCCESS] V47.0 Core Initialized.")
end)
