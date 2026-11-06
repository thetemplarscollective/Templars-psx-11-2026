-- Templar Hub v8
-- Based on v7. v8 fixes scrolling + tabs + move/resize + icons (Dylan 2026-11-06):
-- after scrolling down in Farm, Test buttons at the bottom disappeared, left side of
-- every row was clipped, and only 3.5 tabs were visible. Root cause (verified in
-- /tmp/arrayfield.lua): element frames are built for a 465px-wide window (Dropdown/
-- ColorPicker Size 0,465), tab pages are ScrollingFrames whose CanvasSize is never
-- refreshed in the Lua, and AddDraggingFunctionality only handles MouseButton1 +
-- MouseMovement, never Touch, so the window cannot be dragged on mobile.
-- v8: refit every element to the window width, refresh each page CanvasSize from its
-- UIListLayout content size, reset CanvasPosition.X to 0, make the tab row horizontally
-- scrollable, add touch drag on Topbar + a resize handle, distinct Lucide tab icons,
-- and a Templar cross floating button.
-- Based on v6. v7 fixes the mobile UI (Dylan screenshot 2026-11-06):
-- window was too wide, left edge cut off, top out of bounds, top scrolled off screen.
-- Root cause (verified in /tmp/arrayfield.lua): ArrayField's load tween forces Main to
-- 500x475 ~2.2s after CreateWindow, and ToggleOldTabStyle(true) sets Elements to 364px
-- tall inside a 340px window, so content overflowed and the Topbar went off screen.
-- v7: scale-centred 320x300 window, Elements fitted inside Main, Topbar pinned,
-- re-applied after ArrayField's tween, plus a clamp loop that pulls it back on screen.
-- Tabs: Farm | Safety | Hatch | Collect | Travel | Pets | Auto | Stats | Oracle
-- AMOLED = pure black background, white text, purple accent.
-- NOT a dupe. No coin/pet dupe exists, server-side. Farm / hatch / collect only.
-- Use at your own risk, can get banned. Short sessions on an alt are safest.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
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

local farmTab = Window:CreateTab("Farm", "16898613869", true) -- wheat
local safetyTab = Window:CreateTab("Safety", "16898613777", true) -- shield
local hatchTab = Window:CreateTab("Hatch", "16898613353", true) -- egg
local collectTab = Window:CreateTab("Collect", "16898613353", true) -- gift
local travelTab = Window:CreateTab("Travel", "16898613509", true) -- globe
local petsTab = Window:CreateTab("Pets", "16898613044", true) -- dog
local autoTab = Window:CreateTab("Auto", "16898613869", true) -- zap
local statsTab = Window:CreateTab("Stats", "16898612629", true) -- activity
local oracleTab = Window:CreateTab("Oracle", "16898613353", true) -- eye

-- Distinct tab icons. Lucide names -> {sprite asset id, rect offset} verified in
-- /tmp/rayfield-icons.lua (Sirius Rayfield icons.lua, 48px section, rect size 48x48):
-- wheat 16898613869 (453,967) | shield 16898613777 (869,0) | egg 16898613353 (514,771)
-- gift 16898613353 (820,955) | globe 16898613509 (771,563) | dog 16898613044 (869,808)
-- zap 16898613869 (918,906) | activity 16898612629 (514,771) | eye 16898613353 (771,563)
local TAB_ICONS = {
    Farm = {id = "16898613869", x = 453, y = 967},
    Safety = {id = "16898613777", x = 869, y = 0},
    Hatch = {id = "16898613353", x = 514, y = 771},
    Collect = {id = "16898613353", x = 820, y = 955},
    Travel = {id = "16898613509", x = 771, y = 563},
    Pets = {id = "16898613044", x = 869, y = 808},
    Auto = {id = "16898613869", x = 918, y = 906},
    Stats = {id = "16898612629", x = 514, y = 771},
    Oracle = {id = "16898613353", x = 771, y = 563},
}
local function applyTabIcons()
    pcall(function()
        local gui = _G.LastRayField
        local main = gui and gui:FindFirstChild("Main")
        if not main then return end
        local function patchButton(btn, icon)
            if not btn then return end
            local img = btn:FindFirstChild("Image")
            if img then
                img.Image = "rbxassetid://" .. icon.id
                img.ImageRectOffset = Vector2.new(icon.x, icon.y)
                img.ImageRectSize = Vector2.new(48, 48)
                img.Size = UDim2.new(0, 18, 0, 18)
                img.Visible = true
            end
            local title = btn:FindFirstChild("Title")
            if title then
                title.AnchorPoint = Vector2.new(0, 0.5)
                title.Position = UDim2.new(0, 24, 0.5, 0)
                title.TextXAlignment = Enum.TextXAlignment.Left
            end
            btn.Size = UDim2.new(0, (title and title.TextBounds.X or 40) + 32, 0, 30)
        end
        local topList = main:FindFirstChild("TabList")
        local sideList = main:FindFirstChild("SideTabList")
        local sideHolder = sideList and sideList:FindFirstChild("Holder")
        for name, icon in pairs(TAB_ICONS) do
            if topList then patchButton(topList:FindFirstChild(name), icon) end
            if sideHolder then patchButton(sideHolder:FindFirstChild(name), icon) end
        end
    end)
end
pcall(applyTabIcons)
task.delay(2, function() pcall(applyTabIcons) end)

local function log(msg)
    print("[Templar Hub v8] " .. tostring(msg))
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
local oraclePara = nil
local oracleStatusPara = nil
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

-- v7 MOBILE UI FIX. Floating window: small, phone-safe, scale-centred, draggable by top bar.
-- Main.AnchorPoint is 0.5,0.5 in ArrayField, so offset-centred positions like
-- UDim2.new(0.5,-190,0.5,-170) shift the CENTRE left/up and push the window off screen.
-- Use UDim2.new(0.5,0,0.5,0) instead, so it stays centred on any screen size.
local COMPACT_W, COMPACT_H = 320, 300
local FULL_W, FULL_H = 360, 420
local currentLayoutW, currentLayoutH = COMPACT_W, COMPACT_H

local function getViewportSize()
    local cam = workspace.CurrentCamera
    if cam then return cam.ViewportSize end
    return Vector2.new(400, 800)
end
local function getMain()
    local gui = _G.LastRayField
    if gui and gui:FindFirstChild("Main") then return gui.Main end
    return nil
end
-- Fit ArrayField's content INSIDE Main. ToggleOldTabStyle(true) sets Elements to
-- 364px tall no matter the window size, so it overflowed a 340px window. Here
-- Elements runs from y=90 (below Topbar 45 + tab row ~40) to the bottom of Main,
-- and only each tab page (a ScrollingFrame) scrolls -- never the whole Main window,
-- so the Topbar can never scroll away.
local fitPageElements
local function fitElements(main)
    pcall(function()
        main.ClipsDescendants = true
        local topbar = main:FindFirstChild("Topbar")
        if topbar then
            topbar.AnchorPoint = Vector2.new(0, 0)
            topbar.Position = UDim2.new(0, 0, 0, 0)
            topbar.Size = UDim2.new(1, 0, 0, 45)
            topbar.ZIndex = 10
            -- Stop ArrayField's maximise button forcing the window back to 500x475,
            -- wider than a phone screen. Compact/Full buttons do the job instead.
            local cs = topbar:FindFirstChild("ChangeSize")
            if cs then cs.Visible = false end
        end
        local tabList = main:FindFirstChild("TabList")
        if tabList then
            tabList.AnchorPoint = Vector2.new(0, 0)
            tabList.Position = UDim2.new(0, 0, 0, 45)
            tabList.Size = UDim2.new(1, 0, 0, 40)
            tabList.ClipsDescendants = true
            -- 9 tabs are wider than a 320px window. If TabList is a ScrollingFrame
            -- (as in the Rayfield model), make it scroll horizontally so every tab
            -- is reachable by swiping; otherwise the buttons are shrunk by applyTabIcons.
            pcall(function()
                if tabList:IsA("ScrollingFrame") then
                    tabList.ScrollingDirection = Enum.ScrollingDirection.X
                    tabList.AutomaticCanvasSize = Enum.AutomaticSize.X
                    tabList.CanvasSize = UDim2.new(0, 0, 0, 0)
                    tabList.ScrollBarThickness = 0
                    tabList.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
                end
            end)
        end
        local elements = main:FindFirstChild("Elements")
        if elements then
            elements.AnchorPoint = Vector2.new(0, 0)
            elements.Position = UDim2.new(0, 0, 0, 90)
            elements.Size = UDim2.new(1, 0, 1, -90)
            elements.ClipsDescendants = true
            for _, page in ipairs(elements:GetChildren()) do
                if page:IsA("ScrollingFrame") then
                    page.AnchorPoint = Vector2.new(0, 0)
                    page.Position = UDim2.new(0, 0, 0, 0)
                    page.Size = UDim2.new(1, 0, 1, 0)
                    page.CanvasSize = UDim2.new(0, 0, 0, 0)
                    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
                    page.ScrollingDirection = Enum.ScrollingDirection.Y
                    page.ScrollingEnabled = true
                    page.ScrollBarThickness = 4
                    page.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
                    page.ClipsDescendants = true
                    -- Never let a page sit scrolled sideways: that is what clipped
                    -- the left of every row in Dylan's screenshot 2.
                    pcall(function() page.CanvasPosition = Vector2.new(0, page.CanvasPosition.Y) end)
                    fitPageElements(page)
                end
            end
        end
    end)
end

-- Refit one tab page so nothing falls off the bottom or the side.
-- Element frames are built for a 465px window, so at 320px they overflowed right
-- and their titles clipped; and a page CanvasSize that is never refreshed leaves
-- the bottom buttons (Test: Farm 1 Coin, Test: Count Pets) unreachable after scrolling.
fitPageElements = function(page)
    pcall(function()
        local layout = page:FindFirstChildOfClass("UIListLayout")
        if layout then
            layout.Padding = UDim.new(0, 4)
            -- Explicit CanvasSize from content size, as a fallback if
            -- AutomaticCanvasSize is ignored by this ArrayField build.
            local contentY = layout.AbsoluteContentSize.Y
            if contentY and contentY > 0 then
                page.CanvasSize = UDim2.new(0, 0, 0, contentY + 12)
            end
        end
        for _, el in ipairs(page:GetChildren()) do
            if el:IsA("Frame") and el.Name ~= "Template" and el.Name ~= "Placeholder" and el.Name ~= "SectionSpacing" then
                -- Fit the row to the page width, keep its height.
                local h = el.Size.Y.Offset
                if h and h > 0 then
                    el.Size = UDim2.new(1, -10, 0, h)
                else
                    el.Size = UDim2.new(1, -10, 0, 40)
                end
                el.AnchorPoint = Vector2.new(0, 0)
                -- Titles must wrap instead of clipping at the row edge.
                local title = el:FindFirstChild("Title")
                if title and title:IsA("TextLabel") then
                    title.TextWrapped = true
                    title.TextTruncate = Enum.TextTruncate.None
                    title.TextXAlignment = Enum.TextXAlignment.Left
                end
                local content = el:FindFirstChild("Content")
                if content and content:IsA("TextLabel") then
                    content.TextWrapped = true
                    content.TextTruncate = Enum.TextTruncate.None
                end
                -- Sliders: shrink the track so it fits in a 320px window.
                local sliderMain = el:FindFirstChild("Main")
                if sliderMain and el.Name:find("Distance") or (sliderMain and el.Name:find("Delay")) then
                    pcall(function()
                        sliderMain.Size = UDim2.new(0.55, 0, 0, sliderMain.Size.Y.Offset)
                    end)
                end
            end
        end
    end)
end
local function fitAllPages(main)
    pcall(function()
        local elements = main and main:FindFirstChild("Elements")
        if not elements then return end
        for _, page in ipairs(elements:GetChildren()) do
            if page:IsA("ScrollingFrame") then
                fitPageElements(page)
            end
        end
    end)
end
local function applySize(w, h)
    pcall(function()
        local main = getMain()
        if not main then return end
        local vp = getViewportSize()
        -- Never wider/taller than the screen minus a margin (Delta's right toolbar eats width).
        w = math.min(w, math.max(200, vp.X - 20))
        h = math.min(h, math.max(200, vp.Y - 20))
        currentLayoutW, currentLayoutH = w, h
        main.AnchorPoint = Vector2.new(0.5, 0.5)
        main.Size = UDim2.new(0, w, 0, h)
        main.Position = UDim2.new(0.5, 0, 0.5, 0)
        fitElements(main)
        fitAllPages(main)
    end)
end
local function applyCompact()
    applySize(COMPACT_W, COMPACT_H)
end
local function applyFull()
    applySize(FULL_W, FULL_H)
end
local function resetWindowPosition()
    applySize(currentLayoutW, currentLayoutH)
    setStatus("Window reset to centre, fits phone.")
end
-- Pull the window back on screen if dragging or an ArrayField tween pushed it off.
local function clampWindowToScreen()
    pcall(function()
        local main = getMain()
        if not main or not main.Visible then return end
        local vp = getViewportSize()
        local pos = main.AbsolutePosition
        local size = main.AbsoluteSize
        local off = pos.X < 0 or pos.Y < 0 or (pos.X + size.X) > vp.X or (pos.Y + size.Y) > vp.Y
        if off then
            main.AnchorPoint = Vector2.new(0.5, 0.5)
            main.Position = UDim2.new(0.5, 0, 0.5, 0)
            if size.X > vp.X - 20 or size.Y > vp.Y - 20 then
                applySize(currentLayoutW, currentLayoutH)
            end
        end
        -- Keep Elements fitted even if ArrayField re-set its 364px height.
        local elements = main:FindFirstChild("Elements")
        if elements and elements.AbsoluteSize.Y > main.AbsoluteSize.Y - 80 then
            fitElements(main)
        end
    end)
end
local function applyMobileLayout()
    -- ArrayField's load tween forces 500x475 at ~2.2s, so re-apply AFTER it, twice.
    -- Uses currentLayout size, so it will not override a Full choice the user made.
    applyCompact()
    task.delay(1.5, function() applySize(currentLayoutW, currentLayoutH) end)
    task.delay(3.0, function() applySize(currentLayoutW, currentLayoutH) end)
end
local function toggleHubVisible()
    pcall(function()
        local main = getMain()
        if main then main.Visible = not main.Visible end
    end)
end


-- v8 MOVABLE: ArrayField's AddDraggingFunctionality only handles MouseButton1 +
-- MouseMovement, never Touch, so the window cannot be dragged on a phone.
-- This handler handles both, clamps to screen, and does not tween (no fight
-- with ArrayField's 0.45s tween on mouse).
local function addTopbarDrag(main)
    pcall(function()
        if not main then return end
        local topbar = main:FindFirstChild("Topbar")
        if not topbar or topbar:FindFirstChild("TemplarDrag") then return end
        local marker = Instance.new("BoolValue")
        marker.Name = "TemplarDrag"
        marker.Parent = topbar
        local dragging = false
        local dragInput = nil
        local dragStart = nil
        local startPos = nil
        topbar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = main.Position
            end
        end)
        topbar.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input == dragInput and dragStart and startPos then
                local delta = input.Position - dragStart
                local vp = getViewportSize()
                local w = main.AbsoluteSize.X
                local h = main.AbsoluteSize.Y
                -- Keep the centre inside the screen so the top can never go off.
                local nx = math.clamp(startPos.X.Scale * vp.X + startPos.X.Offset + delta.X, w / 2, vp.X - w / 2)
                local ny = math.clamp(startPos.Y.Scale * vp.Y + startPos.Y.Offset + delta.Y, h / 2, vp.Y - h / 2)
                main.AnchorPoint = Vector2.new(0.5, 0.5)
                main.Position = UDim2.new(0, nx, 0, ny)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                dragInput = nil
            end
        end)
    end)
end
-- v8 SIZABLE: a resize handle in the bottom-right corner of Main.
local function addResizeHandle(main)
    pcall(function()
        if not main or main:FindFirstChild("ResizeHandle") then return end
        local handle = Instance.new("TextButton")
        handle.Name = "ResizeHandle"
        handle.Text = "⤢"
        handle.TextSize = 16
        handle.Font = Enum.Font.GothamBold
        handle.TextColor3 = Color3.fromRGB(166, 120, 255)
        handle.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        handle.BorderSizePixel = 0
        handle.Size = UDim2.new(0, 24, 0, 24)
        handle.Position = UDim2.new(1, -26, 1, -26)
        handle.AnchorPoint = Vector2.new(0, 0)
        handle.ZIndex = 20
        handle.AutoButtonColor = true
        handle.Parent = main
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = handle
        local resizing = false
        local resizeInput = nil
        local resizeStart = nil
        local startSize = nil
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                resizeStart = input.Position
                startSize = main.AbsoluteSize
            end
        end)
        handle.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                resizeInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if resizing and input == resizeInput and resizeStart and startSize then
                local delta = input.Position - resizeStart
                local vp = getViewportSize()
                local nw = math.clamp(startSize.X + delta.X, 280, math.min(500, vp.X - 20))
                local nh = math.clamp(startSize.Y + delta.Y, 260, math.min(475, vp.Y - 20))
                currentLayoutW, currentLayoutH = nw, nh
                main.Size = UDim2.new(0, nw, 0, nh)
                fitElements(main)
                fitAllPages(main)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                resizing = false
                resizeInput = nil
            end
        end)
    end)
end

-- Small floating button, so you can hide / show the Hub on mobile without RightShift
task.spawn(function()
    task.wait(1.5)
    applyMobileLayout()
    pcall(function()
        local m = getMain()
        addTopbarDrag(m)
        addResizeHandle(m)
        applyTabIcons()
        if m then fitAllPages(m) end
    end)
    -- Refit pages for the first 5 seconds (covers ArrayField's late tweens),
    -- so bottom buttons stay reachable after scrolling.
    task.spawn(function()
        for _ = 1, 5 do
            task.wait(1)
            pcall(function()
                local m = getMain()
                if m then fitAllPages(m) end
            end)
        end
    end)
    task.spawn(function()
        while true do
            task.wait(0.5)
            clampWindowToScreen()
        end
    end)
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
        -- Templar Cross Pattee as text (U+2720). No verified Roblox Cross Pattee
        -- decal asset ID was found, so no random asset ID is invented here;
        -- the unicode cross renders on mobile and is purple, Dylan's colour.
        btn.Text = "✠"
        btn.Size = UDim2.new(0, 44, 0, 44)
        btn.Position = UDim2.new(0, 10, 0, 120)
        btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        btn.TextColor3 = Color3.fromRGB(166, 120, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 24
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
        local movedDist = 0
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
                movedDist = math.max(movedDist, math.abs(delta.X) + math.abs(delta.Y))
                btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                -- Tap toggles, drag does not: dragging the cross must not hide the Hub.
                if movedDist < 12 then
                    toggleHubVisible()
                end
                dragging = false
                movedDist = 0
            end
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
safetyTab:CreateButton({ Name = "Reset Window Position (centre, fits phone)", Callback = function() resetWindowPosition() end })
safetyTab:CreateButton({ Name = "Compact Window (320x300)", Callback = function() applyCompact() end })
safetyTab:CreateButton({ Name = "Full Window (360x420 max)", Callback = function() applyFull() end })
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

-- PET VALUE ORACLE (v6)
-- Scores are ESTIMATES: power x rarity multiplier x variant multiplier.
-- NOT live trading prices. Rarity: Common 1, Rare 2, Epic 4, Legendary 8,
-- Mythical 16, Exclusive/Event 16, Huge 50. Variant: Normal 1, Shiny 2,
-- Golden 5, Rainbow 10, Dark Matter 25.
-- Pet data sources verified in Rafa psx.lua v0.4:
--   Library.Directory.Pets[petId] -> .name, .rarity, .huge, .titanic
--   Library.Shared.GetAllCollectablePets() -> .petId, .isGolden, .isRainbow, .isDarkMatter
--   Bank.Storage.Pets entries -> .g (golden), .dm (dark matter)
--   Library.PetCmds.GetEquipped() entries -> .uid
--   Library.Save.Get() -> save table (Pets / Inventory checked)
-- Fuse: grep of /tmp/psx.lua found NO Fuse remote or function, so the Fuse
-- button only tries a real PetCmds function if one exists at runtime and
-- otherwise reports FAILED. No remote name is invented.

local RARITY_MULT = { Common = 1, Rare = 2, Epic = 4, Legendary = 8, Mythical = 16, Exclusive = 16, Event = 16, Huge = 50 }
local RARITY_BASE_POWER = { Common = 10, Rare = 25, Epic = 60, Legendary = 150, Mythical = 400, Exclusive = 400, Event = 400, Huge = 5000 }
local VARIANT_MULT = { Normal = 1, Shiny = 2, Golden = 5, Rainbow = 10, ["Dark Matter"] = 25 }

local oraclePets = {}
local oracleDupes = 0

local function oracleVariantOf(entry)
    if not entry or type(entry) ~= "table" then return "Normal" end
    if entry.isDarkMatter or entry.dm or entry.darkMatter then return "Dark Matter" end
    if entry.isRainbow or entry.rb or entry.rainbow then return "Rainbow" end
    if entry.isGolden or entry.g or entry.golden then return "Golden" end
    if entry.isShiny or entry.shiny then return "Shiny" end
    if type(entry.variant) == "string" and VARIANT_MULT[entry.variant] then return entry.variant end
    return "Normal"
end

local function oraclePowerOf(entry, def, rarity)
    local p = nil
    if entry and type(entry) == "table" then
        p = entry.power or entry.damage
        if type(p) == "table" then p = p.power or p.total end
    end
    if def and type(def) == "table" then
        p = p or def.power or def.strength or def.damage
    end
    if type(p) == "number" then return p, false end
    return RARITY_BASE_POWER[rarity] or 10, true
end

local function oracleCollectPets()
    local found = {}
    local seenUid = {}
    local function addPet(entry, source)
        if not entry then return end
        local petId = nil
        if type(entry) == "string" then
            petId = entry
        elseif type(entry) == "table" then
            petId = entry.id or entry.petId or entry[1]
        end
        if not petId then return end
        local uid = (type(entry) == "table") and (entry.uid or entry.UUID) or nil
        if uid and seenUid[uid] then return end
        if uid then seenUid[uid] = true end
        local def = nil
        pcall(function()
            if Library and Library.Directory and Library.Directory.Pets then
                def = Library.Directory.Pets[petId]
            end
        end)
        local name = (def and def.name) or tostring(petId)
        local rarity = (def and def.rarity) or "Common"
        if def and (def.huge or def.titanic) then rarity = "Huge" end
        local variant = oracleVariantOf(entry)
        local power, estimated = oraclePowerOf(entry, def, rarity)
        local rMult = RARITY_MULT[rarity] or 1
        local vMult = VARIANT_MULT[variant] or 1
        local score = math.floor(power * rMult * vMult + 0.5)
        table.insert(found, { id = petId, name = name, rarity = rarity, variant = variant, power = power, powerEstimated = estimated, score = score, uid = uid, source = source })
    end
    if Library then
        pcall(function()
            local save = Library.Save.Get()
            if save then
                local inv = save.Pets or save.Inventory or save.pets
                if type(inv) == "table" then
                    for _, entry in pairs(inv) do addPet(entry, "save") end
                end
            end
        end)
        pcall(function()
            local equipped = Library.PetCmds.GetEquipped()
            if type(equipped) == "table" then
                for _, entry in pairs(equipped) do addPet(entry, "equipped") end
            end
        end)
        pcall(function()
            if RenderedPets then
                for _, entry in pairs(RenderedPets) do
                    if type(entry) == "table" and (entry.id or entry.petId) then addPet(entry, "rendered") end
                end
            end
        end)
    end
    return found
end

local function oracleTier(index, total)
    if total <= 0 then return "C" end
    local frac = index / total
    if frac <= 0.10 then return "S"
    elseif frac <= 0.30 then return "A"
    elseif frac <= 0.60 then return "B"
    else return "C" end
end

local function scanOracle()
    if not Library then
        pcall(function() oracleStatusPara:Set({ Title = "Oracle Status", Content = "Library not loaded yet. Wait for Ready, then scan again." }) end)
        return
    end
    local pets = oracleCollectPets()
    oraclePets = pets
    if #pets == 0 then
        pcall(function()
            oracleStatusPara:Set({ Title = "Oracle Status", Content = "Scanned 0 pets. Equip pets in-game first, then press Scan My Pets again. (Checked save + equipped pets.)" })
            oraclePara:Set({ Title = "Oracle Results", Content = "No pets found. If this keeps happening, your PSX version stores pets somewhere new - tell Jarvis." })
        end)
        setStatus("Oracle: 0 pets found")
        return
    end
    table.sort(pets, function(a, b) return a.score > b.score end)
    local counts = {}
    for _, p in ipairs(pets) do
        local key = p.id .. "|" .. p.variant
        counts[key] = (counts[key] or 0) + 1
    end
    local dupes = 0
    local fuseList = {}
    for key, c in pairs(counts) do
        if c > 1 then
            dupes = dupes + (c - 1)
            for _, p in ipairs(pets) do
                if p.id .. "|" .. p.variant == key then
                    table.insert(fuseList, p)
                    break
                end
            end
        end
    end
    oracleDupes = dupes
    local lines = {}
    table.insert(lines, "Values are ESTIMATES from power x rarity x variant. NOT live trading prices.")
    table.insert(lines, "S tier = top 10%, marked with a star. Purple = S tier.")
    table.insert(lines, "")
    table.insert(lines, "Best to Equip (top 5):")
    for i = 1, math.min(5, #pets) do
        local p = pets[i]
        local tier = oracleTier(i, #pets)
        local star = (tier == "S") and "★ " or ""
        table.insert(lines, string.format("%d. %s[%s] %s | %s %s | Power %s%s | Score %s", i, star, tier, p.name, p.rarity, p.variant, tostring(p.power), p.powerEstimated and " (est.)" or "", tostring(p.score)))
    end
    table.insert(lines, "")
    table.insert(lines, "Fuse first (duplicates / low commons):")
    if #fuseList == 0 then
        table.insert(lines, "None - no duplicates found.")
    else
        for i = 1, math.min(5, #fuseList) do
            local p = fuseList[i]
            table.insert(lines, string.format("- %s (%s %s) x%d - Fuse", p.name, p.rarity, p.variant, counts[p.id .. "|" .. p.variant]))
        end
        -- Lowest power commons, if any, after duplicates.
        local lowCommons = {}
        for i = #pets, 1, -1 do
            if pets[i].rarity == "Common" and pets[i].variant == "Normal" then table.insert(lowCommons, pets[i]) end
            if #lowCommons >= 3 then break end
        end
        for _, p in ipairs(lowCommons) do
            table.insert(lines, string.format("- %s (Common Normal) - Fuse, lowest power", p.name))
        end
    end
    local best = pets[1]
    pcall(function()
        oraclePara:Set({ Title = "Oracle Results", Content = table.concat(lines, "\n") })
        oracleStatusPara:Set({ Title = "Oracle Status", Content = "Scanned " .. tostring(#pets) .. " pets, " .. tostring(dupes) .. " duplicates, best is " .. best.name .. " (" .. best.rarity .. " " .. best.variant .. ", score " .. tostring(best.score) .. ")" })
    end)
    setStatus("Oracle scanned " .. tostring(#pets) .. " pets. Best: " .. best.name)
    log("Oracle scanned " .. tostring(#pets) .. " pets, " .. tostring(dupes) .. " dupes, best=" .. best.name)
end

local function tryFuseDuplicates()
    if not Library then return false, "Library not loaded yet" end
    -- Only call a real Fuse function if one exists at runtime. No Fuse
    -- remote was found in Rafa psx.lua v0.4, so no remote name is guessed.
    local fuseFn = nil
    pcall(function()
        if Library.PetCmds then
            for k, v in pairs(Library.PetCmds) do
                if type(k) == "string" and string.find(string.lower(k), "fuse") and type(v) == "function" then
                    fuseFn = v
                    break
                end
            end
        end
    end)
    if not fuseFn then
        return false, "FAILED: no Fuse function found in this PSX version"
    end
    local ok, res = pcall(function() return fuseFn() end)
    if ok then return true, "Fuse called: " .. tostring(res) end
    return false, "Fuse call failed: " .. tostring(res)
end

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

-- ORACLE TAB
oracleTab:CreateParagraph({ Title = "Pet Value Oracle", Content = "Scores are ESTIMATES: power x rarity x variant. NOT live trading prices. Common 1, Rare 2, Epic 4, Legendary 8, Mythical 16, Huge 50. Normal 1, Shiny 2, Golden 5, Rainbow 10, Dark Matter 25. S tier = top 10% of your pets." })
oracleStatusPara = oracleTab:CreateParagraph({ Title = "Oracle Status", Content = "Not scanned yet." })
oraclePara = oracleTab:CreateParagraph({ Title = "Oracle Results", Content = "Press Scan My Pets." })
oracleTab:CreateButton({
    Name = "Scan My Pets",
    Callback = function()
        task.spawn(function() scanOracle() end)
    end,
})
oracleTab:CreateButton({
    Name = "Equip Best (try)",
    Callback = function()
        task.spawn(function()
            local done, tried = tryEquipBest()
            setStatus(done and ("Oracle Equip Best OK via " .. tried) or "Equip Best FAILED: no EquipBest function found in this PSX version.")
        end)
    end,
})
oracleTab:CreateButton({
    Name = "Fuse Duplicates (try)",
    Callback = function()
        task.spawn(function()
            local ok, msg = tryFuseDuplicates()
            setStatus((ok and "OK: " or "") .. msg)
        end)
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

print("[Templar Hub v7] Loaded.")
