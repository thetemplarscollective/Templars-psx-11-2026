-- Dylan PSX Farm GUI v2
-- Fixes v1: v1 loaded but did nothing because PSX blocks
-- Library.Network.Invoke from an executor unless the check is bypassed,
-- and v1 had no logging so you could not see why.
-- v2 adds: logging to console, Test 1 Coin button, legit Signal mode first,
-- then Network mode with the same bypass Rafa used, and status that actually changes.
-- NOT a dupe. Farm only. Use at your own risk, can get banned.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local PSX_PLACES = {
    [6284583030] = true,
    [10321372166] = true,
    [7722306047] = true,
    [12610002282] = true,
}
if not PSX_PLACES[game.PlaceId] then
    warn("[Farm v2] Not in PSX. PlaceId: " .. tostring(game.PlaceId))
    return
end

getgenv().SecureMode = true
getgenv().DisableArrayfieldAutoLoad = true

local Rayfield = nil
local ok, err = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/Rafacasari/ArrayField/main/v2.lua"))()
end)
if not ok or not Rayfield then
    warn("[Farm v2] ArrayField failed: " .. tostring(err))
    return
end

local Window = Rayfield:CreateWindow({
    Name = "Dylan PSX Farm v2",
    LoadingTitle = "Dylan PSX Farm v2",
    LoadingSubtitle = "by Jarvis",
    ConfigurationSaving = { Enabled = false },
    OldTabLayout = true,
})

local farmTab = Window:CreateTab("Farm", "13075651575", true)
local lastStatus = ""
local statusPara = farmTab:CreateParagraph({ Title = "Status", Content = "Loading..." })

local function log(msg)
    print("[Farm v2] " .. tostring(msg))
end

local function setStatus(msg)
    msg = tostring(msg)
    if msg == lastStatus then return end
    lastStatus = msg
    log(msg)
    pcall(function()
        statusPara:Set({ Title = "Status", Content = msg })
    end)
end

farmTab:CreateParagraph({
    Title = "Warning",
    Content = "Farm only, NOT a dupe. If Test 1 Coin says FAILED, PSX blocked the remote and farm will not work in this server."
})

local farmEnabled = false
local farmDistance = 100
local farmDelay = 0.35
local collectDrops = false
local useSignalMode = true

farmTab:CreateToggle({
    Name = "Enable Auto-Farm",
    CurrentValue = false,
    Flag = "DylanFarm2_Enabled",
    Callback = function(v) farmEnabled = v setStatus(v and "Auto-Farm ON" or "Auto-Farm OFF") end,
})
farmTab:CreateToggle({
    Name = "Use Signal Mode (safer, try first)",
    CurrentValue = true,
    Flag = "DylanFarm2_Signal",
    Callback = function(v) useSignalMode = v end,
})
farmTab:CreateSlider({
    Name = "Farm Distance",
    Range = {10, 300},
    Increment = 10,
    CurrentValue = 100,
    Flag = "DylanFarm2_Distance",
    Callback = function(v) farmDistance = v end,
})
farmTab:CreateSlider({
    Name = "Farm Delay x0.1s",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = 4,
    Flag = "DylanFarm2_Delay",
    Callback = function(v) farmDelay = v / 10 end,
})
farmTab:CreateToggle({
    Name = "Collect Drops",
    CurrentValue = false,
    Flag = "DylanFarm2_Drops",
    Callback = function(v) collectDrops = v end,
})

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

local function refreshTables()
    pcall(function()
        local coinsScript = LocalPlayer.PlayerScripts:FindFirstChild("Scripts")
        if coinsScript then
            local gameFolder = coinsScript:FindFirstChild("Game")
            if gameFolder then
                local coinsMod = gameFolder:FindFirstChild("Coins")
                local petsMod = gameFolder:FindFirstChild("Pets")
                if coinsMod then
                    local env = getsenv(coinsMod)
                    if env and env.DestroyAllCoins then
                        CoinsTable = debug.getupvalue(env.DestroyAllCoins, 1)
                    end
                end
                if petsMod then
                    local env2 = getsenv(petsMod)
                    if env2 and env2.NetworkUpdate then
                        RenderedPets = debug.getupvalue(env2.NetworkUpdate, 1)
                    end
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
    if not equipped or #equipped == 0 then
        return false, "No pets equipped. Equip pets first."
    end
    local coins = findNearestCoins()
    if #coins == 0 then
        return false, "No coins in range (" .. tostring(farmDistance) .. "). Walk closer to coins."
    end
    local coin = coins[1]
    log("Trying coin " .. tostring(coin.obj.Name) .. " id=" .. tostring(coin.id) .. " mag=" .. tostring(math.floor(coin.mag)) .. " pets=" .. tostring(#equipped))

    -- 1) Signal mode, like the game itself does when you click a coin
    if useSignalMode and RenderedPets then
        local tried = 0
        for _, pet in pairs(RenderedPets) do
            local sOk, sErr = pcall(function()
                if pet and pet.spawned and pet.spawned.owner == LocalPlayer and not pet.farming then
                    Library.Signal.Fire("Select Coin", coin.obj, pet)
                    tried = tried + 1
                end
            end)
            if not sOk then log("Signal error: " .. tostring(sErr)) end
            if tried > 0 then break end
        end
        if tried > 0 then
            return true, "Signal sent to 1 pet for coin " .. tostring(coin.obj.Name)
        else
            log("Signal mode found no idle rendered pet, falling back to Network")
        end
    end

    -- 2) Network mode, direct Join / Farm
    local pet = equipped[1]
    local nOk, nRes = pcall(function()
        local r1 = Library.Network.Invoke("Join Coin", coin.id, { pet.uid })
        local r2 = Library.Network.Fire("Farm Coin", coin.id, pet.uid)
        return tostring(r1) .. " / " .. tostring(r2)
    end)
    if nOk then
        return true, "Network sent. Join/Farm result: " .. tostring(nRes) .. " coin=" .. tostring(coin.id)
    else
        return false, "Network FAILED: " .. tostring(nRes)
    end
end

farmTab:CreateButton({
    Name = "Test: Farm 1 Coin Once",
    Callback = function()
        task.spawn(function()
            refreshTables()
            local success, msg = farmOneCoin()
            setStatus((success and "TEST OK: " or "TEST FAILED: ") .. msg)
            log("Test result: " .. tostring(success) .. " - " .. msg)
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

setStatus("Window loaded. Waiting for Library...")

task.spawn(function()
    local libOk, lib = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Library", 15))
    end)
    if not libOk or not lib then
        setStatus("ERROR: Library not found. Rejoin.")
        return
    end
    Library = lib
    local waited = 0
    while not Library.Loaded and waited < 100 do
        task.wait(0.1)
        waited = waited + 1
    end
    if not Library.Loaded then
        setStatus("ERROR: Library never loaded. Rejoin.")
        return
    end

    -- Bypass, same idea as Rafa v0.4. Without this PSX blocks Network.Invoke.
    -- Wrapped in pcall, if it fails v2 will tell you in Status.
    local bypassOk, bypassErr = pcall(function()
        local blunderMod = ReplicatedStorage:WaitForChild("X", 10):WaitForChild("Blunder", 10):WaitForChild("BlunderList", 10)
        local Blunder = require(blunderMod)
        if Blunder and Blunder.getAndClear then
            local oldGet = Blunder.getAndClear
            setreadonly(Blunder, false)
            Blunder.getAndClear = function(...)
                local packet = ...
                for i, v in next, packet.list do
                    if v.message ~= "PING" then
                        table.remove(packet.list, i)
                    end
                end
                return oldGet(packet)
            end
            setreadonly(Blunder, true)
        end
        if Library.Network and Library.Network.Invoke then
            hookfunction(debug.getupvalue(Library.Network.Invoke, 1), function(...) return true end)
        end
    end)
    if bypassOk then
        setStatus("Ready. Bypass OK. Press Test: Farm 1 Coin Once.")
    else
        setStatus("Ready, but bypass FAILED: " .. tostring(bypassErr) .. ". Signal mode may still work, Network may not.")
    end
    refreshTables()
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if collectDrops and Library and HumanoidRootPart then
            pcall(function()
                local orbs = Library.Things:FindFirstChild("Orbs")
                if orbs then
                    local names = {}
                    for _, o in ipairs(orbs:GetChildren()) do table.insert(names, o.Name) end
                    if #names > 0 then Library.Network.Fire("Claim Orbs", names) end
                end
                local bags = Library.Things:FindFirstChild("Lootbags")
                if bags then
                    for _, b in ipairs(bags:GetChildren()) do
                        if not b:GetAttribute("Collected") then
                            Library.Network.Fire("Collect Lootbag", b.Name, HumanoidRootPart.Position)
                            task.wait(0.05)
                        end
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        if farmEnabled and Library and HumanoidRootPart then
            local success, msg = nil, nil
            pcall(function()
                success, msg = farmOneCoin()
            end)
            if success then
                setStatus("Farming... " .. tostring(msg))
            elseif msg then
                setStatus("Farm paused: " .. tostring(msg))
                task.wait(1)
            end
            task.wait(farmDelay)
        end
    end
end)

print("[Farm v2] Loaded.")
