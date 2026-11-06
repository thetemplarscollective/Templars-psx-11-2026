-- Templar Hub v5
-- Based on working v4. Smart Farm, Safety+, Auto All, Stats.
-- Tabs: Farm | Safety | Hatch | Collect | Travel | Pets | Auto | Stats
-- AMOLED = pure black background, white text, purple accent.
-- NOT a dupe. No coin/pet dupe exists, server-side. Farm / hatch / collect only.
-- Use at your own risk, can get banned. Short sessions on an alt are safest.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local PSX_PLACES = {
    [6284583030] = true,
    [10321372166] = true,
    [7722306047] = true,
    [12610002282] = true,
}
if not PSX_PLACES[game.PlaceId] then
    warn("[Templar Hub] Not in PSX. PlaceId: " .. tostring(game.PlaceId))
    return
end

getgenv().SecureMode = true
getgenv().DisableArrayfieldAutoLoad = true

local Rayfield = nil
local ok, err = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/Rafacasari/ArrayField/main/v2.lua"))()
end)
if not ok or not Rayfield then
    warn("[Templar Hub] ArrayField failed: " .. tostring(err))
    return
end

-- AMOLED: overwrite the Default theme before the window is made.
-- Pure black, white text, purple accent, Dylan's colour.
pcall(function()
    local t = Rayfield.Theme.Default
    t.TextColor = Color3.fromRGB(240, 240, 240)
    t.Background = Color3.fromRGB(0, 0, 0)
    t.Topbar = Color3.fromRGB(5, 5, 5)
    t.Shadow = Color3.fromRGB(0, 0, 0)
    t.NotificationBackground = Color3.fromRGB(0, 0, 0)
    t.NotificationActionsBackground = Color3.fromRGB(20, 20, 20)
    t.TabBackground = Color3.fromRGB(12, 12, 12)
    t.TabStroke = Color3.fromRGB(40, 40, 40)
    t.TabBackgroundSelected = Color3.fromRGB(166, 120, 255)
    t.TabTextColor = Color3.fromRGB(240, 240, 240)
    t.SelectedTabTextColor = Color3.fromRGB(0, 0, 0)
    t.ElementBackground = Color3.fromRGB(10, 10, 10)
    t.ElementBackgroundHover = Color3.fromRGB(18, 18, 18)
    t.SecondaryElementBackground = Color3.fromRGB(5, 5, 5)
    t.ElementStroke = Color3.fromRGB(35, 35, 35)
    t.SecondaryElementStroke = Color3.fromRGB(25, 25, 25)
    t.SliderBackground = Color3.fromRGB(166, 120, 255)
    t.SliderProgress = Color3.fromRGB(166, 120, 255)
    t.SliderStroke = Color3.fromRGB(166, 120, 255)
    t.ToggleBackground = Color3.fromRGB(10, 10, 10)
    t.ToggleEnabled = Color3.fromRGB(166, 120, 255)
    t.ToggleDisabled = Color3.fromRGB(80, 80, 80)
    t.ToggleEnabledStroke = Color3.fromRGB(166, 120, 255)
    t.ToggleDisabledStroke = Color3.fromRGB(100, 100, 100)
    t.ToggleEnabledOuterStroke = Color3.fromRGB(166, 120, 255)
    t.ToggleDisabledOuterStroke = Color3.fromRGB(50, 50, 50)
    t.InputBackground = Color3.fromRGB(10, 10, 10)
    t.InputStroke = Color3.fromRGB(60, 60, 60)
    t.PlaceholderColor = Color3.fromRGB(150, 150, 150)
end)

local Window = Rayfield:CreateWindow({
    Name = "Templar Hub",
    LoadingTitle = "Templar Hub",
    LoadingSubtitle = "The Templars Collective",
    ConfigurationSaving = { Enabled = false },
    OldTabLayout = true,
})

local farmTab = Window:CreateTab("Farm", "13075651575", true)
local safetyTab = Window:CreateTab("Safety", "13075651575", true)
local hatchTab = Window:CreateTab("Hatch", "13075651575", true)
local collectTab = Window:CreateTab("Collect", "13075651575", true)
local travelTab = Window:CreateTab("Travel", "13075651575", true)
local petsTab = Window:CreateTab("Pets", "13075651575", true)
local autoTab = Window:CreateTab("Auto", "13075651575", true)
local statsTab = Window:CreateTab("Stats", "13075651575", true)

local function log(msg)
    print("[Templar Hub v5] " .. tostring(msg))
end

local lastStatus = ""
local statusPara = farmTab:CreateParagraph({ Title = "Status", Content = "Loading..." })
local function setStatus(msg)
    msg = tostring(msg)
    if msg == lastStatus then return end
    lastStatus = msg
    log(msg)
    pcall(function() statusPara:Set({ Title = "Status", Content = msg }) end)
end

local hatchStatusPara = hatchTab:CreateParagraph({ Title = "Hatch Status", Content = "Not hatching yet." })
local statsPara = nil
local sessionStart = os.time()
local successfulFarms = 0
local hatchCount = 0
local collectCount = 0
local function updateStats()
    if not statsPara then return end
    local elapsed = math.max(1, os.time() - sessionStart)
    local mins = math.floor(elapsed / 60)
    local secs = elapsed % 60
    local coinsNow = 0
    -- Inline count (findNearestCoins is defined later in the file, so do not call it here).
    pcall(function()
        local folder = Library and Library.Things:FindFirstChild("Coins")
        if folder and HumanoidRootPart then
            for _, coin in ipairs(folder:GetChildren()) do
                local part = coin:FindFirstChild("Coin")
                if part and (HumanoidRootPart.Position - part.Position).Magnitude <= farmDistance then coinsNow = coinsNow + 1 end
            end
        end
    end)
    local farmsPerHour = math.floor(successfulFarms * 3600 / elapsed)
    local hatchPerHour = math.floor(hatchCount * 3600 / elapsed)
    pcall(function() statsPara:Set({ Title = "Stats (this session)", Content = "Farms: " .. tostring(successfulFarms) .. " (" .. tostring(farmsPerHour) .. "/hr)\nHatches: " .. tostring(hatchCount) .. " (" .. tostring(hatchPerHour) .. "/hr)\nCollected: " .. tostring(collectCount) .. "\nTime: " .. string.format("%02d:%02d", mins, secs) .. "\nCoins in range now: " .. tostring(coinsNow) }) end)
end
local function setHatchStatus(msg)
    log("Hatch: " .. tostring(msg))
    pcall(function() hatchStatusPara:Set({ Title = "Hatch Status", Content = tostring(msg) }) end)
end

-- Settings
local farmEnabled = false
local farmDistance = 100
local farmDelay = 0.35
local collectDrops = false
local useSignalMode = true
local antiAfkEnabled = true
local humanMoveEnabled = true
local takeBreaksEnabled = false
local farmActions = 0
local nextHumanAt = 20
local nextBreakAt = 200
local autoHatch = false
local hatchEggName = "Basic Egg"
local tripleHatch = false
local teleportToEgg = true
local smartFarmEnabled = true
local playerPauseEnabled = true
local pausedByPlayer = false
local sessionLimitMinutes = 60
local autoStopAfterLimit = false
local sessionStopped = false
local autoHatchBest = false
local autoEquipOnHatch = false
local autoBuyAreas = false
local lastSmartReason = "Nearest"

local Library = nil
local HumanoidRootPart = nil
local CoinsTable = nil
local RenderedPets = nil

LocalPlayer.CharacterAdded:Connect(function(char)
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
end)
if LocalPlayer.Character then
    HumanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
end

-- Floating window: compact size that fits a phone frame, draggable by its top bar
local function getMain()
    local gui = _G.LastRayField
    if gui and gui:FindFirstChild("Main") then return gui.Main end
    return nil
end
local function applyCompact()
    pcall(function()
        local main = getMain()
        if main then
            main.Size = UDim2.new(0, 380, 0, 340)
            main.Position = UDim2.new(0.5, -190, 0.5, -170)
            if main:FindFirstChild("Topbar") then
                main.Topbar.Size = UDim2.new(0, 380, 0, 45)
            end
        end
    end)
end
local function applyFull()
    pcall(function()
        local main = getMain()
        if main then
            main.Size = UDim2.new(0, 500, 0, 475)
            main.Position = UDim2.new(0.5, -250, 0.5, -237)
            if main:FindFirstChild("Topbar") then
                main.Topbar.Size = UDim2.new(0, 500, 0, 45)
            end
        end
    end)
end
local function toggleHubVisible()
    pcall(function()
        local main = getMain()
        if main then main.Visible = not main.Visible end
    end)
end

-- Small floating button, so you can hide / show the Hub on mobile without RightShift
task.spawn(function()
    task.wait(1.5)
    applyCompact()
    pcall(function()
        local parent = nil
        if gethui then parent = gethui() end
        if not parent then parent = CoreGui end
        if not parent then parent = LocalPlayer:FindFirstChildWhichIsA("PlayerGui") end
        if not parent then return end
        if parent:FindFirstChild("TemplarHubFloat") then return end
        local sg = Instance.new("ScreenGui")
        sg.Name = "TemplarHubFloat"
        sg.ResetOnSpawn = false
        sg.DisplayOrder = 999
        sg.Parent = parent
        local btn = Instance.new("TextButton")
        btn.Name = "HubButton"
        btn.Text = "⚔ Hub"
        btn.Size = UDim2.new(0, 80, 0, 36)
        btn.Position = UDim2.new(0, 10, 0, 200)
        btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = true
        btn.Parent = sg
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(166, 120, 255)
        stroke.Thickness = 2
        stroke.Parent = btn
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = btn
        local dragging = false
        local dragStart = nil
        local startPos = nil
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = btn.Position
            end
        end)
        btn.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        btn.MouseButton1Click:Connect(function()
            toggleHubVisible()
        end)
    end)
end)

local function refreshTables()
    pcall(function()
        local scripts = LocalPlayer.PlayerScripts:FindFirstChild("Scripts")
        if scripts then
            local gameFolder = scripts:FindFirstChild("Game")
            if gameFolder then
                local coinsMod = gameFolder:FindFirstChild("Coins")
                local petsMod = gameFolder:FindFirstChild("Pets")
                if coinsMod then
                    local env = getsenv(coinsMod)
                    if env and env.DestroyAllCoins then CoinsTable = debug.getupvalue(env.DestroyAllCoins, 1) end
                end
                if petsMod then
                    local env2 = getsenv(petsMod)
                    if env2 and env2.NetworkUpdate then RenderedPets = debug.getupvalue(env2.NetworkUpdate, 1) end
                end
            end
        end
    end)
end

local function getCoinId(coinObj)
    if CoinsTable and CoinsTable[coinObj.Name] and CoinsTable[coinObj.Name].coinId then
        return CoinsTable[coinObj.Name].coinId
    end
    return coinObj.Name
end

-- Smart Farm: CalcMultiplier ported from Rafa psx.lua v0.4.
-- coinBonus.l is a list of {m = multiplier}; sum them, 0 if missing.
local function calcMultiplier(coinBonus)
    if not coinBonus or not coinBonus.l then return 0 end
    local total = 0
    pcall(function()
        for _, v in pairs(coinBonus.l) do
            if v and v.m and tonumber(v.m) then total = total + v.m end
        end
    end)
    return total
end

local function findSmartCoins()
    if not Library or not HumanoidRootPart then return {} end
    local folder = Library.Things:FindFirstChild("Coins")
    if not folder then return {} end
    local list = {}
    for _, coin in ipairs(folder:GetChildren()) do
        local part = coin:FindFirstChild("Coin")
        if part then
            local mag = (HumanoidRootPart.Position - part.Position).Magnitude
            local hasArea = true
            pcall(function() hasArea = Library.WorldCmds.HasArea(coin:GetAttribute("Area")) end)
            if mag <= farmDistance and hasArea then
                local entry = nil
                pcall(function() entry = CoinsTable and CoinsTable[coin.Name] end)
                local isDiamond = false
                local isFruit = false
                local mult = 0
                local health = 999999
                if entry then
                    mult = calcMultiplier(entry.b)
                    if entry.health and tonumber(entry.health) then health = entry.health end
                    pcall(function()
                        local def = Library.Directory.Coins[entry.n]
                        if def then
                            if def.currencyType == "Diamonds" then isDiamond = true end
                            if def.breakSound == "fruit" then isFruit = true end
                        end
                    end)
                end
                table.insert(list, { obj = coin, mag = mag, id = getCoinId(coin), isDiamond = isDiamond, isFruit = isFruit, mult = mult, health = health })
            end
        end
    end
    -- Priority, in order: Diamonds, Fruits, Highest Multiplier, Lowest Life, Nearest.
    table.sort(list, function(a, b)
        if a.isDiamond ~= b.isDiamond then return a.isDiamond end
        if a.isFruit ~= b.isFruit then return a.isFruit end
        if a.mult ~= b.mult then return a.mult > b.mult end
        if a.health ~= b.health then return a.health < b.health end
        return a.mag < b.mag
    end)
    if #list > 0 then
        local top = list[1]
        if top.isDiamond then lastSmartReason = "Diamond"
        elseif top.isFruit then lastSmartReason = "Fruit"
        elseif top.mult > 0 then lastSmartReason = "Multiplier " .. tostring(top.mult)
        elseif top.health < 999999 then lastSmartReason = "Lowest Life"
        else lastSmartReason = "Nearest" end
    end
    return list
end

-- IsEggUnlocked ported from Rafa psx.lua v0.4 (simplified, pcall-safe).
local function isEggUnlocked(eggId)
    local ok, res = pcall(function()
        local egg = Library.Directory.Eggs[eggId]
        if not egg then return false end
        if egg.areaRequired and not Library.WorldCmds.HasArea(egg.area) then return false end
        if egg.eggRequired and egg.eggRequired ~= "" and egg.eggRequired ~= eggId then
            if not isEggUnlocked(egg.eggRequired) then return false end
        end
        if egg.eggRequiredOpenAmount and egg.eggRequiredOpenAmount > 0 and egg.eggRequired then
            local saveData = Library.Save.Get()
            local opened = saveData and saveData.EggsOpened and saveData.EggsOpened[egg.eggRequired]
            if not opened or opened < egg.eggRequiredOpenAmount then return false end
        end
        return true
    end)
    if not ok then return false end
    return res
end

-- Best egg = highest-cost unlocked, hatchable egg the player can afford.
-- Egg .cost / .currency verified in Rafa psx.lua (line ~1404).
local function getBestEgg()
    if not Library then return nil end
    local bestId, bestCost = nil, -1
    pcall(function()
        local saveData = Library.Save.Get()
        for eggId, egg in pairs(Library.Directory.Eggs) do
            if egg and egg.hatchable ~= false and not egg.disabled and isEggUnlocked(eggId) then
                local cost = tonumber(egg.cost) or 0
                local currency = egg.currency or "Coins"
                local balance = saveData and tonumber(saveData[currency]) or 0
                local need = cost * (tripleHatch and 3 or 1)
                if cost > bestCost and balance and balance >= need then
                    bestId, bestCost = eggId, cost
                end
            end
        end
    end)
    return bestId
end

local function tryEquipBest()
    local done, tried = false, ""
    pcall(function()
        if Library.PetCmds.EquipBest then Library.PetCmds.EquipBest() done = true tried = "EquipBest" end
    end)
    if not done then
        pcall(function()
            if Library.PetCmds.EquipBestPets then Library.PetCmds.EquipBestPets() done = true tried = "EquipBestPets" end
        end)
    end
    return done, tried
end

-- Auto-Buy Areas: "Buy Area" remote verified in Rafa psx.lua (line ~2412).
-- Area order here is by Directory.Areas id (simplified vs Rafa's world/currency sort).
local function getNextArea()
    local nextArea = nil
    pcall(function()
        local names = {}
        for name, _ in pairs(Library.Directory.Areas) do table.insert(names, name) end
        table.sort(names, function(a, b)
            local ia = Library.Directory.Areas[a] and Library.Directory.Areas[a].id or 0
            local ib = Library.Directory.Areas[b] and Library.Directory.Areas[b].id or 0
            return ia < ib
        end)
        for _, name in ipairs(names) do
            if not Library.WorldCmds.HasArea(name) then nextArea = name break end
        end
    end)
    return nextArea
end
local function canAffordArea(areaName)
    local ok, res = pcall(function()
        local saveData = Library.Save.Get()
        local area = Library.Directory.Areas[areaName]
        if not saveData or not area then return false end
        if not area.gate then return true end
        local currency = saveData[area.gate.currency]
        return currency and currency >= area.gate.cost
    end)
    return ok and res
end
local function buyNextArea()
    local nextArea = getNextArea()
    if not nextArea then return false, "All areas unlocked" end
    if not canAffordArea(nextArea) then return false, "Cannot afford next area: " .. nextArea end
    local ok, res = pcall(function() return Library.Network.Invoke("Buy Area", nextArea) end)
    if ok then return true, "Bought area: " .. nextArea .. " result: " .. tostring(res) end
    return false, "Buy Area failed: " .. tostring(res)
end

local function findNearestCoins()
    if not Library or not HumanoidRootPart then return {} end
    local folder = Library.Things:FindFirstChild("Coins")
    if not folder then return {} end
    local list = {}
    for _, coin in ipairs(folder:GetChildren()) do
        local part = coin:FindFirstChild("Coin")
        if part then
            local mag = (HumanoidRootPart.Position - part.Position).Magnitude
            local hasArea = true
            pcall(function() hasArea = Library.WorldCmds.HasArea(coin:GetAttribute("Area")) end)
            if mag <= farmDistance and hasArea then
                table.insert(list, { obj = coin, mag = mag, id = getCoinId(coin) })
            end
        end
    end
    table.sort(list, function(a, b) return a.mag < b.mag end)
    return list
end

local function farmOneCoin()
    if not Library then return false, "Library not loaded yet" end
    if not HumanoidRootPart then return false, "No character / HRP" end
    local equipped = nil
    pcall(function() equipped = Library.PetCmds.GetEquipped() end)
    if not equipped or #equipped == 0 then return false, "No pets equipped. Equip pets first." end
    local coins = {}
    if smartFarmEnabled then
        coins = findSmartCoins()
    else
        coins = findNearestCoins()
    end
    if #coins == 0 then return false, "No coins in range (" .. tostring(farmDistance) .. "). Walk closer to coins." end
    local coin = coins[1]
    if not smartFarmEnabled and #coins >= 3 and math.random() < 0.2 then coin = coins[math.random(2, 3)] end
    if smartFarmEnabled then log("Smart Farm picked: " .. tostring(coin.obj.Name) .. " reason=" .. lastSmartReason) end
    log("Trying coin " .. tostring(coin.obj.Name) .. " id=" .. tostring(coin.id) .. " mag=" .. tostring(math.floor(coin.mag)))
    if useSignalMode and RenderedPets then
        local tried = 0
        for _, pet in pairs(RenderedPets) do
            pcall(function()
                if pet and pet.spawned and pet.spawned.owner == LocalPlayer and not pet.farming then
                    Library.Signal.Fire("Select Coin", coin.obj, pet)
                    tried = tried + 1
                end
            end)
            if tried > 0 then break end
        end
        if tried > 0 then return true, "Signal sent to 1 pet for coin " .. tostring(coin.obj.Name) end
        log("Signal found no idle pet, falling back to Network")
    end
    local pet = equipped[1]
    local nOk, nRes = pcall(function()
        local r1 = Library.Network.Invoke("Join Coin", coin.id, { pet.uid })
        local r2 = Library.Network.Fire("Farm Coin", coin.id, pet.uid)
        return tostring(r1) .. " / " .. tostring(r2)
    end)
    if nOk then return true, "Network sent. Result: " .. tostring(nRes) .. " coin=" .. tostring(coin.id) end
    return false, "Network FAILED: " .. tostring(nRes)
end

local function hatchOneEgg()
    if not Library then return false, "Library not loaded yet" end
    if not HumanoidRootPart then return false, "No character" end
    local eggId = hatchEggName
    if autoHatchBest then
        local best = getBestEgg()
        if best then eggId = best log("Auto-Hatch Best Egg picked: " .. best) else return false, "No affordable unlocked egg found, using Egg Name input failed too" end
    end
    local eggData = nil
    pcall(function() eggData = Library.Directory.Eggs[eggId] end)
    if not eggData then return false, "Egg not found: " .. eggId .. " - check exact name" end
    if eggData.hatchable == false or eggData.disabled then return false, "Egg not hatchable: " .. eggId end
    pcall(function()
        local area = Library.Directory.Areas[eggData.area]
        if area and teleportToEgg then
            if Library.WorldCmds.Get() ~= area.world then Library.WorldCmds.Load(area.world) task.wait(0.5) end
            for _, v in pairs(Library.WorldCmds.GetAllEggs()) do
                if v:GetAttribute("ID") == eggId then
                    local pp = v.PrimaryPart
                    if pp then HumanoidRootPart.CFrame = CFrame.new(pp.Position) + Vector3.new(10, 0, 0) task.wait(0.3) end
                    break
                end
            end
        end
    end)
    local ok, res = pcall(function() return Library.Network.Invoke("Buy Egg", eggId, tripleHatch, false) end)
    if ok then
        hatchCount = hatchCount + 1
        if autoEquipOnHatch then pcall(function() tryEquipBest() end) end
        return true, "Hatched " .. eggId .. " result: " .. tostring(res)
    end
    return false, "Buy Egg failed: " .. tostring(res)
end

local function collectAllNow()
    if not Library or not HumanoidRootPart then return end
    local collected = 0
    pcall(function()
        local orbs = Library.Things:FindFirstChild("Orbs")
        if orbs then
            local names = {}
            for _, o in ipairs(orbs:GetChildren()) do table.insert(names, o.Name) end
            if #names > 0 then Library.Network.Fire("Claim Orbs", names) collected = collected + #names end
        end
        local bags = Library.Things:FindFirstChild("Lootbags")
        if bags then
            for _, b in ipairs(bags:GetChildren()) do
                if not b:GetAttribute("Collected") then
                    Library.Network.Fire("Collect Lootbag", b.Name, HumanoidRootPart.Position)
                    collected = collected + 1
                    task.wait(0.05)
                end
            end
        end
    end)
    collectCount = collectCount + collected
end

local function teleportToWorld(name)
    if not Library then return false, "Library not loaded" end
    local ok, res = pcall(function() return Library.WorldCmds.Load(name) end)
    if ok then return true, name end
    return false, tostring(res)
end

local function teleportToBank()
    if not Library or not HumanoidRootPart then return false, "Not ready" end
    local ok, res = pcall(function()
        if Library.WorldCmds.Get() ~= "Spawn" then Library.WorldCmds.Load("Spawn") task.wait(0.5) end
        HumanoidRootPart.CFrame = Library.WorldCmds.GetMap().Interactive.Bank.Pad.CFrame + Vector3.new(0, 3, 0)
        return true
    end)
    return ok, tostring(res)
end

-- Anti-AFK
pcall(function()
    for _, conn in pairs(getconnections(LocalPlayer.Idled)) do conn:Disable() end
end)
LocalPlayer.Idled:Connect(function()
    if antiAfkEnabled then
        pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end)
    end
end)
task.spawn(function()
    while true do
        task.wait(math.random(60, 120))
        if antiAfkEnabled and LocalPlayer.Character then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(math.random(0, 500), math.random(0, 500)))
                local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum and math.random() < 0.5 then hum.Jump = true end
            end)
        end
    end
end)

local function humanStep()
    if not humanMoveEnabled or not HumanoidRootPart then return end
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            local angle = math.random() * math.pi * 2
            local dist = math.random(3, 10)
            local target = HumanoidRootPart.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
            hum:MoveTo(target)
            if math.random() < 0.3 then hum.Jump = true end
            task.wait(math.random(5, 12) / 10)
        end
    end)
end

-- FARM TAB
farmTab:CreateParagraph({ Title = "Templar Hub", Content = "Farm only. NOT a dupe. AMOLED black, purple accent." })
farmTab:CreateToggle({
    Name = "Enable Auto-Farm", CurrentValue = false, Flag = "HubFarm_Enabled",
    Callback = function(v) farmEnabled = v setStatus(v and "Auto-Farm ON" or "Auto-Farm OFF") end,
})
farmTab:CreateToggle({
    Name = "Use Signal Mode (safer, try first)", CurrentValue = true, Flag = "HubFarm_Signal",
    Callback = function(v) useSignalMode = v end,
})
farmTab:CreateToggle({
    Name = "Smart Farm (Diamonds > Fruits > Multiplier > Life > Nearest)", CurrentValue = true, Flag = "HubFarm_Smart",
    Callback = function(v) smartFarmEnabled = v setStatus(v and "Smart Farm ON" or "Smart Farm OFF - nearest only") end,
})
farmTab:CreateSlider({
    Name = "Farm Distance", Range = {10, 300}, Increment = 10, CurrentValue = 100, Flag = "HubFarm_Distance",
    Callback = function(v) farmDistance = v end,
})
farmTab:CreateSlider({
    Name = "Farm Delay x0.1s", Range = {1, 10}, Increment = 1, CurrentValue = 4, Flag = "HubFarm_Delay",
    Callback = function(v) farmDelay = v / 10 end,
})
farmTab:CreateButton({
    Name = "Test: Farm 1 Coin Once",
    Callback = function()
        task.spawn(function()
            refreshTables()
            local success, msg = farmOneCoin()
            setStatus((success and "TEST OK: " or "TEST FAILED: ") .. msg)
        end)
    end,
})
farmTab:CreateButton({
    Name = "Test: Count Pets + Coins",
    Callback = function()
        task.spawn(function()
            refreshTables()
            local msg = "Test: "
            pcall(function()
                local equipped = Library.PetCmds.GetEquipped()
                msg = msg .. "Pets=" .. tostring(equipped and #equipped or 0) .. " "
                local coins = findNearestCoins()
                msg = msg .. "CoinsInRange=" .. tostring(#coins) .. " "
                msg = msg .. "CoinsTable=" .. tostring(CoinsTable and "yes" or "NO") .. " "
                msg = msg .. "RenderedPets=" .. tostring(RenderedPets and "yes" or "NO")
            end)
            setStatus(msg)
        end)
    end,
})

-- SAFETY TAB
safetyTab:CreateParagraph({ Title = "Safety", Content = "Human-like lowers ban risk, it does NOT remove it. Short sessions on an alt are safest." })
safetyTab:CreateToggle({
    Name = "Anti-AFK (stay logged in)", CurrentValue = true, Flag = "HubSafety_AntiAfk",
    Callback = function(v) antiAfkEnabled = v end,
})
safetyTab:CreateToggle({
    Name = "Human-like Movement", CurrentValue = true, Flag = "HubSafety_Human",
    Callback = function(v) humanMoveEnabled = v end,
})
safetyTab:CreateToggle({
    Name = "Take Breaks (pause every ~200 farms)", CurrentValue = false, Flag = "HubSafety_Breaks",
    Callback = function(v) takeBreaksEnabled = v end,
})
safetyTab:CreateToggle({
    Name = "Pause if a player gets close (25 studs, 10s)", CurrentValue = true, Flag = "HubSafety_PlayerPause",
    Callback = function(v) playerPauseEnabled = v if not v then pausedByPlayer = false end end,
})
safetyTab:CreateSlider({
    Name = "Session Limit (minutes)", Range = {30, 180}, Increment = 10, CurrentValue = 60, Flag = "HubSafety_SessionLimit",
    Callback = function(v) sessionLimitMinutes = v end,
})
safetyTab:CreateToggle({
    Name = "Auto-Stop After Session Limit", CurrentValue = false, Flag = "HubSafety_AutoStop",
    Callback = function(v) autoStopAfterLimit = v end,
})
safetyTab:CreateButton({ Name = "Compact Window (fits phone)", Callback = function() applyCompact() end })
safetyTab:CreateButton({ Name = "Full Window (500x475)", Callback = function() applyFull() end })
safetyTab:CreateButton({ Name = "Hide Hub (tap Hub button to bring back)", Callback = function() toggleHubVisible() end })

-- HATCH TAB
hatchTab:CreateParagraph({ Title = "Hatch", Content = "Type the exact egg name as in-game, e.g. Basic Egg. Teleport to egg is on by default." })
hatchTab:CreateInput({
    Name = "Egg Name", PlaceholderText = "Basic Egg",
    Callback = function(text) if text and text ~= "" then hatchEggName = text setHatchStatus("Egg set to: " .. text) end end,
})
hatchTab:CreateToggle({
    Name = "Triple Hatch", CurrentValue = false, Flag = "HubHatch_Triple",
    Callback = function(v) tripleHatch = v end,
})
hatchTab:CreateToggle({
    Name = "Teleport to Egg", CurrentValue = true, Flag = "HubHatch_Teleport",
    Callback = function(v) teleportToEgg = v end,
})
hatchTab:CreateToggle({
    Name = "Auto-Hatch Best Egg (highest affordable unlocked)", CurrentValue = false, Flag = "HubHatch_BestEgg",
    Callback = function(v) autoHatchBest = v setHatchStatus(v and "Auto-Hatch Best Egg ON" or "Auto-Hatch Best Egg OFF") end,
})
hatchTab:CreateToggle({
    Name = "Auto-Equip Best on Hatch", CurrentValue = false, Flag = "HubHatch_AutoEquip",
    Callback = function(v) autoEquipOnHatch = v end,
})
hatchTab:CreateToggle({
    Name = "Auto-Hatch", CurrentValue = false, Flag = "HubHatch_Auto",
    Callback = function(v) autoHatch = v setHatchStatus(v and "Auto-Hatch ON: " .. hatchEggName or "Auto-Hatch OFF") end,
})
hatchTab:CreateButton({
    Name = "Hatch 1 Egg Once",
    Callback = function()
        task.spawn(function()
            local success, msg = hatchOneEgg()
            setHatchStatus((success and "OK: " or "FAILED: ") .. msg)
        end)
    end,
})

-- COLLECT TAB
collectTab:CreateParagraph({ Title = "Collect", Content = "Orbs and lootbags on the ground." })
collectTab:CreateToggle({
    Name = "Collect Drops (Orbs + Lootbags)", CurrentValue = false, Flag = "HubCollect_Drops",
    Callback = function(v) collectDrops = v end,
})
collectTab:CreateButton({
    Name = "Collect All Now",
    Callback = function()
        task.spawn(function()
            collectAllNow()
            setStatus("Collect All pressed. Check console for errors.")
        end)
    end,
})

-- AUTO TAB
autoTab:CreateParagraph({ Title = "Auto All", Content = "Auto-buy areas uses the verified Buy Area remote. Auto-Claim does orbs + lootbags only - no verified Gift claim remote was found in Rafa v0.4, so no Gift claim is attempted." })
autoTab:CreateToggle({
    Name = "Auto-Buy Areas (when affordable)", CurrentValue = false, Flag = "HubAuto_BuyAreas",
    Callback = function(v) autoBuyAreas = v setStatus(v and "Auto-Buy Areas ON" or "Auto-Buy Areas OFF") end,
})
autoTab:CreateButton({
    Name = "Buy Next Area Now",
    Callback = function()
        task.spawn(function()
            local success, msg = buyNextArea()
            setStatus((success and "OK: " or "FAILED: ") .. msg)
        end)
    end,
})
autoTab:CreateButton({
    Name = "Auto-Claim Now (Orbs + Lootbags only)",
    Callback = function()
        task.spawn(function()
            collectAllNow()
            setStatus("Auto-Claim pressed: orbs + lootbags only. No verified Gift remote, so no Gift claim attempted.")
        end)
    end,
})

-- TRAVEL TAB
travelTab:CreateParagraph({ Title = "Travel", Content = "Teleport to a world. Type the exact world name, e.g. Spawn, Fantasy, Tech." })
local travelWorldName = "Spawn"
travelTab:CreateInput({
    Name = "World Name", PlaceholderText = "Spawn",
    Callback = function(text) if text and text ~= "" then travelWorldName = text end end,
})
travelTab:CreateButton({
    Name = "Teleport to World",
    Callback = function()
        task.spawn(function()
            local success, msg = teleportToWorld(travelWorldName)
            setStatus((success and "Teleported to " or "Teleport FAILED: ") .. tostring(msg))
        end)
    end,
})
travelTab:CreateButton({ Name = "Teleport: Spawn", Callback = function() task.spawn(function() teleportToWorld("Spawn") end) end })
travelTab:CreateButton({ Name = "Teleport: Fantasy", Callback = function() task.spawn(function() teleportToWorld("Fantasy") end) end })
travelTab:CreateButton({ Name = "Teleport: Bank", Callback = function() task.spawn(function() teleportToBank() end) end })

-- PETS TAB
petsTab:CreateParagraph({ Title = "Pets", Content = "Equip best is a try - PSX changes the API, if it says FAILED the game blocked it." })
petsTab:CreateButton({
    Name = "Count My Pets",
    Callback = function()
        task.spawn(function()
            local msg = "Pets: "
            pcall(function()
                local equipped = Library.PetCmds.GetEquipped()
                msg = msg .. "Equipped=" .. tostring(equipped and #equipped or 0)
            end)
            setStatus(msg)
        end)
    end,
})
petsTab:CreateButton({
    Name = "Equip Best (try)",
    Callback = function()
        task.spawn(function()
            local done = false
            local tried = ""
            pcall(function()
                if Library.PetCmds.EquipBest then Library.PetCmds.EquipBest() done = true tried = "EquipBest" end
            end)
            if not done then
                pcall(function()
                    if Library.PetCmds.EquipBestPets then Library.PetCmds.EquipBestPets() done = true tried = "EquipBestPets" end
                end)
            end
            setStatus(done and ("Equip Best OK via " .. tried) or "Equip Best FAILED: no EquipBest function found in this PSX version.")
        end)
    end,
})

-- STATS TAB
statsPara = statsTab:CreateParagraph({ Title = "Stats (this session)", Content = "Farms: 0 (0/hr)\nHatches: 0 (0/hr)\nCollected: 0\nTime: 00:00\nCoins in range now: 0" })
statsTab:CreateButton({
    Name = "Reset Stats",
    Callback = function()
        sessionStart = os.time()
        successfulFarms = 0
        farmActions = 0
        hatchCount = 0
        collectCount = 0
        updateStats()
        setStatus("Stats reset.")
    end,
})

setStatus("Window loaded. Waiting for Library...")

task.spawn(function()
    local libOk, lib = pcall(function() return require(ReplicatedStorage:WaitForChild("Library", 15)) end)
    if not libOk or not lib then setStatus("ERROR: Library not found. Rejoin.") return end
    Library = lib
    local waited = 0
    while not Library.Loaded and waited < 100 do task.wait(0.1) waited = waited + 1 end
    if not Library.Loaded then setStatus("ERROR: Library never loaded. Rejoin.") return end
    local bypassOk, bypassErr = pcall(function()
        local blunderMod = ReplicatedStorage:WaitForChild("X", 10):WaitForChild("Blunder", 10):WaitForChild("BlunderList", 10)
        local Blunder = require(blunderMod)
        if Blunder and Blunder.getAndClear then
            local oldGet = Blunder.getAndClear
            setreadonly(Blunder, false)
            Blunder.getAndClear = function(...)
                local packet = ...
                for i, v in next, packet.list do
                    if v.message ~= "PING" then table.remove(packet.list, i) end
                end
                return oldGet(packet)
            end
            setreadonly(Blunder, true)
        end
        if Library.Network and Library.Network.Invoke then
            hookfunction(debug.getupvalue(Library.Network.Invoke, 1), function(...) return true end)
        end
    end)
    if bypassOk then setStatus("Ready. Templar Hub loaded. Press Test: Farm 1 Coin Once.") else setStatus("Ready, but bypass FAILED: " .. tostring(bypassErr)) end
    refreshTables()
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if collectDrops and Library and HumanoidRootPart then collectAllNow() end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if autoHatch and Library then
            local success, msg = hatchOneEgg()
            setHatchStatus((success and "OK: " or "FAILED: ") .. msg)
            task.wait(math.random(10, 20) / 10)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        if farmEnabled and Library and HumanoidRootPart and not pausedByPlayer and not sessionStopped then
            local success, msg = nil, nil
            pcall(function() success, msg = farmOneCoin() end)
            if success then
                farmActions = farmActions + 1
                successfulFarms = successfulFarms + 1
                setStatus("Farming... " .. tostring(msg) .. " | Farms: " .. tostring(farmActions))
                if humanMoveEnabled and farmActions >= nextHumanAt then
                    nextHumanAt = farmActions + math.random(15, 30)
                    setStatus("Human pause... walking around")
                    humanStep()
                    task.wait(math.random(20, 80) / 10)
                end
                if takeBreaksEnabled and farmActions >= nextBreakAt then
                    nextBreakAt = farmActions + math.random(150, 250)
                    local breakTime = math.random(30, 60)
                    setStatus("Taking a break for " .. tostring(breakTime) .. "s...")
                    task.wait(breakTime)
                    setStatus("Back from break. Farming...")
                end
            elseif msg then
                setStatus("Farm paused: " .. tostring(msg))
                task.wait(1)
            end
            local waitTime = math.max(0.05, farmDelay + math.random(-10, 35) / 100)
            task.wait(waitTime)
        end
    end
end)

-- Safety watcher: pause if another player is within 25 studs for >10s.
task.spawn(function()
    local nearSince = nil
    while true do
        task.wait(1)
        if playerPauseEnabled and HumanoidRootPart then
            local nearestDist = 999999
            pcall(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Character then
                        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local d = (HumanoidRootPart.Position - hrp.Position).Magnitude
                            if d < nearestDist then nearestDist = d end
                        end
                    end
                end
            end)
            if nearestDist <= 25 then
                if not nearSince then nearSince = os.time() end
                if os.time() - nearSince >= 10 and not pausedByPlayer then
                    pausedByPlayer = true
                    setStatus("Player nearby, paused")
                end
            else
                if nearSince and pausedByPlayer then
                    task.wait(10)
                    pausedByPlayer = false
                    setStatus("Player left, farming resumed")
                end
                nearSince = nil
            end
        end
    end
end)

-- Session limit watcher.
task.spawn(function()
    while true do
        task.wait(30)
        if autoStopAfterLimit and not sessionStopped then
            local elapsedMin = (os.time() - sessionStart) / 60
            if elapsedMin >= sessionLimitMinutes then
                sessionStopped = true
                farmEnabled = false
                autoHatch = false
                setStatus("Session limit reached (" .. tostring(sessionLimitMinutes) .. " min), stopped")
            end
        end
    end
end)

-- Auto-Buy Areas watcher.
task.spawn(function()
    while true do
        task.wait(30)
        if autoBuyAreas and Library and not sessionStopped then
            local success, msg = buyNextArea()
            if success then setStatus("Auto-Buy Areas OK: " .. msg) end
        end
    end
end)

-- Stats updater, every 5 seconds.
task.spawn(function()
    while true do
        task.wait(5)
        updateStats()
    end
end)

print("[Templar Hub v5] Loaded.")
