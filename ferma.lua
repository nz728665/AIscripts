local RunService = game:GetService("RunService")
local cloneref = (cloneref or clonereference or function(instance) return instance end)
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
   
local function SendLog(keyUsed)
   print(keyUsed)
end

local function LoadMainScript()
    SendLog(_G.LastKeyEntered or "Unknown")

    local Window = WindUI:CreateWindow({
        Title = "hub",
        Folder = "my hub",
        Icon = "lucide:swords",
		Background = "rbxassetid://7229442422",
        NewElements = true,
        HideSearchBar = false,
        OpenButton = {
            Title = "Hub",
            Enabled = true,
            Draggable = true,
            Scale = 0.5,
            Color = ColorSequence.new(Color3.fromHex("#30FF6A"), Color3.fromHex("#e7ff2f"))
        }
    })

Window:SetBackgroundImageTransparency(0.8)
Window:SetToggleKey(Enum.KeyCode.K)
local larry = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Larry")

local FarmTab = Window:Tab({ Title = "Farm", Icon = "solar:home-2-bold" })

local larry = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Larry")
local plowField = larry:WaitForChild("EVTPlowFieldCell")
local field = workspace:WaitForChild("Objects"):WaitForChild("Fields"):WaitForChild("Field")

local function getPlowAttachment()
    local equipment = workspace.Objects.Equipment:FindFirstChild("JDShank")
    if equipment then
        local attach = equipment.Components.Plow.RaycastPart.Attachment
        return {attach, attach}
    end
    return nil
end

local PlowSection = FarmTab:Section({ Title = "Field Tools" })

PlowSection:Button({
    Title = "Auto Plow All",
	   Desc = "Auto plow all (MAY NOT WORK)",
    Callback = function()
        task.spawn(function()
            local attachments = getPlowAttachment()
            if not attachments then return end

            for i = 1, 2920, 50 do
                local batch = {}
                for j = i, math.min(i + 49, 2920) do
                    table.insert(batch, j)
                end
                
                plowField:FireServer(field, batch, attachments)
                task.wait(0.1)
            end
        end)
    end
})

PlowSection:Button({
    Title = "Hire Cropduster",
    Desc = "Hires a cropduster ( may not work)",
    Callback = function()
        local args = {
            workspace:WaitForChild("Objects"):WaitForChild("Fields"):WaitForChild("Field")
        }
        
        game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Larry"):WaitForChild("EVTHireCropduster"):FireServer(unpack(args))
    end
})

PlowSection:Toggle({ 
    Title = "Fast Growth (Rain)",
    Desc = "Activates rain to significantly speed up crop growth",
    Default = false,
    Callback = function(state)
        game:GetService("ReplicatedStorage").Values.RainEnabled.Value = state
        if state then
            print("Hub | X: Rain activated for faster growth!")
        else
            print("Hub | X: Rain deactivated.")
        end
    end
})

    local CowsTab = Window:Tab({ Title = "Cows", Icon = "solar:bone-bold" })
CowsTab:Toggle({
    Title = "Auto Herd, Milk & Open All Barn Gates(Premium)",
	   Desc = "All options in one",
    Callback = function(state)
        _G.AutoHerdMilk = state
        task.spawn(function()
            while _G.AutoHerdMilk do
                local rMilk = larry:WaitForChild("EVTCollectAnimalProduction")
                local rHerd = larry:WaitForChild("EVTHerdRequest")
                local rGate = larry:WaitForChild("EVTOpenBarnGate")
                
                local animalsFolder = workspace:WaitForChild("Objects"):WaitForChild("Animals")
                local buildingsFolder = workspace:WaitForChild("Objects"):WaitForChild("Buildings")
                
                local barns = {}
                for _, b in pairs(buildingsFolder:GetChildren()) do
                    if b.Name:find("Barn") and b:FindFirstChild("AnimalContainer") then
                        table.insert(barns, b)
                        if #barns >= 5 then break end
                    end
                end

                for _, a in pairs(animalsFolder:GetChildren()) do
                    if not _G.AutoHerdMilk then break end
                    
                    if a.Name == "Cow" and a:FindFirstChild("HumanoidRootPart") then
                        rMilk:FireServer("Milk", a)
                        
                        local nearestBarn, shortestDistance = nil, math.huge
                        for _, barn in pairs(barns) do
                            local barnPart = barn:FindFirstChild("Base") or barn:FindFirstChildWhichIsA("BasePart")
                            if barnPart then
                                local distance = (a.HumanoidRootPart.Position - barnPart.Position).Magnitude
                                if distance < shortestDistance then
                                    shortestDistance = distance
                                    nearestBarn = barn
                                end
                            end
                        end
                        
                        if nearestBarn then
                            rHerd:FireServer({a}, nearestBarn)
                            
                            task.spawn(function()
                                task.wait(5)
                                if _G.AutoHerdMilk then
                                    local spots = nearestBarn:WaitForChild("AnimalContainer"):WaitForChild("Spots")
                                    for _, spot in pairs(spots:GetChildren()) do
                                        if spot:FindFirstChild("Gate") then
                                            rGate:FireServer(spot.Gate)
                                        end
                                    end
                                end
                            end)
                        end
                    end
                end
                task.wait(10)
            end
        end)
    end
})

CowsTab:Toggle({
    Title = "Auto Milk",
	   Desc = "Milks all the cows",
    Callback = function(state)
        _G.AutoMilkFree = state
        task.spawn(function()
            while _G.AutoMilkFree do
                local rMilk = larry:WaitForChild("EVTCollectAnimalProduction")
                local animalsFolder = workspace:WaitForChild("Objects"):WaitForChild("Animals")

                for _, a in pairs(animalsFolder:GetChildren()) do
                    if not _G.AutoMilkFree then break end
                    
                    if a.Name == "Cow" then
                        rMilk:FireServer("Milk", a)
                    end
                end
                task.wait(5)
            end
        end)
    end
})

    CowsTab:Button({
    Title = "Open All Gates",
    Desc = "Opens all barn stall gates automatically",
    Callback = function()
        task.spawn(function()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local Workspace = game:GetService("Workspace")
            local Modules = ReplicatedStorage:WaitForChild("Modules")
            local Larry = Modules:WaitForChild("Larry")
            local Remote = Larry:WaitForChild("EVTOpenBarnGate")
            local Objects = Workspace:WaitForChild("Objects")
            local Buildings = Objects:WaitForChild("Buildings")

            local allBuildings = Buildings:GetChildren()
            
            for i = 1, #allBuildings do
                local currentBuilding = allBuildings[i]
                
                if currentBuilding.Name:find("Barn") then
                    local container = currentBuilding:FindFirstChild("AnimalContainer")
                    
                    if container then
                        local spotsFolder = container:FindFirstChild("Spots")
                        
                        if spotsFolder then
                            local allSpots = spotsFolder:GetChildren()
                            
                            for j = 1, #allSpots do
                                local currentSpot = allSpots[j]
                                local targetGate = currentSpot:FindFirstChild("Gate")
                                
                                if targetGate then
                                    local callSuccess, callError = pcall(function()
                                        Remote:FireServer(targetGate)
                                    end)
                                    
                                    if not callSuccess then
                                        warn("Remote error: " .. tostring(callError))
                                    end
                                    
                                    task.wait(0.025)
                                end
                            end
                        end
                    end
                end
                
                task.wait(0.1)
            end

            WindUI:Notify({
                Title = "Hub | X",
                Content = "Execution finished: All detected barn gates opened.",
                Duration = 4
            })
        end)
    end
})

CowsTab:Button({
    Title = "Herd All Cows",
    Desc = "Sends all cows back to the specified wooden barn",
    Callback = function()
        task.spawn(function()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local Workspace = game:GetService("Workspace")
            local RunService = game:GetService("RunService")
            
            local Modules = ReplicatedStorage:WaitForChild("Modules")
            local Larry = Modules:WaitForChild("Larry")
            local HerdRemote = Larry:WaitForChild("EVTHerdRequest")
            
            local Objects = Workspace:WaitForChild("Objects")
            local Buildings = Objects:WaitForChild("Buildings")
            local Animals = Objects:WaitForChild("Animals")
            
            local TargetBarn = Buildings:WaitForChild("AutoWoodenBarn")
            local AllAnimals = Animals:GetChildren()
            local CowTable = {}
            
            for index = 1, #AllAnimals do
                local currentAnimal = AllAnimals[index]
                
                if currentAnimal.Name == "Cow" then
                    table.insert(CowTable, currentAnimal)
                end
            end
            
            if #CowTable > 0 then
                local executionSuccess, executionError = pcall(function()
                    HerdRemote:FireServer(CowTable, TargetBarn)
                end)
                
                if executionSuccess then
                    WindUI:Notify({
                        Title = "Hub | X",
                        Content = "Successfully herded " .. tostring(#CowTable) .. " cows to the barn (including all cows on the map)",
                        Duration = 5
                    })
                else
                    WindUI:Notify({
                        Title = "Hub | X Error",
                        Content = "Failed to herd animals: " .. tostring(executionError),
                        Duration = 5
                    })
                end
            else
                WindUI:Notify({
                    Title = "Hub | X",
                    Content = "No cows were detected on the map.",
                    Duration = 5
                })
            end
        end)
    end
})

CowsTab:Button({
    Title = "Clean All Barns",
    Desc = "Performs a deep cleaning of all detected barn filth",
    Callback = function()
        task.spawn(function()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local Workspace = game:GetService("Workspace")
            local RunService = game:GetService("RunService")
            
            local Modules = ReplicatedStorage:WaitForChild("Modules")
            local Larry = Modules:WaitForChild("Larry")
            local CleaningRemote = Larry:WaitForChild("EVTFilthCleaning")
            
            local Objects = Workspace:WaitForChild("Objects")
            local Buildings = Objects:WaitForChild("Buildings")
            
            local AllBuildings = Buildings:GetChildren()
            local CleanedSpotsCount = 0
            
            for i = 1, #AllBuildings do
                local currentBuilding = AllBuildings[i]
                
                if currentBuilding.Name:find("Barn") then
                    local animalContainer = currentBuilding:FindFirstChild("AnimalContainer")
                    
                    if animalContainer then
                        local spotsFolder = animalContainer:FindFirstChild("Spots")
                        
                        if spotsFolder then
                            local allSpots = spotsFolder:GetChildren()
                            
                            for j = 1, #allSpots do
                                local currentSpot = allSpots[j]
                                
                                if currentSpot then
                                    local success, errorMessage = pcall(function()
                                        CleaningRemote:FireServer(currentSpot)
                                    end)
                                    
                                    if success then
                                        CleanedSpotsCount = CleanedSpotsCount + 1
                                    end
                                    
                                    if j % 10 == 0 then
                                        task.wait(0.01)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            if CleanedSpotsCount > 0 then
                WindUI:Notify({
                    Title = "Hub | X",
                    Content = "Sanitation complete. Total spots processed: " .. tostring(CleanedSpotsCount),
                    Duration = 5
                })
            else
                WindUI:Notify({
                    Title = "Hub | X",
                    Content = "Cleaning protocol finished. No filth detected in barns.",
                    Duration = 5
                })
            end
        end)
    end
})

local larry = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Larry")
local stage1 = larry:WaitForChild("EVTCutTreeWithClaw_Stage1")
local stage2 = larry:WaitForChild("EVTCutTreeWithClaw_Stage2")
local field = workspace:WaitForChild("Objects"):WaitForChild("Fields"):WaitForChild("Field")

local WoodTab = Window:Tab({
    Title = "Wood",
    Icon = "trees"
})

local WoodSection = WoodTab:Section({ Title = "Forestry Tools" })

WoodSection:Button({
    Title = "Auto Cut All Trees",
	   Desc = "Cuts All Trees (delay)",
    Callback = function()
        task.spawn(function()
            for i = 1, 2920 do
                stage1:FireServer(field, i)
                task.wait(0.1)
                
                for cut = 1, 8 do
                    stage2:FireServer(field, i, -2.6332246724327177)
                    task.wait(0.01)
                end
                
                if i % 5 == 0 then
                    task.wait(0.2)
                end
            end
        end)
    end
})

WoodSection:Toggle({
    Title = "Load All Logs",
	   Desc = "Loads all logs onto your hauler",
    Callback = function()
        local draggableObjects = workspace:FindFirstChild("Objects") 
            and workspace.Objects:FindFirstChild("DraggableObjects")
        
        if draggableObjects then
            for _, obj in ipairs(draggableObjects:GetChildren()) do
                if obj.Name == "Log" then
                    local args = {
                        {
                            obj
                        }
                    }
                    
                    game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Larry"):WaitForChild("EVTEatDraggables"):FireServer(unpack(args))
                    task.wait(0.05)
                end
            end
        end
    end
})

local AutoFarmEnabled = false

WoodSection:Toggle({
    Title = "Auto Load & Deposit",
    Value = false,
    Callback = function(state)
        AutoFarmEnabled = state
        task.spawn(function()
            while AutoFarmEnabled do
                local larry = game:GetService("ReplicatedStorage").Modules.Larry
                local objects = workspace.Objects
                local logs = objects.DraggableObjects:GetChildren()
                
                for _, obj in ipairs(logs) do
                    if not AutoFarmEnabled then break end
                    if obj.Name == "Log" then
                        larry.EVTEatDraggables:FireServer({obj})
                        task.wait(0.01)
                    end
                end

                task.wait(0.5)

                if AutoFarmEnabled then
                    local hauler = objects.Equipment.IndustrialLogHauler
                    local storage = objects.Buildings.LogStorage
                    local depositArgs = {hauler, storage}
                    
                    larry.EVTDepositLogs_Stage1:FireServer(unpack(depositArgs))
                    task.wait(0.2)
                    larry.EVTDepositLogs_Stage2:FireServer(unpack(depositArgs))
                end
                
                task.wait(1.5)
            end
        end)
    end
})

WoodSection:Input({
    Title = "Custom Birch Planks Value",
 Desc = "Sets the birch planks value",
    Default = "12000",
    Placeholder = "Enter number...",
    Callback = function(Value)
        local birchPlank = game:GetService("ReplicatedStorage").SellValues.Log.BirchPlank
        if birchPlank and tonumber(Value) then
            birchPlank.Value = tonumber(Value)
        end
    end
})

local VehicleTab = Window:Tab({ 
    Title = "Vehicle", 
    Icon = "solar:bus-bold" 
})

local TargetSpeed = 38
local TargetBoost = 1.25

VehicleTab:Input({
    Title = "Max Speed",
    Desc = "Enter value (Default: 38)",
    Default = "38",
    Callback = function(value)
        TargetSpeed = tonumber(value) or 38
    end
})

VehicleTab:Input({
    Title = "Road Boost",
    Desc = "Enter value (Default: 1.25)",
    Default = "1.25",
    Callback = function(value)
        TargetBoost = tonumber(value) or 1.25
    end
})

VehicleTab:Paragraph({
    Title = "Note",
    Desc = "When changed speed and boost, simply re-enter the equipment the changes were made on to work"
})

local function applyTuning(vehicle)
    if vehicle then
        local pt = vehicle:FindFirstChild("Powertrain", true)
        if pt then
            pt:SetAttribute("MaxSpeed", TargetSpeed)
            pt:SetAttribute("RoadBoost", TargetBoost)
        end
    end
end

game.Players.LocalPlayer.Character.Humanoid.Seated:Connect(function(active, seatPart)
    if active and seatPart and seatPart:IsA("VehicleSeat") then
        local veh = seatPart:FindFirstAncestorOfClass("Model")
        applyTuning(veh)
    end
end)

game:GetService("RunService").Heartbeat:Connect(function()
    local char = game.Players.LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum and hum.SeatPart then
        local veh = hum.SeatPart:FindFirstAncestorOfClass("Model")
        applyTuning(veh)
    end
end)

    local ChickensTab = Window:Tab({ Title = "Chickens", Icon = "solar:check-square-bold" })
   ChickensTab:Button({
    Title = "Collect Eggs",
	   Desc = "Collects all eggs",
    Callback = function()
        local rCollect = larry:WaitForChild("EVTCollectAnimalProduction")
        local buildingsFolder = workspace:WaitForChild("Objects"):WaitForChild("Buildings")
        
        for _, b in pairs(buildingsFolder:GetChildren()) do
            if b.Name:find("Coop") or b.Name:find("Chicken") then
                rCollect:FireServer("Eggs", b)
            end
        end
    end
})

ChickensTab:Button({
    Title = "Clean Chicken Coop",
	   Desc = "Cleans the chicken coop",
    Callback = function()
        local rClean = larry:WaitForChild("EVTFilthCleaning")
        local buildingsFolder = workspace:WaitForChild("Objects"):WaitForChild("Buildings")
        
        for _, b in pairs(buildingsFolder:GetChildren()) do
            if b.Name:find("Coop") or b.Name:find("Chicken") then
                rClean:FireServer(b)
            end
        end
    end
})

    local HighRiskTab = Window:Tab({ Title = "High Risk", Icon = "solar:danger-bold" })
    local superRunEnabled = false
    HighRiskTab:Toggle({
        Title = "Super Run (Bypass)",
		   Desc = "Super Run",
        Callback = function(state)
            superRunEnabled = state
            local player = game.Players.LocalPlayer
            task.spawn(function()
                while superRunEnabled do
                    local char = player.Character
                    local hum = char and char:FindFirstChild("Humanoid")
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root and hum and hum.MoveDirection.Magnitude > 0 then
                        root.AssemblyLinearVelocity = Vector3.new(hum.MoveDirection.X * 100, root.AssemblyLinearVelocity.Y, hum.MoveDirection.Z * 100)
                    end
                    task.wait()
                end
            end)
        end
    })

    local infJumpEnabled = false
    HighRiskTab:Toggle({
        Title = "Infinite Jump",
		   Desc = "Infinite Jump",
        Callback = function(state)
            infJumpEnabled = state
            game:GetService("UserInputService").JumpRequest:Connect(function()
                if infJumpEnabled then
                    local char = game.Players.LocalPlayer.Character
                    if char and char:FindFirstChildOfClass("Humanoid") then
                        char:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
                    end
                end
            end)
        end
    })

HighRiskTab:Toggle({
    Title = "Fly & No Clip",
	   Desc = "Fly and No Clip",
    Callback = function(state)
        _G.Flying = state
        local FlySpeed = 350
        local lp = game:GetService("Players").LocalPlayer
        
        task.spawn(function()
            while _G.Flying do
                local char = lp.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")
                local cam = workspace.CurrentCamera
                
                if hrp and hum then
                    hum.PlatformStand = true
                    local moveDir = Vector3.new(0, 0, 0)
                    local uis = game:GetService("UserInputService")
                    
                    if uis:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
                    if uis:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
                    if uis:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
                    if uis:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
                    if uis:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
                    if uis:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
                    
                    if moveDir.Magnitude > 0 then
                        hrp.Velocity = moveDir.Unit * FlySpeed
                    else
                        hrp.Velocity = Vector3.new(0, 0, 0)
                    end
                    
                    for _, part in pairs(char:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
                task.wait()
            end
            
            if lp.Character and lp.Character:FindFirstChild("Humanoid") then
                lp.Character.Humanoid.PlatformStand = false
                for _, part in pairs(lp.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end)
    end
})

    local PaidTab = Window:Tab({ Title = "Premium", Icon = "solar:dollar-minimalistic-bold" })

   PaidTab:Toggle({
    Title = "Unlock Farmers Club",
    Desc = "Bypass local checks to grant instant access to exclusive Farmers Club features",
    Callback = function(toggleState)
        task.spawn(function()
            local Players = game:GetService("Players")
            local RunService = game:GetService("RunService")
            local LocalPlayer = Players.LocalPlayer
            
            local AttributeName = "OwnsFarmersClub"
            local InitialValue = true
            
            if toggleState then
                local success, err = pcall(function()
                    LocalPlayer:SetAttribute(AttributeName, InitialValue)
                end)
                
                if success then
                    local connection
                    connection = LocalPlayer.AttributeChanged:Connect(function(changedAttribute)
                        if changedAttribute == AttributeName then
                            local currentValue = LocalPlayer:GetAttribute(AttributeName)
                            
                            if currentValue == false or currentValue == nil then
                                local reApplySuccess, reApplyError = pcall(function()
                                    LocalPlayer:SetAttribute(AttributeName, true)
                                end)
                                
                                if not reApplySuccess then
                                    warn("[Hub | X] Failed to re-inject attribute: " .. tostring(reApplyError))
                                end
                            end
                        end
                    end)
                    
                    WindUI:Notify({
                        Title = "Hub | X",
                        Content = "Farmers Club has been successfully unlocked. Status: Active",
                        Duration = 6
                    })
                else
                    WindUI:Notify({
                        Title = "Hub | X Critical Error",
                        Content = "Failed to modify player attributes: " .. tostring(err),
                        Duration = 6
                    })
                end
            else
                local removalSuccess = pcall(function()
                    LocalPlayer:SetAttribute(AttributeName, false)
                end)
                
                WindUI:Notify({
                    Title = "Hub | X",
                    Content = "Farmers Club bypass has been disabled.",
                    Duration = 4
                })
            end
        end)
    end
})

PaidTab:Toggle({
Title = "Unlock Custom Colors",
Desc = "Instant access to Custom Colors features",
Callback = function()
local player = game:GetService("Players").LocalPlayer
local path = player.PlayerGui.GuiViews.Stores.PremiumShop.Background.Other.Passes["Custom Colors"]
end
})

    local MiscTab = Window:Tab({ Title = "Misc", Icon = "solar:settings-bold" })
    MiscTab:Button({
        Title = "Finish Tasks",
		Desc = "Finishes all tasks (NOT WORKING)",
        Callback = function()
            local r = larry:WaitForChild("EVTCompleteTask")
            for i = 1, 10 do r:FireServer(i) task.wait(0.05) end
        end
    })

    MiscTab:Button({
    Title = "Free Task Refresh",
    Desc = "Forcefully reloads and synchronizes new tasks with the server",
    Callback = function()
        task.spawn(function()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local RunService = game:GetService("RunService")
            local HttpService = game:GetService("HttpService")
            
            local ModulesFolder = ReplicatedStorage:WaitForChild("Modules")
            local LarryModule = ModulesFolder:WaitForChild("Larry")
            local RefreshRemote = LarryModule:WaitForChild("EVTLoadNewTasks")
            
            local ExecutionID = HttpService:GenerateGUID(false)
            local StartTick = tick()
            
            local RequestStatus, RequestError = pcall(function()
                RefreshRemote:FireServer()
            end)
            
            if RequestStatus then
                local ExecutionTime = math.floor((tick() - StartTick) * 1000)
                
                WindUI:Notify({
                    Title = "Hub | X",
                    Content = "Task refresh successfully dispatched. Latency: " .. tostring(ExecutionTime) .. "ms",
                    Duration = 5
                })
            else
                WindUI:Notify({
                    Title = "Hub | X Error",
                    Content = "Internal remote failure: " .. tostring(RequestError),
                    Duration = 6
                })
            end
            
            local PostExecutionWait = task.wait(0.1)
        end)
    end
})

	local MiscSection = MiscTab:Section({
    Title = "Utilities"
})

MiscSection:Button({
    Title = "Rejoin Server",
    Desc = "rejoins and auto-executes the script",
    Callback = function()
        local ts = game:GetService("TeleportService")
        local p = game:GetService("Players").LocalPlayer
        local scriptToLoad = [[loadstring(game:HttpGet("https://gist.github.com/cocacola1fran-code/5af6dd4ca936ebfe3f81822694e5cdf6"))()]]

        if syn and syn.queue_on_teleport then
            syn.queue_on_teleport(scriptToLoad)
        elseif queue_on_teleport then
            queue_on_teleport(scriptToLoad)
        end

        if #game:GetService("Players"):GetPlayers() <= 1 then
            p:Kick("\nRejoining...")
            task.wait()
            ts:Teleport(game.PlaceId, p)
        else
            ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, p)
        end
    end
})

MiscSection:Button({
    Title = "Server Hop",
     Desc = "Server Hop",
    Callback = function()
        local HttpService = game:GetService("HttpService")
        local TeleportService = game:GetService("TeleportService")
        local Servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        for _, s in pairs(Servers.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id)
                break
            end
        end
    end
})

MiscSection:Button({
    Title = "Teleport to UFO",
    Desc = "Relocates your character to the secret UFO coordinates",
    Callback = function()
        task.spawn(function()
            local Players = game:GetService("Players")
            local Workspace = game:GetService("Workspace")
            local RunService = game:GetService("RunService")
            
            local LocalPlayer = Players.LocalPlayer
            local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
            
            local MarkersFolder = Workspace:WaitForChild("Markers")
            local GotoLocations = MarkersFolder:WaitForChild("GotoLocations")
            local TargetUFO = GotoLocations:FindFirstChild("UFO")
            
            local VerticalOffset = Vector3.new(0, 5, 0)
            
            if TargetUFO then
                local TargetCFrame = TargetUFO.CFrame
                local FinalPosition = TargetCFrame * CFrame.new(VerticalOffset)
                
                local TeleportSuccess, TeleportError = pcall(function()
                    Character:PivotTo(FinalPosition)
                end)
                
                if TeleportSuccess then
                    WindUI:Notify({
                        Title = "Hub | X",
                        Content = "Successfully teleported to UFO location.",
                        Duration = 5
                    })
                else
                    WindUI:Notify({
                        Title = "Hub | X Error",
                        Content = "Teleport protocol failed: " .. tostring(TeleportError),
                        Duration = 5
                    })
                end
            else
                WindUI:Notify({
                    Title = "Hub | X",
                    Content = "Error: UFO marker not found in Workspace.Markers.",
                    Duration = 6
                })
            end
        end)
    end
})

MiscSection:Toggle({
    Title = "Enable Anti-AFK Protocol",
    Desc = "Utilizes VirtualUser injection to bypass idle-kick detection globally",
    Callback = function(toggleState)
        task.spawn(function()
            local Players = game:GetService("Players")
            local VirtualUser = game:GetService("VirtualUser")
            local RunService = game:GetService("RunService")
            local LocalPlayer = Players.LocalPlayer
            
            getgenv().AntiAFKActive = toggleState
            
            if toggleState then
                local idledConnection
                idledConnection = LocalPlayer.Idled:Connect(function()
                    if getgenv().AntiAFKActive then
                        pcall(function()
                            VirtualUser:CaptureController()
                            VirtualUser:ClickButton2(Vector2.new(0, 0))
                        end)
                    else
                        if idledConnection then
                            idledConnection:Disconnect()
                        end
                    end
                end)
                
                task.spawn(function()
                    while getgenv().AntiAFKActive do
                        local success, err = pcall(function()
                            local viewportSize = workspace.CurrentCamera.ViewportSize
                            local randomPoint = Vector2.new(math.random(0, viewportSize.X), math.random(0, viewportSize.Y))
                            
                            VirtualUser:ButtonDown(Enum.UserInputType.MouseButton2, randomPoint, workspace.CurrentCamera.CFrame)
                            task.wait(0.05)
                            VirtualUser:ButtonUp(Enum.UserInputType.MouseButton2, randomPoint, workspace.CurrentCamera.CFrame)
                        end)
                        
                        if not success then
                            warn("Internal protocol error: " .. tostring(err))
                        end
                        
                        local waitInterval = math.random(150, 280)
                        task.wait(waitInterval)
                    end
                end)
                
                WindUI:Notify({
                    Title = "Hub | X",
                    Content = "Anti-AFK Global Protocol initiated. Protection: Active",
                    Duration = 6
                })
            else
                getgenv().AntiAFKActive = false
                
                WindUI:Notify({
                    Title = "Hub | X",
                    Content = "Anti-AFK Protection has been successfully terminated.",
                    Duration = 5
                })
            end
        end)
    end
})

local lightToggle = false
MiscSection:Button({
    Title = "Toggle Day/Night",
    Desc = "Switch between Noon and Midnight",
    Callback = function()
        lightToggle = not lightToggle
        game.Lighting.ClockTime = lightToggle and 0 or 12
    end
})

    local CreditsTab = Window:Tab({ Title = "Credits", Icon = "solar:info-square-bold" })
    CreditsTab:Paragraph({
        Title = "FaF V1.0.0 Credits",
        Desc = "opensourceguy"
    })
end
LoadMainScript()
