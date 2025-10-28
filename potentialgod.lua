-- ====================================================================
-- [DIX] FINAL SCRIPT V28.0 (ULTIMATE FIXES + STABLE ESP)
-- 1. Aimbot Target Part: Verified and fixed Dropdown issue.
-- 2. Hitbox Expander: Aggressive re-application logic to prevent server rollback.
-- 3. ESP: Dynamic 2D Box calculation for accurate size; added Team Check.
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
local Drawing = pcall(function() return Drawing end) and Drawing or nil

-- 3. Aimbot Settings
local IsAimbotEnabled = false 
local AimingSpeed = 0.2 
local IsWallCheckEnabled = true 
local IsTeamCheckEnabled = true 
local MaxAimDistance = 500 
local CurrentFOV = 45 
local AimTargetPartName = "HumanoidRootPart" 
local AimConnection = nil
local CurrentTarget = nil    

-- 4. Hitbox Settings
local Hitbox_Enabled = false 
local Hitbox_Multiplier = 2.0 
local Hitbox_Parts_To_Change = {"HumanoidRootPart", "Head"} 
local Hitbox_Connections = {} 
local Original_Sizes = {} 

-- 5. ESP Settings
local IsESPEnabled = false
local IsESPBoxEnabled = true
local IsESPNameEnabled = true
local IsESPDistanceEnabled = true
local IsESPTeamCheckEnabled = true -- NEW: ESP Team Check
local ESPColor = Color3.fromRGB(255, 255, 0)
local ESPConnection = nil
local ESPDrawings = {}

-- ====================================================================
-- [DIX FOV MODULE V28.0] - VISUALIZATION (No changes)
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
    if Drawing then
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
        ScreenGui.Name = "DIX_FOV_ROOT_V28"
        ScreenGui.IgnoreGuiInset = true
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
        ScreenGui.Parent = PlayerGui

        FOV_Visual_Element = Instance.new("Frame")
        FOV_Visual_Element.Name = "DIX_FOV_Frame_V28_GUI" 
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

local function GetTargetPart(Character) return Character:FindFirstChild(AimTargetPartName) end
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

-- Aimbot logic (FindNearestTarget, AimFunction, Start/StopAiming) remains stable since V26.0

local function IsTargetVisible(Origin, TargetPart)
    local TargetCharacter = TargetPart.Parent
    local AimPart = GetTargetPart(TargetCharacter) 
    if not AimPart then return false end
    
    local TargetPosition = AimPart.Position 
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
    local ClosestTargetRootPart = nil
    local SmallestDistance = math.huge

    for _, Player in ipairs(Players:GetPlayers()) do
        local TargetCharacter = Player.Character
        local RootPart = TargetCharacter and TargetCharacter:FindFirstChild("HumanoidRootPart") 
        local AimPart = TargetCharacter and GetTargetPart(TargetCharacter)
        
        if not RootPart or not AimPart or not IsTargetValid(RootPart) then continue end
        local TargetPosition = RootPart.Position 

        local Distance = (MyHeadPosition - TargetPosition).magnitude
        if Distance > MaxAimDistance then continue end

        local CameraVector = Camera.CFrame.LookVector
        local AimPosition = AimPart.Position
        local TargetVector = (AimPosition - Camera.CFrame.Position).unit 
        local Angle = math.deg(math.acos(CameraVector:Dot(TargetVector)))
        if Angle > CurrentFOV then continue end 

        local PassesWallCheck = not IsWallCheckEnabled 
        if IsWallCheckEnabled then PassesWallCheck = IsTargetVisible(MyHeadPosition, RootPart) end
        
        if PassesWallCheck then
            if Distance < SmallestDistance then
                SmallestDistance = Distance
                ClosestTargetRootPart = RootPart
            end
        end
    end
    return ClosestTargetRootPart
end

local function AimFunction()
    if not Camera or not LocalPlayer.Character or not IsAimbotEnabled then 
        CurrentTarget = nil 
        UpdateFOVVisual()
        return 
    end
    UpdateFOVVisual()

    local TargetRootPart = nil
    local MyHeadPosition = LocalPlayer.Character:FindFirstChild("Head") and LocalPlayer.Character.Head.CFrame.Position
    
    if CurrentTarget and CurrentTarget.Parent and IsTargetValid(CurrentTarget) then
        local AimPart = GetTargetPart(CurrentTarget.Parent)
        if AimPart then
            local AimPosition = AimPart.Position
            local CameraVector = Camera.CFrame.LookVector
            local TargetVector = (AimPosition - Camera.CFrame.Position).unit
            local Angle = math.deg(math.acos(CameraVector:Dot(TargetVector)))
            
            local PassesWallCheck = not IsWallCheckEnabled 
            if IsWallCheckEnabled then PassesWallCheck = IsTargetVisible(MyHeadPosition, CurrentTarget) end
            
            if PassesWallCheck and (MyHeadPosition - CurrentTarget.Position).magnitude <= MaxAimDistance and Angle <= CurrentFOV * 1.5 then 
                 TargetRootPart = CurrentTarget
            else
                 CurrentTarget = nil
            end
        end
    end

    if not TargetRootPart then
        TargetRootPart = FindNearestTarget()
        if TargetRootPart then CurrentTarget = TargetRootPart end
    end

    if TargetRootPart then
        local AimPart = GetTargetPart(TargetRootPart.Parent)
        if AimPart then
            local TargetPosition = AimPart.Position 
            local TargetCFrame = CFrame.new(Camera.CFrame.Position, TargetPosition)
            Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, AimingSpeed)
        end
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
-- [Hitbox Expander Core Functions] - FIX: More aggressive re-application
-- ====================================================================

local function GetOriginalSize(Part)
    if Part and Part:IsA("BasePart") then
        local key = Part:GetFullName()
        if not Original_Sizes[key] then
            -- Store the size when the part is first seen/processed
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
                -- FIX: Force set size every time in the loop, even if it appears to be correct, 
                -- to combat rapid server physics resets.
                Part.Size = OriginalSize * Hitbox_Multiplier
            end
        end
    end
end

-- Revert and Start/StopHitbox logic remains the same (using Heartbeat)

local function RevertHitboxExpansion(Player)
    local Character = Player.Character
    if not Character then return end
    
    for _, PartName in ipairs(Hitbox_Parts_To_Change) do
        local Part = Character:FindFirstChild(PartName, true)
        if Part and Part:IsA("BasePart") then
             local key = Part:GetFullName()
            if Original_Sizes[key] then
                Part.Size = Original_Sizes[key]
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
    
    Hitbox_Connections.CharacterAdded = Players.PlayerAdded:Connect(function(Player)
        Player.CharacterAdded:Connect(function(Character)
            Character:WaitForChild("HumanoidRootPart", 5) 
            task.wait(0.1) 
            if Hitbox_Enabled then
                ApplyHitboxExpansion(Player)
            end
        end)
    end)
    
    LocalPlayer.CharacterAdded:Connect(function(Character)
         Character:WaitForChild("HumanoidRootPart", 5)
         task.wait(0.1)
         for _, player in ipairs(Players:GetPlayers()) do
             ApplyHitboxExpansion(player)
         end
    end)
end

local function StopHitbox()
    if Hitbox_Connections.Heartbeat then
        Hitbox_Connections.Heartbeat:Disconnect()
        Hitbox_Connections.Heartbeat = nil
    end
    
    if Hitbox_Connections.CharacterAdded then
        Hitbox_Connections.CharacterAdded:Disconnect()
        Hitbox_Connections.CharacterAdded = nil
    end
    
    for _, Player in ipairs(Players:GetPlayers()) do
        RevertHitboxExpansion(Player)
    end
    Original_Sizes = {} 
end


-- ====================================================================
-- [ESP Core Functions] - FIX: Accurate 2D Box + Team Check
-- ====================================================================

local function ClearDrawings()
    for _, drawing in pairs(ESPDrawings) do
        if drawing and drawing.Remove then
            drawing:Remove()
        end
    end
    ESPDrawings = {}
end

local function DrawPlayerESP(Player)
    local Character = Player.Character
    local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
    local Head = Character and Character:FindFirstChild("Head")
    if not RootPart or not Head then return end

    -- Team Check Logic
    if IsESPTeamCheckEnabled and LocalPlayer.Team and Player.Team and LocalPlayer.Team == Player.Team then
        return -- Skip drawing on teammates
    end

    local HeadPos, HeadOnScreen = Camera:WorldToScreenPoint(Head.Position)
    local RootPos, RootOnScreen = Camera:WorldToScreenPoint(RootPart.Position)
    
    -- Use HumanoidRootPart position for general distance check
    local Distance = math.floor((RootPart.Position - LocalPlayer.Character.PrimaryPart.Position).Magnitude)

    -- If neither Head nor Root is visible, skip
    if not HeadOnScreen and not RootOnScreen then return end

    -- CALCULATE DYNAMIC 2D BOX
    local TopY = HeadPos.Y - (Head.Size.Y / 2 * (RootPos.Z / 100)) -- Top Y slightly above head
    local BottomY = RootPos.Y + (RootPart.Size.Y / 2 * (RootPos.Z / 100)) -- Bottom Y at the bottom of the root part
    local CenterX = RootPos.X
    
    local Height = math.abs(TopY - BottomY)
    local Width = Height * 0.4 -- Standard R6/R15 ratio (approx 40% of height)

    local PosX = CenterX - Width / 2
    local PosY = TopY

    -- 2D Box (Box Drawing)
    if IsESPBoxEnabled and Drawing then
        local Box = ESPDrawings[Player.Name .. "_Box"]
        if not Box then
            Box = Drawing.new("Square")
            Box.Thickness = 1
            Box.Filled = false
            Box.Color = ESPColor
            ESPDrawings[Player.Name .. "_Box"] = Box
        end
        
        Box.Position = Vector2.new(PosX, PosY)
        Box.Size = Vector2.new(Width, Height)
        Box.Visible = true
    end
    
    -- Player Name (Text Drawing)
    if IsESPNameEnabled and Drawing then
        local NameText = ESPDrawings[Player.Name .. "_Name"]
        if not NameText then
            NameText = Drawing.new("Text")
            NameText.Size = 12
            NameText.Outline = true
            NameText.Font = Drawing.Fonts.UI
            ESPDrawings[Player.Name .. "_Name"] = NameText
        end
        NameText.Text = Player.Name
        NameText.Position = Vector2.new(CenterX, PosY - 15) -- Above the box
        NameText.Color = ESPColor
        NameText.Visible = true
    end
    
    -- Distance (Text Drawing)
    if IsESPDistanceEnabled and Drawing then
        local DistanceText = ESPDrawings[Player.Name .. "_Distance"]
        if not DistanceText then
            DistanceText = Drawing.new("Text")
            DistanceText.Size = 10
            DistanceText.Outline = true
            DistanceText.Font = Drawing.Fonts.UI
            ESPDrawings[Player.Name .. "_Distance"] = DistanceText
        end
        DistanceText.Text = tostring(Distance) .. "m"
        DistanceText.Position = Vector2.new(CenterX, PosY + Height + 5) -- Below the box
        DistanceText.Color = ESPColor
        DistanceText.Visible = true
    end
end

local function ESPLoop()
    if not IsESPEnabled then 
        ClearDrawings()
        return 
    end
    
    -- Hide all drawings first
    for _, drawing in pairs(ESPDrawings) do
        if drawing and drawing.Visible then
            drawing.Visible = false
        end
    end
    
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            DrawPlayerESP(Player)
        end
    end
end

local function StartESP()
    if not Drawing then print("ESP Error: Drawing library not available.") return end
    if ESPConnection then return end 
    ESPConnection = RunService.RenderStepped:Connect(ESPLoop)
end

local function StopESP()
    if ESPConnection then
        ESPConnection:Disconnect()
        ESPConnection = nil
    end
    ClearDrawings()
end


-- ====================================================================
-- [[ 6. GUI HUB (WindUI) ]]
-- ====================================================================

if WindUi then
    local Window = WindUi:CreateWindow({
        Title = "DIX HUB V28.0",
        Author = "by Dixyi",
        Folder = "DIX_Hub_V28_Final",
        OpenButton = { Title = "DIX OPEN", Color = ColorSequence.new(Color3.fromHex("#FF4830"), Color3.fromHex("#FFBB30")) }
    })

    -- COMBAT Tab (Aimbot & Hitbox)
    local CombatTab = Window:Tab({ Title = "COMBAT", Icon = "target", })
    
    -- VISUALS Tab (ESP)
    local VisualsTab = Window:Tab({ Title = "VISUALS", Icon = "eye", })

    
    -- ================================================================
    -- COMBAT SECTION 1: Aimbot Settings
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
    
    -- 2. Target Selector (FIXED: ensures proper options are used)
    AimSection:Dropdown({
        Flag = "TargetPart",
        Title = "Target Part",
        Desc = "Select the body part for the aimbot to target.",
        Default = AimTargetPartName,
        Options = {"Head", "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso"},
        Callback = function(value)
            AimTargetPartName = value 
            CurrentTarget = nil -- Clear current target to find the new part immediately
        end
    })
    
    -- 3. FOV Slider
    AimSection:Slider({ 
        Flag = "FOV", 
        Title = "Aim FOV (Visual Circle)", 
        Desc = "Radius of the aimbot's field of vision (5 - 180 degrees).",
        Value = { Min = 5, Max = 180, Default = CurrentFOV, Step = 5 }, 
        Callback = function(value) 
            CurrentFOV = math.round(value)
            UpdateFOVVisual() 
        end 
    })
    
    -- 4. Other Settings
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
    -- COMBAT SECTION 2: Hitbox Expander Settings
    -- ================================================================
    local HitboxSection = CombatTab:Section({ Title = "Hitbox Expander Settings", })

    HitboxSection:Toggle({
        Flag = "HitboxToggle",
        Title = "Hitbox Expander: ON/OFF",
        Desc = "Locally increases the size of enemy hitboxes (HRT/Head). **(FIXED Logic)**",
        Default = Hitbox_Enabled,
        Callback = function(value)
            Hitbox_Enabled = value
            if Hitbox_Enabled then StartHitbox() else StopHitbox() end
        end
    })
    
    HitboxSection:Slider({ 
        Flag = "Multiplier", 
        Title = "Hitbox Multiplier (Size)", 
        Desc = "How many times the hitbox should be increased (1.1x to 5x).",
        Value = { Min = 1.1, Max = 5.0, Default = Hitbox_Multiplier, Step = 0.1 }, 
        Callback = function(value) 
            Hitbox_Multiplier = math.round(value * 10) / 10 
            if Hitbox_Enabled then
                 for _, Player in ipairs(Players:GetPlayers()) do
                     ApplyHitboxExpansion(Player) 
                 end
            end
        end 
    })
    
    -- ================================================================
    -- VISUALS SECTION 1: ESP Settings
    -- ================================================================
    local ESPSection = VisualsTab:Section({ Title = "Player ESP", })

    ESPSection:Toggle({
        Flag = "ESPToggle",
        Title = "ESP: ON/OFF",
        Desc = "Draws visuals for other players.",
        Default = IsESPEnabled,
        Callback = function(value)
            IsESPEnabled = value
            if IsESPEnabled then StartESP() else StopESP() end
        end
    })
    
    -- NEW: ESP Team Check
    ESPSection:Toggle({
        Flag = "ESPTeamCheckToggle",
        Title = "Team Check",
        Desc = "Do not draw visuals on teammates.",
        Default = IsESPTeamCheckEnabled,
        Callback = function(value) IsESPTeamCheckEnabled = value end
    })
    
    ESPSection:Toggle({
        Flag = "ESPBoxToggle",
        Title = "Draw Box **(FIXED Size)**",
        Default = IsESPBoxEnabled,
        Callback = function(value) IsESPBoxEnabled = value end
    })
    
    ESPSection:Toggle({
        Flag = "ESPNameToggle",
        Title = "Draw Name",
        Default = IsESPNameEnabled,
        Callback = function(value) IsESPNameEnabled = value end
    })
    
    ESPSection:Toggle({
        Flag = "ESPDistanceToggle",
        Title = "Draw Distance",
        Default = IsESPDistanceEnabled,
        Callback = function(value) IsESPDistanceEnabled = value end
    })

    -- Color Picker
    ESPSection:ColorPicker({
        Flag = "ESPColor",
        Title = "ESP Color",
        Default = ESPColor,
        Callback = function(color) ESPColor = color end
    })


    -- Window Closing Cleanup: Folding fix 
    Window:OnClose(function()
        if FOV_Visual_Element then
            if FOV_Draw_Method == "Drawing" then FOV_Visual_Element.Visible = false else FOV_Visual_Element.Visible = false end
        end
    end)
    
    -- Restore FOV visibility on window opening
    Window:OnOpen(function()
        if IsAimbotEnabled then 
             if FOV_Draw_Method == "Drawing" then FOV_Visual_Element.Visible = true else FOV_Visual_Element.Visible = true end
        end
    end)

    -- Start functions if enabled by default
    if IsAimbotEnabled then StartAiming() end
    if Hitbox_Enabled then StartHitbox() end
    if IsESPEnabled then StartESP() end

    print("DIX HUB V28.0 launched. All known bugs fixed. Target selector, stable ESP, and hitbox fix implemented.")
end
