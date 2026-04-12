local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

-- // Variáveis de Estado
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local scriptRunning = true
local infJumpEnabled = false
local speedBoostEnabled = false
local autoStealEnabled = false
local antiRagdollEnabled = false
local serverHopEnabled = false
local tpToBestEnabled = true -- Agora sempre true
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
local brainrotDetectedFlag = false -- Nova flag para garantir que o celular pare

-- ============================================================
-- ANTI-BEE & ANTI-DISCO SYSTEM (SEMPRE ATIVO)
-- ============================================================

local FOV_MANAGER = {
    activeCount = 0,
    conn = nil,
    forcedFOV = 70,
}

function FOV_MANAGER:Start()
    if self.conn then return end
    
    self.conn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if cam and cam.FieldOfView ~= self.forcedFOV then
            cam.FieldOfView = self.forcedFOV
        end
    end)
end

function FOV_MANAGER:Stop()
    if self.conn then
        self.conn:Disconnect()
        self.conn = nil
    end
end

function FOV_MANAGER:Push()
    self.activeCount = self.activeCount + 1
    self:Start()
end

function FOV_MANAGER:Pop()
    if self.activeCount > 0 then
        self.activeCount = self.activeCount - 1
    end
    if self.activeCount == 0 then
        self:Stop()
    end
end

local antiBeeDiscoRunning = true -- SEMPRE ATIVO
local antiBeeDiscoConnections = {}
local originalMoveFunction = nil
local controlsProtected = false

local BAD_LIGHTING_NAMES = {
    Blue = true,
    DiscoEffect = true,
    BeeBlur = true,
    ColorCorrection = true,
}

local function antiBeeDiscoNuke(obj)
    if not obj or not obj.Parent then return end
    if BAD_LIGHTING_NAMES[obj.Name] then
        pcall(function()
            obj:Destroy()
        end)
    end
end

local function antiBeeDiscoDisconnectAll()
    for _, conn in ipairs(antiBeeDiscoConnections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    antiBeeDiscoConnections = {}
end

-- Protect player controls from inversion
local function protectControls()
    if controlsProtected then return end
    
    pcall(function()
        local PlayerScripts = player.PlayerScripts
        local PlayerModule = PlayerScripts:FindFirstChild("PlayerModule")
        if not PlayerModule then return end
        
        local Controls = require(PlayerModule):GetControls()
        if not Controls then return end
        
        -- Store original move function
        if not originalMoveFunction then
            originalMoveFunction = Controls.moveFunction
        end
        
        -- Create protected wrapper that prevents control inversion
        local function protectedMoveFunction(self, moveVector, relativeToCamera)
            -- Call original function with original parameters (no negation)
            if originalMoveFunction then
                originalMoveFunction(self, moveVector, relativeToCamera)
            end
        end
        
        -- Monitor for control hijacking
        local controlCheckConn = RunService.Heartbeat:Connect(function()
            if not antiBeeDiscoRunning then return end
            
            -- Restore controls if they've been modified
            if Controls.moveFunction ~= protectedMoveFunction then
                Controls.moveFunction = protectedMoveFunction
            end
        end)
        
        table.insert(antiBeeDiscoConnections, controlCheckConn)
        
        -- Set protected function
        Controls.moveFunction = protectedMoveFunction
        controlsProtected = true
    end)
end

-- Restore original controls (mantido para compatibilidade, mas não usado pois nunca desativa)
local function restoreControls()
    if not controlsProtected then return end
    
    pcall(function()
        local PlayerScripts = player.PlayerScripts
        local PlayerModule = PlayerScripts:FindFirstChild("PlayerModule")
        if not PlayerModule then return end
        
        local Controls = require(PlayerModule):GetControls()
        if not Controls or not originalMoveFunction then return end
        
        Controls.moveFunction = originalMoveFunction
        controlsProtected = false
    end)
end

-- Block buzzing sound
local function blockBuzzingSound()
    pcall(function()
        local PlayerScripts = player.PlayerScripts
        local beeScript = PlayerScripts:FindFirstChild("Bee", true)
        if beeScript then
            local buzzing = beeScript:FindFirstChild("Buzzing")
            if buzzing and buzzing:IsA("Sound") then
                buzzing:Stop()
                buzzing.Volume = 0
            end
        end
    end)
end

-- Inicializa o Anti-Bee & Anti-Disco (sempre ativo)
local function initAntiBeeDisco()
    -- Nuke existing bad effects
    for _, inst in ipairs(Lighting:GetDescendants()) do
        antiBeeDiscoNuke(inst)
    end
    
    -- Monitor for new effects
    table.insert(antiBeeDiscoConnections, Lighting.DescendantAdded:Connect(function(obj)
        if not antiBeeDiscoRunning then return end
        antiBeeDiscoNuke(obj)
    end))
    
    -- Protect controls from inversion
    protectControls()
    
    -- Block buzzing sound
    table.insert(antiBeeDiscoConnections, RunService.Heartbeat:Connect(function()
        if not antiBeeDiscoRunning then return end
        blockBuzzingSound()
    end))
    
    FOV_MANAGER:Push()
    
    print("[SkyHub] Anti-Bee & Anti-Disco ativado permanentemente")
end

-- ============================================================

-- Variável para armazenar o JobId atual
local currentServerJobId = nil

-- ===== COORDENADAS DAS ZONAS DE COLETA (preenchidas) =====
local basesColeta = {
    Vector3.new(-477.76, 12.96, 222.40),  -- Base 1
    Vector3.new(-477.99, 12.96, 113.67),  -- Base 2
    Vector3.new(-477.77, 12.90, 6.08),    -- Base 3
    Vector3.new(-477.86, 12.96, -100.56), -- Base 4
    Vector3.new(-341.44, 12.96, -101.09), -- Base 5
    Vector3.new(-341.43, 12.96, 5.70),    -- Base 6
    Vector3.new(-341.42, 12.96, 113.54),  -- Base 7
    Vector3.new(-341.21, 12.96, 221.10),  -- Base 8
}
-- ========================================================

-- // Sistema de Arquivos e Configurações
local folderName = "SkyHub"
local fileName = folderName .. "/Config.json"
local jobIdFile = folderName .. "/CurrentJobId.txt"

if makefolder and not isfolder(folderName) then makefolder(folderName) end

local function saveJobIdToFile(jobId)
    if writefile then
        writefile(jobIdFile, jobId or "")
        print("[SkyHub] 💾 JobId salvo no arquivo: " .. (jobId or "vazio"))
    end
end

local function loadJobIdFromFile()
    if isfile and isfile(jobIdFile) then
        local data = readfile(jobIdFile)
        if data and data ~= "" then
            currentServerJobId = data
            print("[SkyHub] 📂 JobId carregado do arquivo: " .. currentServerJobId)
            return currentServerJobId
        end
    end
    return nil
end

-- ==================== DISCORD WEBHOOK ====================
local discordWebhookEnabled = true
local webhookUrl = "https://discord.com/api/webhooks/1492197458950754527/JXmigrKS6vN7BYD-72Hb6ZlT6DBa8q5vLgBy4u0qMMCEdPUFpbn1CSh0meDEFYdeiuXb"

local function sendBrainrotToDiscord(bestData)
    if not discordWebhookEnabled or not bestData then return end
    local jobIdToSend = currentServerJobId or loadJobIdFromFile()
    if not jobIdToSend or jobIdToSend == "" then
        print("[SkyHub] ⚠️ Nenhum JobId salvo para este servidor! Não vai enviar.")
        return
    end
    print("[SkyHub] 💰 Brainrot detectado! Enviando para o Discord com JobId: " .. jobIdToSend)

    local message = "💰 **Brainrot Detectado!**\n" ..
        "**Nome:** " .. (bestData.name or "Brainrot") .. "\n" ..
        "**Valor:** " .. (bestData.income or "$0/s") .. "\n\n" ..
        "**ID do Servidor**\n```\n" .. jobIdToSend .. "\n```\n\n" ..
        "**Comando para Rejoin (PC/Mobile)**\n```lua\ngame:GetService(\"TeleportService\"):TeleportToPlaceInstance(" .. game.PlaceId .. ", \"" .. jobIdToSend .. "\", game.Players.LocalPlayer)\n```\n\n" ..
        "**📱 ID do Servidor (Mobile)**\n`" .. jobIdToSend .. "`"

    local data = { ["content"] = message }
    local jsonData = HttpService:JSONEncode(data)
    local req = syn and syn.request or http_request or request
    if not req then warn("[SkyHub] ❌ Seu executor não suporta HTTP Requests") return end

    local success, err = pcall(function()
        req({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = jsonData
        })
    end)
    if success then
        print("[SkyHub] ✅ Webhook enviado com sucesso! ID: " .. jobIdToSend)
    else
        warn("[SkyHub] ❌ Erro ao enviar: " .. tostring(err))
    end
end

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

-- Blacklist
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

-- Interface Base
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

-- ==================== SISTEMA DE KICK ====================
local kickFrame = nil
local kickEnabled = false

local function kickSelf()
    player:Kick("Você foi kickado!")
end

local function createKickWidget()
    if kickFrame then return end
    
    kickFrame = Instance.new("Frame", screenGui)
    kickFrame.Name = "KickFrame"
    kickFrame.Size = UDim2.new(0, 200, 0, 50)
    kickFrame.Position = UDim2.new(0.8, 0, 0.5, -260)
    kickFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    kickFrame.BackgroundTransparency = 0
    kickFrame.Visible = true
    kickFrame.ZIndex = 100
    
    local corner = Instance.new("UICorner", kickFrame)
    corner.CornerRadius = UDim.new(0, 12)
    
    local kickStroke = Instance.new("UIStroke", kickFrame)
    kickStroke.Thickness = 2
    kickStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    kickStroke.Color = Color3.fromRGB(255, 255, 255)
    kickStroke.ZIndex = 101
    
    local ledGradient = Instance.new("UIGradient", kickStroke)
    ledGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 15)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 15))
    })
    table.insert(rotatingGradients, ledGradient)
    
    local kickText = Instance.new("TextLabel", kickFrame)
    kickText.Size = UDim2.new(0, 50, 1, 0)
    kickText.Position = UDim2.new(0, 10, 0, 0)
    kickText.BackgroundTransparency = 1
    kickText.Text = "Kick"
    kickText.TextColor3 = Color3.fromRGB(255, 215, 0)
    kickText.Font = Enum.Font.GothamBold
    kickText.TextSize = 16
    kickText.TextXAlignment = Enum.TextXAlignment.Left
    kickText.TextYAlignment = Enum.TextYAlignment.Center
    kickText.ZIndex = 102
    
    local toggleContainer = Instance.new("Frame", kickFrame)
    toggleContainer.Size = UDim2.new(0, 60, 0, 30)
    toggleContainer.Position = UDim2.new(0, 60, 0.5, -15)
    toggleContainer.BackgroundTransparency = 1
    toggleContainer.ZIndex = 102
    
    local toggleBg = Instance.new("Frame", toggleContainer)
    toggleBg.Size = UDim2.new(1, 0, 1, 0)
    toggleBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    toggleBg.BorderSizePixel = 0
    toggleBg.ZIndex = 102
    
    local toggleCorner = Instance.new("UICorner", toggleBg)
    toggleCorner.CornerRadius = UDim.new(1, 0)
    
    local toggleCircle = Instance.new("Frame", toggleBg)
    toggleCircle.Size = UDim2.new(0, 24, 0, 24)
    toggleCircle.Position = UDim2.new(0, 3, 0.5, -12)
    toggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    toggleCircle.BorderSizePixel = 0
    toggleCircle.ZIndex = 103
    
    local toggleCircleCorner = Instance.new("UICorner", toggleCircle)
    toggleCircleCorner.CornerRadius = UDim.new(1, 0)
    
    local toggleButton = Instance.new("TextButton", toggleContainer)
    toggleButton.Size = UDim2.new(1, 0, 1, 0)
    toggleButton.BackgroundTransparency = 1
    toggleButton.Text = ""
    toggleButton.ZIndex = 102
    
    local keybindLabel = Instance.new("TextLabel", kickFrame)
    keybindLabel.Size = UDim2.new(0, 80, 1, 0)
    keybindLabel.Position = UDim2.new(1, -85, 0, 0)
    keybindLabel.BackgroundTransparency = 1
    keybindLabel.Text = "KeyBind: R"
    keybindLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    keybindLabel.Font = Enum.Font.GothamMedium
    keybindLabel.TextSize = 12
    keybindLabel.TextXAlignment = Enum.TextXAlignment.Right
    keybindLabel.TextYAlignment = Enum.TextYAlignment.Center
    keybindLabel.ZIndex = 102
    
    local function updateToggleVisual()
        if kickEnabled then
            toggleBg.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
            toggleCircle.Position = UDim2.new(1, -27, 0.5, -12)
        else
            toggleBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            toggleCircle.Position = UDim2.new(0, 3, 0.5, -12)
        end
    end
    
    toggleButton.MouseButton1Click:Connect(function()
        kickEnabled = not kickEnabled
        updateToggleVisual()
        if kickEnabled then
            kickSelf()
        end
    end)
    
    updateToggleVisual()
    
    local dragging, dragInput, dragStart, startPos
    kickFrame.InputBegan:Connect(function(input)
        if scriptRunning and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true
            dragStart = input.Position
            startPos = kickFrame.Position
        end
    end)
    
    kickFrame.InputChanged:Connect(function(input)
        if scriptRunning and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            dragInput = input
        end
    end)
    
    RunService.RenderStepped:Connect(function()
        if scriptRunning and dragging and dragInput then
            local delta = dragInput.Position - dragStart
            kickFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Funções de cálculo
local function parseValue(text)
    text = text:lower()
    local num = tonumber(text:match("[%d%.]+"))
    if not num then return 0 end
    if text:match("%d+%.?%d*%s*k") then num = num * 1000
    elseif text:match("%d+%.?%d*%s*m") then num = num * 1000000
    elseif text:match("%d+%.?%d*%s*b") then num = num * 1000000000 end
    return num
end

local function formatValue(n)
    if n >= 1000000000 then return string.format("%.1fb", n/1000000000)
    elseif n >= 1000000 then return string.format("%.1fm", n/1000000)
    elseif n >= 1000 then return string.format("%.1fk", n/1000)
    else return tostring(n) end
end

-- ===== DETECÇÃO DE BRAINROT (retorna BasePart) =====
local function getBestBrainrot()
    local highest = 0
    local bestData = nil
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name:lower():find("overhead") then
            local name, income, attachedPart
            for _, gui in pairs(obj:GetDescendants()) do
                if gui:IsA("TextLabel") then
                    local txt = gui.Text
                    if txt:find("%$") and (txt:lower():find("/s") or txt:lower():find("sec")) then
                        income = txt
                        local val = parseValue(txt)
                        if val > highest then
                            local part = nil
                            local current = obj
                            while current do
                                if current:IsA("BasePart") then
                                    part = current
                                    break
                                end
                                current = current.Parent
                            end
                            if part then
                                highest = val
                                attachedPart = part
                                bestData = {
                                    overhead = obj,
                                    name = name or "Brainrot",
                                    income = income,
                                    value = val,
                                    part = part
                                }
                            end
                        end
                    elseif not txt:find("%$") and #txt > 2 and not name then
                        name = txt
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

-- Server Hop (MODIFICADO - comportamento do script simples)
local function doServerHop()
    if not hopActive then return end
    
    statusLabel.Text = "Status: Iniciando busca..."
    
    local placeId = game.PlaceId
    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    local success, content = pcall(function()
        return game:HttpGet(url)
    end)
    
    if not success or not content or not hopActive then
        statusLabel.Text = "Status: Erro ou Parado"
        return
    end
    
    local decoded = HttpService:JSONDecode(content)
    
    if decoded and decoded.data then
        for _, server in ipairs(decoded.data) do
            if not hopActive then break end
            
            if server.playing < server.maxPlayers 
            and server.id ~= game.JobId 
            and not isBlacklisted(server.id) then
                
                addServerToBlacklist(server.id)
                statusLabel.Text = "Status: Teleportando..."
                currentServerJobId = server.id
                saveJobIdToFile(currentServerJobId)
                
                pcall(function()
                    if autoModeEnabled then
                        writefile(folderName .. "/AutoMode.txt", "true")
                    end
                    TeleportService:TeleportToPlaceInstance(placeId, server.id, player)
                end)
                
                task.wait(2)
            end
        end
        
        if hopActive then
            statusLabel.Text = "Status: Nenhum serv. livre"
            if autoModeEnabled and hopActive then
                task.wait(2)
                doServerHop()
            end
        end
    else
        statusLabel.Text = "Status: Lista vazia (tentando novamente...)"
        if autoModeEnabled and hopActive then
            task.wait(2)
            doServerHop()
        end
    end
end

-- ===== FUNÇÕES AUXILIARES DO TP TO BEST =====
local function getHRP()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
end

local function getPlotFromPart(part)
    if not part then return nil end
    local current = part
    if part:IsA("BasePart") then current = part.Parent end
    while current do
        if current.Name and current:IsA("Model") and current:FindFirstChild("AnimalPodiums") then
            return current
        end
        current = current.Parent
    end
    return nil
end

-- ===== FUNÇÃO PRINCIPAL DE TELEPORTE (usa coordenada fixa da base mais próxima) =====
local function teleportToPosition(targetPart, plot)
    if not targetPart or not targetPart:IsA("BasePart") then
        print("[Teleporte] Erro: targetPart não é uma BasePart válida.")
        return false
    end

    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        print("[Teleporte] Personagem não encontrado")
        return false
    end
    local humanoid = character:FindFirstChild("Humanoid")
    local hrp = character.HumanoidRootPart
    if not humanoid or not hrp then return false end

    -- Equipa o tapete se disponível
    local carpet = player.Backpack:FindFirstChild("Flying Carpet")
    if carpet then humanoid:EquipTool(carpet) end

    -- Obtém a posição do plot (centro da base onde o brainrot está)
    local plotPos = plot and plot:GetPivot().Position or targetPart.Position

    -- Encontra a base mais próxima do brainrot usando as coordenadas da tabela
    local closestBasePos = nil
    local closestDist = math.huge
    for _, basePos in pairs(basesColeta) do
        local dist = (plotPos - basePos).Magnitude
        if dist < closestDist then
            closestDist = dist
            closestBasePos = basePos
        end
    end

    if not closestBasePos then
        print("[Teleporte] Nenhuma base configurada! Usando posição do plot + offset.")
        local forward = plot and plot:GetPivot().LookVector or Vector3.new(0, 0, 1)
        closestBasePos = plotPos + forward * 8
    end

    -- Ajusta a altura para o chão (raycast)
    local rayOrigin = closestBasePos + Vector3.new(0, 50, 0)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = { workspace:FindFirstChild("Map") }
    rayParams.FilterType = Enum.RaycastFilterType.Whitelist
    local result = workspace:Raycast(rayOrigin, Vector3.new(0, -100, 0), rayParams)
    local groundY = result and result.Position.Y or (closestBasePos.Y - 5)
    local finalPos = Vector3.new(closestBasePos.X, groundY + 3, closestBasePos.Z)

    -- Pequeno pulo para evitar colisão
    local state = humanoid:GetState()
    if state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        task.wait(0.05)
    end
    hrp.Velocity = Vector3.new(hrp.Velocity.X, 200, hrp.Velocity.Z)
    task.wait(0.1)

    -- Teleporta para a coordenada da Zona de Coleta, virado para o centro da base
    local lookPos = plot and plot:GetPivot().Position or targetPart.Position
    hrp.CFrame = CFrame.new(finalPos, lookPos)

    print(string.format("[Teleporte] Teleportado para Zona de Coleta da base mais próxima em %s", tostring(finalPos)))
    return true
end

-- Função principal de teleporte (exportada)
local function teleportToBestBrainrot()
    local best = getBestBrainrot()
    if not best or not best.part then
        print("[Teleporte] Nenhum brainrot encontrado no servidor.")
        return false
    end

    local plot = getPlotFromPart(best.part)
    print(string.format("[Teleporte] Melhor brainrot: %s (%s) - Plot: %s", 
        best.name or "?", best.income, plot and plot.Name or "desconhecido"))

    local success = teleportToPosition(best.part, plot)
    if success then
        print("[Teleporte] Teleportado com sucesso para a Zona de Coleta!")
    else
        print("[Teleporte] Falha ao teleportar.")
    end
    return success
end

_G.teleportToBestBrainrot = teleportToBestBrainrot

-- ===== FIM DAS FUNÇÕES TP TO BEST =====

-- Efeitos Visuais (mantido igual)
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

-- Helpers da Interface
local function handleToggle(btn, circle, state)
    TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = state and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(50, 50, 50) }):Play()
    TweenService:Create(circle, TweenInfo.new(0.2), { Position = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10) }):Play()
end

local function drag(o)
    local dragging, dragInput, dragStart, startPos
    o.InputBegan:Connect(function(input)
        if scriptRunning and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true
            dragStart = input.Position
            startPos = o.Position
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
            o.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Janela Auto Steal Selector
selectorFrame = Instance.new("Frame", screenGui)
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
                        if itemSelecionado == d then
                            itemSelecionado = nil
                        else
                            itemSelecionado = d
                        end
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
        if child:IsA("TextButton") and not itensNoMapa[child.Name] then
            child:Destroy()
        end
    end
end

-- Janela Server Hop
hopFrame = Instance.new("Frame", screenGui)
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

-- Botão Flutuante
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

-- Janela Principal
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
-- Botão do TP to Best foi removido pois agora está sempre ligado

-- ====================== ANTI RAGDOLL CORRIGIDO ======================
local antiRagdollMode = nil
local ragdollConnections = {}
local cachedCharData = {}
local lastCheckTime = 0
local CHECK_INTERVAL = 0.1

local function cacheCharacterData()
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    cachedCharData = { 
        character = char, 
        humanoid = hum, 
        root = root,
        lastPosition = root.Position,
        lastState = hum:GetState()
    }
    return true
end

local function disconnectAll()
    for _, conn in ipairs(ragdollConnections) do
        if typeof(conn) == "RBXScriptConnection" then 
            pcall(function() conn:Disconnect() end) 
        end
    end
    ragdollConnections = {}
end

local function isRagdolled()
    if not cachedCharData.humanoid then 
        cacheCharacterData()
        if not cachedCharData.humanoid then return false end
    end
    
    local hum = cachedCharData.humanoid
    local state = hum:GetState()
    
    local ragdollStates = { 
        [Enum.HumanoidStateType.Physics] = true, 
        [Enum.HumanoidStateType.Ragdoll] = true, 
        [Enum.HumanoidStateType.FallingDown] = true 
    }
    
    if ragdollStates[state] then 
        return true 
    end
    
    local endTime = player:GetAttribute("RagdollEndTime")
    if endTime then
        local now = workspace:GetServerTimeNow()
        if (endTime - now) > 0 then return true end
    end
    
    return false
end

local function removeRagdollConstraints()
    if not cachedCharData.character then 
        cacheCharacterData()
        if not cachedCharData.character then return end
    end
    
    for _, descendant in ipairs(cachedCharData.character:GetDescendants()) do
        if descendant:IsA("BallSocketConstraint") or 
           (descendant:IsA("Attachment") and descendant.Name:find("RagdollAttachment")) then
            pcall(function() descendant:Destroy() end)
        end
    end
end

local function forceExitRagdoll()
    if not cachedCharData.humanoid or not cachedCharData.root then 
        cacheCharacterData()
        if not cachedCharData.humanoid or not cachedCharData.root then return end
    end
    
    local hum = cachedCharData.humanoid
    local root = cachedCharData.root
    
    pcall(function() 
        player:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow()) 
    end)
    
    if hum.Health > 0 then 
        hum:ChangeState(Enum.HumanoidStateType.Running) 
    end
    
    root.Anchored = false
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    task.wait(0.05)
end

local function antiRagdollLoop()
    while antiRagdollMode == "v1" and scriptRunning do
        task.wait(CHECK_INTERVAL)
        
        if not player.Character or not player.Character.Parent then
            cacheCharacterData()
            task.wait(0.5)
            goto continue
        end
        
        local now = tick()
        if now - lastCheckTime > 2 then
            cacheCharacterData()
            lastCheckTime = now
        end
        
        if not cachedCharData.humanoid or not cachedCharData.root then
            cacheCharacterData()
            if not cachedCharData.humanoid or not cachedCharData.root then
                goto continue
            end
        end
        
        if isRagdolled() then
            removeRagdollConstraints()
            forceExitRagdoll()
        end
        
        ::continue::
    end
end

local function setupCameraBinding()
    local conn = RunService.RenderStepped:Connect(function()
        if antiRagdollMode ~= "v1" then return end
        if not cachedCharData.humanoid then 
            cacheCharacterData()
            if not cachedCharData.humanoid then return end
        end
        local cam = workspace.CurrentCamera
        if cam and cachedCharData.humanoid and cam.CameraSubject ~= cachedCharData.humanoid then
            cam.CameraSubject = cachedCharData.humanoid
        end
    end)
    table.insert(ragdollConnections, conn)
end

local function monitorTeleports()
    local lastPosition = nil
    
    while antiRagdollMode == "v1" and scriptRunning do
        task.wait(0.5)
        
        local root = cachedCharData.root
        if root then
            local currentPos = root.Position
            
            if lastPosition and (currentPos - lastPosition).Magnitude > 100 then
                print("[Anti-Ragdoll] Teleporte detectado! Recacheando...")
                task.wait(0.3)
                cacheCharacterData()
            end
            
            lastPosition = currentPos
        end
    end
end

local function onCharacterAdded(char)
    print("[Anti-Ragdoll] Personagem recarregado, reiniciando proteção...")
    task.wait(0.5)
    
    if not antiRagdollMode or not scriptRunning then return end
    
    disconnectAll()
    
    if cacheCharacterData() then
        if antiRagdollMode == "v1" then
            setupCameraBinding()
            task.spawn(antiRagdollLoop)
            task.spawn(monitorTeleports)
            print("[Anti-Ragdoll] Proteção restaurada com sucesso!")
        end
    else
        print("[Anti-Ragdoll] Falha ao recachear personagem, tentando novamente...")
        task.wait(1)
        onCharacterAdded(char)
    end
end

local function enableAntiRagdoll()
    if antiRagdollMode == "v1" then return false end
    if antiRagdollMode then disableAntiRagdoll() end
    
    print("[Anti-Ragdoll] Ativando proteção...")
    
    if not cacheCharacterData() then 
        print("[Anti-Ragdoll] Falha ao cachear personagem")
        return false 
    end
    
    antiRagdollMode = "v1"
    
    local charConn = player.CharacterAdded:Connect(onCharacterAdded)
    table.insert(ragdollConnections, charConn)
    
    setupCameraBinding()
    task.spawn(antiRagdollLoop)
    task.spawn(monitorTeleports)
    
    print("[Anti-Ragdoll] Proteção ativada com sucesso!")
    return true
end

local function disableAntiRagdoll()
    if not antiRagdollMode then return false end
    
    print("[Anti-Ragdoll] Desativando proteção...")
    antiRagdollMode = nil
    disconnectAll()
    cachedCharData = {}
    return true
end

-- Funções de Controle de Janela
local function toggleMenu()
    if not scriptRunning or isAnimating then return end
    isAnimating = true
    menuOpen = not menuOpen
    targetRotation = targetRotation + 360
    TweenService:Create(cloudIcon, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = targetRotation }):Play()
    if menuOpen then
        mainFrame.Visible = true
        mainFrame:TweenSize(isMinimized and UDim2.new(0, 400, 0, 40) or UDim2.new(0, 400, 0, 350), "Out", "Back", 0.4, true, function() isAnimating = false end)
    else
        mainFrame:TweenSize(UDim2.new(0, 0, 0, 0), "In", "Quad", 0.3, true, function() mainFrame.Visible = false isAnimating = false end)
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

-- Carregamento e Conexões
local function loadSettings()
    if isfile and isfile(fileName) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(fileName)) end)
        if success then
            infJumpEnabled = data.infJump or false
            handleToggle(infBtn, infCirc, infJumpEnabled)
            speedBoostEnabled = data.speedBoost or false
            handleToggle(speedBtn, speedCirc, speedBoostEnabled)
            autoStealEnabled = data.autoSteal or false
            handleToggle(stealBtn, stealCirc, autoStealEnabled)
            selectorFrame.Visible = autoStealEnabled
            antiRagdollEnabled = data.antiRagdoll or false
            handleToggle(ragBtn, ragCirc, antiRagdollEnabled)
            if antiRagdollEnabled then enableAntiRagdoll() end
            serverHopEnabled = data.serverHop or false
            handleToggle(hopBtn, hopCirc, serverHopEnabled)
            hopFrame.Visible = serverHopEnabled
            hopTextBox.Text = data.hopValue or ""
        end
    end
end

infBtn.MouseButton1Click:Connect(function()
    infJumpEnabled = not infJumpEnabled
    handleToggle(infBtn, infCirc, infJumpEnabled)
    saveSettings()
end)

stealBtn.MouseButton1Click:Connect(function()
    autoStealEnabled = not autoStealEnabled
    handleToggle(stealBtn, stealCirc, autoStealEnabled)
    selectorFrame.Visible = autoStealEnabled
    saveSettings()
end)

speedBtn.MouseButton1Click:Connect(function()
    speedBoostEnabled = not speedBoostEnabled
    handleToggle(speedBtn, speedCirc, speedBoostEnabled)
    saveSettings()
end)

ragBtn.MouseButton1Click:Connect(function()
    antiRagdollEnabled = not antiRagdollEnabled
    handleToggle(ragBtn, ragCirc, antiRagdollEnabled)
    if antiRagdollEnabled then
        enableAntiRagdoll()
    else
        disableAntiRagdoll()
    end
    saveSettings()
end)

hopBtn.MouseButton1Click:Connect(function()
    serverHopEnabled = not serverHopEnabled
    handleToggle(hopBtn, hopCirc, serverHopEnabled)
    hopFrame.Visible = serverHopEnabled
    saveSettings()
end)

hopTextBox:GetPropertyChangedSignal("Text"):Connect(function()
    hopTextBox.Text = hopTextBox.Text:gsub("%D+", "")
    saveSettings()
end)

startBtn.MouseButton1Click:Connect(function()
    hopActive = true
    brainrotDetectedFlag = false
    local target = tonumber(hopTextBox.Text)
    if not target then statusLabel.Text = "Status: Digite um valor!" return end
    statusLabel.Text = "Status: Verificando..."
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    task.wait(1)
    if not hopActive then return end
    local maxFound = getHighestValue()
    if maxFound >= target then
        statusLabel.Text = "Alvo " .. formatValue(target) .. "+ Detectado!"
        statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    else
        statusLabel.Text = "Status: Pulando servidor..."
        statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        doServerHop()
    end
end)

stopBtn.MouseButton1Click:Connect(function()
    hopActive = false
    brainrotDetectedFlag = false
    statusLabel.Text = "Status: Parado Imediatamente"
    statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
end)

autoBtn.MouseButton1Click:Connect(function()
    autoModeEnabled = not autoModeEnabled
    brainrotDetectedFlag = false
    if autoModeEnabled then
        statusLabel.Text = "Auto: Ligado"
        hopActive = true
        doServerHop()
    else
        hopActive = false
        statusLabel.Text = "Auto: Desligado"
    end
end)

-- Loop Principal (Heartbeat)
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
        speedDisplay.Text = "Speed: " .. math.floor(root.AssemblyLinearVelocity.Magnitude) .. " SPS"

        if speedBoostEnabled and hum.MoveDirection.Magnitude > 0 then
            local rayParam = RaycastParams.new()
            rayParam.FilterDescendantsInstances = {char}
            rayParam.FilterType = Enum.RaycastFilterType.Exclude
            local rayCast = workspace:Raycast(root.Position, hum.MoveDirection * 3, rayParam)
            if not rayCast then
                root.AssemblyLinearVelocity = Vector3.new(
                    hum.MoveDirection.X * boostPower,
                    root.AssemblyLinearVelocity.Y,
                    hum.MoveDirection.Z * boostPower
                )
            end
        end

        if infJumpEnabled and spaceHeld then
            root.AssemblyLinearVelocity = Vector3.new(
                root.AssemblyLinearVelocity.X, 48, root.AssemblyLinearVelocity.Z
            )
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

-- Loop de Detecção de Brainrot
local currentBrainrotValue = 0
local lastNotify = 0
local lastNotifiedBrainrot = nil

loadJobIdFromFile()

task.spawn(function()
    while scriptRunning do
        local best = getBestBrainrot()
        if best then
            local value = best.value or parseValue(best.income)
            local needNewESP = false
            if not espGui or not espGui.Adornee or not espGui.Adornee:IsDescendantOf(workspace) or value > currentBrainrotValue then
                needNewESP = true
            end

            if needNewESP then
                if espGui then 
                    espGui:Destroy() 
                    espGui = nil 
                end
                espGui = createBrainrotESP(best)
                currentBrainrotValue = value
            end

            local brainrotId = (best.name or "") .. "|" .. (best.income or "")

            if value >= 10000000 and (os.clock() - lastNotify > 10) then
                if brainrotId ~= lastNotifiedBrainrot then
                    notifyLabel.Text = "💰 " .. best.name .. " | " .. best.income
                    
                    if autoModeEnabled or hopActive then
                        autoModeEnabled = false
                        hopActive = false
                        brainrotDetectedFlag = true
                        statusLabel.Text = "Auto: Brainrot detectado!"
                        print("[SkyHub] Brainrot detectado! Auto Mode e Server Hop desativados.")
                    end
                    
                    notifySound:Play()
                    notifyLabel:TweenPosition(UDim2.new(0, 0, 0, 10), "Out", "Back", 0.5, true)
                    
                    sendBrainrotToDiscord(best)
                    
                    lastNotifiedBrainrot = brainrotId
                    
                    task.delay(5, function()
                        if notifyLabel then
                            notifyLabel:TweenPosition(UDim2.new(0, 0, 0, -40), "In", "Quad", 0.5, true)
                            notifyLabel.Text = ""
                        end
                    end)
                    lastNotify = os.clock()
                end
            end
        else
            currentBrainrotValue = 0
            if notifyLabel then notifyLabel.Text = "" end
        end
        task.wait(2)
    end
end)

-- Input Events
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
        if i.KeyCode == Enum.KeyCode.R then
            kickSelf()
        end
    end
end)

-- Loop de Atualização da Lista
task.spawn(function()
    while scriptRunning do
        atualizarLista()
        task.wait(3)
    end
end)

-- Inicialização Final
drag(mainFrame)
drag(toggleBall)
drag(selectorFrame)
drag(hopFrame)

loadSettings()
loadBlacklist()
createKickWidget()

-- Inicializa o Anti-Bee & Anti-Disco (SEMPRE ATIVO)
initAntiBeeDisco()

-- Execução automática do TP to Best (SEMPRE ATIVO)
local function autoTpToBest()
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        player.CharacterAdded:Wait()
        task.wait(1)
    end
    task.wait(2)
    teleportToBestBrainrot()
end

task.spawn(autoTpToBest)

player.CharacterAdded:Connect(function()
    task.wait(2)
    teleportToBestBrainrot()
end)

task.spawn(function()
    if isfile and isfile(folderName .. "/AutoMode.txt") then
        local data = readfile(folderName .. "/AutoMode.txt")
        if data == "true" then
            autoModeEnabled = true
            statusLabel.Text = "Auto: Retomado"
            pcall(function() delfile(folderName .. "/AutoMode.txt") end)
            repeat task.wait() until player.Character
            task.wait(5)
            if brainrotDetectedFlag or notifyLabel.Text ~= "" then
                autoModeEnabled = false
                hopActive = false
                statusLabel.Text = "Auto: Encontrado!"
            else
                statusLabel.Text = "Auto: Continuando..."
                hopActive = true
                doServerHop()
            end
        end
    end
end)

task.spawn(function()
    while scriptRunning do
        pcall(function()
            local coreGui = game:GetService("CoreGui")
            for _, v in pairs(coreGui:GetDescendants()) do
                if v:IsA("TextLabel") then
                    local txt = v.Text:lower()
                    if txt:find("full") or txt:find("cheio") or txt:find("error") or txt:find("erro") then
                        v.Visible = false
                    end
                end
            end
        end)
        task.wait(1)
    end
end)

task.wait(1)
toggleMenu()

print("[SkyHub] Carregado com sucesso - TP to Best SEMPRE ATIVO!")
print("[SkyHub] Anti-Bee & Anti-Disco ATIVADO permanentemente!")
print("[SkyHub] Anti-Ragdoll CORRIGIDO - funciona mesmo após teleportes!")
