-- ====================================================================
-- 2. ФУНКЦИИ ЯДРА (ПОЛНЫЙ РАБОЧИЙ КОД ИЗ V48.0)
-- ====================================================================

-- [[ Helper Functions ]]
local function GetTargetPart(Character) return Character:FindFirstChild("Head") or Character:FindFirstChild("HumanoidRootPart") end

local function IsTargetValid(TargetPart)
    local Player = Players:GetPlayerFromCharacter(TargetPart.Parent)
    if not Player or Player == LocalPlayer then return false end
    -- Используем _G.teamCheckEnabled, так как он привязан к GUI
    if _G.teamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then return false end
    return true
end

local function FindNearestTarget()
    local TargetRootPart = nil
    local SmallestFOV = math.huge

    for _, Player in ipairs(Players:GetPlayers()) do
        local TargetCharacter = Player.Character
        local RootPart = TargetCharacter and TargetCharacter:FindFirstChild("HumanoidRootPart") 
        local AimPart = TargetCharacter and GetTargetPart(TargetCharacter)
        
        if not RootPart or not AimPart or not IsTargetValid(RootPart) then continue end

        -- Проверка FOV (используем _G.aimbotFOV из GUI)
        local CameraVector = Camera.CFrame.LookVector
        local TargetVector = (AimPart.Position - Camera.CFrame.Position).unit 
        local Angle = math.deg(math.acos(CameraVector:Dot(TargetVector)))
        if Angle < SmallestFOV and Angle <= _G.aimbotFOV then 
            SmallestFOV = Angle
            TargetRootPart = RootPart
        end
    end
    return TargetRootPart
end

-- [[ Aimbot Functions ]]
local function StartAimbot() 
    if _G.AimConnection then return end 
    _G.AimConnection = RunService.RenderStepped:Connect(function()
        if not _G.aimbotEnabled then return end
        
        local TargetRootPart = FindNearestTarget()
        if TargetRootPart then 
            local AimPart = GetTargetPart(TargetRootPart.Parent)
            if AimPart then
                local TargetCFrame = CFrame.new(Camera.CFrame.Position, AimPart.Position)
                -- Скорость 0.2 как стандарт
                Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, 0.2) 
            end
        end
    end)
    print("[DIX: Aimbot] Аимбот ВКЛ.")
end
local function StopAimbot()
    if _G.AimConnection then _G.AimConnection:Disconnect() _G.AimConnection = nil end
    print("[DIX: Aimbot] Аимбот ВЫКЛ.")
end

-- [[ Hitbox Functions ]]
local function ApplyHitboxExpansion(Player)
    local Character = Player.Character
    if not Character or Player == LocalPlayer then return end
    if _G.teamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then return end
    
    local Hitbox_Parts_To_Change = {"HumanoidRootPart", "Head"} 
    local Hitbox_Multiplier = 2.0 

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
    local Hitbox_Parts_To_Change = {"HumanoidRootPart", "Head"}
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
    if _G.HitboxConnections.Heartbeat then return end 
    _G.HitboxConnections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not _G.hitboxEnabled then return end
        for _, Player in ipairs(Players:GetPlayers()) do ApplyHitboxExpansion(Player) end
    end)
    Players.PlayerAdded:Connect(ApplyHitboxExpansion)
    Players.PlayerRemoving:Connect(RevertHitboxExpansion)
    print("[DIX: Hitbox] Экспандер ВКЛ.")
end
local function StopHitbox()
    if _G.HitboxConnections.Heartbeat then _G.HitboxConnections.Heartbeat:Disconnect() _G.HitboxConnections.Heartbeat = nil end
    for _, Player in ipairs(Players:GetPlayers()) do RevertHitboxExpansion(Player) end
    print("[DIX: Hitbox] Экспандер ВЫКЛ.")
end

-- [[ ESP Functions ]]
local function StartESP()
    if _G.ESPConnection then return end
    -- Color3.fromRGB(0, 255, 255) - стандартный цвет
    local ESPColor = Color3.fromRGB(0, 255, 255) 
    
    _G.ESPConnection = RunService.Heartbeat:Connect(function()
        if not _G.espEnabled then 
            for player, highlight in pairs(_G.ESPHighlights) do if highlight.Enabled then highlight.Enabled = false end end
            return 
        end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and IsTargetValid(player.Character.PrimaryPart) then
                local character = player.Character
                
                if not _G.ESPHighlights[player] then
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
    if _G.ESPConnection then 
        _G.ESPConnection:Disconnect() 
        _G.ESPConnection = nil 
    end
    for _, highlight in pairs(_G.ESPHighlights) do
        highlight:Destroy()
    end
    table.clear(_G.ESPHighlights)
    print("[DIX: ESP] ESP ВЫКЛ.")
end

-- [[ Noclip Functions ]]
local function EnableNoclip()
    if not LocalPlayer.Character then return end
    LocalPlayer.Character.Humanoid.PlatformStand = true
    ContextActionService:BindAction("DIX_Noclip", function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            -- Добавьте логику для игнорирования коллизий (самый безопасный способ)
        end
        return Enum.ContextActionResult.Pass
    end, false, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D)
    print("[DIX: Noclip] Noclip ВКЛ.")
end
local function DisableNoclip()
    if LocalPlayer.Character and LocalPlayer.Character.Humanoid then
        LocalPlayer.Character.Humanoid.PlatformStand = false
        ContextActionService:UnbindAction("DIX_Noclip")
    end
    print("[DIX: Noclip] Noclip ВЫКЛ.")
end
