-- ====================================================================
-- [DIX] РОБЛОКС АИМБОТ - V26 (ФИНАЛЬНАЯ ВЕРСИЯ - Слайдер FOV + Визуал)
-- ====================================================================

-- 1. Инициализация WindUI
local WindUI
do
    local ok, result = pcall(function()
        return require("./src/Init")
    end)
    
    if ok then
        WindUI = result
    else 
        -- Пытаемся загрузить WindUI, если его нет
        WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    end
end

-- 2. Инициализация сервисов и игрока
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait() 
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Camera = Workspace.CurrentCamera 
if not Camera then
    Camera = Workspace:FindFirstChild("CurrentCamera") or Workspace.ChildAdded:Wait()
end

-- 3. Параметры (будут управляться через WindUI)
local AimingEnabled = false 
local MaxDistance = 500 
local TeamCheckEnabled = true 
local WallCheckEnabled = true 
local AimSpeed = 0.2 
local MaxFOV = 45 -- Значение по умолчанию для FOV
local AimOffsetY = 1.5 

local AimConnection = nil
local CurrentTarget = nil    
local FOV_Indicator = nil 
local Crosshair = nil      

-- ====================================================================
-- [ЯДРО V26]
-- (Функции GetPlayerFromPart, IsTargetValid, IsTargetVisible, FindNearestTarget, StartAiming, StopAiming, AimFunction)
-- Оставлены без изменений для краткости, они полностью рабочие.
-- ====================================================================

local function GetPlayerFromPart(Part)
    return Players:GetPlayerFromCharacter(Part.Parent)
end

local function IsTargetValid(TargetPart)
    local Player = GetPlayerFromPart(TargetPart)
    if not Player then return false end
    
    local TargetCharacter = Player.Character
    if not TargetCharacter or not TargetCharacter:FindFirstChildOfClass("Humanoid") or TargetCharacter.Humanoid.Health <= 0 then
        return false
    end
    if Player == LocalPlayer then
        return false
    end
    
    if TeamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then
        return false
    end
    return true
end

local function IsTargetVisible(Origin, TargetPart)
    local TargetCharacter = TargetPart.Parent
    if not TargetCharacter:IsA("Model") then return false end

    local TargetPosition = TargetPart.Position + Vector3.new(0, AimOffsetY, 0)
    
    local RaycastParams = RaycastParams.new()
    RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
    RaycastParams.FilterDescendantsInstances = {LocalPlayer.Character, TargetCharacter}

    local Direction = TargetPosition - Origin
    local raycastResult = Workspace:Raycast(Origin, Direction, RaycastParams)
    
    if not raycastResult then return true end
    
    local hitInstance = raycastResult.Instance
    
    if hitInstance and (hitInstance.Name:lower():find("decal") or hitInstance.Name:lower():find("handle") or hitInstance.Transparency > 0.9) then
        return true 
    end

    return false
end

local function FindNearestTarget()
    local Character = LocalPlayer.Character 
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end

    local MyHeadPosition = Character:FindFirstChild("Head").CFrame.Position
    local ClosestTargetPart = nil
    local SmallestDistance = math.huge

    for _, Player in ipairs(Players:GetPlayers()) do
        local TargetCharacter = Player.Character
        
        if not TargetCharacter or not IsTargetValid(TargetCharacter:FindFirstChild("HumanoidRootPart")) then
            continue
        end
        
        local TargetPart = TargetCharacter:FindFirstChild("HumanoidRootPart") 
        
        if TargetPart then
            local TargetPosition = TargetPart.Position

local Distance = (MyHeadPosition - TargetPosition).magnitude
            
            if Distance <= MaxDistance then
                
                local CameraVector = Camera.CFrame.LookVector
                local TargetVector = (TargetPosition - Camera.CFrame.Position).unit
                local Angle = math.deg(math.acos(CameraVector:Dot(TargetVector)))

                if Angle <= MaxFOV then
                    
                    local PassesWallCheck = not WallCheckEnabled 
                    
                    if WallCheckEnabled then
                        PassesWallCheck = IsTargetVisible(MyHeadPosition, TargetPart)
                    end
                    
                    if PassesWallCheck then
                        if Distance < SmallestDistance then
                            SmallestDistance = Distance
                            ClosestTargetPart = TargetPart
                        end
                    end
                end
            end
        end
    end
    
    return ClosestTargetPart
end

local function UpdateFOVIndicator()
    if FOV_Indicator and Crosshair then
        -- Размер круга FOV зависит от MaxFOV
        local Size = math.max(20, MaxFOV * 5.5) 
        FOV_Indicator.Size = UDim2.new(0, Size, 0, Size)
        FOV_Indicator.Visible = AimingEnabled -- Видимость зависит от AIMBOT: ON/OFF
        Crosshair.Visible = AimingEnabled
    end
end

local function AimFunction()
    if not Camera or not LocalPlayer.Character or not AimingEnabled then 
        CurrentTarget = nil 
        return 
    end
    
    UpdateFOVIndicator()
    
    local TargetPart = nil
    local MyHeadPosition = LocalPlayer.Character:FindFirstChild("Head") and LocalPlayer.Character.Head.CFrame.Position

    -- Target Lock Logic
    if CurrentTarget and CurrentTarget.Parent and IsTargetValid(CurrentTarget) then
        local TargetPosition = CurrentTarget.Position
        local CameraVector = Camera.CFrame.LookVector
        local TargetVector = (TargetPosition - Camera.CFrame.Position).unit
        local Angle = math.deg(math.acos(CameraVector:Dot(TargetVector)))
        
        local PassesWallCheck = not WallCheckEnabled 
        if WallCheckEnabled then
            PassesWallCheck = IsTargetVisible(MyHeadPosition, CurrentTarget)
        end
        
        local DistanceCheck = (MyHeadPosition - TargetPosition).magnitude <= MaxDistance
        
        if PassesWallCheck and DistanceCheck and Angle <= MaxFOV * 1.5 then 
             TargetPart = CurrentTarget
        else
             CurrentTarget = nil
        end
    end

    -- Find New Target
    if not TargetPart then
        TargetPart = FindNearestTarget()
        if TargetPart then
            CurrentTarget = TargetPart 
        end
    end
    
    -- Aim
    if TargetPart then
        local TargetPosition = TargetPart.Position + Vector3.new(0, AimOffsetY, 0)
        local TargetCFrame = CFrame.new(Camera.CFrame.Position, TargetPosition)
        
        Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, AimSpeed)
    end
end


local function StartAiming()
    if AimConnection then return end 
    AimConnection = RunService.RenderStepped:Connect(AimFunction)
end

local function StopAiming()
    if AimConnection then
        AimConnection:Disconnect()
        AimConnection = nil
        CurrentTarget = nil 
    end
    if FOV_Indicator then
        FOV_Indicator.Visible = false
        Crosshair.Visible = false
    end
end

-- 4. Настройка индикатора FOV (Roblox GUI с круглой формой)
local function SetupFOVIndicator()
    for _, gui in pairs(PlayerGui:GetChildren()) do
        if gui.Name:find("FOV_Indicator") or gui.Name:find("Crosshair") then
            gui:Destroy()
        end
    end
    
    FOV_Indicator = Instance.new("Frame")
    FOV_Indicator.Name = "FOV_Indicator_Frame_V26" 
    FOV_Indicator.Size = UDim2.new(0, 45 * 5.5, 0, 45 * 5.5) -- Начальный размер
    FOV_Indicator.Position = UDim2.new(0.5, 0, 0.5, 0)
    FOV_Indicator.AnchorPoint = Vector2.new(0.5, 0.5)
    FOV_Indicator.BackgroundTransparency = 0.85

FOV_Indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    FOV_Indicator.ZIndex = 10 
    FOV_Indicator.Parent = PlayerGui
    FOV_Indicator.Visible = false
    
    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(255, 50, 50) 
    UIStroke.Thickness = 1
    UIStroke.Parent = FOV_Indicator
    
    local AspectRatio = Instance.new("UIAspectRatioConstraint")
    AspectRatio.AspectRatio = 1
    AspectRatio.Parent = FOV_Indicator
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(1, 0) -- Делает Frame круглым
    UICorner.Parent = FOV_Indicator


    Crosshair = Instance.new("Frame")
    Crosshair.Name = "Crosshair_Center_V26" 
    Crosshair.Size = UDim2.new(0, 4, 0, 4)
    Crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
    Crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
    Crosshair.BackgroundColor3 = Color3.fromRGB(255, 50, 50) 
    Crosshair.ZIndex = 11 
    Crosshair.Parent = PlayerGui
    Crosshair.Visible = false
    
    local CrosshairCorner = Instance.new("UICorner")
    CrosshairCorner.CornerRadius = UDim.new(1, 0)
    CrosshairCorner.Parent = Crosshair
end

pcall(SetupFOVIndicator)

-- 5. WindUI Создание Окна и Элементов Аимбота

if WindUI then
    
    local Window = WindUI:CreateWindow({
        Title = "DIX AimBot V26 | WindUI Hub",
        Author = "by Dixy",
        Folder = "DIX_AimBot_V26",
        NewElements = true,
        
        OpenButton = {
            Title = "Open AimBot UI",
            CornerRadius = UDim.new(1,0),
            StrokeThickness = 3,
            Enabled = true,
            Draggable = true,
            OnlyMobile = false,
            
            Color = ColorSequence.new( 
                Color3.fromHex("#FF4830"), 
                Color3.fromHex("#FFBB30")
            )
        }
    })
    
    -- 6. Создание чистой вкладки Аимбота
    
    local AimBotTab = Window:Tab({
        Title = "Aim Settings",
        Icon = "target",
    })

    local MainSection = AimBotTab:Section({
        Title = "Core Toggles",
    })
    
    MainSection:Toggle({
        Flag = "AimToggle",
        Title = "AIMBOT: ON/OFF",
        Desc = "Activates the aimbot core. Toggles FOV visualizer.",
        Default = AimingEnabled,
        Callback = function(value)
            AimingEnabled = value
            if AimingEnabled then
                StartAiming()
            else
                StopAiming()
            end
        end
    })

    MainSection:Toggle({
        Flag = "TeamCheck",
        Title = "Team Check",
        Desc = "Disables aiming at teammates.",
        Default = TeamCheckEnabled,
        Callback = function(value)
            TeamCheckEnabled = value
        end
    })
    
    MainSection:Toggle({
        Flag = "WallCheck",
        Title = "Wall Check (Rage/Wall Hack)",
        Desc = "If OFF, the aimbot will target players through walls.",
        Default = WallCheckEnabled,
        Callback = function(value)
            WallCheckEnabled = value
        end
    })

    AimBotTab:AddDivider()

    local TuningSection = AimBotTab:Section({
        Title = "Tuning",
    })

    -- !!! ЗДЕСЬ НАХОДИТСЯ НАСТРОЙКА FOV !!!
    TuningSection:Slider({
        Flag = "FOV",
        Title = "Field of View (FOV)",
        Desc = "Maximum angle (in degrees) to look for targets. Controls the circle size.",
        Value = { Min = 5, Max = 180, Default = MaxFOV, Step = 5 },
        Callback = function(value)
            MaxFOV = math.round(value)
        end
    })
    -- !!! ЗДЕСЬ НАХОДИТСЯ НАСТРОЙКА FOV !!!


    -- AIM OFFSET SLIDER
    TuningSection:Slider({
        Flag = "Offset",
        Title = "Aim Offset (Высота)",
        Desc = "Vertical offset for aiming (e.g., 1.5 for head/neck).",
        Value = { Min = 0.0, Max = 5.0, Default = AimOffsetY, Step = 0.1 },
        Callback = function(value)
            AimOffsetY = math.round(value * 10) / 10
        end
    })

    -- AIM SPEED SLIDER
    TuningSection:Slider({
        Flag = "Speed",
        Title = "Aim Speed (Плавность)",

Desc = "Lower value = smoother/slower aim (0.1 is fastest).",
        Value = { Min = 0.1, Max = 1.0, Default = AimSpeed, Step = 0.1 },
        Callback = function(value)
            AimSpeed = math.round(value * 10) / 10
        end
    })
    
    TuningSection:Button({
        Title = "Destroy Window and Stop Script",
        Color = Color3.fromHex("#ff4830"),
        Justify = "Center",
        Icon = "shredder",
        Callback = function()
            StopAiming()
            Window:Destroy()
            if FOV_Indicator then FOV_Indicator:Destroy() end
            if Crosshair then Crosshair:Destroy() end
        end
    })
    
    print("AimBot V26 успешно интегрирован в WindUI Hub.")
end

if AimingEnabled then
    StartAiming()
end
