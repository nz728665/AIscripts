local SCRIPT_NAME = "AERO"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- === CONFIG ===
local Config = {
    ESP = { 
        Enabled = true, 
        ShowTeam = false,
        BoxColor = Color3.fromRGB(255, 50, 50), -- Red
        TeamColor = Color3.fromRGB(50, 255, 50) -- Green
    },
    Hitbox = { 
        Enabled = false, 
        Multiplier = 2.0, 
        MaxMultiplier = 10.0,
        EnableCollision = false
    },
    Blink = {
        Enabled = false,
        Cooldown = 1.5
    },
    GUI = { Visible = true }
}

-- === CONNECTIONS ===
local connections = {}
local function connect(service, event, callback)
    local conn = service[event]:Connect(callback)
    table.insert(connections, conn)
    return conn
end

-- === ESP SYSTEM ===
local espHighlights = {}
local function updatePlayerESP(plr)
    if not plr or plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end
    local hl = espHighlights[plr]
    if not hl or hl.Parent ~= char then
        if hl then pcall(function() hl:Destroy() end) end
        local success, newHl = pcall(function()
            local h = Instance.new("Highlight")
            h.Parent = char
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Adornee = char
            return h
        end)
        if success then hl = newHl; espHighlights[plr] = hl else return end
    end
    local plrTeam = plr.Team
    local myTeam = LocalPlayer.Team
    local isSameTeam = (plrTeam ~= nil and myTeam ~= nil and plrTeam == myTeam)
    local shouldShow = Config.ESP.Enabled and (Config.ESP.ShowTeam or not isSameTeam)
    hl.Enabled = shouldShow
    if shouldShow then
        hl.FillColor = isSameTeam and Config.ESP.TeamColor or Config.ESP.BoxColor
        hl.OutlineColor = hl.FillColor
        hl.FillTransparency = 0.7
        hl.OutlineTransparency = 0.3
    else
        hl.FillTransparency = 1
        hl.OutlineTransparency = 1
    end
end
local function refreshAllESP()
    for _, plr in ipairs(Players:GetPlayers()) do task.spawn(function() updatePlayerESP(plr) end) end
end
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char) task.wait(0.5); updatePlayerESP(plr) end)
    if plr.Character then task.delay(0.5, function() updatePlayerESP(plr) end) end
end)
Players.PlayerRemoving:Connect(function(plr)
    if espHighlights[plr] then pcall(function() espHighlights[plr]:Destroy() end); espHighlights[plr] = nil end
end)
task.spawn(function()
    while true do
        task.wait(2)
        if Config.ESP.Enabled then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local hl = espHighlights[plr]
                    if not hl or not hl.Parent or hl.Parent ~= plr.Character then updatePlayerESP(plr) end
                end
            end
        end
    end
end)
task.delay(1, refreshAllESP)

-- === HITBOX SYSTEM ===
local hitboxCache = {}
local hitboxWhitelist = {"Head", "UpperTorso", "LowerTorso", "Torso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"}
local function cacheCharacterParts(character)
    local cached = {}
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") and table.find(hitboxWhitelist, part.Name) then 
            cached[part] = {Size = part.Size, CanCollide = part.CanCollide, Massless = part.Massless} 
        end
    end return cached
end
local function applyHitboxToCharacter(character, multiplier, enableCollision)
    if not character then return end
    local safeMult = math.min(multiplier, Config.Hitbox.MaxMultiplier)
    if not hitboxCache[character] then hitboxCache[character] = cacheCharacterParts(character) end
    for part, data in pairs(hitboxCache[character]) do
        if part and part.Parent then 
            part.Size = data.Size * safeMult
            part.CanCollide = enableCollision
            part.Massless = true
            part.Anchored = false
        end
    end
end
local function restoreCharacterHitbox(character)
    if not character or not hitboxCache[character] then return end
    for part, data in pairs(hitboxCache[character]) do
        if part and part.Parent then 
            part.Size = data.Size; part.CanCollide = data.CanCollide; part.Massless = data.Massless; part.Anchored = false 
        end
    end
    hitboxCache[character] = nil
end
local function refreshHitboxes()
    if not Config.Hitbox.Enabled then
        for char, _ in pairs(hitboxCache) do if char and char.Parent then restoreCharacterHitbox(char) end end
        hitboxCache = {}; return
    end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local isEnemy = (not LocalPlayer.Team) or (player.Team ~= LocalPlayer.Team)
            if isEnemy then applyHitboxToCharacter(player.Character, Config.Hitbox.Multiplier, Config.Hitbox.EnableCollision)
            elseif hitboxCache[player.Character] then restoreCharacterHitbox(player.Character) end
        end
    end
end
local function monitorCharacter(char)
    if not char then return end
    task.wait(0.3)
    if Config.Hitbox.Enabled then refreshHitboxes() end
end
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(monitorCharacter)
    if player.Character then monitorCharacter(player.Character) end
end)
for _, player in pairs(Players:GetPlayers()) do if player.Character then monitorCharacter(player.Character) end end

-- === CHAIN BLINK SYSTEM ===
local lastBlinkTime = 0
local isBlinking = false
local function impulseBlink(targetPos)
    if isBlinking then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end
    local now = tick()
    if now - lastBlinkTime < Config.Blink.Cooldown then return end
    local start = root.Position
    local diff = targetPos - start
    local totalDist = diff.Magnitude
    if totalDist < 50 then
        lastBlinkTime = now; isBlinking = true
        root.Anchored = true; task.wait()
        pcall(function() root.CFrame = CFrame.new(targetPos, targetPos + Vector3.new(0, 1, 0)) end)
        root.Anchored = false; humanoid:ChangeState(Enum.HumanoidStateType.Landed)
        root.Velocity = Vector3.zero; root.RotVelocity = Vector3.zero; isBlinking = false
        return
    end
    lastBlinkTime = now; isBlinking = true
    local stepSize = 40; local steps = math.ceil(totalDist / stepSize); local direction = diff.Unit
    local oldAutoRotate = humanoid.AutoRotate; humanoid.AutoRotate = false
    for i = 1, steps do
        local nextPos = start + (direction * stepSize * i)
        if i == steps then nextPos = targetPos end
        local rayOrigin = nextPos + Vector3.new(0, 5, 0); local rayDir = Vector3.new(0, -20, 0)
        local rayParams = RaycastParams.new(); rayParams.FilterDescendantsInstances = {char}
        local rayResult = workspace:Raycast(rayOrigin, rayDir, rayParams)
        local finalPos = rayResult and (rayResult.Position + Vector3.new(0, 2, 0)) or nextPos
        root.Anchored = true; task.wait()
        pcall(function() root.CFrame = CFrame.new(finalPos, finalPos + Vector3.new(0, 1, 0)) end)
        root.Anchored = false; root.Velocity = Vector3.zero; root.RotVelocity = Vector3.zero
        task.wait(0.01)
    end
    humanoid.AutoRotate = oldAutoRotate; humanoid:ChangeState(Enum.HumanoidStateType.Landed)
    root.Velocity = Vector3.zero; isBlinking = false
end
connect(UserInputService, "InputBegan", function(input, gameProcessed)
    if gameProcessed then return end
    if Config.Blink.Enabled and input.UserInputType == Enum.UserInputType.MouseButton1 then
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
            impulseBlink(Mouse.Hit.Position)
        end
    end
end)

-- === FUTURISTIC GUI SETUP ===
local AeroGUI = Instance.new("ScreenGui")
AeroGUI.Name = "AERO_INTERFACE"
AeroGUI.ResetOnSpawn = false
AeroGUI.Parent = game.CoreGui
AeroGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
AeroGUI.DisplayOrder = 100

-- Main Container
local mainFrame = Instance.new("Frame", AeroGUI)
mainFrame.Size = UDim2.new(0, 380, 0, 450)
mainFrame.Position = UDim2.new(0.5, -190, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20) -- Deep Dark Blue/Black
mainFrame.BorderSizePixel = 0
mainFrame.ZIndex = 1
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 4) -- Sharp corners
Instance.new("UIStroke", mainFrame).Color = Color3.fromRGB(0, 255, 255) -- Cyan Border
Instance.new("UIStroke", mainFrame).Thickness = 1

-- Header
local header = Instance.new("Frame", mainFrame)
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
header.BorderSizePixel = 0
header.ZIndex = 2
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 4)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, -60, 1, 0)
title.BackgroundTransparency = 1
title.Text = "AERO // v8.0"
title.Font = Enum.Font.Code
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(0, 255, 255) -- Cyan
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.new(0, 20, 0, 0)
title.ZIndex = 3
title.TextStrokeTransparency = 0.8

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0, 40, 1, 0)
closeBtn.Position = UDim2.new(1, -40, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
closeBtn.Text = "[X]"
closeBtn.Font = Enum.Font.Code
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 3
closeBtn.MouseButton1Click:Connect(function() Config.GUI.Visible = false; mainFrame.Visible = false end)

-- Tab Selector
local tabSelector = Instance.new("Frame", mainFrame)
tabSelector.Size = UDim2.new(1, -20, 0, 30)
tabSelector.Position = UDim2.new(0, 10, 0, 60)
tabSelector.BackgroundTransparency = 1
tabSelector.ZIndex = 2

local tabs = {"ESP", "HITBOX", "BLINK", "SYS"}
local tabButtons = {}
local tabContent = {}

local function switchTab(idx)
    for i, btn in ipairs(tabButtons) do
        if i == idx then
            btn.BackgroundColor3 = Color3.fromRGB(0, 255, 255) -- Active Cyan
            btn.TextColor3 = Color3.fromRGB(0, 0, 0)
        else
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            btn.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end
    for i, frame in ipairs(tabContent) do frame.Visible = i == idx end
end

for i, name in ipairs(tabs) do
    local btn = Instance.new("TextButton", tabSelector)
    btn.Size = UDim2.new(1/#tabs, -5, 1, 0)
    btn.Position = UDim2.new((i-1)/#tabs, 5*(i-1), 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.Text = name
    btn.Font = Enum.Font.Code
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(150, 150, 150)
    btn.BorderSizePixel = 0
    btn.ZIndex = 2
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 2)
    btn.MouseButton1Click:Connect(function() switchTab(i) end)
    tabButtons[i] = btn
    
    local content = Instance.new("ScrollingFrame", mainFrame)
    content.Size = UDim2.new(1, -20, 1, -120)
    content.Position = UDim2.new(0, 10, 0, 100)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 4
    content.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 255)
    content.BorderSizePixel = 0
    content.Visible = i == 1
    content.ZIndex = 1
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabContent[i] = content
end

-- UI HELPERS (Strict Style)
local function createToggle(parent, text, yPos, defaultValue, callback)
    local state = { value = defaultValue }
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, 0, 0, 40)
    container.Position = UDim2.new(0, 0, 0, yPos)
    container.BackgroundTransparency = 1
    
    local label = Instance.new("TextLabel", container)
    label.Size = UDim2.new(1, -50, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.Code
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextXAlignment = Enum.TextXAlignment.Left
    
    local btn = Instance.new("TextButton", container)
    btn.Size = UDim2.new(0, 40, 0, 20)
    btn.Position = UDim2.new(1, -40, 0.5, -10)
    btn.BackgroundColor3 = state.value and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(50, 50, 50)
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.ZIndex = 2
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 2)
    
    local knob = Instance.new("Frame", btn)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 2)
    
    btn.MouseButton1Click:Connect(function()
        state.value = not state.value
        btn.BackgroundColor3 = state.value and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(50, 50, 50)
        knob.Position = UDim2.new(0, state.value and 22 or 2, 0.5, -8)
        callback(state.value)
    end)
    
    -- Update canvas size
    parent.CanvasSize = UDim2.new(0, 0, 0, yPos + 50)
end

local function createSlider(parent, label, min, max, default, yPos, callback)
    local value = default
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, 0, 0, 50)
    container.Position = UDim2.new(0, 0, 0, yPos)
    container.BackgroundTransparency = 1
    
    local labelObj = Instance.new("TextLabel", container)
    labelObj.Size = UDim2.new(1, 0, 0, 20)
    labelObj.BackgroundTransparency = 1
    labelObj.Text = label .. " // " .. string.format("%.1f", default)
    labelObj.Font = Enum.Font.Code
    labelObj.TextSize = 12
    labelObj.TextColor3 = Color3.fromRGB(150, 150, 150)
    labelObj.TextXAlignment = Enum.TextXAlignment.Left
    
    local track = Instance.new("Frame", container)
    track.Size = UDim2.new(1, 0, 0, 4)
    track.Position = UDim2.new(0, 0, 0, 30)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 2)
    
    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 2)
    
    local knob = Instance.new("TextButton", track)
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = UDim2.new((default-min)/(max-min), -6, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    
    local dragging = false
    knob.MouseButton1Down:Connect(function() dragging = true end)
    connect(UserInputService, "InputEnded", function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    connect(UserInputService, "InputChanged", function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
            local newVal = min + (rel / track.AbsoluteSize.X) * (max - min)
            value = newVal
            fill.Size = UDim2.new((value-min)/(max-min), 0, 1, 0)
            knob.Position = UDim2.new((value-min)/(max-min), -6, 0.5, -6)
            labelObj.Text = label .. " // " .. string.format("%.1f", value)
            callback(value)
        end
    end)
    
    parent.CanvasSize = UDim2.new(0, 0, 0, yPos + 60)
end

-- === GUI CONTENT ===

-- ESP TAB
createToggle(tabContent[1], "ENABLE ESP", 10, Config.ESP.Enabled, function(v) Config.ESP.Enabled = v; refreshAllESP() end)
createToggle(tabContent[1], "SHOW TEAMMATES", 60, Config.ESP.ShowTeam, function(v) Config.ESP.ShowTeam = v; refreshAllESP() end)

-- HITBOX TAB
createToggle(tabContent[2], "ENABLE HITBOX", 10, Config.Hitbox.Enabled, function(v) Config.Hitbox.Enabled = v; refreshHitboxes() end)
createToggle(tabContent[2], "COLLISION", 60, Config.Hitbox.EnableCollision, function(v) Config.Hitbox.EnableCollision = v; if Config.Hitbox.Enabled then refreshHitboxes() end end)
createSlider(tabContent[2], "MULTIPLIER", 1, 20, Config.Hitbox.Multiplier, 110, function(v) Config.Hitbox.Multiplier = v; if Config.Hitbox.Enabled then refreshHitboxes() end end)

-- BLINK TAB
createToggle(tabContent[3], "ENABLE BLINK", 10, Config.Blink.Enabled, function(v) Config.Blink.Enabled = v end)
createSlider(tabContent[3], "COOLDOWN", 0.5, 5.0, Config.Blink.Cooldown, 60, function(v) Config.Blink.Cooldown = v end)
local blinkInfo = Instance.new("TextLabel", tabContent[3])
blinkInfo.Size = UDim2.new(1, 0, 0, 40)
blinkInfo.Position = UDim2.new(0, 0, 0, 120)
blinkInfo.BackgroundTransparency = 1
blinkInfo.Text = "CTRL + CLICK TO TELEPORT"
blinkInfo.Font = Enum.Font.Code
blinkInfo.TextSize = 12
blinkInfo.TextColor3 = Color3.fromRGB(0, 255, 255)
blinkInfo.TextWrapped = true
tabContent[3].CanvasSize = UDim2.new(0, 0, 0, 170)

-- SYS TAB
local rejoinBtn = Instance.new("TextButton", tabContent[4])
rejoinBtn.Size = UDim2.new(1, 0, 0, 40)
rejoinBtn.Position = UDim2.new(0, 0, 0, 10)
rejoinBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
rejoinBtn.Text = "REJOIN SERVER"
rejoinBtn.Font = Enum.Font.Code
rejoinBtn.TextSize = 14
rejoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rejoinBtn.BorderSizePixel = 0
Instance.new("UICorner", rejoinBtn).CornerRadius = UDim.new(0, 2)
rejoinBtn.MouseButton1Click:Connect(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)

local menuKey = Enum.KeyCode.LeftAlt
local keyBtn = Instance.new("TextButton", tabContent[4])
keyBtn.Size = UDim2.new(1, 0, 0, 40)
keyBtn.Position = UDim2.new(0, 0, 0, 60)
keyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
keyBtn.Text = "MENU KEY: LEFT_ALT"
keyBtn.Font = Enum.Font.Code
keyBtn.TextSize = 14
keyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
keyBtn.BorderSizePixel = 0
Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 2)

local isSetting = false
keyBtn.MouseButton1Click:Connect(function() 
    isSetting = true
    keyBtn.Text = "PRESS ANY KEY..." 
end)

connect(UserInputService, "InputBegan", function(inp, gProc)
    if gProc then return end
    if isSetting then
        if inp.KeyCode ~= Enum.KeyCode.Unknown then menuKey = inp.KeyCode
        elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then menuKey = inp.UserInputType
        end
        keyBtn.Text = "MENU KEY: " .. tostring(menuKey):gsub("Enum.KeyCode.", ""):gsub("Enum.UserInputType.", ""):upper()
        isSetting = false
        return
    end
    if inp.KeyCode == menuKey or inp.UserInputType == menuKey then
        Config.GUI.Visible = not Config.GUI.Visible
        mainFrame.Visible = Config.GUI.Visible
    end
end)

tabContent[4].CanvasSize = UDim2.new(0, 0, 0, 110)

-- Dragging Logic
local dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)
connect(UserInputService, "InputChanged", function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        if dragStart then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)
header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragStart = nil end
end)

-- Init
mainFrame.Visible = Config.GUI.Visible
print("AERO v8.0")
print("21.04.2026 last update")
