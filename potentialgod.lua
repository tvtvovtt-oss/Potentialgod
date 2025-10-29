-- ====================================================================
-- [DIX] V42.6 (Silent Aim + Hitbox Revamp)
-- Цель: Проверить совместимость с hookfunction и полной логикой Hitbox.
-- ====================================================================

-- 1. Service Initialization
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService") 
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait() 
local Camera = Workspace.CurrentCamera 

-- 2. CORE SETTINGS 
local IsAimbotEnabled = true    
local IsSilentAimEnabled = true -- ДОБАВЛЕНО
local AimingSpeed = 0.2 
local IsWallCheckEnabled = false 
local IsTeamCheckEnabled = false 
local MaxAimDistance = 500 
local CurrentFOV = 180 
local AimTargetPartName = "Head" 
local AimConnection = nil
local CurrentTarget = nil

local Hitbox_Enabled = true 
local Hitbox_Multiplier = 2.0 
local Hitbox_Parts_To_Change = {"HumanoidRootPart", "Head"} 
local Hitbox_Connections = {} 
local Original_Sizes = {} 

local IsBypassActive = false
local RaycastHook = nil 

-- ====================================================================
-- [HELPER: PREDICATION] 
-- (Без изменений)
-- ====================================================================
local function GetPredictedPosition(TargetPart, BulletSpeed)
    if not TargetPart or not TargetPart:IsA("BasePart") then return nil end
    local Velocity = TargetPart.AssemblyLinearVelocity
    local MyPosition = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart.Position
    if not MyPosition then return TargetPart.Position end
    local TargetPosition = TargetPart.Position
    local Distance = (MyPosition - TargetPosition).Magnitude
    local TimeToTarget = Distance / (BulletSpeed or 2000) 
    local PredictedPosition = TargetPosition + (Velocity * TimeToTarget)
    if (PredictedPosition - TargetPosition).Magnitude > 20 then return TargetPosition end
    return PredictedPosition
end

-- ====================================================================
-- [AIMBOT CORE]
-- (FindNearestTarget, AimFunction - Без изменений)
-- ====================================================================
local function GetTargetPart(Character) return Character:FindFirstChild(AimTargetPartName) or Character:FindFirstChild("HumanoidRootPart") end

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

local function FindNearestTarget()
    local Character = LocalPlayer.Character 
    if not Character or not Character:FindFirstChild("Head") then return nil end
    local MyHeadPosition = Character:FindFirstChild("Head").CFrame.Position
    local ClosestTargetRootPart = nil
    local SmallestDistance = math.huge

    for _, Player in ipairs(Players:GetPlayers()) do
        local TargetCharacter = Player.Character
        local RootPart = TargetCharacter and TargetCharacter:FindFirstChild("HumanoidRootPart") 
        local AimPart = TargetCharacter and GetTargetPart(TargetCharacter)
        
        if not RootPart or not AimPart or not IsTargetValid(RootPart) then continue end
        local TargetPosition = RootPart.Position 

        local Distance = (MyHeadPosition - TargetPosition).Magnitude
        if Distance > MaxAimDistance then continue end

        local CameraVector = Camera.CFrame.LookVector
        local TargetVector = (AimPart.Position - Camera.CFrame.Position).unit 
        local Angle = math.deg(math.acos(CameraVector:Dot(TargetVector)))
        if Angle > CurrentFOV then continue end 

        if Distance < SmallestDistance then
            SmallestDistance = Distance
            ClosestTargetRootPart = RootPart
        end
    end
    return ClosestTargetRootPart
end

local function AimFunction()
    if not Camera or not LocalPlayer.Character or not IsAimbotEnabled then return end
    
    local TargetRootPart = FindNearestTarget()
    
    if TargetRootPart then 
        local AimPart = GetTargetPart(TargetRootPart.Parent)
        if AimPart then
            local TargetPosition = GetPredictedPosition(AimPart, 1500) 
            local TargetCFrame = CFrame.new(Camera.CFrame.Position, TargetPosition)
            Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, AimingSpeed) 
            -- print("[DIX DEBUG] Aimbot Target Found: " .. TargetRootPart.Parent.Name)
        end
    end
end

local function StartAiming()
    if AimConnection then return end 
    AimConnection = RunService.RenderStepped:Connect(AimFunction)
end

-- ====================================================================
-- [SILENT AIM HANDLER] 
-- ====================================================================

local function HandleSilentAimShot()
    if not IsSilentAimEnabled or not LocalPlayer.Character then return end
    
    local TargetRootPart = FindNearestTarget() 
    
    if TargetRootPart then
        local AimPart = GetTargetPart(TargetRootPart.Parent)
        
        if AimPart and AimPart:IsA("BasePart") then
            
            local PredictedPosition = GetPredictedPosition(AimPart, 1500) 
            
            if hookfunction and Workspace.Raycast and AimPart.CFrame then 
                IsBypassActive = true
                
                if not RaycastHook then
                    RaycastHook = hookfunction(Workspace.Raycast, function(self, origin, direction, params)
                        
                        if IsSilentAimEnabled and IsBypassActive and AimPart.Parent and AimPart.CFrame then
                            
                            local TargetVector = PredictedPosition - origin
                            local TargetDirection = TargetVector.unit
                            
                            return RaycastHook(self, origin, TargetDirection, params)
                            
                        else
                            return RaycastHook(self, origin, direction, params)
                        end
                    end)
                    
                    print("[DIX INFO] Silent Aim: Raycast hook applied.")
                end
            else
                 print("[DIX WARNING] Silent Aim: Cannot apply Raycast hook (Missing 'hookfunction' or 'Workspace.Raycast').")
            end

            -- Выключаем байпас сразу после стрельбы, чтобы не мешать другим рейкастам
            task.delay(0.1, function()
                IsBypassActive = false
            end)
            
        end
    end
end

-- Привязка к нажатию левой кнопки мыши (M1) или пробела (Space)
ContextActionService:BindAction("SilentAimShot", function(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.KeyCode == Enum.KeyCode.Space then
             if IsSilentAimEnabled then
                 HandleSilentAimShot()
             end
        end
    end
    return Enum.ContextActionResult.Pass
end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.Space)

-- ====================================================================
-- [HITBOX CORE]
-- ====================================================================

local function ApplyHitboxExpansion(Player)
    local Character = Player.Character
    if not Character or Player == LocalPlayer then return end
    
    -- Проверка на команду (если IsTeamCheckEnabled будет включен позже)
    if IsTeamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then return end
    
    for _, PartName in ipairs(Hitbox_Parts_To_Change) do
        local Part = Character:FindFirstChild(PartName, true)
        if Part and Part:IsA("BasePart") then 
            local key = Part:GetFullName()
            if not Original_Sizes[key] then Original_Sizes[key] = Part.Size end
            Part.Size = Original_Sizes[key] * Hitbox_Multiplier
        end
    end
end

local function RevertHitboxExpansion(Player)
    local Character = Player.Character
    if not Character then return end
    
    for _, PartName in ipairs(Hitbox_Parts_To_Change) do
        local Part = Character:FindFirstChild(PartName, true)
        local key = Part and Part:GetFullName()
        if Part and Original_Sizes[key] then
            Part.Size = Original_Sizes[key]
            Original_Sizes[key] = nil 
        end
    end
end

local function HitboxLoop()
    if not Hitbox_Enabled then return end
    -- Итерируемся по игрокам, чтобы применить расширение, даже если они появились позже
    for _, Player in ipairs(Players:GetPlayers()) do ApplyHitboxExpansion(Player) end
end

local function StartHitbox()
    if Hitbox_Connections.Heartbeat then return end 
    Hitbox_Connections.PlayerAdded = Players.PlayerAdded:Connect(ApplyHitboxExpansion)
    Hitbox_Connections.PlayerRemoving = Players.PlayerRemoving:Connect(RevertHitboxExpansion)
    Hitbox_Connections.Heartbeat = RunService.Heartbeat:Connect(HitboxLoop)
    print("[DIX INFO] Hitbox Expander Activated (x2.0).")
end

-- ====================================================================
-- [[ STARTUP ]]
-- ====================================================================

StartAiming() 
StartHitbox()

print("[DIX SUCCESS] V42.6 (Silent Aim Core) запущен.")
