local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")


local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local scriptRunning = true
local infJumpEnabled = false
local speedBoostEnabled = false
local autoStealEnabled = false
local antiRagdollEnabled = false
local serverHopEnabled = false
local menuOpen = false
local isMinimized = false
local spaceHeld = false
local isAnimating = false
local hopActive = false
local autoModeEnabled = false 
local boostPower = 28
local itemSelecionado = nil
local stealCache = {}
local shineGradients = {}
local rotatingGradients = {}
local targetRotation = 0
local espGui


local folderName = "SkyHub"
local fileName = folderName .. "/Config.json"
if makefolder and not isfolder(folderName) then makefolder(folderName) end

local function saveSettings()
    if not writefile then return end
    local config = {
        infJump = infJumpEnabled,
        speedBoost = speedBoostEnabled,
        autoSteal = autoStealEnabled,
        antiRagdoll = antiRagdollEnabled,
        serverHop = serverHopEnabled,
        hopValue = (hopTextBox and hopTextBox.Text) or ""
    }
    writefile(fileName, HttpService:JSONEncode(config))
end


local blacklistFile = folderName .. "/ServerBlacklist.json"
local serverBlacklist = {}

local function loadBlacklist()
    if isfile and isfile(blacklistFile) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(blacklistFile)) end)
        if success and type(data) == "table" then serverBlacklist = data end
    end
end

local function saveBlacklist()
    if writefile then writefile(blacklistFile, HttpService:JSONEncode(serverBlacklist)) end
end

local function addServerToBlacklist(id)
    if not id then return end
    table.insert(serverBlacklist, id)
    if #serverBlacklist >= 300 then serverBlacklist = {} end
    saveBlacklist()
end

local function isBlacklisted(id)
    for _, v in pairs(serverBlacklist) do
        if v == id then return true end
    end
    return false
end


local oldGui = playerGui:FindFirstChild("DarkGeminiMenu")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DarkGeminiMenu"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false

local notifySound = Instance.new("Sound", screenGui)
notifySound.SoundId = "rbxassetid://4590662766"
notifySound.Volume = 0.5

local notifyLabel = Instance.new("TextLabel", screenGui)
notifyLabel.Size = UDim2.new(1, 0, 0, 30)
notifyLabel.Position = UDim2.new(0, 0, 0, -40)
notifyLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
notifyLabel.BackgroundTransparency = 0.3
notifyLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
notifyLabel.Font = Enum.Font.GothamBold
notifyLabel.TextSize = 16
notifyLabel.Text = ""
Instance.new("UIStroke", notifyLabel).Color = Color3.fromRGB(255, 215, 0)


local function parseValue(text)
    text = text:lower()
    local num = tonumber(text:match("[%d%.]+"))
    if not num then return 0 end
    if text:match("%d+%.?%d*%s*k") then 
        num = num * 1000 
    elseif text:match("%d+%.?%d*%s*m") then 
        num = num * 1000000 
    elseif text:match("%d+%.?%d*%s*b") then 
        num = num * 1000000000 
    end
    return num
end

local function formatValue(n)
    if n >= 1000000000 then 
        return string.format("%.1fb", n/1000000000) 
    elseif n >= 1000000 then 
        return string.format("%.1fm", n/1000000) 
    elseif n >= 1000 then 
        return string.format("%.1fk", n/1000) 
    else 
        return tostring(n) 
    end
end


local function getBestBrainrot()
    local highest = 0
    local bestData = nil
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name:lower():find("overhead") then
            local name, income
            for _, gui in pairs(obj:GetDescendants()) do
                if gui:IsA("TextLabel") then
                    local text = gui.Text
                    if text:find("%$") and (text:lower():find("/s") or text:lower():find("sec")) then
                        income = text
                        local num = parseValue(text)
                        if num > highest then
                            highest = num
                            bestData = { overhead = obj, income = income, name = name or "Brainrot", }
                        end
                    elseif not text:find("%$") and text ~= "STOLEN" and #text > 2 then
                        name = text
                    end
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
                if gui:IsA("TextLabel") then
                    local text = gui.Text:lower()
                    if text:find("%$") and (text:find("/s") or text:find("sec")) then
                        local currentVal = parseValue(text)
                        if currentVal > highest then highest = currentVal end
                    end
                end
            end
        end
    end
    return highest
end


local function doServerHop()
    if not hopActive then return end
    statusLabel.Text = "Status: Iniciando busca..."
    local placeId = game.PlaceId
    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
    local success, content = pcall(function() return game:HttpGet(url) end)
    
    if not success or not content or not hopActive then 
        statusLabel.Text = "Status: Erro ou Parado"
        return 
    end
    
    local decoded = HttpService:JSONDecode(content)
    if decoded and decoded.data then
        for _, server in ipairs(decoded.data) do
            if not hopActive then break end
            if server.playing < server.maxPlayers and server.id ~= game.JobId and not isBlacklisted(server.id) then
                addServerToBlacklist(server.id)
                statusLabel.Text = "Status: Teleportando..."
                pcall(function() TeleportService:TeleportToPlaceInstance(placeId, server.id, player) end)
                task.wait(2)
            end
        end
        if hopActive then statusLabel.Text = "Status: Nenhum serv. livre" end
    else
        statusLabel.Text = "Status: Lista vazia"
    end
end


local function applyShine(target)
    local grad = Instance.new("UIGradient", target)
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 215, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 15, 15)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 215, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0))
    })
    table.insert(shineGradients, grad)
    return grad
end

local function applyRotatingLED(target)
    local grad = Instance.new("UIGradient", target)
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 15)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 15))
    })
    table.insert(rotatingGradients, grad)
    return grad
end

local function createBrainrotESP(data)
    if not data or not data.overhead then return end
    local target = data.overhead
    while target and not target:IsA("BasePart") do target = target.Parent end
    if not target then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "BrainrotESP"
    billboard.Adornee = target
    billboard.AlwaysOnTop = true
    billboard.Parent = screenGui
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)

    local frame = Instance.new("Frame", billboard)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.2
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(255, 255, 255)
    applyRotatingLED(stroke)

    local text = Instance.new("TextLabel", frame)
    text.Size = UDim2.new(1, -10, 1, -10)
    text.Position = UDim2.new(0, 5, 0, 5)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(255, 215, 0)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 11
    text.TextWrapped = true
    text.Text = (data.name or "Item") .. "\n" .. (data.income or "$0/s")
    
    return billboard
end


local function handleToggle(btn, circle, state)
    TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = state and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(50, 50, 50)}):Play()
    TweenService:Create(circle, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)}):Play()
end

local function drag(o)
    local dragging, dragInput, dragStart, startPos
    o.InputBegan:Connect(function(input)
        if scriptRunning and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true; dragStart = input.Position; startPos = o.Position
        end
    end)
    o.InputChanged:Connect(function(input)
        if scriptRunning and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            dragInput = input
        end
    end)
    RunService.RenderStepped:Connect(function()
        if scriptRunning and dragging and dragInput then
            local delta = dragInput.Position - dragStart
            o.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end


local function isBrainrotNotifying()
    return notifyLabel.Text ~= ""
end


local selectorFrame = Instance.new("Frame", screenGui)
selectorFrame.Name = "AutoStealSelector"
selectorFrame.Size = UDim2.new(0, 180, 0, 220)
selectorFrame.Position = UDim2.new(0.8, 0, 0.5, -110)
selectorFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
selectorFrame.Visible = false
Instance.new("UICorner", selectorFrame)
selectorFrame.ZIndex = 5

local selStroke = Instance.new("UIStroke", selectorFrame)
selStroke.Thickness = 5
selStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
selStroke.Color = Color3.fromRGB(255, 255, 255)
applyRotatingLED(selStroke)

local selTitle = Instance.new("TextLabel", selectorFrame)
selTitle.Size = UDim2.new(1, 0, 0, 30)
selTitle.Text = "AUTO STEAL SELECTER"
selTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
selTitle.Font = Enum.Font.GothamBold
selTitle.TextSize = 10
selTitle.BackgroundTransparency = 1
selTitle.AutoLocalize = false
applyShine(selTitle)
selTitle.ZIndex = 6

local scrollList = Instance.new("ScrollingFrame", selectorFrame)
scrollList.Size = UDim2.new(0.9, 0, 0.75, 0)
scrollList.Position = UDim2.new(0.05, 0, 0.18, 0)
scrollList.BackgroundTransparency = 1
scrollList.ScrollBarThickness = 4
scrollList.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollList.ZIndex = 6

local listLayout = Instance.new("UIListLayout", scrollList)
listLayout.Padding = UDim.new(0, 6)

local function atualizarLista()
    if not scriptRunning or not autoStealEnabled then return end
    local itensNoMapa = {}
    local newCache = {}
    for _, d in pairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local actionText = d.ActionText:lower()
            local objectText = d.ObjectText:lower()
            if (actionText:find("steal") or objectText:find("brainrot") or actionText:find("pegar") or actionText:find("roubar")) and not (objectText:find("dealer") or objectText:find("trader")) then
                table.insert(newCache, d)
                local id = d:GetDebugId()
                itensNoMapa[id] = true
                if not scrollList:FindFirstChild(id) then
                    local b = Instance.new("TextButton", scrollList)
                    b.Name = id
                    b.Size = UDim2.new(1, -10, 0, 32)
                    b.Text = d.ObjectText ~= "" and d.ObjectText or "Item"
                    b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                    b.Font = Enum.Font.GothamBold
                    b.TextSize = 9
                    b.TextColor3 = Color3.fromRGB(255, 215, 0)
                    Instance.new("UICorner", b)
                    b.AutoLocalize = false
                    b.ZIndex = 7
                    
                    local bStroke = Instance.new("UIStroke", b)
                    bStroke.Name = "SelectionBorder"
                    bStroke.Thickness = 2
                    bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    bStroke.Color = Color3.fromRGB(255, 215, 0)
                    bStroke.Enabled = (itemSelecionado == d)
                    
                    b.MouseButton1Click:Connect(function()
                        if not scriptRunning then return end
                        if itemSelecionado == d then itemSelecionado = nil else itemSelecionado = d end
                        for _, child in pairs(scrollList:GetChildren()) do
                            if child:IsA("TextButton") and child:FindFirstChild("SelectionBorder") then
                                child.SelectionBorder.Enabled = (itemSelecionado and child.Name == itemSelecionado:GetDebugId())
                            end
                        end
                    end)
                end
            end
        end
    end
    stealCache = newCache
    for _, child in pairs(scrollList:GetChildren()) do
        if child:IsA("TextButton") and not itensNoMapa[child.Name] then child:Destroy() end
    end
end


local hopFrame = Instance.new("Frame", screenGui)
hopFrame.Name = "ServerHopMenu"
hopFrame.Size = UDim2.new(0, 180, 0, 260) 
hopFrame.Position = UDim2.new(0.05, 0, 0.5, -400)
hopFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
hopFrame.Visible = false
Instance.new("UICorner", hopFrame).CornerRadius = UDim.new(0, 10)
hopFrame.ZIndex = 10

local hopStroke = Instance.new("UIStroke", hopFrame)
hopStroke.Thickness = 4
hopStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
hopStroke.Color = Color3.fromRGB(255, 255, 255)
applyRotatingLED(hopStroke)

local hopTitle = Instance.new("TextLabel", hopFrame)
hopTitle.Size = UDim2.new(1, 0, 0, 35)
hopTitle.Text = "SERVER HOP"
hopTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
hopTitle.Font = Enum.Font.GothamBold
hopTitle.TextSize = 14
hopTitle.BackgroundTransparency = 1
hopTitle.ZIndex = 11
applyShine(hopTitle)

statusLabel = Instance.new("TextLabel", hopFrame)
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 38)
statusLabel.Text = "Status: Aguardando"
statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 10
statusLabel.BackgroundTransparency = 1
statusLabel.ZIndex = 11

local inputFrame = Instance.new("Frame", hopFrame)
inputFrame.Size = UDim2.new(0.85, 0, 0, 30)
inputFrame.Position = UDim2.new(0.075, 0, 0, 60)
inputFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Instance.new("UICorner", inputFrame).CornerRadius = UDim.new(0, 8)
inputFrame.ZIndex = 11

local inputStroke = Instance.new("UIStroke", inputFrame)
inputStroke.Thickness = 2
inputStroke.Color = Color3.fromRGB(255, 255, 255)
applyRotatingLED(inputStroke)

hopTextBox = Instance.new("TextBox", inputFrame)
hopTextBox.Size = UDim2.new(1, -10, 1, 0)
hopTextBox.Position = UDim2.new(0, 5, 0, 0)
hopTextBox.BackgroundTransparency = 1
hopTextBox.Text = ""
hopTextBox.PlaceholderText = "Min 1000000"
hopTextBox.TextColor3 = Color3.fromRGB(255, 215, 0)
hopTextBox.Font = Enum.Font.GothamBold
hopTextBox.TextSize = 12
hopTextBox.ClearTextOnFocus = false
hopTextBox.ZIndex = 12

local startBtn = Instance.new("TextButton", hopFrame)
startBtn.Size = UDim2.new(0.85, 0, 0, 35)
startBtn.Position = UDim2.new(0.075, 0, 0, 105)
startBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
startBtn.Text = "Iniciar"
startBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
startBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)
startBtn.ZIndex = 11
applyRotatingLED(Instance.new("UIStroke", startBtn))

local stopBtn = Instance.new("TextButton", hopFrame)
stopBtn.Size = UDim2.new(0.85, 0, 0, 35)
stopBtn.Position = UDim2.new(0.075, 0, 0, 155)
stopBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
stopBtn.Text = "Stop"
stopBtn.TextColor3 = Color3.fromRGB(255, 0, 0)
stopBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 8)
stopBtn.ZIndex = 11
applyRotatingLED(Instance.new("UIStroke", stopBtn))


local autoBtn = Instance.new("TextButton", hopFrame)
autoBtn.Size = UDim2.new(0.85, 0, 0, 35)
autoBtn.Position = UDim2.new(0.075, 0, 0, 205)
autoBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
autoBtn.Text = "Modo Automático"
autoBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
autoBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 8)
autoBtn.ZIndex = 11
applyRotatingLED(Instance.new("UIStroke", autoBtn))


local toggleBall = Instance.new("TextButton", screenGui)
toggleBall.Size = UDim2.new(0, 45, 0, 45)
toggleBall.Position = UDim2.new(0.8, 70, 0.5, -190)
toggleBall.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
toggleBall.Text = ""
Instance.new("UICorner", toggleBall).CornerRadius = UDim.new(1, 0)
toggleBall.ZIndex = 20

local ballStroke = Instance.new("UIStroke", toggleBall)
ballStroke.Thickness = 3
ballStroke.Color = Color3.fromRGB(255, 255, 255)
applyRotatingLED(ballStroke)

local cloudIcon = Instance.new("TextLabel", toggleBall)
cloudIcon.Size = UDim2.new(1, 0, 1, 0)
cloudIcon.BackgroundTransparency = 1
cloudIcon.Text = "☁️"
cloudIcon.TextSize = 25
cloudIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
cloudIcon.AnchorPoint = Vector2.new(0.5, 0.5)
cloudIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
cloudIcon.ZIndex = 21


local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 400, 0, 350)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.ClipsDescendants = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
mainFrame.Visible = false
mainFrame.ZIndex = 30

local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Thickness = 6
mainStroke.Color = Color3.fromRGB(255, 255, 255)
applyRotatingLED(mainStroke)

local titleLabel = Instance.new("TextLabel", mainFrame)
titleLabel.Size = UDim2.new(0, 200, 0, 40)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "SKY HUB"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 20
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
applyShine(titleLabel)
titleLabel.ZIndex = 31

local speedDisplay = Instance.new("TextLabel", mainFrame)
speedDisplay.Size = UDim2.new(0, 150, 0, 20)
speedDisplay.Position = UDim2.new(0, 150, 0, 10)
speedDisplay.BackgroundTransparency = 1
speedDisplay.Text = "Speed: 0 SPS"
speedDisplay.TextColor3 = Color3.fromRGB(255, 215, 0)
speedDisplay.Font = Enum.Font.GothamMedium
speedDisplay.TextSize = 14
speedDisplay.TextXAlignment = Enum.TextXAlignment.Left
speedDisplay.ZIndex = 31

local separatorLine = Instance.new("Frame", mainFrame)
separatorLine.Size = UDim2.new(1, 0, 0, 4)
separatorLine.Position = UDim2.new(0, 0, 0, 40)
applyShine(separatorLine)
separatorLine.ZIndex = 31

local function createOption(name, yPos)
    local label = Instance.new("TextLabel", mainFrame)
    label.Size = UDim2.new(0, 150, 0, 30)
    label.Position = UDim2.new(0, 20, 0, yPos)
    label.BackgroundTransparency = 1
    label.Text = name
    label.Font = Enum.Font.GothamBold
    label.TextSize = 16
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(255, 215, 0)
    label.ZIndex = 32

    local base = Instance.new("TextButton", mainFrame)
    base.Size = UDim2.new(0, 50, 0, 26)
    base.Position = UDim2.new(0, 320, 0, yPos + 2)
    base.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    base.Text = ""
    Instance.new("UICorner", base).CornerRadius = UDim.new(1, 0)
    base.ZIndex = 32

    local circle = Instance.new("Frame", base)
    circle.Size = UDim2.new(0, 20, 0, 20)
    circle.Position = UDim2.new(0, 3, 0.5, -10)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    circle.ZIndex = 33
    
    return base, circle
end

local infBtn, infCirc = createOption("Infinity Jump", 100)
local stealBtn, stealCirc = createOption("Auto Steal", 140)
local speedBtn, speedCirc = createOption("Speed Boost", 180)
local ragBtn, ragCirc = createOption("Anti Ragdoll", 220)
local hopBtn, hopCirc = createOption("Server Hop", 260)


local function toggleMenu()
    if not scriptRunning or isAnimating then return end
    isAnimating = true
    menuOpen = not menuOpen
    targetRotation = targetRotation + 360
    TweenService:Create(cloudIcon, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = targetRotation}):Play()
    
    if menuOpen then
        mainFrame.Visible = true
        mainFrame:TweenSize(isMinimized and UDim2.new(0, 400, 0, 40) or UDim2.new(0, 400, 0, 350), "Out", "Back", 0.4, true, function() isAnimating = false end)
    else
        mainFrame:TweenSize(UDim2.new(0, 0, 0, 0), "In", "Quad", 0.3, true, function() mainFrame.Visible = false; isAnimating = false end)
    end
end

local closeButton = Instance.new("TextButton", mainFrame)
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
closeButton.Text = "X"
Instance.new("UICorner", closeButton)
closeButton.ZIndex = 35

local minButton = Instance.new("TextButton", mainFrame)
minButton.Size = UDim2.new(0, 30, 0, 30)
minButton.Position = UDim2.new(1, -70, 0, 5)
minButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
minButton.Text = "-"
minButton.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", minButton)
minButton.ZIndex = 35

closeButton.MouseButton1Click:Connect(function()
    if isAnimating then return end
    isAnimating = true
    mainFrame:TweenSize(UDim2.new(0, 0, 0, 0), "In", "Back", 0.4, true, function()
        scriptRunning = false
        screenGui:Destroy()
    end)
end)

minButton.MouseButton1Click:Connect(function()
    if not scriptRunning or isAnimating then return end
    isMinimized = not isMinimized
    mainFrame:TweenSize(isMinimized and UDim2.new(0, 400, 0, 40) or UDim2.new(0, 400, 0, 350), "Out", "Quart", 0.3, true)
    separatorLine.Visible = not isMinimized
end)

toggleBall.MouseButton1Click:Connect(toggleMenu)


local function loadSettings()
    if isfile and isfile(fileName) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(fileName)) end)
        if success then
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

hopTextBox:GetPropertyChangedSignal("Text"):Connect(function() 
    hopTextBox.Text = hopTextBox.Text:gsub("%D+", "") 
    saveSettings() 
end)

startBtn.MouseButton1Click:Connect(function()
    hopActive = true
    local target = tonumber(hopTextBox.Text)
    if not target then statusLabel.Text = "Status: Digite um valor!"; return end
    statusLabel.Text = "Status: Verificando..."; statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    task.wait(1)
    if not hopActive then return end
    local maxFound = getHighestValue()
    if maxFound >= target then
        statusLabel.Text = "Alvo " .. formatValue(target) .. "+ Detectado!"
        statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    else
        statusLabel.Text = "Status: Pulando servidor..."; statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        doServerHop()
    end
end)

stopBtn.MouseButton1Click:Connect(function()
    hopActive = false
    statusLabel.Text = "Status: Parado Imediatamente"; statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
end)


autoBtn.MouseButton1Click:Connect(function()
    autoModeEnabled = not autoModeEnabled

    if autoModeEnabled then
        statusLabel.Text = "Auto: Ligado"
    else
        hopActive = false
        statusLabel.Text = "Auto: Desligado"
    end
end)


RunService.Heartbeat:Connect(function()
    if not scriptRunning then return end
    local t = os.clock()
    local rot = (t * 180) % 360
    for _, g in pairs(rotatingGradients) do g.Rotation = rot end
    local shineOffset = Vector2.new(-0.8 + (t * 0.4 % 1.6), 0)
    for _, g in pairs(shineGradients) do g.Offset = shineOffset end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if root and hum then
        
        if antiRagdollEnabled then
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
            if hum:GetState() == Enum.HumanoidStateType.Ragdoll or hum:GetState() == Enum.HumanoidStateType.FallingDown then 
                hum:ChangeState(Enum.HumanoidStateType.GettingUp) 
            end
            if hum.MoveDirection.Magnitude == 0 and root.AssemblyLinearVelocity.Magnitude > 20 then
                root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
        end

        speedDisplay.Text = "Speed: " .. math.floor(root.AssemblyLinearVelocity.Magnitude) .. " SPS"

        
        if speedBoostEnabled and hum.MoveDirection.Magnitude > 0 then
            local rayParam = RaycastParams.new()
            rayParam.FilterDescendantsInstances = {char}
            rayParam.FilterType = Enum.RaycastFilterType.Exclude
            local rayCast = workspace:Raycast(root.Position, hum.MoveDirection * 3, rayParam)
            if not rayCast then
                root.AssemblyLinearVelocity = Vector3.new(hum.MoveDirection.X * boostPower, root.AssemblyLinearVelocity.Y, hum.MoveDirection.Z * boostPower)
            end
        end

        
        if infJumpEnabled and spaceHeld then
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 48, root.AssemblyLinearVelocity.Z)
        end

        
        if autoStealEnabled then
            if itemSelecionado and itemSelecionado.Parent then
                itemSelecionado.HoldDuration = 0
                fireproximityprompt(itemSelecionado)
            else
                for _, d in pairs(stealCache) do
                    if d and d.Parent then 
                        d.HoldDuration = 0
                        fireproximityprompt(d) 
                    end
                end
            end
        end
    end
end)


local currentBrainrotValue = 0
local lastNotify = 0
task.spawn(function()
    while scriptRunning do
        local best = getBestBrainrot()
        if best then
            local value = parseValue(best.income)
            local needNewESP = false
            if not espGui or not espGui.Adornee or not espGui.Adornee:IsDescendantOf(workspace) or value > currentBrainrotValue then
                needNewESP = true
            end
            if needNewESP then
                if espGui then espGui:Destroy() espGui = nil end
                espGui = createBrainrotESP(best)
                currentBrainrotValue = value
            end
            if value >= 10000000 and (os.clock() - lastNotify > 10) then
                notifyLabel.Text = "💰 " .. best.name .. " | " .. best.income
                
                
                if autoModeEnabled then
                    autoModeEnabled = false
                    hopActive = false
                    statusLabel.Text = "Auto: Brainrot detectado!"
                end

                notifySound:Play()
                notifyLabel:TweenPosition(UDim2.new(0, 0, 0, 10), "Out", "Back", 0.5, true)
                task.delay(5, function()
                    notifyLabel:TweenPosition(UDim2.new(0, 0, 0, -40), "In", "Quad", 0.5, true)
                    notifyLabel.Text = ""
                end)
                lastNotify = os.clock()
            end
        else
            currentBrainrotValue = 0
            notifyLabel.Text = ""
        end
        task.wait(2)
    end
end)


UserInputService.JumpRequest:Connect(function()
    if scriptRunning and infJumpEnabled then
        spaceHeld = true
        task.wait(0.1)
        spaceHeld = false
    end
end)

UserInputService.InputBegan:Connect(function(i, g)
    if scriptRunning and not g then
        if i.KeyCode == Enum.KeyCode.LeftControl then
            toggleMenu()
        end
    end
end)


task.spawn(function()
    while scriptRunning do
        atualizarLista()
        task.wait(3)
    end
end)


task.spawn(function()
    while scriptRunning do
        if autoModeEnabled then
            hopActive = true
            doServerHop()
            task.wait(5)
            if isBrainrotNotifying() then
                autoModeEnabled = false
                hopActive = false
                statusLabel.Text = "Auto: Encontrado!"
            else
                statusLabel.Text = "Auto: Repetindo..."
            end
        end
        task.wait(1)
    end
end)


drag(mainFrame)
drag(toggleBall)
drag(selectorFrame)
drag(hopFrame)

loadSettings()
loadBlacklist()


game:GetService("TeleportService").TeleportInitFailed:Connect(function()
    task.spawn(function()
        for _, gui in pairs(playerGui:GetDescendants()) do
            if gui:IsA("TextLabel") and gui.Text:lower():find("error") then
                gui.Visible = true
                task.wait(1)
                gui.Visible = false
            end
        end
    end)
end)

task.wait(1)
toggleMenu()
