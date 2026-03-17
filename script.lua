local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local scriptRunning, menuOpen, isMinimized, isAnimating = true, false, false, false
local infJumpEnabled, speedBoostEnabled, autoStealEnabled, antiRagdollEnabled, serverHopEnabled = false, false, false, false, false
local spaceHeld, hopActive, boostPower, targetRotation = false, false, 28, 0
local itemSelecionado, espGui = nil, nil
local stealCache, shineGradients, rotatingGradients = {}, {}, {}

local folderName, fileName = "SkyHub", "SkyHub/Config.json"
if makefolder and not isfolder(folderName) then makefolder(folderName) end

local function saveSettings()
    if not writefile then return end
    writefile(fileName, HttpService:JSONEncode({
        infJump = infJumpEnabled, speedBoost = speedBoostEnabled, autoSteal = autoStealEnabled,
        antiRagdoll = antiRagdollEnabled, serverHop = serverHopEnabled, hopValue = (hopTextBox and hopTextBox.Text) or ""
    }))
end

local blacklistFile, serverBlacklist = folderName .. "/ServerBlacklist.json", {}
local function loadBlacklist()
    if isfile and isfile(blacklistFile) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(blacklistFile)) end)
        if success and type(data) == "table" then serverBlacklist = data end
    end
end
local function saveBlacklist() if writefile then writefile(blacklistFile, HttpService:JSONEncode(serverBlacklist)) end end
local function addServerToBlacklist(id) if not id then return end table.insert(serverBlacklist, id) if #serverBlacklist >= 300 then serverBlacklist = {} end saveBlacklist() end
local function isBlacklisted(id) for _, v in pairs(serverBlacklist) do if v == id then return true end end return false end

local oldGui = playerGui:FindFirstChild("DarkGeminiMenu")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui", playerGui)
screenGui.Name, screenGui.ResetOnSpawn = "DarkGeminiMenu", false

local notifySound = Instance.new("Sound", screenGui)
notifySound.SoundId, notifySound.Volume = "rbxassetid://4590662766", 0.5

local notifyLabel = Instance.new("TextLabel", screenGui)
notifyLabel.Size, notifyLabel.Position = UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, -40)
notifyLabel.BackgroundColor3, notifyLabel.BackgroundTransparency = Color3.fromRGB(0, 0, 0), 0.3
notifyLabel.TextColor3, notifyLabel.Font, notifyLabel.TextSize = Color3.fromRGB(0, 255, 0), Enum.Font.GothamBold, 16
notifyLabel.Text = ""
Instance.new("UIStroke", notifyLabel).Color = Color3.fromRGB(255, 215, 0)

local function parseValue(text)
    text = text:lower()
    local num = tonumber(text:match("[%d%.]+")) or 0
    if text:match("k") then num = num * 1000 elseif text:match("m") then num = num * 1000000 elseif text:match("b") then num = num * 1000000000 end
    return num
end

local function formatValue(n)
    if n >= 1e9 then return string.format("%.1fb", n/1e9) elseif n >= 1e6 then return string.format("%.1fm", n/1e6) elseif n >= 1e3 then return string.format("%.1fk", n/1e3) end
    return tostring(n)
end

local function getBestBrainrot()
    local highest, bestData = 0, nil
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name:lower():find("overhead") then
            local name, income
            for _, gui in pairs(obj:GetDescendants()) do
                if gui:IsA("TextLabel") then
                    local text = gui.Text
                    if text:find("%$") and (text:lower():find("/s") or text:lower():find("sec")) then
                        income = text
                        local num = parseValue(text)
                        if num > highest then highest, bestData = num, { overhead = obj, income = income, name = name or "Brainrot" } end
                    elseif not text:find("%$") and text ~= "STOLEN" and #text > 2 then name = text end
                end
            end
        end
    end
    return bestData
end

local function getHighestValue()
    local highest = 0
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name:lower():find("overhead") then
            for _, gui in pairs(obj:GetDescendants()) do
                if gui:IsA("TextLabel") and gui.Text:find("%$") and (gui.Text:lower():find("/s") or gui.Text:lower():find("sec")) then
                    local v = parseValue(gui.Text) if v > highest then highest = v end
                end
            end
        end
    end
    return highest
end

local function doServerHop()
    if not hopActive then return end
    statusLabel.Text = "Status: Iniciando busca..."
    local success, content = pcall(function() return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100") end)
    if not success or not content or not hopActive then statusLabel.Text = "Status: Erro ou Parado" return end
    local decoded = HttpService:JSONDecode(content)
    if decoded and decoded.data then
        for _, server in ipairs(decoded.data) do
            if not hopActive then break end
            if server.playing < server.maxPlayers and server.id ~= game.JobId and not isBlacklisted(server.id) then
                addServerToBlacklist(server.id)
                statusLabel.Text = "Status: Teleportando..."
                pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player) end)
                task.wait(2)
            end
        end
    end
end

local function applyShine(target)
    local grad = Instance.new("UIGradient", target)
    grad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)), ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 215, 0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 15, 15)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 215, 0)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0))})
    table.insert(shineGradients, grad) return grad
end

local function applyRotatingLED(target)
    local grad = Instance.new("UIGradient", target)
    grad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 15)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 0)), ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 15))})
    table.insert(rotatingGradients, grad) return grad
end

local function createBrainrotESP(data)
    if not data or not data.overhead then return end
    local target = data.overhead
    while target and not target:IsA("BasePart") do target = target.Parent end
    if not target then return end
    local b = Instance.new("BillboardGui", screenGui)
    b.Name, b.Adornee, b.AlwaysOnTop, b.Size, b.StudsOffset = "BrainrotESP", target, true, UDim2.new(0, 100, 0, 50), Vector3.new(0, 3, 0)
    local f = Instance.new("Frame", b)
    f.Size, f.BackgroundColor3, f.BackgroundTransparency = UDim2.new(1, 0, 1, 0), Color3.fromRGB(0, 0, 0), 0.2
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", f)
    s.Thickness, s.Color = 2, Color3.fromRGB(255, 255, 255)
    applyRotatingLED(s)
    local t = Instance.new("TextLabel", f)
    t.Size, t.Position, t.BackgroundTransparency = UDim2.new(1, -10, 1, -10), UDim2.new(0, 5, 0, 5), 1
    t.TextColor3, t.Font, t.TextSize, t.TextWrapped = Color3.fromRGB(255, 215, 0), Enum.Font.GothamBold, 11, true
    t.Text = (data.name or "Item") .. "\n" .. (data.income or "$0/s")
    return b
end

local function handleToggle(btn, circle, state)
    TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = state and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(50, 50, 50)}):Play()
    TweenService:Create(circle, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)}):Play()
end

local function drag(o)
    local dragging, dragInput, dragStart, startPos
    o.InputBegan:Connect(function(input) if scriptRunning and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then dragging, dragStart, startPos = true, input.Position, o.Position end end)
    o.InputChanged:Connect(function(input) if scriptRunning and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then dragInput = input end end)
    RunService.RenderStepped:Connect(function() if scriptRunning and dragging and dragInput then local delta = dragInput.Position - dragStart o.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
end

local selectorFrame = Instance.new("Frame", screenGui)
selectorFrame.Name, selectorFrame.Size, selectorFrame.Position, selectorFrame.BackgroundColor3, selectorFrame.Visible, selectorFrame.ZIndex = "AutoStealSelector", UDim2.new(0, 180, 0, 220), UDim2.new(0.8, 0, 0.5, -110), Color3.fromRGB(0, 0, 0), false, 5
Instance.new("UICorner", selectorFrame)
local selStroke = Instance.new("UIStroke", selectorFrame)
selStroke.Thickness, selStroke.ApplyStrokeMode = 5, Enum.ApplyStrokeMode.Border
applyRotatingLED(selStroke)
local selTitle = Instance.new("TextLabel", selectorFrame)
selTitle.Size, selTitle.Text, selTitle.TextColor3, selTitle.Font, selTitle.TextSize, selTitle.BackgroundTransparency, selTitle.ZIndex = UDim2.new(1, 0, 0, 30), "AUTO STEAL SELECTER", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 10, 1, 6
applyShine(selTitle)
local scrollList = Instance.new("ScrollingFrame", selectorFrame)
scrollList.Size, scrollList.Position, scrollList.BackgroundTransparency, scrollList.ScrollBarThickness, scrollList.AutomaticCanvasSize, scrollList.ZIndex = UDim2.new(0.9, 0, 0.75, 0), UDim2.new(0.05, 0, 0.18, 0), 1, 4, Enum.AutomaticSize.Y, 6
Instance.new("UIListLayout", scrollList).Padding = UDim.new(0, 6)

local function atualizarLista()
    if not scriptRunning or not autoStealEnabled then return end
    local itensNoMapa, newCache = {}, {}
    for _, d in pairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local act, obj = d.ActionText:lower(), d.ObjectText:lower()
            if (act:find("steal") or obj:find("brainrot") or act:find("pegar") or act:find("roubar")) and not (obj:find("dealer") or obj:find("trader")) then
                table.insert(newCache, d) local id = d:GetDebugId() itensNoMapa[id] = true
                if not scrollList:FindFirstChild(id) then
                    local b = Instance.new("TextButton", scrollList)
                    b.Name, b.Size, b.Text, b.BackgroundColor3, b.Font, b.TextSize, b.TextColor3, b.ZIndex = id, UDim2.new(1, -10, 0, 32), d.ObjectText ~= "" and d.ObjectText or "Item", Color3.fromRGB(25, 25, 25), Enum.Font.GothamBold, 9, Color3.fromRGB(255, 215, 0), 7
                    Instance.new("UICorner", b)
                    local bs = Instance.new("UIStroke", b)
                    bs.Name, bs.Thickness, bs.ApplyStrokeMode, bs.Color, bs.Enabled = "SelectionBorder", 2, Enum.ApplyStrokeMode.Border, Color3.fromRGB(255, 215, 0), (itemSelecionado == d)
                    b.MouseButton1Click:Connect(function() if not scriptRunning then return end itemSelecionado = (itemSelecionado == d and nil or d) for _, c in pairs(scrollList:GetChildren()) do if c:IsA("TextButton") and c:FindFirstChild("SelectionBorder") then c.SelectionBorder.Enabled = (itemSelecionado and c.Name == itemSelecionado:GetDebugId()) end end end)
                end
            end
        end
    end
    stealCache = newCache
    for _, c in pairs(scrollList:GetChildren()) do if c:IsA("TextButton") and not itensNoMapa[c.Name] then c:Destroy() end end
end

local hopFrame = Instance.new("Frame", screenGui)
hopFrame.Name, hopFrame.Size, hopFrame.Position, hopFrame.BackgroundColor3, hopFrame.Visible, hopFrame.ZIndex = "ServerHopMenu", UDim2.new(0, 180, 0, 220), UDim2.new(0.05, 0, 0.5, -400), Color3.fromRGB(0, 0, 0), false, 10
Instance.new("UICorner", hopFrame).CornerRadius = UDim.new(0, 10)
local hopStroke = Instance.new("UIStroke", hopFrame)
hopStroke.Thickness, hopStroke.ApplyStrokeMode = 4, Enum.ApplyStrokeMode.Border
applyRotatingLED(hopStroke)
local hopTitle = Instance.new("TextLabel", hopFrame)
hopTitle.Size, hopTitle.Text, hopTitle.TextColor3, hopTitle.Font, hopTitle.TextSize, hopTitle.BackgroundTransparency, hopTitle.ZIndex = UDim2.new(1, 0, 0, 35), "SERVER HOP", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 14, 1, 11
applyShine(hopTitle)
statusLabel = Instance.new("TextLabel", hopFrame)
statusLabel.Size, statusLabel.Position, statusLabel.Text, statusLabel.TextColor3, statusLabel.Font, statusLabel.TextSize, statusLabel.BackgroundTransparency, statusLabel.ZIndex = UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 38), "Status: Aguardando", Color3.fromRGB(255, 215, 0), Enum.Font.GothamBold, 10, 1, 11
local inputFrame = Instance.new("Frame", hopFrame)
inputFrame.Size, inputFrame.Position, inputFrame.BackgroundColor3, inputFrame.ZIndex = UDim2.new(0.85, 0, 0, 30), UDim2.new(0.075, 0, 0, 60), Color3.fromRGB(15, 15, 15), 11
Instance.new("UICorner", inputFrame).CornerRadius = UDim.new(0, 8)
applyRotatingLED(Instance.new("UIStroke", inputFrame))
hopTextBox = Instance.new("TextBox", inputFrame)
hopTextBox.Size, hopTextBox.Position, hopTextBox.BackgroundTransparency, hopTextBox.Text, hopTextBox.PlaceholderText, hopTextBox.TextColor3, hopTextBox.Font, hopTextBox.TextSize, hopTextBox.ZIndex = UDim2.new(1, -10, 1, 0), UDim2.new(0, 5, 0, 0), 1, "", "Min 1000000", Color3.fromRGB(255, 215, 0), Enum.Font.GothamBold, 12, 12
local startBtn = Instance.new("TextButton", hopFrame)
startBtn.Size, startBtn.Position, startBtn.BackgroundColor3, startBtn.Text, startBtn.TextColor3, startBtn.Font, startBtn.ZIndex = UDim2.new(0.85, 0, 0, 35), UDim2.new(0.075, 0, 0, 105), Color3.fromRGB(15, 15, 15), "Iniciar", Color3.fromRGB(255, 215, 0), Enum.Font.GothamBold, 11
Instance.new("UICorner", startBtn)
applyRotatingLED(Instance.new("UIStroke", startBtn))
local stopBtn = Instance.new("TextButton", hopFrame)
stopBtn.Size, stopBtn.Position, stopBtn.BackgroundColor3, stopBtn.Text, stopBtn.TextColor3, stopBtn.Font, stopBtn.ZIndex = UDim2.new(0.85, 0, 0, 35), UDim2.new(0.075, 0, 0, 155), Color3.fromRGB(15, 15, 15), "Stop", Color3.fromRGB(255, 0, 0), Enum.Font.GothamBold, 11
Instance.new("UICorner", stopBtn)
applyRotatingLED(Instance.new("UIStroke", stopBtn))

local toggleBall = Instance.new("TextButton", screenGui)
toggleBall.Size, toggleBall.Position, toggleBall.BackgroundColor3, toggleBall.ZIndex = UDim2.new(0, 45, 0, 45), UDim2.new(0.8, 70, 0.5, -190), Color3.fromRGB(0, 0, 0), 20
Instance.new("UICorner", toggleBall).CornerRadius = UDim.new(1, 0)
applyRotatingLED(Instance.new("UIStroke", toggleBall))
local cloudIcon = Instance.new("TextLabel", toggleBall)
cloudIcon.Size, cloudIcon.BackgroundTransparency, cloudIcon.Text, cloudIcon.TextSize, cloudIcon.TextColor3, cloudIcon.AnchorPoint, cloudIcon.Position, cloudIcon.ZIndex = UDim2.new(1, 0, 1, 0), 1, "☁️", 25, Color3.fromRGB(255, 215, 0), Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, 0), 21

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size, mainFrame.Position, mainFrame.AnchorPoint, mainFrame.BackgroundColor3, mainFrame.Visible, mainFrame.ZIndex = UDim2.new(0, 400, 0, 350), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5), Color3.fromRGB(0, 0, 0), false, 30
Instance.new("UICorner", mainFrame)
applyRotatingLED(Instance.new("UIStroke", mainFrame))
local titleLabel = Instance.new("TextLabel", mainFrame)
titleLabel.Size, titleLabel.Position, titleLabel.BackgroundTransparency, titleLabel.Text, titleLabel.TextColor3, titleLabel.Font, titleLabel.TextSize, titleLabel.ZIndex = UDim2.new(0, 200, 0, 40), UDim2.new(0, 15, 0, 0), 1, "SKY HUB", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 20, 31
applyShine(titleLabel)
local speedDisplay = Instance.new("TextLabel", mainFrame)
speedDisplay.Size, speedDisplay.Position, speedDisplay.BackgroundTransparency, speedDisplay.Text, speedDisplay.TextColor3, speedDisplay.Font, speedDisplay.TextSize, speedDisplay.ZIndex = UDim2.new(0, 150, 0, 20), UDim2.new(0, 150, 0, 10), 1, "Speed: 0 SPS", Color3.fromRGB(255, 215, 0), Enum.Font.GothamMedium, 14, 31
local separatorLine = Instance.new("Frame", mainFrame)
separatorLine.Size, separatorLine.Position, separatorLine.ZIndex = UDim2.new(1, 0, 0, 4), UDim2.new(0, 0, 0, 40), 31
applyShine(separatorLine)

local function createOption(name, y)
    local l = Instance.new("TextLabel", mainFrame)
    l.Size, l.Position, l.BackgroundTransparency, l.Text, l.Font, l.TextSize, l.TextColor3, l.ZIndex = UDim2.new(0, 150, 0, 30), UDim2.new(0, 20, 0, y), 1, name, Enum.Font.GothamBold, 16, Color3.fromRGB(255, 215, 0), 32
    local b = Instance.new("TextButton", mainFrame)
    b.Size, b.Position, b.BackgroundColor3, b.ZIndex = UDim2.new(0, 50, 0, 26), UDim2.new(0, 320, 0, y + 2), Color3.fromRGB(40, 40, 40), 32
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    local c = Instance.new("Frame", b)
    c.Size, c.Position, c.BackgroundColor3, c.ZIndex = UDim2.new(0, 20, 0, 20), UDim2.new(0, 3, 0.5, -10), Color3.fromRGB(255, 255, 255), 33
    Instance.new("UICorner", c).CornerRadius = UDim.new(1, 0)
    return b, c
end

local infBtn, infCirc = createOption("Infinity Jump", 100)
local stealBtn, stealCirc = createOption("Auto Steal", 140)
local speedBtn, speedCirc = createOption("Speed Boost", 180)
local ragBtn, ragCirc = createOption("Anti Ragdoll", 220)
local hopBtn, hopCirc = createOption("Server Hop", 260)

local function toggleMenu()
    if not scriptRunning or isAnimating then return end
    isAnimating, menuOpen = true, not menuOpen
    targetRotation = targetRotation + 360
    TweenService:Create(cloudIcon, TweenInfo.new(0.4), {Rotation = targetRotation}):Play()
    if menuOpen then mainFrame.Visible = true mainFrame:TweenSize(isMinimized and UDim2.new(0, 400, 0, 40) or UDim2.new(0, 400, 0, 350), "Out", "Back", 0.4, true, function() isAnimating = false end)
    else mainFrame:TweenSize(UDim2.new(0, 0, 0, 0), "In", "Quad", 0.3, true, function() mainFrame.Visible, isAnimating = false, false end) end
end

local closeButton = Instance.new("TextButton", mainFrame)
closeButton.Size, closeButton.Position, closeButton.BackgroundColor3, closeButton.Text, closeButton.ZIndex = UDim2.new(0, 30, 0, 30), UDim2.new(1, -35, 0, 5), Color3.fromRGB(150, 0, 0), "X", 35
Instance.new("UICorner", closeButton)
local minButton = Instance.new("TextButton", mainFrame)
minButton.Size, minButton.Position, minButton.BackgroundColor3, minButton.Text, minButton.TextColor3, minButton.ZIndex = UDim2.new(0, 30, 0, 30), UDim2.new(1, -70, 0, 5), Color3.fromRGB(40, 40, 40), "-", Color3.fromRGB(255, 255, 255), 35
Instance.new("UICorner", minButton)

closeButton.MouseButton1Click:Connect(function() if isAnimating then return end isAnimating = true mainFrame:TweenSize(UDim2.new(0, 0, 0, 0), "In", "Back", 0.4, true, function() scriptRunning = false screenGui:Destroy() end) end)
minButton.MouseButton1Click:Connect(function() if not scriptRunning or isAnimating then return end isMinimized = not isMinimized mainFrame:TweenSize(isMinimized and UDim2.new(0, 400, 0, 40) or UDim2.new(0, 400, 0, 350), "Out", "Quart", 0.3, true) separatorLine.Visible = not isMinimized end)
toggleBall.MouseButton1Click:Connect(toggleMenu)

local function loadSettings()
    if isfile and isfile(fileName) then
        local s, data = pcall(function() return HttpService:JSONDecode(readfile(fileName)) end)
        if s then
            infJumpEnabled = data.infJump; handleToggle(infBtn, infCirc, infJumpEnabled)
            speedBoostEnabled = data.speedBoost; handleToggle(speedBtn, speedCirc, speedBoostEnabled)
            autoStealEnabled = data.autoSteal; handleToggle(stealBtn, stealCirc, autoStealEnabled); selectorFrame.Visible = autoStealEnabled
            antiRagdollEnabled = data.antiRagdoll; handleToggle(ragBtn, ragCirc, antiRagdollEnabled)
            serverHopEnabled = data.serverHop; handleToggle(hopBtn, hopCirc, serverHopEnabled); hopFrame.Visible = serverHopEnabled
            hopTextBox.Text = data.hopValue or ""
        end
    end
end

infBtn.MouseButton1Click:Connect(function() infJumpEnabled = not infJumpEnabled; handleToggle(infBtn, infCirc, infJumpEnabled); saveSettings() end)
stealBtn.MouseButton1Click:Connect(function() autoStealEnabled = not autoStealEnabled; handleToggle(stealBtn, stealCirc, autoStealEnabled); selectorFrame.Visible = autoStealEnabled; saveSettings() end)
speedBtn.MouseButton1Click:Connect(function() speedBoostEnabled = not speedBoostEnabled; handleToggle(speedBtn, speedCirc, speedBoostEnabled); saveSettings() end)
ragBtn.MouseButton1Click:Connect(function() antiRagdollEnabled = not antiRagdollEnabled; handleToggle(ragBtn, ragCirc, antiRagdollEnabled); saveSettings() end)
hopBtn.MouseButton1Click:Connect(function() serverHopEnabled = not serverHopEnabled; handleToggle(hopBtn, hopCirc, serverHopEnabled); hopFrame.Visible = serverHopEnabled; saveSettings() end)
hopTextBox:GetPropertyChangedSignal("Text"):Connect(function() hopTextBox.Text = hopTextBox.Text:gsub("%D+", "") saveSettings() end)

startBtn.MouseButton1Click:Connect(function()
    hopActive = true
    local target = tonumber(hopTextBox.Text)
    if not target then statusLabel.Text = "Status: Digite um valor!" return end
    statusLabel.Text, statusLabel.TextColor3 = "Status: Verificando...", Color3.fromRGB(255, 255, 255)
    task.wait(1)
    if not hopActive then return end
    if getHighestValue() >= target then statusLabel.Text, statusLabel.TextColor3 = "Alvo " .. formatValue(target) .. "+ Detectado!", Color3.fromRGB(0, 255, 0)
    else statusLabel.Text, statusLabel.TextColor3 = "Status: Pulando servidor...", Color3.fromRGB(255, 0, 0) doServerHop() end
end)
stopBtn.MouseButton1Click:Connect(function() hopActive = false statusLabel.Text, statusLabel.TextColor3 = "Status: Parado Imediatamente", Color3.fromRGB(255, 215, 0) end)

RunService.Heartbeat:Connect(function()
    if not scriptRunning then return end
    local t = os.clock()
    for _, g in pairs(rotatingGradients) do g.Rotation = (t * 180) % 360 end
    for _, g in pairs(shineGradients) do g.Offset = Vector2.new(-0.8 + (t * 0.4 % 1.6), 0) end
    local char = player.Character local root = char and char:FindFirstChild("HumanoidRootPart") local hum = char and char:FindFirstChildOfClass("Humanoid")
    if root and hum then
        if antiRagdollEnabled then
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
            if hum:GetState() == Enum.HumanoidStateType.Ragdoll or hum:GetState() == Enum.HumanoidStateType.FallingDown then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
            if hum.MoveDirection.Magnitude == 0 and root.AssemblyLinearVelocity.Magnitude > 20 then root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0), Vector3.new(0, 0, 0) end
        end
        speedDisplay.Text = "Speed: " .. math.floor(root.AssemblyLinearVelocity.Magnitude) .. " SPS"
        if speedBoostEnabled and hum.MoveDirection.Magnitude > 0 then
            local rp = RaycastParams.new() rp.FilterDescendantsInstances, rp.FilterType = {char}, Enum.RaycastFilterType.Exclude
            if not workspace:Raycast(root.Position, hum.MoveDirection * 3, rp) then root.AssemblyLinearVelocity = Vector3.new(hum.MoveDirection.X * boostPower, root.AssemblyLinearVelocity.Y, hum.MoveDirection.Z * boostPower) end
        end
        if infJumpEnabled and spaceHeld then root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 48, root.AssemblyLinearVelocity.Z) end
        if autoStealEnabled then
            if itemSelecionado and itemSelecionado.Parent then itemSelecionado.HoldDuration = 0 fireproximityprompt(itemSelecionado)
            else for _, d in pairs(stealCache) do if d and d.Parent then d.HoldDuration = 0 fireproximityprompt(d) end end end
        end
    end
end)

local currentBrainrotValue, lastNotify = 0, 0
task.spawn(function()
    while scriptRunning do
        local best = getBestBrainrot()
        if best then
            local val = parseValue(best.income)
            if not espGui or not espGui.Adornee or not espGui.Adornee:IsDescendantOf(workspace) or val > currentBrainrotValue then
                if espGui then espGui:Destroy() end espGui, currentBrainrotValue = createBrainrotESP(best), val
            end
            if val >= 1e7 and (os.clock() - lastNotify > 10) then
                notifyLabel.Text, lastNotify = "💰 " .. best.name .. " | " .. best.income, os.clock()
                notifySound:Play() notifyLabel:TweenPosition(UDim2.new(0, 0, 0, 10), "Out", "Back", 0.5, true)
                task.delay(5, function() notifyLabel:TweenPosition(UDim2.new(0, 0, 0, -40), "In", "Quad", 0.5, true) notifyLabel.Text = "" end)
            end
        else currentBrainrotValue, notifyLabel.Text = 0, "" end
        task.wait(2)
    end
end)

UserInputService.JumpRequest:Connect(function() if scriptRunning and infJumpEnabled then spaceHeld = true task.wait(0.1) spaceHeld = false end end)
UserInputService.InputBegan:Connect(function(i, g) if scriptRunning and not g and i.KeyCode == Enum.KeyCode.LeftControl then toggleMenu() end end)
task.spawn(function() while scriptRunning do atualizarLista() task.wait(3) end end)

drag(mainFrame) drag(toggleBall) drag(selectorFrame) drag(hopFrame)
loadSettings() loadBlacklist()
task.wait(1) toggleMenu()
