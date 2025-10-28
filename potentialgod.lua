-- ====================================================================
-- [DIX] FINAL SCRIPT V25.0 (COMBAT: AIMBOT + HITBOX)
-- All fixes preserved: working slider, minimized GUI closing fix, no offset.
-- All labels and comments are in English.
-- ====================================================================

-- 1. Load WindUi Library (Verified link)
local WindUi = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- 2. Service Initialization
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait() 
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera 

-- 3. Aimbot Settings
local IsAimbotEnabled = false 
local AimingSpeed = 0.2 
local IsWallCheckEnabled = true 
local IsTeamCheckEnabled = true 
local MaxAimDistance = 500 
local CurrentFOV = 45 
local AimConnection = nil
local CurrentTarget = nil    

-- 4. Hitbox Settings
local Hitbox_Enabled = false 
local Hitbox_Multiplier = 2.0 
local Hitbox_Parts_To_Change = {"HumanoidRootPart", "Head"} 
local Hitbox_Connections = {} 
local Original_Sizes = {} 

-- ====================================================================
-- [DIX FOV MODULE V25.0] - VISUALIZATION
-- ====================================================================

local FOV_Visual_Element = nil 
local FOV_Draw_Method = "GUI" 
local ScreenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

local function UpdateFOVVisual()
    local IsVisible = IsAimbotEnabled
    local Size = math.max(20, CurrentFOV * 5.5) 
    
    if FOV_Draw_Method == "Drawing" and FOV_Visual_Element then
        FOV_Visual_Element.Radius = Size
        FOV_Visual_Element.Visible = IsVisible
    elseif FOV_Visual_Element then
        FOV_Visual_Element.Size = UDim2.new(0, Size, 0, Size)
        FOV_Visual_Element.Visible = IsVisible
    end
end

local function SetupFOVVisuals()
    if pcall(function() return Drawing end) then
        FOV_Draw_Method = "Drawing"
        FOV_Visual_Element = Drawing.new("Circle")
        FOV_Visual_Element.Thickness = 2
        FOV_Visual_Element.Color = Color3.fromRGB(0, 255, 255)
        FOV_Visual_Element.Filled = false 
        FOV_Visual_Element.Transparency = 0.5
        FOV_Visual_Element.Position = ScreenCenter
        FOV_Visual_Element.Visible = false
    else
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "DIX_FOV_ROOT_V25"
        ScreenGui.IgnoreGuiInset = true
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
        ScreenGui.Parent = PlayerGui

        FOV_Visual_Element = Instance.new("Frame")
        FOV_Visual_Element.Name = "DIX_FOV_Frame_V25_GUI" 
        FOV_Visual_Element.Position = UDim2.new(0.5, 0, 0.5, 0)
        FOV_Visual_Element.AnchorPoint = Vector2.new(0.5, 0.5)
        FOV_Visual_Element.BackgroundTransparency = 0.5 
        FOV_Visual_Element.BackgroundColor3 = Color3.fromRGB(0, 255, 255) 
        FOV_Visual_Element.ZIndex = 9999 
        FOV_Visual_Element.Parent = ScreenGui
        
        local AspectRatio = Instance.new("UIAspectRatioConstraint")
        AspectRatio.AspectRatio = 1
        AspectRatio.Parent = FOV_Visual_Element
        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(1, 0)
        UICorner.Parent = FOV_Visual_Element
    end
end

SetupFOVVisuals()

-- ====================================================================
-- [Aimbot Core Functions]
-- ====================================================================

local function IsTargetValid(TargetPart)
    local Player = Players:GetPlayerFromCharacter(TargetPart.Parent)
    if not Player then return false end
    local TargetCharacter = Player.Character
    if not TargetCharacter or not TargetCharacter:FindFirstChildOfClass("Humanoid") or TargetCharacter.Humanoid.Health <= 0 then return false end
    if Player == LocalPlayer then return false end
    if IsTeamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then return false end
    return true
end

local function IsTargetVisible(Origin, TargetPart)
    local TargetCharacter = TargetPart.Parent
    local TargetPosition = TargetPart.Position 
    local RaycastParams = RaycastParams.new()
    RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
    RaycastParams.FilterDescendantsInstances = {LocalPlayer.Character, TargetCharacter}
    local Direction = TargetPosition - Origin
    local raycastResult = Workspace:Raycast(Origin, Direction.unit * (Origin - TargetPosition).magnitude, RaycastParams)
    return not raycastResult or Players:GetPlayerFromCharacter(raycastResult.Instance:FindFirstAncestorOfClass("Model")) == Players:GetPlayerFromCharacter(TargetCharacter)
end

local function FindNearestTarget()
    local Character = LocalPlayer.Character 
    if not Character or not Character:FindFirstChild("Head") then return nil end
    local MyHeadPosition = Character:FindFirstChild("Head").CFrame.Position
    local ClosestTargetPart = nil
    local SmallestDistance = math.huge

    for _, Player in ipairs(Players:GetPlayers()) do
        local TargetCharacter = Player.Character
        local TargetPart = TargetCharacter and TargetCharacter:FindFirstChild("HumanoidRootPart") 
        if not TargetPart or not IsTargetValid(TargetPart) then continue end
        local TargetPosition = TargetPart.Position 

        local Distance = (MyHeadPosition - TargetPosition).magnitude
        if Distance > MaxAimDistance then continue end

        local CameraVector = Camera.CFrame.LookVector
        local TargetVector = (TargetPosition - Camera.CFrame.Position).unit
        local Angle = math.deg(math.acos(CameraVector:Dot(TargetVector)))
        if Angle > CurrentFOV then continue end 

        local PassesWallCheck = not IsWallCheckEnabled 
        if IsWallCheckEnabled then PassesWallCheck = IsTargetVisible(MyHeadPosition, TargetPart) end
        if PassesWallCheck then
            if Distance < SmallestDistance then
                SmallestDistance = Distance
                ClosestTargetPart = TargetPart
            end
        end
    end
    return ClosestTargetPart
end

local function AimFunction()
    if not Camera or not LocalPlayer.Character or not IsAimbotEnabled then 
        CurrentTarget = nil 
        UpdateFOVVisual()
        return 
    end
    UpdateFOVVisual()

    local TargetPart = nil
    local MyHeadPosition = LocalPlayer.Character:FindFirstChild("Head") and LocalPlayer.Character.Head.CFrame.Position
    if CurrentTarget and CurrentTarget.Parent and IsTargetValid(CurrentTarget) then
        local TargetPosition = CurrentTarget.Position 
        local CameraVector = Camera.CFrame.LookVector
        local TargetVector = (TargetPosition - Camera.CFrame.Position).unit
        local Angle = math.deg(math.acos(CameraVector:Dot(TargetVector)))
        local PassesWallCheck = not IsWallCheckEnabled 
        if IsWallCheckEnabled then PassesWallCheck = IsTargetVisible(MyHeadPosition, CurrentTarget) end
        
        if PassesWallCheck and (MyHeadPosition - TargetPosition).magnitude <= MaxAimDistance and Angle <= CurrentFOV * 1.5 then 
             TargetPart = CurrentTarget
        else
             CurrentTarget = nil
        end
    end

    if not TargetPart then
        TargetPart = FindNearestTarget()
        if TargetPart then CurrentTarget = TargetPart end
    end

    if TargetPart then
        local TargetPosition = TargetPart.Position 
        local TargetCFrame = CFrame.new(Camera.CFrame.Position, TargetPosition)
        Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, AimingSpeed)
    end
end

local function StartAiming()
    if AimConnection then return end 
    AimConnection = RunService.RenderStepped:Connect(AimFunction)
    UpdateFOVVisual()
end

local function StopAiming()
    if AimConnection then
        AimConnection:Disconnect()
        AimConnection = nil
        CurrentTarget = nil 
    end
    UpdateFOVVisual()
end


-- ====================================================================
-- [Hitbox Expander Core Functions]
-- ====================================================================

local function GetOriginalSize(Part)
    if Part and Part:IsA("BasePart") then
        local key = Part:GetFullName()
        if not Original_Sizes[key] then
            Original_Sizes[key] = Part.Size
        end
        return Original_Sizes[key]
    end
    return nil
end

local function ApplyHitboxExpansion(Player)
    local Character = Player.Character
    if not Character then return end
    
    local function isPlayerTargetable(p)
        if not p or p == LocalPlayer then return false end
        local c = p.Character
        if not c or not c:FindFirstChildOfClass("Humanoid") or c.Humanoid.Health <= 0 then return false end
        return true
    end
    
    if not isPlayerTargetable(Player) then return end
    
    for _, PartName in ipairs(Hitbox_Parts_To_Change) do
        local Part = Character:FindFirstChild(PartName, true)
        
        if Part and Part:IsA("BasePart") then
            local OriginalSize = GetOriginalSize(Part)
            if OriginalSize then
                Part.Size = OriginalSize * Hitbox_Multiplier
            end
        end
    end
end

local function RevertHitboxExpansion(Player)
    local Character = Player.Character
    if not Character then return end
    
    for _, PartName in ipairs(Hitbox_Parts_To_Change) do
        local Part = Character:FindFirstChild(PartName, true)
        if Part and Part:IsA("BasePart") then
             local key = Part:GetFullName()
            if Original_Sizes[key] then
                Part.Size = Original_Sizes[key]
                Original_Sizes[key] = nil 
            end
        end
    end
end

local function HitboxLoop()
    if not Hitbox_Enabled then return end
    
    for _, Player in ipairs(Players:GetPlayers()) do
        ApplyHitboxExpansion(Player)
    end
end

local function StartHitbox()
    if Hitbox_Connections.Heartbeat then return end 
    
    Hitbox_Connections.Heartbeat = RunService.Heartbeat:Connect(HitboxLoop)
    
    for _, Player in ipairs(Players:GetPlayers()) do
        ApplyHitboxExpansion(Player)
    end
    
    Hitbox_Connections.PlayerAdded = Players.PlayerAdded:Connect(function(Player)
        Player.CharacterAdded:Connect(function()
            task.wait(0.2)
            if Hitbox_Enabled then
                ApplyHitboxExpansion(Player)
            end
        end)
    end)
end

local function StopHitbox()
    if Hitbox_Connections.Heartbeat then
        Hitbox_Connections.Heartbeat:Disconnect()
        Hitbox_Connections.Heartbeat = nil
    end
    
    if Hitbox_Connections.PlayerAdded then
        Hitbox_Connections.PlayerAdded:Disconnect()
        Hitbox_Connections.PlayerAdded = nil
    end
    
    for _, Player in ipairs(Players:GetPlayers()) do
        RevertHitboxExpansion(Player)
    end
    Original_Sizes = {}
end


-- ====================================================================
-- [[ 5. GUI HUB (WindUI) ]]
-- ====================================================================

if WindUi then
    local Window = WindUi:CreateWindow({
        Title = "DIX COMBAT HUB V25.0",
        Author = "by Dixyi",
        Folder = "DIX_Aimbot_V26_V25_English",
        OpenButton = { Title = "DIX OPEN", Color = ColorSequence.new(Color3.fromHex("#FF4830"), Color3.fromHex("#FFBB30")) }
    })

    -- COMBAT Tab
    local CombatTab = Window:Tab({ 
        Title = "COMBAT", 
        Icon = "target", 
    })
    
    -- ================================================================
    -- Aimbot Settings (SECTION 1)
    -- ================================================================
    local AimSection = CombatTab:Section({ Title = "Aimbot Settings", })

    -- 1. AIMBOT ON/OFF Toggle
    AimSection:Toggle({
        Flag = "AimToggle",
        Title = "AIMBOT: ON/OFF",
        Desc = "Activates the aimbot core and FOV Visualizer.",
        Default = IsAimbotEnabled,
        Callback = function(value)
            IsAimbotEnabled = value
            if IsAimbotEnabled then StartAiming() else StopAiming() end
        end
    })
    
    -- 2. FOV Slider
    AimSection:Slider({ 
        Flag = "FOV", 
        Title = "Aim FOV (Visual Circle)", 
        Desc = "Radius of the aimbot's field of vision (5 - 180 degrees).",
        Value = { 
            Min = 5, 
            Max = 180, 
            Default = CurrentFOV, 
            Step = 5 
        }, 
        Callback = function(value) 
            CurrentFOV = math.round(value)
            UpdateFOVVisual() 
        end 
    })
    
    -- 3. Other Settings
    AimSection:Slider({ 
        Flag = "Speed", 
        Title = "Aim Speed (Smoothness)", 
        Value = { Min = 0.1, Max = 1.0, Default = AimingSpeed, Step = 0.05 }, 
        Callback = function(value) AimingSpeed = math.round(value * 100) / 100 end 
    })
    AimSection:Toggle({ 
        Flag = "WallCheck", 
        Title = "Wall Check", 
        Default = IsWallCheckEnabled, 
        Callback = function(value) IsWallCheckEnabled = value end 
    })
    AimSection:Toggle({ 
        Flag = "TeamCheck", 
        Title = "Team Check", 
        Default = IsTeamCheckEnabled, 
        Callback = function(value) IsTeamCheckEnabled = value end 
    })

    
    -- ================================================================
    -- Hitbox Expander Settings (SECTION 2)
    -- ================================================================
    local HitboxSection = CombatTab:Section({ Title = "Hitbox Expander Settings", })

    -- 1. HITBOX EXPANDER ON/OFF Toggle
    HitboxSection:Toggle({
        Flag = "HitboxToggle",
        Title = "Hitbox Expander: ON/OFF",
        Desc = "Locally increases the size of enemy hitboxes (HRT/Head).",
        Default = Hitbox_Enabled,
        Callback = function(value)
            Hitbox_Enabled = value
            if Hitbox_Enabled then 
                StartHitbox() 
            else 
                StopHitbox() 
            end
        end
    })
    
    -- 2. Multiplier Slider
    HitboxSection:Slider({ 
        Flag = "Multiplier", 
        Title = "Hitbox Multiplier (Size)", 
        Desc = "How many times the hitbox should be increased (1.1x to 5x).",
        Value = { 
            Min = 1.1, 
            Max = 5.0, 
            Default = Hitbox_Multiplier, 
            Step = 0.1 
        }, 
        Callback = function(value) 
            Hitbox_Multiplier = math.round(value * 10) / 10 
            if Hitbox_Enabled then
                 -- Apply new size to all players already in the game
                 for _, Player in ipairs(Players:GetPlayers()) do
                     ApplyHitboxExpansion(Player) 
                 end
            end
        end 
    })


    -- Window Closing Cleanup: Folding fix (only hide visuals)
    Window:OnClose(function()
        if FOV_Visual_Element then
            if FOV_Draw_Method == "Drawing" then
                FOV_Visual_Element.Visible = false
            else
                FOV_Visual_Element.Visible = false
            end
        end
        -- Hitbox and Aimbot logic continues to run if toggles are ON
    end)
    
    -- Restore FOV visibility on window opening
    Window:OnOpen(function()
        if IsAimbotEnabled then 
             if FOV_Draw_Method == "Drawing" then
                FOV_Visual_Element.Visible = true
            else
                FOV_Visual_Element.Visible = true
            end
        end
    end)

    -- Start functions if enabled by default
    if IsAimbotEnabled then StartAiming() end
    if Hitbox_Enabled then StartHitbox() end

    print("DIX Combat HUB V25.0 launched. All features on 'COMBAT' tab.")
end
